# Tick full semantic colours — feature plan

Status: implemented on the feature branch. See `docs/semantic-colors.md` for
current behaviour, checks and remaining verification limits. This document
retains the original design plan and its proposed integration milestones.

## Branch and baseline

- Branch: `feature/tick-semantic-colors`.
- Base: local `tick` at `0800bd00` (`merge(tick): sync Flea 0.3.12`).
- This is a Tick-specific appearance feature, deliberately based on Tick rather
  than a clean upstream contribution branch. Keep deployment/branding edits out.
- The separate `feature/tick-adaptive-icons` branch is not part of this baseline.
  Semantic colours must work without it. Verify their combination at integration;
  do not merge either branch into `tick` as part of planning.
- No desktop theme files, installed icon themes, live preferences or deployment
  bundles are changed. Creating this branch does not change the daily build.

## Goal and visual direction

Let the active Omarchy theme colour more of Tick's meaningful UI, not just focus,
symlinks and executables. Add an opt-in **Full semantic colours** setting under
Settings → Display → Appearance. The result should feel distinctly themed while
remaining a calm file manager, not a rainbow of unrelated decorations.

Colour communicates a stable meaning: success, caution, information, file family
or navigation. Neutral backgrounds, ordinary body text and metadata preserve the
reading hierarchy. Accent still means interaction/focus, never simply “important”.
No new colour scheme, hardcoded rainbow, per-theme special cases or animations.

## What exists on the baseline

- `ui/Theme.qml` parses `colors.toml`, retains `palette`, derives opaque roles and
  reloads through the existing `theme.name` watcher.
- `ui/ThemeColors.qml` exposes the effective colours and routes glass-aware inks
  through `ui/js/Material.js`. Extend this seam rather than bypassing it.
- `ui/js/Palette.js` parses six-digit hex colours and provides ordered fallbacks;
  `ui/js/Contrast.js` supplies contrast and tag-colour handling.
- `ui/Row.qml::nameColor()` gives resting symlinks cyan and trusted executables
  green. Directories stay neutral; lifted rows give up type colour for contrast.
- `ui/ColumnRow.qml` uses accent/foreground/muted ink, while `ui/GridTile.qml`
  keeps filenames foreground. Full mode needs deliberate parity across views.
- `ui/MenuRow.qml` already distinguishes dangerous, unavailable and picked rows.
  Preserve those semantics and its current cursor-wash recipe.
- `ui/StatusBar.qml::centreColor()` already resolves a role, but
  `ui/js/Status.js::centreRole()` currently returns only error or foreground.
  A non-error message is not proof of success.
- `ui/TransferCard.qml` uses accent for progress. Settings and preference
  validation live in `ui/js/Settings.js`, `ui/ViewState.qml` and `src/uischema.rs`.

## User contract

Proposed persisted key: `display.semanticColors`, a strict boolean, default false.
Missing keys in old state mean false. Turning it on or off updates existing and
new windows immediately through the normal preference path; no restart required.
Use the existing shared `ui.json`, not a new configuration file or environment
variable. Invalid writes are rejected by the existing schema machinery.

Suggested label: **Full semantic colours**.
Suggested hint: “Use theme colours for file types, navigation and operation states.
Selection and focus keep the theme accent.”

Off preserves the current appearance, including existing symlink/executable inks,
tag colours, syntax highlighting and selected icon family. “Off” does not mean
monochrome. On is independent of Interface icons, installed File and folder icons,
and the separately developed Adaptive mode. Never recolour third-party artwork,
thumbnails, brand marks, user tag swatches or document preview content.

## Role vocabulary and palette precedence

These are proposed Tick-local semantic roles, not claims about an existing
Omarchy semantic-key specification. Resolve them from the parsed palette only.
Each chain uses the first valid colour, then the next fallback:

