# Supplied Tick animations

Imported from `personal/branding/tick-mascot-animation-sources.zip`, which
consolidates OldJobobo's two supplied animation packs. The newer nine-state
sources are canonical. The older rig, demo and README are preserved under
`tick-animations/legacy/three-state/`, and its unique `tick-preview.gif` is retained.
Byte-identical shared files are stored once; `CONSOLIDATION.json` maps every
original file to its preserved member and records the original archive hashes.
The archive and its rendered GIF previews are not needed at runtime and are not
modified by the importer. No new authorship or license is inferred for the supplied
artwork or motion studies.

- `assets/`: the exact 15 supplied static SVG vector pieces.
- `supplied/TickMascot.qml`: the original supplied native Qt Quick rig, retained
  as reference data, not imported or executed by Tick.
- `motion-spec.json`: the six additional supplied keyframe tracks.
- `source.json`: name/SHA-256 of the input archive and each retained source file.
- `TickMotions.js`: generated finite-duration keyframe data for the six extra states.
- `TickParts.js`: generated compound-path strings from those SVGs. Rebuild with
  `python3 -B personal/import_tick_animations.py` while the supplied ZIP is present.

The production adaptation is `personal/branding/TickIdleMotion.qml`. It preserves
all nine supplied poses and timings while using finite cycles,
theme-colored ShapePaths, no painted background plate, and the existing Tick
empty-state lifecycle. It does not run the archive's looping SVGs or GIFs.

All pieces share a 24-unit grid. The six upper/lower leg pivots, alternating gait
phases, antenna pivots, body breathing, seven hop keyframes and extra mood tracks
come from the supplied rig. The host scales the scene to the empty-state mark; clipping and
neutral poses are checked at the shipped size. Reduced motion and hidden views
stop playback and clear queued clips; non-empty-state marks remain static.
