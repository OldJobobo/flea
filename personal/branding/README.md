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
and About implementation under their existing QML names. No extra component
registration or per-file operation is introduced. The `shelf` brand mark uses the
same main Shape in every icon family; Markdown and other third-party marks stay
unchanged. The original icon family's selector label intentionally remains Flea.

The browser uses app ID `com.oldjobobo.tick`, and the picker appends `.picker`.
Flea shell IDs, IPC target, backend command names, crate/package names, environment
variables, data paths and keys remain compatible. About retains upstream credit,
links to this fork and Flea sponsorship, and exposes neither the stock package
updater nor the stock default-handler action. Tick updates go through `tick-dev`.

Guarded upstream seams fail closed if changed. Bundle metadata records original
source hashes and final file fingerprints; old unbranded bundles remain valid.
Only commits that contain these personal branding assets receive the overlay.
