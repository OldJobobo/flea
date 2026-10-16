# Icon packs

For installed GTK/freedesktop file and folder artwork, see
`docs/desktop-icon-themes.md`. That selection is independent of these interface
packs; Settings → Display labels this selector **Interface icons**.

Settings > Display > Appearance > **Icon set** selects **Flea**, **Tabler Outline**,
**Lucide**, **Iconoir**, **Heroicons Outline**, **Phosphor Regular**, **Feather**, or
**Custom**. Changes apply immediately to existing glyphs and are saved in
`display.iconSet` in the shared `ui.json`. Flea remains the default; older state
files need no migration. This does not change the desktop's application icon theme.

The pack covers the path-based file, folder, sidebar, menu and toolbar marks rendered
by `Glyph.qml`, in browser and chooser windows alike. Official brand marks, app icons,
thumbnails and separately drawn font glyphs are not replaced. Flea's shelf spiral and
the Markdown logo retain their original artwork.

## Load another set

Select **Custom** after placing a pack at
`$XDG_CONFIG_HOME/flea/icons/custom.json`, or `~/.config/flea/icons/custom.json`
when `XDG_CONFIG_HOME` is unset. The file is watched: saving a replacement reloads
it without restarting Flea. Only the selected pack is read, once per process and
again on modification, never once per file or directory entry.

A missing, unreadable or invalid pack falls back to Flea's complete set and shows
an explanation under the selector. Creating or correcting the custom file recovers
automatically. Missing individual marks retain their original Flea artwork and
edge style, not a generic document icon. Selecting Flea releases the pack reader.

A minimal pack:

```json
{
  "version": 1,
  "grid": 24,
  "style": "round",
  "icons": {
    "folder": { "path": "M3 5h6l3 3h9v12H3z" },
    "file": { "path": "M5 3h9l5 5v13H5z M14 3v5h5" }
  }
}
```

- `version` must be `1`, `grid` must be `24`, and `style` is `round` or `square`.
- Optional `paint` is `stroke` (the backward-compatible default) or `fill`. Expanded
  outlines such as Phosphor use `fill`: their path is filled with nonzero winding,
  without a stroke, using the existing main shape rather than extra per-row objects.
  This changes only supplied marks; missing marks keep Flea's stroke/fill recipe.
- `icons` maps Flea's stable semantic names to objects containing `path` and an
  optional `filled` path. Names are the keys of `ui/js/Icons.js`'s `PATHS` table.
  `shelf` and `markdown` are reserved and cannot be overridden by custom packs.
  Use an empty/absent `filled` for an outline; a replacement never inherits the
  old mark's filled geometry. Official network/app brand marks are outside this table.
- Geometry is SVG **path data**, not an SVG document. Combine source shapes into
  one multi-subpath string, converting rectangles/circles where necessary. Independent
  relative first moves must be normalized before concatenating paths.
- Flea owns size, semantic color and stroke width for stroked geometry. Filled
  outlines retain the weight baked into their source artwork. Packs do not change
  layout, colors, MIME classification, symlink handling or theme settings. The existing
  Hyprland-aware-icons switch still governs fallback Flea marks; a replacement's
  edge style comes from its pack.
- Data validation limits decoded text to 524,288 characters, 128 marks, and 16,384
  characters per path. Coordinates must be finite and at most 1,024 in magnitude;
  arc radii and flags are checked. Invalid geometry rejects the whole pack.
  The text limit is checked after the local file has been read, not an I/O byte cap.
- Packs are local JSON data. No JavaScript, QML, SVG markup, image references or
  network URLs are evaluated or fetched by the loader. Use packs from trusted authors;
  this is not a sandbox for untrusted content or a general SVG import facility.

The first version has one custom slot, not a discovery catalog or installer. To try
another set, replace `custom.json`; stock SVG directories and desktop icon themes
must first be converted to this semantic format.

## Bundled Tabler Outline

`ui/icons/tabler.json` contains 71 outline marks from Tabler Icons v3.49.0, with
source-name mappings stored alongside the geometry. The original MIT license is
in `ui/icons/TABLER-LICENSE`. No font package or runtime network access is needed.
Regenerate the pack with `python3 tools/flea-tabler-import.py` (network required).
The importer uses a pinned release and refuses unreviewed SVG elements.

## Additional bundled sets

Each set supplies all 71 non-brand semantic marks, using the nearest available
symbol where a library has no exact equivalent (for example, a command-key symbol
for keyboard settings). The explicit mappings are recorded in each pack and in
`tools/icon-pack-sources.json`; selecting a set requires no font or network access.
These are internal Flea marks, not complete desktop file/MIME icon themes.

| Selection | Pinned release | License file in `ui/icons/` |
| --- | --- | --- |
| Lucide | 1.57.0 | `LUCIDE-LICENSE` (ISC + MIT for Feather-derived marks) |
| Iconoir | v7.12.1 | `ICONOIR-LICENSE` (MIT) |
| Heroicons Outline | v2.2.0 | `HEROICONS-LICENSE` (MIT) |
| Phosphor Regular | v2.0.8 | `PHOSPHOR-LICENSE` (MIT) |
| Feather | v4.29.2 | `FEATHER-LICENSE` (MIT) |

Lucide preserves the stock rounded artwork rather than Flea's squared-off recut.
Phosphor's 256-unit expanded contours are normalized to the same 24-unit contract;
its Regular weight is not the separate Phosphor Fill variant. Heroicons and Iconoir
outlines use Flea's themed stroke width, rather than their upstream 1.5-unit width.

Regenerate all five with `python3 tools/flea-icon-packs-import.py`, or append pack
IDs to regenerate individual sets. The stdlib-only importer verifies the recorded
SHA-256 of each pinned release archive, reads regular members without extraction,
normalizes relative commands and primitives, scales geometry, and refuses unsupported
SVG effects. `--cache DIRECTORY` optionally supplies downloaded `<id>.tar.gz` archives;
without a matching cached archive it fetches the pinned release (network required).
Source attribution and archive digests are also embedded in the generated JSON.

## Checks

- `tests/js.sh iconpacks`: pack validation, path limits, fallback, edge styles,
  filled-path replacement, paint modes, and completeness of all six bundled packs.
- `tests/js.sh settings`: Display choice model and existing keyboard behavior.
- `tests/icon-packs.sh`: real glyphs, the settings selector, live switching, saved
  preferences, next-process startup with every bundled set, missing custom file, file
  creation/reloads, malformed data, recovery and restored fills.
  It requires a built backend and uses the standard guarded disposable fixture.
- `python3 -B tests/icon-geometry.py`: relative/implicit commands, arcs, 256-unit
  scaling, primitives, mixed fills, and rejection of unsupported SVG effects.
  This is also run by `tests/icon-packs.sh`.
- `cargo test uischema::tests`: persisted selection, invalid-value recovery and
  preservation of neighboring Display settings.

The runtime suite optionally exports one PNG per selection (`flea.png`, `tabler.png`,
`lucide.png`, `iconoir.png`, `heroicons.png`, `phosphor.png`, `feather.png`, `custom.png`) when
`ICON_PACK_CAPTURE_DIR` names an existing caller-owned evidence directory. It
allows only the known offscreen window-mask and missing-Hyprland-signature warnings;
other engine diagnostics still fail it.
