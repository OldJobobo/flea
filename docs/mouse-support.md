# Tick mouse support

Tick is keyboard-first, not keyboard-dependent. Pointer actions reuse the existing
navigation, selection, file-operation, confirmation and undo paths. This does not
change the terminal interface or install anything into the daily bundle.

## Navigation and discoverability

- Back, Forward and Parent folder are visible chrome controls. Forward is disabled
  without forward history, and in Trash, Recent and the image flasher.
- Rest the pointer for 650 ms to see a control's name and its current keyboard
  shortcut, where available. Icon-only chrome controls share one tooltip lane.
- Listing, grid and column items expose their full filename; sidebar locations and
  tabs expose their path. Close-tab, new-tab and eject targets have their own hints.
- Hints are plain text, stay inside the window, never take keyboard focus and do
  not consume clicks. Pointer presses, focus changes, keyboard browsing, overlays
  and changed/reused items dismiss stale hints.

## Context menus

- Right-click a file, a selection, listing background, column header or sidebar
  location to use its existing contextual actions. Right-click within a selection
  retains it; right-click outside it targets the clicked item.
- A folder's file menu now includes **Open in new tab**, disabled for files and
  multi-selection. The background menu includes **New tab** and **Refresh**.
- Right-click a tab for **New tab**, **Duplicate tab**, or **Close tab**. This uses
  the pane's existing menu, not a second focus-claiming popup. It captures the tab's
  stable identity and path: reorder follows the same tab, while closing or
  navigating it invalidates the old menu. Escape restores the prior focus.
- Existing menu customization is respected. In particular, Flea's Places row menu
  and optional actions such as Properties may still be hidden by the saved
  **Settings > Menus** choices. This change does not overwrite those preferences.

## Existing conventions retained

Single-click selection, double-click opening (or the configured single-click
mode), Ctrl-click toggling, Shift-click ranges, drag-to-select, draggable
scrollbars, clickable path segments, middle-click folder tabs, back/forward mouse
buttons, file drag-and-drop and tab dragging continue through their existing
implementations. Undo remains clickable in the status strip after undoable actions.
No confirmation or collision handling is bypassed.

## Architecture and budgets

`MouseHints.qml` owns one window-wide hover handler, passive press handler, delay
and window-focus connection. `MouseHintBubble.qml` is instantiated only on first
use. `js/MouseHints.js` walks only the item chain under the pointer; it never
reads the directory model or requests file metadata. Rows gain a string property,
not an additional object. `js/TabMenu.js` resolves captured tab identities and
uses the existing `Tabs` commands. `keys.toml` records the new tab right-click
contract; `ui/js/Keymap.js` is regenerated.

The measured default startup census moves from 628 to 641 objects: eight for the
additional chrome button and five for the shared tooltip lane. Its bubble remains
absent before first hover. The first-frame trace moves from 178 to 181 units and
from 1684068 to 1692919 bytes, pinned in `tests/startup-units.txt`.

File ceilings re-derived with `wc -l`: `ui/ContextMenu.qml` 804,
`ui/TabBar.qml` 682, `ui/WindowBody.qml` 820, `ui/Row.qml` 499,
`ui/js/Focus.js` 484, `ui/js/Menu.js` 497, `tests/js/menu.js` 599 and
`tests/js/tap.js` 402. New tooltip and tab-menu units remain below their caps.

## Verification

- `bash tests/mouse-support.sh`: real Qt pointer events, delayed hints, plain text,
  reused-item dismissal, overlay blocking, edge placement, focus preservation,
  Forward enablement, tab right-click, Escape and menu-context transitions.
- `bash tests/js.sh`: includes `mousesupport`, menu eligibility, stale/reordered tab
  identities, keyboard reachability and the regenerated pointer contract.
- `bash tests/path-click.sh`: path entry, breadcrumbs and click-away behavior.
- `bash tests/startup-objects.sh`: startup object/unit budgets and lazy Quick Look.
- `tools/flea-file-budget`: documented file ceilings.

The implementation passed 15206 standard JavaScript checks, the 4 Edmonton and
13 DST checks, 22 Qt mouse checks, the 26 path-click checks, startup and file-budget
gates, and generated-keymap comparison. The full `tests/run-all.sh` battery was
not run. The QML lint gate is still blocked by the same failures reproduced on
unchanged HEAD: 24 import findings against a ceiling of 12 and four unclassified
warning categories. Its actionable counts do not increase with this feature;
pre-existing archive-test stub color warnings also remain in the JS harness.

These are headless tests, not a claim of an exhaustive physical-mouse or visual
accessibility audit. Existing drag/drop, portal-picker and touchpad suites remain
separate coverage; the new tooltip lane is currently installed in the main file
manager window, not the portal picker. Theme/monitor scaling and platform drag
feedback still merit an interactive desktop check.
