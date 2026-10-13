# Flea listing font-hinting evidence

These review assets live on a separate fork-only branch so the code PR does not add screenshots to Flea's shipped tree.

## Actual Flea: before and after

`before.png` and `after.png` are native-resolution captures of the actual upstream GUI at commit `664d80365adea52deaa738706f213d2a792c9a11`, without and with the listing full-hinting patch. Both use the same development backend, generated fixture files, isolated home/preferences/theme state, 1100 × 660 client size, Vulkan backend, Maple Mono NF Regular, 14 px body text and a scale-1 display. Runtime inspection confirmed `renderType=1` on both sides and `hinting=0` before versus `hinting=3` after. This is not a switch from distance-field to native rendering: Flea already enables native rendering.

The filesystem status strip was excluded from the capture. All visible names, paths, contents, sizes and timestamps are synthetic. No personal directory, private file, desktop wallpaper, other window or machine storage information is shown. Added labels sit above the original captures; the captured pixels have not been rescaled or sharpened. PNG metadata has been stripped.

The side-by-side image is 2200 × 688. Open the original PNG at 100% to compare rasterization, rather than a browser's scaled preview.

Before and after:
https://raw.githubusercontent.com/OldJobobo/flea/evidence/font-hinting/before-after.png

Before:
https://raw.githubusercontent.com/OldJobobo/flea/evidence/font-hinting/before.png

After:
https://raw.githubusercontent.com/OldJobobo/flea/evidence/font-hinting/after.png

## Current, vertical and full hinting

The independent `hinting-comparison.qml` demonstration uses `Text.NativeRendering` in every column, identical text/colors/font sizes, and respectively `Font.PreferDefaultHinting`, `Font.PreferVerticalHinting` and `Font.PreferFullHinting`. It shows 10, 12, 14, 16 and 20 px. Only each sample's hinting differs; headings use the same full-hinted font in all columns. Run with `qs -p ./hinting-comparison.qml`; to reproduce this capture, `monospace` must resolve to Maple Mono NF Regular and the display must use scale 1. Change the font label if comparing another face.

The native-resolution image is 1180 × 780:
https://raw.githubusercontent.com/OldJobobo/flea/evidence/font-hinting/hinting-comparison.png

Full hinting improved this particular font/display setup, not necessarily every font or fractional scale. It can change horizontal advances, so the production patch also aligns filename budgets and column autofit measurements with the hinted text. It preserves system font-family and text-size bindings and does not add a production tree traversal, timer, renderer change or font-size setting.

`--[ Pi :: gpt-6.1-sol ]--`  
   `--- on behalf of:` @OldJobobo
