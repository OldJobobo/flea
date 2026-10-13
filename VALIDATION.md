# Validation report

Code commit: `b7407922` on `fix/listing-full-font-hinting`.
Baseline: upstream `664d80365adea52deaa738706f213d2a792c9a11`.

## Passed

- `cargo build --locked -q`
- `cargo test --locked --quiet`: 2541 passed, 1 ignored, 0 failed.
- `tests/font-hinting.sh`: 444 checks at 9, 10, 11, 12, 14, 16 and 20 px. Includes actual MatchText, Row, ColumnRow, GridTile and RenameField components, lazy marked/location/drop/tooltip text, native rendering, preserved family/size bindings, and full-hinted body/caption measurements. The same new test against the unmodified baseline completes with 144 failures, so it detects the missing preferences and measurements.
- `tests/columnrow-geom.sh`
- `tests/gridcaption.sh`
- `tests/gridmark.sh`
- `tests/listnamebudget.sh`
- `tests/rowcost.sh`: unchanged delegate-object counts.
- `tests/budget.sh`
- `tests/staticgates.sh`: all 14 gates.
- `tools/flea-file-budget`
- `bash -n tests/font-hinting.sh`
- `git diff --check` on the code patch.
- Startup source bytes independently summed to 1674197 over the unchanged unit list. Existing unqualified-read allowance identities/counts independently compared before and after; only line positions moved.
- The actual GUI captures confirm Maple Mono NF, 14 px, native rendering on both sides, default hinting before and full hinting after. Captures inspected visually and with OCR for personal paths/identifiers, and published PNG metadata stripped. Installed Flea and ordinary preferences were not changed.

## Not green locally; reproduced on the unchanged baseline

- `tests/headercost.sh`: functional fixture passes (236 checks); the wrapper rejects the headless environment's `$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.` warning. The updated Recent assertion measures against the dual layout's actual floor rather than assuming it must exceed the single-pane floor after the font advance changes.
- `tests/startup-objects.sh`: the functional probe passes with 628 objects against limit 628 and no added production objects; the wrapper rejects the same headless Hyprland warning.
- `tests/rename-frame.sh`: the negative-control assumption that the 9 px Tight frame must overhang fails before and after (5447 checks, one failure). No unrelated font/platform assumption was changed in that suite.
- `tools/flea-qmllint-gate`: both baseline and patch report 24 imports against ceiling 12 and the same four unclassified diagnostic categories. Actionable category counts are otherwise within the existing ceilings. No lint ceiling was increased.
- `tests/rename-grid-bottom.sh`: both baseline and patch fail to instantiate GridArea because a fixture references the non-existent `dropsLocal` property.

`tests/rename-list-bottom.sh` was interrupted by the enclosing multi-command timeout; it has no completion result. The full test matrix was not run. These limitations are why the contribution is a draft rather than a claim of an entirely green local test environment.

`--[ Pi :: gpt-6.1-sol ]--`  
   `--- on behalf of:` @OldJobobo
