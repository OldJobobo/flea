# Path editing

Click the path once to open its input, with the current directory selected for
replacement. Ctrl+L and `:` still open the same editor.

In breadcrumb mode, ancestor segments remain single-click navigation targets.
The current folder, collapsed marker and empty strip open the input on one click.
The same rule applies to a dual pane's path strip.

Clicking outside the input and its suggestions dismisses editing and drops
uncommitted text without navigating. The original outside click still reaches
its target, including another text field or a button. Clicking within the input
preserves editing; suggestion presses are not treated as outside clicks.
Deactivating the window also dismisses editing. Enter and suggestion selection
still navigate; Escape cancels. Closing explicitly releases the text field's
focus before the host restores its own focus.

The shared `PathEntry.qml` owns dismissal, so keyboard-opened picker inputs use
the same focus behavior. Its outside-press layer is constructed only with the
lazy editor in the browser, is inactive when editing is closed, and excludes the
input and suggestion dropdown through a containment mask. It rejects the outside
press after dismissal rather than swallowing or synthesizing another click.

`tests/path-click.sh` sends real Qt mouse/key events through the shipped components
and covers first-click activation, initial selection, blank-ground dismissal,
focus transfer, click-through, current/ancestor/elided breadcrumbs, dual-pane
padding, input guards, suggestion safety, Enter/Escape and window deactivation.
The existing jump and completion suites cover keyboard navigation and stale
answers. The headless dropdown probe can fall back to keyboard selection when
its pointer choice is not delivered; the native `tests/ui.sh` click/dual cases
remain the compositor-level checks.
