#!/usr/bin/env python3
"""Regression tests for the offline SVG-to-pack conversion helpers."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
from icon_geometry import absolute, geometry  # noqa: E402


def svg(body, grid=24, paint='fill="none" stroke="currentColor"'):
    return f'<svg viewBox="0 0 {grid} {grid}" {paint}>{body}</svg>'


class GeometryTests(unittest.TestCase):
    def test_relative_moves_and_implicit_tails(self):
        self.assertEqual(absolute("m1 2 3 4z m5 6h2v-1"), "M1 2 L4 6 Z M6 8 H8 V7")
        self.assertEqual(geometry(svg('<path d="m1 2 3 4"/><path d="m5 6 2 3"/>')),
                         {"path": "M1 2 L4 6 M5 6 L7 9"})

    def test_control_points_stay_relative_to_segment_start(self):
        self.assertEqual(absolute("M10 20c1 2 3 4 5 6s1 2 3 4q1 2 3 4t1 2"),
                         "M10 20 C11 22 13 24 15 26 S16 28 18 30 Q19 32 21 34 T22 36")

    def test_arcs_scale_radii_and_endpoints_not_flags_or_rotation(self):
        self.assertEqual(absolute("M128 128a64 32 45 1 0 64 -32", 24 / 256),
                         "M12 12 A6 3 45 1 0 18 9")

    def test_phosphor_fill_uses_normalized_main_path(self):
        self.assertEqual(geometry(svg('<path d="M0 0H256V256Z"/>', 256, 'fill="currentColor"'), "fill"),
                         {"path": "M0 0 H24 V24 Z"})

    def test_primitives(self):
        body = ('<rect x="1" y="2" width="6" height="4" rx="9"/>'
                '<circle cx="5" cy="6" r="2"/><ellipse cx="5" cy="6" rx="3" ry="1"/>'
                '<line x1="1" y1="2" x2="3" y2="4"/><polygon points="1,2 3,4 5,6"/>'
                '<polyline points="2,3 4,5"/>')
        path = geometry(svg(body))["path"]
        self.assertIn("M4 2 H4 A3 2 0 0 1 7 4", path)
        self.assertIn("M7 6 A2 2 0 1 0 3 6 A2 2 0 1 0 7 6 Z", path)
        self.assertIn("M8 6 A3 1 0 1 0 2 6", path)
        self.assertTrue(path.endswith("M1 2 L3 4 M1 2 L3 4 L5 6 Z M2 3 L4 5"))

    def test_mixed_filled_and_stroked_parts(self):
        result = geometry(svg('<path d="M1 2H3"/><path d="M2 3H4V5Z" fill="currentColor" stroke="none"/>'))
        self.assertEqual(result, {"path": "M1 2 H3", "filled": "M2 3 H4 V5 Z"})
        result = geometry(svg('<path d="M2 3H4V5Z" fill="currentColor" stroke="none"/>'))
        self.assertEqual(result["path"], "M0 0")

    def test_unreviewed_features_fail_closed(self):
        for body in ['<g transform="scale(2)"><path d="M1 2H3"/></g>',
                     '<path style="stroke:red" d="M1 2H3"/>', '<use href="elsewhere.svg"/>',
                     '<path d="M1 2L"/>', '<path d="M1 2A1 2 0 2 0 3 4"/>']:
            with self.subTest(body=body), self.assertRaises((ValueError, KeyError)):
                geometry(svg(body))
        with self.assertRaises(ValueError):
            geometry(svg('<path d="M1 2H3"/>', 16))


if __name__ == "__main__":
    unittest.main()