| Role | Proposed palette inputs, in order | Purpose |
| --- | --- | --- |
| success | `success`, `green`, `color2`, accent | Confirmed operation completion, positive state |
| warning | `warning`, `yellow`, `color3`, accent | Caution, recoverable/partial outcome, collision review |
| info | `info`, `blue`, `color4`, accent | Informational state, non-destructive activity |
| danger | existing urgent/error derivation | Destructive actions and actual failures |
| directory | accent | Folder names and eligible interface folder glyphs |
| link | existing cyan/`color6` symlink derivation | Symlinks, before file-family classification |
| executable | existing green/`color2` derivation | Trusted executable rows only |
| document | `blue`, `color4`, accent | Documents and plain text |
| media | `magenta`, `color5`, accent | Images, audio and video |
| archive | `yellow`, `color3`, accent | Archives and compressed files |
| code | `cyan`, `color6`, accent | Source and structured data |
| unknown | foreground | No reliable family information |

Do not reinterpret an arbitrary `error` key differently from today's urgent role.
Check representative theme inputs before freezing the optional success/warning/info
aliases. Do not add support for unrelated shell sections or a general TOML rewrite.

Resolve text and glyph/frame variants against their actual background and surface
planes. Use at least 4.5:1 for text and 3:1 for meaningful non-text marks. Reuse
`ThemeColors.modeInk()` and the existing material policy for glass, alpha, mode and
focus changes. A new role must not read raw ANSI colour directly at a call site.
For hueless themes, retain neutral/theme-derived fallback behaviour: shape, labels
and state wording must communicate everything without distinct hues. Missing or
malformed palette entries must never leak colours from the previous theme.

## Where full mode adds colour

### File views: first visible milestone

Use one pure resolver shared by list, columns and grid, not three copies of the
rules. Classify only from already supplied row/icon/name data. Never stat, sniff
MIME, scan a directory or request metadata just to select a colour. A small bounded
mapping of existing generic icon names and conservative extension hints is enough;
unknown and ambiguous types remain neutral. Do not classify using translated kind
labels. Document and test the mapping before expanding it.

At rest, names take the semantic family role. Interface file/folder glyphs may use
that role too; installed artwork and thumbnails remain untouched. All columns
other than the filename retain their current metadata hierarchy.

Precedence: unavailable/dim/cut handling and interaction legibility override type
colour; symlink wins over directory, directory wins over executable, a trusted
executable wins over ordinary family classification. Preserve `row.x !== false`
and the existing permission/mount trust rules—file extensions must never imply
executable permission. Inspect each view's current cursor/lifted/selected/hover/drop
states before wiring: full mode must retain its exact focus and selection drawing.
Keep filenames PlainText and leave search-match highlights unchanged.

### Operation states: explicit meaning, not text guessing

Use success only for confirmed completed work, warning for an explicit caution or
partial result, info for an explicit information/activity state, and existing error
roles for failures. Cancelled work is not success. Do not recolour the entire
status bar or dialog ground; colour the state mark and short state-bearing text.
Progress may use info; Cancel and focus controls keep their current meanings.

Audit the notice producers in `ui/js/Ops.js`, `ui/PaneWire.qml` and their callers.
Where today's payload is only text plus `isError`, add a narrowly scoped optional
semantic kind along the existing UI event path. Preserve ordering, error queues,
timeouts and acknowledgements. Unknown producers stay neutral. Never infer state
from English substrings, a translated sentence, or simply `!isError`. Require a
separate protocol decision and tests if a backend message actually needs changing;
a wire-contract change is not assumed necessary here.

### Navigation and controls: restrained expansion

Use directory/info roles on eligible resting sidebar and breadcrumb interface
marks, and warning on explicit caution marks in collision/review surfaces. Keep
ordinary menu actions neutral; destructive rows keep error, selected choices and
focus rings keep accent, unavailable rows keep muted. Do not make every toolbar
icon a different colour. Reuse existing marks/text: no extra row badges or objects.
Settings facts or checks get semantic ink only when their data expresses an actual
state, never merely because a toggle is on.

## Implementation slices and completion criteria

1. **Palette resolver and preference.** Add a small pure `ui/js/SemanticColors.js`
   for ordered role derivation and bounded family classification. Wire the schema,
   ViewState and Display control, then expose effective roles through ThemeColors.
   Add schema and pure JS tests first. Done when defaults, bad writes, persistence,
   cross-window changes, neutral palettes and palette replacement are covered.
