# Initial setup and verification (historical)

The personal application and GitHub fork are now named **Tick**. The checkout and
engine identities remain Flea-compatible. The figures below describe the initial
setup, not current verification; current commands and branding are documented in
`personal/README.md`.

## Installed layout

- Fork: `OldJobobo/tick`; local checkout `/home/oldjobobo/Projects/flea`.
- Persistent daily integration branch: `tick` (originally `personal`), based initially on `v0.3.10`.
- Clean upstream `main`: `.personal-worktrees/upstream`.
- `origin` is the push destination; upstream pushing is locally disabled.
- No existing fork feature branch is automatically integrated or deleted.
- Runtime bundles, private profiles, snapshots, logs and verification metadata are
  ignored under `.local-builds/`; the system Flea package stays untouched.

The final selected commit and current routing are runtime state, not values to pin in
this document. Inspect `personal/tick-dev status`, `personal/tick --custom-info`
and `.local-builds/desktop.json` when an installation has been recorded.

## Verification achieved

- Rust unit tests in debug and release: 2,541 passed and 1 ignored in each profile.
- Personal tooling: 26 regression tests covering bundles, branch isolation, promotion,
  rollback, timeouts, launcher pinning and conservative desktop install/restoration.
- Real deployed backend listing and offscreen/native Quickshell startup: passed, including
  fixture path, three visible entries and the real Omarchy theme loading.
- Smoke IPC is pinned to the exact process started, not the shared `flea` shell ID;
  configuration-path selection can otherwise accidentally query an existing stock window.
- At initial setup, Git source under `src/`, `ui/`, `shelf/` and upstream tests was
  unmodified from the release baseline; subsequent integrated features are recorded
  in Git history. Personal deployment/branding machinery lives in `personal/`.

## Broad upstream battery: not green

The initial `tests/run-all.sh` attempt was stopped by the execution limit after
2,400 seconds. Of 203 completed suites, 143 passed and 60 failed. It did not finish,
and neither a complete pass nor a complete skip inventory can be claimed.
The log is retained locally at:

`.local-builds/logs/1792020247564085404-upstream-battery.log`

Observed blockers include missing quickjs-ng `/usr/bin/qjs`, missing generated media
fixtures, a stale upstream benchmark image, private-bus/session limitations, strict
Hyprland-warning gates in offscreen suites, and several assertion failures that have
not been individually diagnosed. Do not assume every failure is environmental.
No test was removed or silently skipped to turn this result green.

The usable bundle is explicitly labelled `quick`: both unit profiles, personal tools
and startup smoke pass, while the broader battery is incomplete/failed. Build and
verification commands now have explicit time bounds, and record timeout evidence as
incomplete. A future full verification needs the complete upstream dependency and
fixture closure and individual investigation of remaining failures.

## Boundary of initial integration

The custom launcher, desktop entry, both file-manager shortcuts and directory MIME
default were installed with explicit permission. The MIME file's symlink into
`/home/oldjobobo/dotfiles/xdg/.config/mimeapps.list` was preserved; only its directory
default changed. The installer retains original files and modes for restoration.

A distinct custom launcher and user-level desktop-routing installer are implemented.
Installing those user files, changing default handlers/shortcuts, taking over existing
D-Bus service names, and activating the shelf are separate explicit operations. Never
infer live routing merely because a bundle was built. Inspect the runtime installation
record and desktop defaults.

The shelf sources and portal/reveal helpers are bundled. Shelf/bar environment routing
has not been activated or verified. Optional reveal/chooser installation remains guarded
because it replaces user-level activation of the same stock service names, not parallel
namespaced services. No automatic upstream deployment or upstream PR is created.
