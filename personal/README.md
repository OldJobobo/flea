# Tick development and deployment

`docs/personal-fork-plan.md` records the architecture and maintenance policy. Run
these commands from `/home/oldjobobo/Projects/flea`. The normal checkout stays on
`tick` (the GitHub default branch); clean upstream `main` has its own worktree. `origin` is OldJobobo/tick,
the only push destination, and upstream pushing remains disabled.

## Daily use

```sh
personal/tick --gui
personal/tick --gui ~/Downloads
personal/tick --select ~/Downloads/example.txt
personal/tick --custom-info
personal/tick-dev status
personal/tick-dev doctor
```

The launcher resolves `current` once, pinning the engine, overlaid UI, shelf and
helpers to one immutable bundle. It never accidentally uses checkout/package UI.
Stock `/usr/bin/flea` remains a separate fallback. `personal/flea-custom` and
`personal/flea-dev` remain working compatibility entry points.

State/caches stay in `.local-builds/profiles/daily/`; smoke tests use a separate
profile. The undo journal is private to this profile. HOME/config/data retain
real desktop locations for theme and MIME integration; this is not a security
sandbox, and opening real files acts on them. Child applications may inherit the
private XDG_STATE_HOME/XDG_CACHE_HOME.

## Build, verify and promote

Commit source changes first; deployment refuses a dirty source tree.

```sh
personal/tick-dev build
personal/tick-dev smoke --native <full-commit-hash>
personal/tick-dev promote <full-commit-hash>
```

The default build runs Rust tests in both profiles, personal tooling and the full
upstream battery. An explicitly quick build omits only the broad battery and
remains labelled `quick`. Tick bundles also run the branding-specific QML probe
against the transformed UI before packaging:

```sh
personal/tick-dev build --checks quick
personal/tick-dev verify <full-commit-hash>
personal/tick-dev verify --timeout 3600 <full-commit-hash>
```

Checks default to 600 seconds each. Timeouts are incomplete, never successful.
Logs live under `.local-builds/logs/`. Both modes require cargo, rustc, Git, Python
and Bubblewrap; smoke needs Quickshell/Omarchy. The broad battery also needs
upstream's documented test closure, including quickjs-ng `/usr/bin/qjs`. Nothing
is installed automatically.

Test/build subprocesses have a read-only host filesystem and this repository as
the writable area. Fixtures, HOME, Cargo home and logs stay repository-local.
Private in-repository scratch tmpfs is bound to conventional `/tmp` in a nested
namespace; it disappears after checks. That namespace has no network; Flea has
no Cargo dependencies at this version. Revisit this policy if upstream adds any.

Bundles archive tracked runtime assets, apply the reviewed personal branding
transform, then fingerprint every result. The manifest records original hashes
of overlaid files as well as the final assets. Drift in guarded upstream seams
fails the build rather than silently producing mixed branding. Clean contribution
commits without `personal/branding/` build without the Tick overlay.

Smoke checks validate the deployed listing, GUI path/count and loaded Omarchy
theme with three disposable entries. Native mode briefly opens a real window;
this is startup/integration evidence, not exhaustive UI testing.

Close Tick/custom service processes before promotion or rollback. Promotion
snapshots private state and selects the bundle atomically, retaining `previous`.

```sh
personal/tick-dev rollback
```

Rollback restores the previous bundle and its pre-promotion state, preserving
newer state separately. It does not undo file operations or external preferences.
Desktop branding is separate from bundle selection; rolling back to pre-Tick
Flea does not rewrite desktop files. Bundles are not auto-pruned.

## Upstream updates and contributions

```sh
personal/tick-dev fetch
personal/tick-dev sync
personal/tick-dev sync --base main
```

Default sync targets the latest stable upstream release; `--base main` opts into
unreleased work. Resolve and test in the printed sync worktree, integrate it into
`tick`, then rebuild/smoke/promote the resulting merge commit. No timer merges
or deploys unattended. `main` only fast-forwards and `tick` retains merges.

```sh
personal/tick-dev feature my-feature
personal/tick-dev integrate feature/my-feature
```

Feature worktrees start from `upstream/main` with no personal deployment/branding
commits. Push a branch to `origin` or open an upstream PR only when deliberately
publishing it; these tools never push or submit a PR automatically.

## Desktop integration

Preview a fresh installation before explicitly authorizing the named targets:

```sh
personal/tick-dev desktop plan --shortcuts --directory-default
personal/tick-dev desktop install --shortcuts --directory-default --confirm
```

This installs `~/.local/bin/tick`, its legacy `flea-custom` alias, a Tick desktop
entry/icon and a hidden legacy desktop entry. Fresh directory defaults use
`com.oldjobobo.tick.desktop`. Existing shortcuts and MIME defaults targeting the
old launcher/desktop ID keep working through those aliases.

For an already recorded Flea Custom installation, refresh branding only:

```sh
personal/tick-dev desktop rebrand
personal/tick-dev desktop rebrand --confirm
```

This touches only both launchers, both desktop entries and Tick's icon. It leaves
shortcuts, MIME preferences, D-Bus and portal routing byte-for-byte unchanged.
Icons come from the selected Tick bundle. The command refuses unowned collisions,
symlinks, modified managed files, unfinished recovery records and running custom
processes. Rollback/removal backups are retained; interrupted rebrands record
immediate recovery data in `.local-builds/desktop-rebrand-pending.json`.

Fresh installation refuses an existing recorded installation and symlinked
preference files. A symlinked MIME file requires explicit authorization of its
resolved target; only that file is edited and the symlink is preserved. On this
installation that target is `/home/oldjobobo/dotfiles/xdg/.config/mimeapps.list`:

```sh
personal/tick-dev desktop install --shortcuts --directory-default \
  --mime-target /home/oldjobobo/dotfiles/xdg/.config/mimeapps.list --confirm
```

Optional reveal/chooser routes require separate explicit installation flags:

```sh
personal/tick-dev desktop plan --shortcuts --directory-default --reveal --picker
```

They override the same packaged FileManager1/Flea portal service names, not
parallel services. Only FileChooser is preferred; other portal interfaces stay
unchanged. Stock owners may need to exit before the next activation uses the
custom helpers. Picker installation restarts the user portal frontend; avoid it
during screen sharing. The `.portal` registration still comes from stock Flea.
Tick's picker window uses `com.oldjobobo.tick.picker`.

Removal refuses subsequent user edits, otherwise restoring pre-install files:

```sh
personal/tick-dev desktop remove --confirm
```

No service is killed automatically. Shelf/bar activation is not silently enabled;
its bundled source still needs separately verified environment/routing. Keep it
disabled until that work is explicitly done. Backups can contain personal data;
never publish `.local-builds/`.

## Checks

```sh
python3 -B -m unittest discover -s personal/tests -v
```

Tests use scratch repositories/profiles under `.local-builds/tmp/`. They do not
change live preferences, install to real user directories, submit PRs or push.
The branding-specific runtime probe also checks the transformed bundle in a
disposable profile; see `personal/tests/branding.qml`.
