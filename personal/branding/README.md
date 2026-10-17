# Tick identity

Tick's mark is derived from the supplied
`personal/Refined monochrome Tick with segmented antennae.png`. The original is
kept unchanged. No new authorship or license for that supplied image is inferred;
Flea's upstream MIT attribution and other libraries' notices remain separate.

The cleaned vector retains the body, eyes, segmented antennae and legs. Small
alpha/noise islands are removed before tracing, making the supplied artwork usable
at application-icon sizes. The desktop icon uses a charcoal `#202326` plate and
`#f4f4f4` artwork; in-app marks use the existing semantic theme color, including
light themes. The drawing is normalized to 24 units with a one-unit inset.

Regenerate with the already installed ImageMagick and Potrace:

```sh
python3 -B personal/trace_tick.py
```

The exact alpha threshold, connected-component threshold and tracing parameters
are recorded in that script. Scratch files stay under `.local-builds/tick-branding/`.
It writes `tick.svg` and `mark.json`, never the source PNG.

## Personal bundle overlay

`personal/branding.py` transforms a disposable archived bundle, not the upstream
working tree. Runtime templates here replace the existing `FleaMark.qml`, updater
and About implementation under their existing QML names. The idle-motion helper
is registered only in the disposable bundle's `ui/qmldir` and loaded on demand;
no per-file operation is introduced. The `shelf` brand mark uses the
same main Shape in every icon family; Markdown and other third-party marks stay
unchanged. The original icon family's selector label intentionally remains Flea.

The browser uses app ID `com.oldjobobo.tick`, and the picker appends `.picker`.
Flea shell IDs, IPC target, backend command names, crate/package names, environment
variables, data paths and keys remain compatible. About retains upstream credit,
links to this fork and Flea sponsorship, and exposes neither the stock package
updater nor the stock default-handler action. Tick updates go through `tick-dev`.

## Empty-folder character beats

The empty-folder mascot has a soft arrival, then three short gestures on the
existing 2.8-second caption cadence: a curious tilt, a little hop, and a wiggle.
After the third beat it returns exactly to its neutral pose and stays still.
There is no continuous idle loop, extra recurring timer, or directory work.

`TickMark.qml` keeps the existing `replay()`, `settle()` and `settled` contract.
Only the overlaid `EmptyState.qml` opts into `idleGestures`; menu/settings/shelf
marks remain static. Fixed-caption states keep their own glyph instead of the
mascot. Artwork, theme ink, layout and caption wording are unchanged.

`TickIdleMotion.qml` is instantiated only for a visible animated mascot and
released on hide. Reduced motion skips allocation on appearance, refuses replay,
and interrupts an active gesture back to neutral immediately. A fresh appearance
resets the gesture order. Both files remain under their normal QML file caps;
no upstream file ceiling or source startup-unit budget changes.

`personal/tests/mascot.sh` tests the actual overlaid EmptyState. It runs as part
of the bundle branding gate and covers all gestures, three-beat rest, interruption,
hidden release, fixed captions, and non-empty-state marks. Optional screenshots
can be saved to an existing directory under `.local-builds` by setting
`TICK_MASCOT_CAPTURE`; `TICK_BUNDLE` selects the staged bundle under test.

Guarded upstream seams fail closed if changed. Bundle metadata records original
source hashes and final file fingerprints; old unbranded bundles remain valid.
Only commits that contain these personal branding assets receive the overlay.
