"""Rebranding never edits routing and retains transactional removal/rollback safeguards."""
from argparse import Namespace
from pathlib import Path
import hashlib
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

PERSONAL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PERSONAL))
import bundles
import common
import desktop
import desktop_rebrand


class DesktopRebrand(unittest.TestCase):
    def setUp(self):
        scratch = PERSONAL.parent / ".local-builds/tmp"
        scratch.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.store = self.root / ".local-builds"
        for module in (common, bundles, desktop, desktop_rebrand):
            for name, value in (("ROOT", self.root), ("STORE", self.store)):
                if hasattr(module, name):
                    mock = patch.object(module, name, value)
                    mock.start()
                    self.addCleanup(mock.stop)
        home = self.root / "home"
        env = patch.dict(os.environ, {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
                                     "XDG_DATA_HOME": str(home / ".local/share")})
        env.start()
        self.addCleanup(env.stop)
        common.initialize()
        self.target = desktop.paths(home)
        self.args = Namespace(action="rebrand", confirm=False, shortcuts=False, picker=False,
                              reveal=False, directory_default=False, mime_target=None)
        self.bundle = self.store / "releases" / ("a" * 40)
        for leaf in ("bin/flea", "ui/boot/shell.qml", "shelf/manifest.json",
                     *["tools/" + name for name in bundles.HELPERS]):
            path = self.bundle / leaf
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        for leaf in bundles.UI_LINKS:
            (self.bundle / leaf).mkdir()
        icon = self.bundle / "personal/branding/tick.svg"
        icon.parent.mkdir(parents=True)
        icon.write_bytes(desktop.ICON.read_bytes())
        common.atomic_json(self.bundle / "manifest.json", {"commit": self.bundle.name, "version": "fixture",
                           "files": bundles.fingerprints(self.bundle), "brand": {"app_id": desktop.APP_ID}})
        common.atomic_link(self.store / "current", "releases/" + self.bundle.name)
        installed = {}
        for key, value in (("legacy_launcher", "old launcher"), ("legacy_desktop", "old desktop"),
                           ("bindings", "unchanged bindings"), ("mime", "unchanged MIME")):
            path = self.target[key]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
            installed[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.record = {"installed": installed, "originals": {name: None for name in installed},
                       "shortcuts": False, "picker": False, "directory_default": True, "previous_mime": "stock.desktop"}
        common.atomic_json(self.store / "desktop.json", self.record)
        guard = patch.object(desktop_rebrand, "require_stopped")
        guard.start()
        self.addCleanup(guard.stop)

    def run_rebrand(self, confirm=True):
        self.args.confirm = confirm
        desktop_rebrand.execute(self.args, self.target)

    def test_preview_does_not_change_any_file(self):
        self.run_rebrand(False)
        self.assertFalse(self.target["launcher"].exists())
        self.assertEqual(common.read_json(self.store / "desktop.json"), self.record)
        self.assertEqual(self.target["legacy_desktop"].read_text(), "old desktop")

    def test_refresh_preserves_routing_and_keeps_legacy_entry_points(self):
        self.run_rebrand()
        self.assertIn("personal/tick", self.target["launcher"].read_text())
        self.assertEqual(self.target["launcher"].read_bytes(), self.target["legacy_launcher"].read_bytes())
        self.assertIn("Name=Tick", self.target["desktop"].read_text())
        self.assertNotIn("NoDisplay", self.target["desktop"].read_text())
        self.assertIn("NoDisplay=true", self.target["legacy_desktop"].read_text())
        self.assertEqual(self.target["icon"].read_bytes(), (self.bundle / "personal/branding/tick.svg").read_bytes())
        self.assertEqual(self.target["bindings"].read_text(), "unchanged bindings")
        self.assertEqual(self.target["mime"].read_text(), "unchanged MIME")
        record = common.read_json(self.store / "desktop.json")
        self.assertTrue(record["directory_default"])
        self.assertEqual(record["previous_mime"], "stock.desktop")
        self.assertEqual(record["originals"], {name: None for name in record["installed"]})
        self.assertFalse((self.store / "desktop-rebrand-pending.json").exists())
        self.run_rebrand()  # An owned refresh is safe to repeat.

    def test_user_edits_are_never_overwritten(self):
        self.target["legacy_desktop"].write_text("user edits")
        with self.assertRaisesRegex(common.Refusal, "Changed since installation"):
            self.run_rebrand()
        self.assertEqual(self.target["legacy_desktop"].read_text(), "user edits")
        self.assertFalse(self.target["launcher"].exists())

    def test_new_target_collision_is_not_clobbered(self):
        self.target["launcher"].write_text("another tick")
        with self.assertRaisesRegex(common.Refusal, "unowned Tick"):
            self.run_rebrand()
        self.assertEqual(self.target["launcher"].read_text(), "another tick")

    def test_partial_write_failure_rolls_back_files_and_metadata(self):
        write = desktop.external_write
        calls = 0
        def fail_once(*args):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("fixture failure")
            return write(*args)
        with patch.object(desktop, "external_write", side_effect=fail_once):
            with self.assertRaisesRegex(OSError, "fixture failure"):
                self.run_rebrand()
        self.assertFalse(self.target["launcher"].exists())
        self.assertEqual(self.target["legacy_launcher"].read_text(), "old launcher")
        self.assertEqual(self.target["legacy_desktop"].read_text(), "old desktop")
        self.assertEqual(common.read_json(self.store / "desktop.json"), self.record)
        self.assertFalse((self.store / "desktop-rebrand-pending.json").exists())

    def test_symlinked_target_is_refused(self):
        self.target["legacy_desktop"].unlink()
        self.target["legacy_desktop"].symlink_to(self.target["mime"])
        with self.assertRaisesRegex(common.Refusal, "symlinked"):
            self.run_rebrand()
        self.assertEqual(self.target["mime"].read_text(), "unchanged MIME")

    def test_removal_can_restore_original_installation_after_refresh(self):
        self.run_rebrand()
        with patch.object(desktop, "require_stopped"):
            desktop.remove()
        for key in ("launcher", "legacy_launcher", "desktop", "legacy_desktop", "icon"):
            self.assertFalse(self.target[key].exists())


if __name__ == "__main__":
    unittest.main()
