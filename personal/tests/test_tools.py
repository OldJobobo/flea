"""Repository-local regression tests; no live desktop preferences are touched."""
from argparse import Namespace
from pathlib import Path
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

PERSONAL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PERSONAL))
import common
import bundles
import desktop
import workflow


class Tools(unittest.TestCase):
    def setUp(self):
        scratch = PERSONAL.parent / ".local-builds/tmp"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.store = self.root / ".local-builds"
        self.patches = []
        for module in (common, bundles, desktop, workflow):
            for name, value in (("ROOT", self.root), ("STORE", self.store)):
                if hasattr(module, name):
                    item = patch.object(module, name, value)
                    item.start()
                    self.patches.append(item)
                    self.addCleanup(item.stop)
        common.initialize()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.root / ".gitignore").write_text("/.local-builds/\n/.personal-worktrees/\n/target/\n")
        self.git("add", ".gitignore")
        self.git("commit", "-m", "initial")
        self.git("tag", "v0.0.1")
        self.git("update-ref", "refs/remotes/upstream/main", "HEAD")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, stderr=subprocess.DEVNULL, text=True).strip()

    def bundle(self, name="a" * 40):
        path = self.store / "releases" / name
        for leaf in ("bin/flea", "ui/boot/shell.qml", "shelf/manifest.json", *[f"tools/{h}" for h in bundles.HELPERS]):
            item = path / leaf
            item.parent.mkdir(parents=True, exist_ok=True)
            item.write_text("fixture\n")
        for leaf in bundles.UI_LINKS:
            (path / leaf).mkdir()
        files = bundles.fingerprints(path)
        common.atomic_json(path / "manifest.json", {"commit": name, "version": "fixture", "checks": "quick", "files": files})
        common.atomic_json(self.store / "verification" / f"{name}.json", {"files": files, "smoke_passed": True})
        return path

    def test_selection_cannot_escape_release_directory(self):
        (self.store / "current").symlink_to(self.root)
        with self.assertRaises(common.Refusal):
            bundles.selected()

    def test_environment_pins_all_runtime_assets_and_isolates_state(self):
        bundle = self.bundle()
        env = common.environment(bundle)
        self.assertEqual(env["FLEA_BIN"], str(bundle / "bin/flea"))
        self.assertEqual(env["FLEA_UI"], str(bundle / "ui"))
        self.assertEqual(env["FLEA_UDISKS"], str(bundle / "tools/flea-udisks"))
        self.assertEqual(env["FLEA_GIO_AUTH"], str(bundle / "tools/flea-gio-auth"))
        self.assertEqual(env["FLEA_SHELF"], str(bundle / "shelf"))
        self.assertEqual(env["XDG_STATE_HOME"], str(self.store / "profiles/daily/state"))
        self.assertEqual(env.get("HOME"), os.environ.get("HOME"))
        self.assertEqual(env.get("XDG_CONFIG_HOME"), os.environ.get("XDG_CONFIG_HOME"))

    def test_bundle_detects_modified_ui(self):
        path = self.bundle()
        bundles.validate(path)
        (path / "ui/boot/shell.qml").write_text("changed")
        with self.assertRaises(common.Refusal):
            bundles.validate(path)

    def test_dirty_checkout_is_refused(self):
        (self.root / "uncommitted").write_text("not committed")
        with self.assertRaises(common.Refusal):
            common.clean(self.root)

    def test_missing_smoke_evidence_cannot_promote(self):
        path = self.bundle()
        (self.store / "verification" / f"{path.name}.json").unlink()
        with patch.object(bundles, "require_stopped"):
            with self.assertRaises(common.Refusal):
                bundles.promote(path.name)
        self.assertFalse((self.store / "current").exists())

    def test_changed_evidence_cannot_promote(self):
        path = self.bundle()
        common.atomic_json(self.store / "verification" / f"{path.name}.json", {"files": {}, "smoke_passed": True})
        with patch.object(bundles, "require_stopped"):
            with self.assertRaises(common.Refusal):
                bundles.promote(path.name)

    def test_promotion_and_rollback_restore_pre_promotion_state(self):
        old = self.bundle()
        new = self.bundle("b" * 40)
        state = self.store / "profiles/daily/state"
        state.mkdir(parents=True)
        file = state / "ui.json"
        file.write_text("old state")
        with patch.object(bundles, "require_stopped"):
            bundles.promote(old.name)
            bundles.promote(new.name)
            file.write_text("new state")
            bundles.rollback()
        self.assertEqual(bundles.selected(), old)
        self.assertEqual(file.read_text(), "old state")
        self.assertTrue(list((self.store / "snapshots").glob("before-rollback-*/state/ui.json")))

    def test_first_build_has_no_rollback(self):
        path = self.bundle()
        with patch.object(bundles, "require_stopped"):
            bundles.promote(path.name)
            with self.assertRaises(common.Refusal):
                bundles.rollback()

    def test_live_process_blocks_promotion(self):
        path = self.bundle()
        with patch.object(common, "active_processes", return_value=[123]):
            with self.assertRaises(common.Refusal):
                bundles.promote(path.name)

    def test_feature_worktree_has_no_personal_commits(self):
        self.git("switch", "-c", "personal")
        (self.root / "personal-only").write_text("private workflow")
        self.git("add", "personal-only")
        self.git("commit", "-m", "personal")
        workflow.feature("example")
        tree = self.root / ".personal-worktrees/feature-example"
        self.assertFalse((tree / "personal-only").exists())
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=tree, text=True).strip()
        self.assertEqual(head, self.git("rev-parse", "upstream/main"))

    def test_feature_name_cannot_be_a_path(self):
        with self.assertRaises(common.Refusal):
            workflow.feature("../../outside")

    def test_failed_check_leaves_current_unchanged(self):
        path = self.bundle()
        common.atomic_link(self.store / "current", f"releases/{path.name}")
        with patch.object(bundles, "logged", side_effect=common.Refusal("failed")):
            with self.assertRaises(common.Refusal):
                bundles.build(self.root, "quick")
        self.assertEqual(bundles.selected(), path)
        self.assertEqual(len(list((self.store / "releases").iterdir())), 1)

    def source_assets(self):
        for leaf in ("ui/boot/shell.qml", "shelf/manifest.json", "keys.toml", "LICENSE",
                     "packaging/com.thisisgm.flea.svg", *[f"tools/{h}" for h in bundles.HELPERS]):
            path = self.root / leaf
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture\n")
        for leaf in bundles.UI_LINKS:
            (self.root / leaf).symlink_to(f"/usr/share/omarchy/shell/{Path(leaf).name}")
        binary = self.root / "target/release/flea"
        binary.parent.mkdir(parents=True)
        binary.write_text("#!/bin/sh\nprintf 'flea fixture\\n'\n")
        binary.chmod(0o755)
        self.git("add", "ui", "shelf", "keys.toml", "LICENSE", "packaging", "tools")
        self.git("commit", "-m", "source assets")

    def test_archive_refuses_unexpected_symlink(self):
        self.source_assets()
        (self.root / "ui/evil").symlink_to("/etc/passwd")
        self.git("add", "ui/evil")
        self.git("commit", "-m", "unsafe symlink")
        stage = self.store / "tmp/stage"
        stage.mkdir()
        with self.assertRaisesRegex(common.Refusal, "Unexpected source symlink"):
            bundles.extract_source(self.root, stage)

    def test_successful_build_archives_exact_tracked_assets(self):
        self.source_assets()
        with patch.object(bundles, "logged", return_value="fixture-log"):
            path = bundles.build(self.root, "quick")
        manifest = bundles.validate(path)
        self.assertEqual(manifest["commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(manifest["checks"], "quick")
        self.assertEqual((path / "ui/boot/shell.qml").read_text(), "fixture\n")
        for leaf in bundles.UI_LINKS:
            self.assertTrue((path / leaf).is_symlink())
        self.assertFalse((self.store / "current").exists())

    def test_timeout_is_reported_as_incomplete_with_a_log(self):
        with patch.object(common.subprocess, "run", side_effect=subprocess.TimeoutExpired("fixture", 1)):
            with self.assertRaises(common.CheckFailure) as caught:
                common.logged(["fixture"], self.root, "timeout-fixture", {}, timeout=1)
        self.assertTrue(caught.exception.timed_out)
        self.assertTrue((self.root / caught.exception.log).is_file())

    def test_desktop_install_and_remove_restore_existing_files(self):
        args = Namespace(shortcuts=False, directory_default=False, reveal=False, picker=False)
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root / "home/.config"), "XDG_DATA_HOME": str(self.root / "home/.local/share")}):
            target = desktop.paths(self.root / "home")
        target["launcher"].parent.mkdir(parents=True)
        target["launcher"].write_text("existing launcher")
        target["launcher"].chmod(0o750)
        bundle = self.bundle()
        common.atomic_link(self.store / "current", f"releases/{bundle.name}")
        values = desktop.payloads(args, target)
        with patch.object(desktop, "require_stopped"):
            desktop.install(args, target, values)
            self.assertTrue(target["desktop"].exists())
            desktop.remove()
        self.assertEqual(target["launcher"].read_text(), "existing launcher")
        self.assertEqual(target["launcher"].stat().st_mode & 0o777, 0o750)
        self.assertFalse(target["desktop"].exists())

    def test_desktop_removal_preserves_subsequent_user_edits(self):
        args = Namespace(shortcuts=False, directory_default=False, reveal=False, picker=False)
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root / "home/.config"), "XDG_DATA_HOME": str(self.root / "home/.local/share")}):
            target = desktop.paths(self.root / "home")
        bundle = self.bundle()
        common.atomic_link(self.store / "current", f"releases/{bundle.name}")
        with patch.object(desktop, "require_stopped"):
            desktop.install(args, target, desktop.payloads(args, target))
            target["desktop"].write_text("user edits")
            with self.assertRaises(common.Refusal):
                desktop.remove()
        self.assertEqual(target["desktop"].read_text(), "user edits")

    def test_desktop_plan_never_installs(self):
        args = Namespace(action="plan", shortcuts=False, directory_default=False, reveal=False, picker=False, confirm=False)
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root / "home/.config"), "XDG_DATA_HOME": str(self.root / "home/.local/share")}):
            targets = desktop.paths(self.root / "home")
        with patch.object(desktop, "paths", return_value=targets), patch.object(desktop, "install") as install:
            desktop.execute(args)
        install.assert_not_called()

    def test_desktop_requires_explicit_confirmation(self):
        args = Namespace(action="install", shortcuts=False, directory_default=False, reveal=False, picker=False, confirm=False)
        with self.assertRaises(common.Refusal):
            desktop.execute(args)

    @unittest.skipUnless(shutil.which("xdg-mime"), "xdg-mime is not installed")
    def test_desktop_entry_is_discoverable_by_real_xdg_mime(self):
        home = self.root / "home"
        env = {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
               "XDG_DATA_HOME": str(home / ".local/share"), "PATH": "/usr/bin:/bin"}
        args = Namespace(shortcuts=False, directory_default=True, reveal=False, picker=False)
        with patch.dict(os.environ, env):
            target = desktop.paths(home)
            for path, value in desktop.payloads(args, target).items():
                desktop.external_write(Path(path), value["bytes"], value["mode"])
            result = subprocess.run(["xdg-mime", "query", "default", "inode/directory"],
                                    capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), desktop.DESKTOP_ID)

    def test_directory_default_edit_preserves_other_associations(self):
        original = "[Default Applications]\n# keep me\ninode/directory=stock.desktop\ntext/plain=editor.desktop\n\n[Added Associations]\ninode/directory=stock.desktop;\n"
        expected = original.replace("inode/directory=stock.desktop\n", f"inode/directory={desktop.DESKTOP_ID}\n")
        self.assertEqual(desktop.directory_default(original), expected)

    def test_symlinked_mime_requires_exact_target_authorization(self):
        file = self.root / "dotfiles/mimeapps.list"
        file.parent.mkdir()
        file.write_text("[Default Applications]\ninode/directory=stock.desktop\n")
        alias = self.root / "mimeapps.list"
        alias.symlink_to(file)
        args = Namespace(mime_target=None)
        with self.assertRaises(common.Refusal):
            desktop.mime_target(args, {"mime": alias})
        args.mime_target = file
        self.assertEqual(desktop.mime_target(args, {"mime": alias}), file)
        self.assertTrue(alias.is_symlink())
        self.assertIn("stock.desktop", file.read_text())

    def test_portal_preference_preserves_other_interfaces(self):
        result = desktop.prefer_picker("[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=gnome;gtk\norg.freedesktop.impl.portal.ScreenCast=hyprland\n")
        self.assertIn("default=hyprland;gtk", result)
        self.assertIn("org.freedesktop.impl.portal.ScreenCast=hyprland", result)
        self.assertEqual(result.count("org.freedesktop.impl.portal.FileChooser="), 1)
        self.assertIn("org.freedesktop.impl.portal.FileChooser=flea;gtk", result)

    def test_launcher_resolves_current_once_before_exec(self):
        loader = importlib.machinery.SourceFileLoader("custom_launcher", str(PERSONAL / "flea-custom"))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        launcher = importlib.util.module_from_spec(spec)
        loader.exec_module(launcher)
        path = self.bundle()
        with patch.object(launcher, "selected", return_value=path) as selection, patch.object(sys, "argv", ["flea-custom", "--gui", "folder with spaces"]), patch.object(os, "execve") as execute:
            launcher.main()
        selection.assert_called_once()
        self.assertEqual(execute.call_args.args[1], [str(path / "bin/flea"), "--gui", "folder with spaces"])
        self.assertEqual(execute.call_args.args[2]["FLEA_UI"], str(path / "ui"))

    def test_launcher_rejects_stock_default_verb(self):
        loader = importlib.machinery.SourceFileLoader("custom_launcher_refusal", str(PERSONAL / "flea-custom"))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        launcher = importlib.util.module_from_spec(spec)
        loader.exec_module(launcher)
        with patch.object(launcher, "selected", return_value=self.bundle()), patch.object(sys, "argv", ["flea-custom", "--default"]):
            with self.assertRaises(common.Refusal):
                launcher.main()


if __name__ == "__main__":
    unittest.main()
