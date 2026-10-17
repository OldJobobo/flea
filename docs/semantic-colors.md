# Full semantic colours

Deployment integration: `deploy/tick-semantic-adaptive` combines this feature
with adaptive icons on Tick 0.3.12. Rebuilding the combined backend adds the
adaptive-selection validator missing from the earlier composition probe. The
full adaptive lifecycle, restart, 360-decode catalogue and six-stop zoom tests
now pass with semantic colours enabled (20/3/360/176 checks respectively).
The combined pure-JS battery passes 19,680 checks; semantic Qt/persistence checks
and present-module static gates pass too. Historical limitations below describe
the original semantic-only verification; deployment evidence is recorded in the
immutable bundle manifest and smoke receipt when promotion succeeds.

On `feature/tick-semantic-colors`, enable **Settings → Display → Appearance →
Full semantic colours**. It is off by default. The saved setting is the strict
boolean `display.semanticColors` in the existing shared `ui.json`. Switching it
updates existing windows immediately; switching off restores the prior appearance.
No live preference or daily deployment is changed by developing this feature.
The terminal interface is unchanged.

## What changes

- Resting filenames and interface glyphs use the same semantic families in list,
  columns and grid: folders, documents, media, archives and code. Unknown families
  keep their ordinary ink. Other metadata remains neutral.
- Symlinks win over folders, folders over executable bits, and trusted executables
  over ordinary file families. Existing mount/permission trust flags still apply;
  a script extension never grants executable permission.
- Hover, cursor, selection, drop targets and dimmed ancestor columns keep their
  existing interaction inks. Cut content keeps its existing dimming. Focus rings,
  selection fills, search marks and destructive menu rows are not redesigned.
- Confirmed completion notices can use success; partial/skipped outcomes or a
  pending remote-write note use warning; activity and cancellation use information.
  Armed second-press prompts use warning. Errors retain the existing error role
  and queue/acknowledgement priority. Ordinary untyped messages stay neutral.
- Resting Home/Favorites interface marks take the folder role. Ancestor breadcrumb
  text takes information; the current crumb, hover and drop treatments stay intact.
- Transfer progress takes the information mark role; collision-review headings
  take warning. Buttons retain their current focus/destructive treatments.

Installed icon artwork, thumbnails, brand marks, code-mark artwork, user tags,
syntax highlighting and preview contents are not recoloured. Interface icon
selection and installed file/folder themes remain independent. Adaptive icons are
on a separate branch and are not required or integrated by this feature.

## Theme inputs

Tick reads its existing parsed Omarchy `colors.toml` palette. These optional
semantic aliases are Tick-local inputs, not a new global Omarchy configuration
format. Each row takes the first valid six-digit hex input, then the accent:

| Meaning | Inputs |
| --- | --- |
| Success | `success`, `green`, `color2` |
| Warning / archive | `warning`, `yellow`, `color3` for warning; `yellow`, `color3` for archive |
| Information / document | `info`, `blue`, `color4` for information; `blue`, `color4` for document |
| Directory | `accent` |
| Media | `magenta`, `color5` |
| Code | `cyan`, `color6` |

Link, executable and error keep the existing derivations. An approximately neutral
accent keeps the additional semantic roles neutral too. Replacing a palette
replaces the entire derived role map, so missing roles cannot retain a previous
theme's colours. No hardcoded rainbow or per-theme special case is introduced.

Text and mark variants reuse the existing material lightness-lift policy, targeting
4.5:1 for text and 3:1 for meaningful marks on both background and surface. Default
Glassy follows the existing material alpha/blur model. This is not a guarantee over
arbitrary wallpaper, compositor opacity or user/theme-pinned transparency: the
same explicit-alpha limitations as the existing material system remain.

## Implementation boundaries

`ui/js/SemanticColors.js` contains a bounded family catalogue and pure role math.
It uses only the row name, generic icon name, directory bit, reported mode and
executable-trust flag already delivered by the backend. It performs no stat, MIME
sniffing, directory scan, metadata request, polling, process launch or artwork
rewrite. Translated kind labels are not classification inputs.

`ThemeColors.qml` derives shared role maps once per palette/material change while
the setting is enabled. Off builds no semantic inks. Delegates only choose a role
from those maps; there is no new per-row object or model. One helper JS unit joins
the first-frame source inventory.