2. **File-view parity.** Wire the same resolver into Row, ColumnRow and GridTile.
   Done when representative folders/files, links and trusted/untrusted executables
   agree across views, unknowns are neutral, and every interaction state retains
   focus/selection legibility. Off-mode renders must match the baseline.
3. **Operation-state semantics.** Introduce typed notice kinds only at audited
   producers, then wire StatusBar, TransferCard and applicable review surfaces.
   Done when success, failure, cancellation, partial outcomes and concurrent activity
   keep correct wording, precedence and dismissal with both modes.
4. **Navigation polish and visual proof.** Apply the restrained navigation/control
   pass, exercise icon combinations and glass modes, and review actual Qt captures.
   Done when both colour modes are intentional on dark, light, neutral and
   low-contrast themes, without claiming inaccessible wallpaper combinations pass.
5. **Integration readiness.** Document shipped roles and known limits, run the
   complete gates, and separately test a temporary integration with adaptive icons.
   No merge, push, deployment or default-on migration is implied by this plan.

Keep each slice independently reviewable. Prefer new small helpers to growing
already oversized files. Register every new QML component in `ui/qmldir`. Avoid
new components where a pure JS helper and existing colour bindings suffice.

## Verification plan

- Pure tests: role precedence, missing/invalid colours, malformed/empty input,
  replacement without stale roles, neutral palettes, bounded family mapping,
  executable trust and interaction overrides. Add `tests/js/semanticcolors.js` to
  the existing JS battery rather than inventing a separate runner.
- Schema/settings: strict boolean validation; old state defaults; preservation of
  sibling Display keys; persistence; live two-window and picker behaviour. Extend
  existing Rust and JS settings tests, splitting files where budgets require it.
- QML: add a focused semantic-colour harness, register it in `tests/run-all.sh`,
  and run existing `tests/theme-contrast.sh`, button, glass-mode and material
  probes. Check text and marks on their actual planes and interaction washes,
  not merely on the listing background. Use existing palette fixtures plus sparse,
  malformed and hueless inputs; no installed theme mutation for tests.
- Native proof: capture list/columns/grid, menus, rail, transfer and collision
  states, with mode off/on; dark/light/neutral/low-contrast themes; opaque/default
  transparency/glassy modes; active/inactive panes; hover/cursor/multi-selection;
  built-in/system icons and adaptive icons only in the integration candidate.
- Performance: no per-file operations, extra delegate objects, model changes,
  directory sweeps, polling, new process or icon cache for colours. Compare startup
  census and first-frame units/bytes with the actual branch baseline. Re-derive
  affected file ceilings using `wc -l` and use the scoped override for Tick notes;
  do not restructure the upstream-heavy `AGENTS.md`.
- Final gates: `tools/flea-file-budget`, `tools/flea-qmllint-gate`, documented
  warning-free Clippy/hooks, `cargo test`, and `./tests/run-all.sh` (both profiles).
  Record failures/skips honestly. Read each harness's guard requirements before
  execution; fixture/destructive work requires `tools/flea-sandbox-guard` and
  `/home/flea-sandbox`. This plan does not authorize out-of-repository writes.

## Deliberate non-goals

No TUI recolour in this first feature, global Omarchy customization, theme editor,
new icon pack, desktop-wide generated assets, syntax palette rewrite, tag palette
rewrite, persistent generated files, new metadata protocol, or changes to selection
geometry, glass planes, keyboard bindings or filesystem operation behaviour.

## Review decisions before implementation

- Default proposal is opt-in and reversible; enabling it by default is a separate
  explicit decision after visual review.
- Initial family taxonomy is intentionally small. Split media or add special
  folder roles only if visual proof shows a useful distinction, not for hue count.
- Inspect the current source and relevant `AGENTS.md` sections again per slice;
  this document is a plan against the recorded base, not authority to override
  later upstream fixes or measured budget gates.
