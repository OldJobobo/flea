# Desktop file and folder icon themes

Settings → Display has two independent selections:

- **Interface icons** selects Flea's drawn interface marks (including bundled
  Lucide, Tabler and other families). See `docs/icon-packs.md`.
- **File and folder icons** selects the artwork in list, dual-pane, column, grid
  and file-picker entries. **Interface icons** is the default; **Adaptive / theme
  palette** draws original artwork using the active theme colours (see
  `docs/adaptive-icons.md`); **System / Omarchy** follows the desktop theme,
  and named entries select an installed theme such as
  Papirus, Yaru, Tela or Colloid. Nothing is downloaded or installed by Flea.

The selection does not change other applications' icons, the application's own
brand, toolbar/sidebar marks, thumbnails or the desktop's icon-theme settings.
Thumbnails take priority. After theme inheritance, unresolved or undecodable
artwork falls back to the existing interface glyph. An unresponsive resolver
also falls back without blocking the window.

## Installing and choosing a theme

Install a freedesktop-compatible icon theme with your normal package manager or
place its directory, including `index.theme`, in `~/.local/share/icons/` or
`~/.icons/`. Flea also searches `$XDG_DATA_HOME/icons` and each absolute
`$XDG_DATA_DIRS` root's `icons/` directory; the data-dir defaults are
`/usr/local/share` and `/usr/share`.

Open Display, press **Rescan icon themes** after installing or updating a theme,
then step **File and folder icons** to the desired entry. Cursor-only themes and
hidden themes are not offered as named choices. Hidden themes can still supply
inherited icons. Themes that contain only folder artwork work too: other file
kinds inherit artwork or retain their interface glyphs.

System mode uses `QS_ICON_THEME` when explicitly set, otherwise Omarchy's
`~/.local/state/omarchy/current/theme/icons.theme`, then `hicolor`. When Flea's
launcher supplied `QS_ICON_THEME` to avoid loading GTK, the Omarchy file remains
the live authority instead of that startup snapshot. Changes to that file are
watched in System mode. Named themes do not change with the Omarchy theme.

## Storage and compatibility

The existing shared `ui.json` stores `display.fileIconTheme`:

```json
{"display":{"fileIconTheme":"builtin"}}
```

Values are `builtin`, `adaptive`, `system` or `theme:<directory-name>`, for example
`theme:Papirus-Dark`. `display.iconSet` remains the independent interface-pack
selection. Missing named themes remain selected, rather than silently rewriting
preferences; the selector labels an undiscovered selection as not listed.
The next launch retains both choices.

Names are bounded UTF-8 basenames, not paths. No custom SVG-to-JSON conversion is
needed: installed themes use PNG, SVG or XPM artwork directly through the existing
Qt image decoder. Only install icon assets you trust; these are not constrained
path-data packs like the Custom interface-icon slot.

## Bounded, lazy rendering

- The default view creates no desktop-theme reader or worker.
- Opening Display or selecting a desktop theme creates one shared service per
  process. It starts the pinned engine's `--desktop-icons` JSON-lines worker.
- Discovery lists only icon-theme roots and reads bounded `index.theme` metadata;
  it never lists the directory being browsed or recursively scans icon assets.
- Existing viewport delegates supply the already-known freedesktop icon name and
  render size. Hidden/pooled rows do not request artwork. One deferred batch covers
  up to 256 distinct requests; successful and missing results are cached.
- The existing thumbnail `Image` also renders themed icons. No additional image,
  loader or shape is built per row. Artwork decodes asynchronously, shares Qt's
  image cache, and is capped to the slot size (128 logical pixels for installed-theme
  grid marks; Adaptive mode follows all six grid sizes through 256 pixels).
- Metadata supports inherited themes, implicit `hicolor`, fixed/scalable/threshold
  directories and scaled directories. The closest child size is considered before
  trying a parent. User roots take precedence within the same theme directory.
- A rescan invalidates native and QML caches and advances the image URL version,
  so replacing artwork does not leave Qt showing stale decoded pixels.
- Requests stop after five seconds without worker progress and fall back safely;
  **Rescan icon themes** retries. An idle worker is not timed out.

Bounds: 1 MiB per index, 512 declared directories per index, 32 themes per
inheritance chain, 512 cached native results, 512 QML results before trimming,
64 KiB per protocol line, 256 icons per batch and 512 pixels per requested size.
Discovery caps theme names at 1024 across roots and offers at most 256 choices.
No Rust dependencies or GTK process/platform-theme initialization are added.

## Checks

`cargo test --locked icontheme` covers metadata, precedence, inheritance/cycles,
size selection, implicit fallback, bounded caches and protocol/state validation.
`tests/js.sh fileicons` covers selection and separate settings rows.
`tests/desktop-icons.sh` drives the shipped renderers and settings over disposable
SVG/PNG themes, checks missing-icon fallback, inherited art, encoded paths, live
system changes, hidden-view idleness, rescans, row budgets, thumbnail priority and
next-process persistence. It is registered in `tests/run-all.sh`.
