# Save-picker folder creation — isolated validation

This feature branches from upstream `664d8036` and is independent of font-hinting PR #303.

## Verified

- `cargo build --locked`: passed.
- `cargo test --locked`: 2548 passed, 1 ignored.
- Seven new Rust tests cover reviewed-parent ownership, cancellation/close, stale identities, replaced parents, permission refusal, existing files/directories/symlinks, single-component validation, Unicode and preserved whitespace. Preparing a folder does not write it; creation never writes the proposed output file.
- `tests/picker-folder.sh`: 47 QML checks passed. The real window/backend covers collisions, preserved input, duplicate submission, pending cancellation, entering the created folder, retained filename, no automatic save, focus restoration, grid mode and save cancellation. Controlled replies cover preparation retry, stale responses, changed-context committed outcomes, backend loss, Tab focus, narrow 20px layout, and complete action borders at normal size.
- `picker-grid`, `picker-header`, `picker-selection` (75 checks), `picker-stall` (six lifecycle scenarios), and `picker-save-wrap` (16 checks): passed.
- All 14 static gates and file-budget: passed. Unqualified allowances were only repositioned for unchanged statements; none added. Startup units and byte sum unchanged.
- Shell syntax and `git diff --check`: passed.

## Actual desktop interaction

In an isolated native picker, Escape dismissed the folder card without dismissing the save request. Ctrl+Shift+N reopened it. Typing `Prototype folder` and pressing Enter created that directory inside the synthetic Downloads fixture and entered it. The save filename remained `sample-download.zip`, Save became available, and the save request was not automatically accepted.

The updated modal was visually checked: both action borders are complete, and the toolbar has a borderless Nerd Font `nf-fa-folder_plus` glyph at U+EEC7. The card includes the scroll viewport's focus clearance in its height. Regression checks pin the glyph, absent border, accessibility label and full bottom-frame containment.

## Evidence and isolation

The screenshot contains synthetic paths/files only. Device/network entries are omitted in the demo copy, and its creation action is restricted to its synthetic home. The bottom filesystem status strip is cropped out. PNG metadata is stripped. Installed Flea, normal preferences and portal registration were not modified.

The demo launcher creates a new marker-managed fixture under `/home/flea-sandbox`, copies the UI, isolates HOME and XDG preferences/cache, and points at the candidate backend. Its only UI deviations are those privacy restrictions and an optional auto-open timer. A Save confirmation produces a reply JSON; there is no requesting browser to write a downloaded file. Created folders persist in the test fixture.

## Known limits

- `picker-040`: two collision phases fail identically with baseline UI and candidate UI using the same candidate backend; six other phases pass. Baseline comparison uses the untouched upstream UI, not a separately rebuilt baseline backend.
- The full private-portal/native browser harness was not run: its `omarchy-drive` helper is unavailable. Actual native keyboard interaction above was performed with `wtype` against the isolated picker instead.
- Headless tests exclude only known platform warnings about missing Hyprland and unsupported window masks. Live demo logs include host-portal registration and Hyprland workspace-tracking warnings, but no QML type/reference errors.
- Full project test matrix was not run. Fractional scaling remains a manual-review case.
