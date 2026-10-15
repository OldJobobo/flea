# Icon packs

Settings > Display > Appearance > **Icon set** selects **Flea**, **Tabler Outline**,
or **Custom**. Changes apply immediately to existing glyphs and are saved in
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
- `icons` maps Flea's stable semantic names to objects containing `path` and an
  optional `filled` path. Names are the keys of `ui/js/Icons.js`'s `PATHS` table.
  `shelf` and `markdown` are reserved and cannot be overridden by custom packs.
  Use an empty/absent `filled` for an outline; a replacement never inherits the
  old mark's filled geometry. Official network/app brand marks are outside this table.
- Geometry is SVG **path data**, not an SVG document. Combine source shapes into
  one multi-subpath string, converting rectangles/circles where necessary. Independent
  relative first moves must be normalized before concatenating paths.
- Flea owns size, stroke width and semantic color. Packs do not change layout,
  colors, MIME classification, symlink handling or theme settings. The existing
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

## Checks

- `tests/js.sh iconpacks`: pack validation, path limits, fallback, edge styles,
  filled-path replacement, and completeness of the bundled Tabler pack.
- `tests/js.sh settings`: Display choice model and existing keyboard behavior.
- `tests/icon-packs.sh`: real glyphs, the settings selector, live switching, saved
  preferences, next-process startup with Tabler, missing custom file, file
  creation/reloads, malformed data, recovery and restored fills.
  It requires a built backend and uses the standard guarded disposable fixture.
- `cargo test uischema::tests`: persisted selection, invalid-value recovery and
  preservation of neighboring Display settings.

The runtime suite optionally exports `flea.png`, `tabler.png` and `custom.png` when
`ICON_PACK_CAPTURE_DIR` names an existing caller-owned evidence directory. It
allows only the known offscreen window-mask and missing-Hyprland-signature warnings;
other engine diagnostics still fail it.
