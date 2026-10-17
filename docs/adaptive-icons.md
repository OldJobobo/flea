# Adaptive file and folder icons

On the Tick feature branch, choose **Settings → Display → File and folder icons →
Adaptive / theme palette**. The default remains Interface icons. This is independent
of the Interface icons selector and does not change the desktop, launcher, toolbar,
sidebar or another application's icon theme. No installation or network access is
needed. The persistent value is `display.fileIconTheme = "adaptive"` in the existing
shared `ui.json`; selecting another option reverses it.

## Artwork and colour

The artwork is original: folded-tab folders, cut-corner documents, and three generic
application motifs (Terminal, Editor and Files). `ui/js/AdaptiveMarks.js` is the
bounded catalogue of 30 freedesktop icon names and aliases. No third-party logo is
copied or recoloured. This does not introduce application discovery or parse desktop
files; the motifs render when a caller already supplies their standard icon names.

Ordinary folders use the theme accent. Home, Documents, Downloads, Pictures, Music,
Videos, Public, Templates and Desktop have distinct emblems. Explicit freedesktop
folder names win; a plain `folder` also recognises these conventional English
basenames. Those are display hints, not a claim that the folder is an XDG special
directory. Localised or arbitrary names retain the plain folder silhouette.

File families can use the theme's blue, green, yellow, magenta and cyan roles, or
`color4`, `color2`, `color3`, `color5` and `color6`. Missing family colours fall back
to the accent. All colours pass through one OKLCH material recipe:

- Face, rear panel and restrained highlight have perceptually spaced lightness.
- Chroma is capped and reduced into sRGB without independent channel clipping.
- Light and dark grounds receive different materials.
- An approximately neutral accent keeps every family neutral.
- Black or white emblem ink is chosen for contrast against the face.
- A two-tone outline preserves the silhouette. Its primary neutral edge maximises
  the weaker contrast on the normal and selected grounds; the opposite keyline
  helps where no single colour can achieve the target on both grounds.

The `selection_background` or `selection` palette entry supplies the selected
proof ground, falling back to the listing background. These are not a guarantee
of contrast over every wallpaper/translucency combination. Gradients and edge
contrast have automated coverage on six representative opaque proof palettes;
there is no claim of a desktop-wide accessibility audit.

At 24 logical pixels and below, flat faces replace the subtle large-size gradient,
ornamental highlights disappear and emblem strokes strengthen. Geometry and colour
recipes are shared across all themes: there are no named theme variants.

Unknown names, including brand-specific application icons, use the existing System /
Omarchy resolver unchanged, then interface glyphs if artwork cannot be loaded.
Adaptive SVGs remain available if that resolver fails. Installed named themes are
never rewritten. Thumbnails always take priority.

## Rendering contract

`ui/AdaptiveIcons.qml` is created only when Adaptive is selected and is destroyed
when it is deselected. It imports the palette math and artwork only on demand.
`Theme.qml` retains the already-parsed raw palette but does no material derivation
for an ordinary window. The existing `theme.name` watch triggers palette refreshes
on Omarchy theme changes; no new watch or polling process is added.

Visible delegates request a semantic name and size, as they do for desktop icons.
The service materialises explicit-colour, self-contained SVG data URLs synchronously
on cache misses. It never reads the browsed directory, searches application files,
or schedules a whole-directory recolour. Its FIFO cache holds at most 128 semantic
name/size results. Repeated rows at the same size share URLs and Qt's decoded image
cache. SVG intrinsic dimensions match the requested size, with the geometry still
on its 64-unit design grid: Qt's data-URL loader can otherwise hold a 64-pixel image
even as `Image.sourceSize` grows. Grid icons retain the existing 128-pixel cap;
thumbnails can fill the larger 192/256-pixel slots. A palette change clears the
source cache; changed SVG bytes naturally produce new
image URLs, so old Qt pixmaps cannot masquerade as the new colours.

There is one shared existing Rust desktop-icon worker for catalogue/system fallback
when opted in, not one process per row. The SVGs use no external resources, fonts,
filters, arbitrary filename interpolation or untrusted SVG templates. They draw in
the existing thumbnail Images: list/column/grid census remains 17/15/13 objects.
Hidden or pooled delegates request no artwork. There is no shader or extra image
layer per row, new runtime dependency, or persistent generated icon directory.

## Checks and visual proof

```sh
cargo test --locked iconthemes
bash tests/js.sh adaptiveicons
bash tests/js.sh fileicons
bash tests/adaptive-icons.sh
bash tests/desktop-icons.sh
bash tests/startup-objects.sh
node tools/flea-adaptive-proof.mjs
```

The proof tool needs Node only as a development tool. It executes the shipped QML
JavaScript recipes and writes `target/adaptive-icons/proof.svg`. Six test palettes
show 15 representative icons at 64 and 20 pixels on normal and selected grounds.
These fixtures are test inputs, never installed colour variants. Optionally render
the SVG to PNG with an installed SVG-capable image tool.

`ADAPTIVE_ICON_CAPTURE_DIR` can name an existing directory when running the live
suite to save `adaptive-qt.png`, an actual offscreen Qt capture. The suite covers
live theme-file/name changes, cache reuse, hidden idleness, original app fallback,
resolver failure, thumbnail priority, object budgets, switching out/back and
next-process persistence. A zoom leg measures painted and intrinsic Image dimensions
at all six Ctrl+wheel thumbnail stops in both directions, including unchanged
system-app fallback and full-size thumbnail controls. A separate leg decodes all
30 aliases in both geometry
tiers across all six palettes: 360 actual Qt SVG decodes. The suite is registered
in `tests/run-all.sh`; the pure suite runs in the existing JS battery.

The default first-frame inventory remains 181 units; none of the adaptive units
loads by default. Its byte ceiling is re-derived as 1695740. `wc -l` yields
`ui/Theme.qml` 496 and `ui/ViewState.qml` 577; their existing scoped file-budget
ceilings move accordingly. No default startup-object ceiling is raised.

## Scope beyond this branch

A larger branded app collection would require explicitly authored layer mappings
and a licensing/identity review per app. A desktop-wide generated freedesktop theme
could reuse the same recipes, but installation, theme hooks and desktop settings
are deliberately not part of this Flea-local feature.

Colour math reference (OKLab matrices by Björn Ottosson, public domain/MIT):
https://bottosson.github.io/posts/oklab/
