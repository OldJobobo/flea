"""Personal overlay contracts without changing upstream files or live desktop state."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import tempfile
import unittest

PERSONAL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PERSONAL))
import branding
from common import Refusal


class Branding(unittest.TestCase):
    def setUp(self):
        scratch = PERSONAL.parent / ".local-builds/tmp"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.stage = Path(self.temporary.name)

    def stage_sources(self):
        leaves = ["ui/" + leaf for leaf in branding.COPY_FILES]
        leaves += ["ui/boot/shell.qml", "ui/boot/picker.qml", "ui/js/Icons.js", "ui/js/IconPacks.js", "ui/Ipc.qml",
                   "ui/FleaMark.qml", "ui/js/SettingsAbout.js", "ui/UpdateCheck.qml", "ui/DefaultClaim.qml",
                   "shelf/Model.js", "shelf/ShelfActions.qml", "shelf/FleaShelfMark.qml", "shelf/manifest.json"]
        for leaf in leaves:
            destination = self.stage / leaf
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(PERSONAL.parent / leaf, destination)
        shutil.copytree(PERSONAL / "branding", self.stage / "personal/branding")
        return leaves

    def test_clean_upstream_build_is_not_rebranded(self):
        self.assertIsNone(branding.apply(self.stage, "a" * 40))
        self.assertEqual(list(self.stage.iterdir()), [])

    def test_only_presentation_strings_are_rewritten(self):
        source = 'import "." as Flea\n// Flea stays upstream\nvar a = "Flea opens in"; var b = "Using Flea icons."; var c = "FLEA_BIN";'
        result = branding.presentation(source)
        self.assertIn('import "." as Flea', result)
        self.assertIn('// Flea stays upstream', result)
        self.assertIn('"Tick opens in"', result)
        self.assertIn('"Using Flea icons."', result)
        self.assertIn('"FLEA_BIN"', result)

    def test_overlay_preserves_engine_names_and_records_source_hashes(self):
        leaves = self.stage_sources()
        originals = {leaf: hashlib.sha256((self.stage / leaf).read_bytes()).hexdigest() for leaf in leaves}
        answer = branding.apply(self.stage, "a" * 40)
        self.assertEqual(answer["name"], "Tick")
        self.assertEqual(answer["source_files"], originals)
        boot = (self.stage / "ui/boot/shell.qml").read_text()
        self.assertIn('title: "Tick"', boot)
        self.assertIn('AppId com.oldjobobo.tick', boot)
        self.assertIn('ShellId flea', boot)
        self.assertIn('CacheDir $BASE/flea', boot)
        self.assertIn('FLEA_BIN', (self.stage / "ui/RunCard.qml").read_text())
        self.assertIn('Flea shelf', (PERSONAL.parent / "shelf/manifest.json").read_text())
        self.assertEqual(json.loads((self.stage / "shelf/manifest.json").read_text())["barWidget"]["displayName"], "Tick shelf")

    def test_package_update_and_default_actions_are_not_exposed(self):
        self.stage_sources()
        branding.apply(self.stage, "b" * 40)
        about = (self.stage / "ui/js/SettingsAbout.js").read_text()
        self.assertIn('label: "Tick"', about)
        self.assertIn('bbbbbbbbbbbb', about)
        self.assertNotIn('id: "makeDefault"', about)
        self.assertNotIn('id: "updateFlea"', about)
        self.assertNotIn('MakeDefault.rows', about)
        update = (self.stage / "ui/UpdateCheck.qml").read_text()
        self.assertNotIn('Process', update)
        self.assertNotIn('--update', update)
        self.assertIn('function toggle() {}', (self.stage / "ui/DefaultClaim.qml").read_text())

    def test_brand_mark_uses_existing_shape_and_templates_are_resolved(self):
        self.stage_sources()
        branding.apply(self.stage, "c" * 40)
        mark = (self.stage / "ui/FleaMark.qml").read_text()
        self.assertNotIn('@PATH@', mark)
        self.assertIn('ShapePath.WindingFill', mark)
        packs = (self.stage / "ui/js/IconPacks.js").read_text()
        self.assertIn('name === "shelf" ||', packs)
        self.assertIn('var IDS = ["flea", "tabler",', packs)
        self.assertIn('var LABELS = ["Flea",', packs)

    def test_upstream_seam_drift_fails_closed(self):
        self.stage_sources()
        path = self.stage / "ui/boot/shell.qml"
        path.write_text(path.read_text().replace('title: "Flea"', 'title: "Changed upstream"'))
        with self.assertRaisesRegex(Refusal, 'overlay drift'):
            branding.apply(self.stage, "d" * 40)


if __name__ == "__main__":
    unittest.main()
