"""The supplied SVG pieces remain exact, static and reproducibly theme-colorable."""
from pathlib import Path
import hashlib
import json
import sys
import unittest

PERSONAL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PERSONAL))
from import_tick_animations import PARTS, geometry, motions


class AnimationAssets(unittest.TestCase):
    def setUp(self):
        self.assets = PERSONAL / "branding/mascot"
        script = (self.assets / "TickParts.js").read_text()
        self.paths = json.loads(script.split("var PATHS = ", 1)[1])

    def test_all_fifteen_pieces_preserve_supplied_geometry(self):
        self.assertEqual(set(self.paths), set(PARTS))
        for name in PARTS:
            with self.subTest(name=name):
                data = (self.assets / f"assets/{name}.svg").read_bytes()
                self.assertEqual(self.paths[name], geometry(data))

    def test_source_hashes_match_vendored_inputs(self):
        manifest = json.loads((self.assets / "source.json").read_text())
        self.assertEqual(len(manifest["files"]), 17)
        for leaf, expected in manifest["files"].items():
            with self.subTest(leaf=leaf):
                self.assertEqual(hashlib.sha256((self.assets / leaf).read_bytes()).hexdigest(), expected)
        archive = PERSONAL / "branding" / manifest["archive"]
        if archive.exists():
            self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(), manifest["archive_sha256"])

    def test_extra_states_preserve_supplied_keyframes_and_durations(self):
        script = (self.assets / "TickMotions.js").read_text()
        compiled = json.loads(script.split("var CLIPS = ", 1)[1])
        self.assertEqual(compiled, motions((self.assets / "motion-spec.json").read_bytes()))
        self.assertEqual({name: clip["duration"] for name, clip in compiled.items()},
                         {"thinking": 4000, "searching": 4000, "sleepy": 6000,
                          "waving": 3000, "surprised": 3000, "error": 3000})

    def test_non_neutral_or_non_finite_motion_is_rejected(self):
        spec = json.loads((self.assets / "motion-spec.json").read_text())
        spec["thinking"]["keys"][0][1] = 3
        with self.assertRaises(ValueError):
            motions(json.dumps(spec))
        spec["thinking"]["keys"][0][1] = 0
        spec["thinking"]["duration_seconds"] = float("inf")
        with self.assertRaises(ValueError):
            motions(json.dumps(spec))

    def test_active_or_external_svg_content_is_rejected(self):
        for content in ('<script/>', '<image href="outside.svg"/>', '<foreignObject/>', '<path d="M1 2Z" onclick="run()"/>'):
            with self.subTest(content=content), self.assertRaises(ValueError):
                geometry(('<svg viewBox="0 0 24 24">' + content + '</svg>').encode())

    def test_unreviewed_geometry_contract_is_rejected(self):
        for content in (b'<svg viewBox="0 0 48 48"><path d="M1 2Z"/></svg>',
                        b'<svg viewBox="0 0 24 24"><path d="url(external)"/></svg>',
                        b'<!DOCTYPE svg><svg viewBox="0 0 24 24"><path d="M1 2Z"/></svg>',
                        b'<svg viewBox="0 0 24 24"/>'):
            with self.subTest(content=content), self.assertRaises(ValueError):
                geometry(content)


if __name__ == "__main__":
    unittest.main()