`PaneWire.qml` enriches only audited completion producers immediately after their
existing message delivery, through `StatusBar.classifyNotice(text, kind)`. The bar
accepts the classification only for the matching notice. This leaves message
signals, error routing, ordering, undo hints, dismissal and the backend protocol
unchanged. `StatusBar.say` also accepts an optional fourth `kind` argument. No
English/translated message parsing is used to infer an outcome.

## Verification

Build the current backend first, then run the dedicated suite with the project's
normal sandbox authorization and dependencies:

```sh
cargo build --locked
bash tests/js.sh semanticcolors
bash tests/js.sh semanticnotices
bash tests/semantic-colors.sh
```

The suite is registered in `tests/run-all.sh`. It uses guarded fixtures under
`/home/flea-sandbox`, not live settings. It retains an actual offscreen Qt proof
image at `target/semantic-checks/proof.png`. That image demonstrates real delegates,
not a native compositor screenshot or a desktop-wide accessibility audit.

Verified in this checkout:

- **1,313 real-Qt checks**, including family parity, interaction overrides, cut
  dimming, live palette replacement, neutral themes, status priority and text/mark
  contrast over 25 palette fixtures in Opaque, Transparent and Glassy modes.
- A real QML preference write, a next-process backend read, sibling preference
  preservation and two running ViewState instances following on/off changes.
- Pure JS: **17,145 standard checks**, four Edmonton and 13 DST checks. Existing
  archive-stub QColor diagnostics also reproduce in the baseline JS battery.
- Present-module static gates, file budget and the shared Clippy ratchet pass;
  Clippy reports zero rustc warnings and no raised lint counts.
- Focused theme-contrast (1,129 checks), glass-mode, material-startup, lazy-object,
  row/column cost, gridmark, language-toggle, uiwriter, menu-card-sink, status-hint,
  mouse, path-click, desktop-icons, icon-packs, settings-tail and runner-rule suites
  pass. Existing list/column/grid delegate counts stay 17/15/13.

### Remaining verification limits

This is **not** a fully green broad-runner result or a deployment approval:

- Debug and release unit runs each finish with 2,974 passed, two ignored and two
  failed undo-manifest permission-hook tests. Both failures reproduce against the
  unchanged baseline source. No Rust compiler warnings are reported.
- The legacy QML lint gate has the same five failing categories on this feature
  and the baseline: import-count drift and four newly reported lint categories.
  Its limits are not relaxed. The current present-module static allowance profile
  passes; absent-module locations were source-line remapped, not newly verified.
- Startup measures 732 objects on both baseline and feature against an inherited
  618-object baseline. The object ceiling is unchanged; the census gate remains
  red. The observed default source inventory adds only `js/SemanticColors.js`.
  Its 186 units sum to 1,801,180 bytes. The saved-OFF inventory's 183-unit source
  sum is re-derived as 1,690,339 bytes; its later census leg is blocked by the
  earlier object-count refusal.
- The full runner was attempted for 15 minutes in a read-only-host namespace.
  Before timeout, 86 suites completed: 59 passed and 27 failed. Early namespace
  restrictions caused several temporary-file/D-Bus/tool failures; corrected
  isolated focused reruns supersede those results where listed above. This is
  not a claim that every remaining failure is inherited.
- Of 20 focused reruns, 18 pass. Button-system also scans a pre-existing unrelated
  worktree and refuses its retired-recipe text. Xwsettings has mise trust/launch
  and private-bus/portal problems; this feature's dedicated two-instance preference
  proof passes independently. No trust settings or portal registrations are changed.
- A temporary source-overlay candidate was also composed with the adaptive-icons
  branch. Its older branch requires runner/budget reconciliation and removal of a
  duplicate raw-palette declaration after merging Tick's newer sources. With those
  candidate-only adjustments, the adaptive pure suite passes 2,534 checks, the
  actual Qt catalogue decodes all 360 cases with semantic mode enabled, and the
  semantic/persistence suite passes. The adaptive normal lifecycle probe times out
  in phase 1 with semantic mode both on and off, so full combined integration is
  not verified. The candidate and its logs stay under `target/semantic-checks/`;
  none of those integration adjustments is applied to either feature branch.
- Native compositor captures remain unverified. No merge into `tick`, commit,
  push, installation or bundle promotion has been performed.

Local logs are under `target/semantic-checks/`. Per-file ceilings re-derived by
`wc -l`: schema 625, ViewState 588, Settings.js 488, PaneWire 616 and StatusBar 486.
The branch baseline and design rationale are in `docs/semantic-colors-plan.md`.
