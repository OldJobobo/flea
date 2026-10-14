# OldJobobo's Flea development and deployment tools

The architecture and maintenance policy are recorded in `docs/personal-fork-plan.md`.
All commands below run from `/home/oldjobobo/Projects/flea` unless stated otherwise.
The normal checkout stays on `personal`; clean upstream `main` has its own worktree.
`origin` is your fork, and upstream pushing is disabled locally.

## Daily use

```sh
personal/flea-custom --gui
personal/flea-custom --gui ~/Downloads
personal/flea-custom --select ~/Downloads/example.txt
personal/flea-custom --custom-info
personal/flea-dev status
personal/flea-dev doctor
```

The launcher resolves `current` once and pins the binary, UI, shelf and helpers to the
same deployed commit. It never uses checkout UI or the packaged UI by accident.
Packaged `/usr/bin/flea` remains a separate fallback, not a symlink to this version.

Daily state and caches live in `.local-builds/profiles/daily/`. Smoke tests have a
separate profile. HOME/config/data retain the real desktop locations so theme and
MIME integration work. Applications launched directly from Flea may inherit its
private XDG_STATE_HOME/XDG_CACHE_HOME; this is not full process sandboxing.

The undo journal is private to the custom profile; rollback is not filesystem undo.
Do not activate the shelf from Settings until its Omarchy shell routing is configured:
the bar process would otherwise use a different environment/profile. Likewise, the
upstream Settings > About default/update buttons describe packaged Flea, not this fork.
Use these tools instead; the launcher refuses stock default/picker/update CLI verbs.

## Build, verify, promote

Commit source changes first. A build packages a clean commit, not uncommitted edits.

```sh
personal/flea-dev build                      # both unit-test profiles, tools, full upstream battery
personal/flea-dev smoke "$(git rev-parse HEAD)"
personal/flea-dev promote "$(git rev-parse HEAD)"
```

A quick build omits the broad upstream battery but still tests Rust in both profiles
and this tooling. It must be chosen explicitly and remains labelled `quick` in status.

```sh
personal/flea-dev build --checks quick
personal/flea-dev verify "$(git rev-parse HEAD)"  # add full-battery evidence later
```

Both build modes also need `cargo`, `rustc`, `git`, `python3`, and `bwrap`; GUI smoke needs
Omarchy and Quickshell. The broad battery needs upstream's documented runtime/test
closure, including quickjs-ng's `/usr/bin/qjs` for Markdown figure tests. No dependency
is installed by these commands. Test/build subprocesses run in a Bubblewrap namespace
with a read-only host filesystem and this repository as the writable area. Fixtures,
HOME, Cargo home, runtime state, logs, and temporary files remain repository-local.
The namespace has no network; this Flea release has no Cargo dependencies. Revisit
that policy if upstream adds dependencies rather than silently allowing downloads.

A failed test does not select a new build. Logs are kept under `.local-builds/logs/`.
Bundles are archived tracked assets plus the tested release binary; Omarchy's shared
UI modules remain external runtime dependencies and are validated at promotion.
Integrity hashes detect edits or missing assets. Versioned bundles are not auto-pruned.

Smoke checks drive the deployed backend and a real offscreen Quickshell window against
three disposable entries, asserting the returned listing, UI path/count, and loaded
theme. This is startup/integration coverage, not exhaustive mouse/keyboard testing.

```sh
personal/flea-dev smoke --native "$(git rev-parse HEAD)"  # briefly opens a real test window
```

Close custom windows and D-Bus services before promotion or rollback. Services can idle
for a short period before exiting. Promotion records a pre-promotion snapshot of private
state and updates `previous` and `current`. Rollback preserves newer state separately:

```sh
personal/flea-dev rollback
```

The initial deployment has no previous version; rollback becomes available after a
second promotion. External file operations, trash, tags, and other application state
are not restored by a build rollback.

## Upstream update

```sh
personal/flea-dev fetch                # safe to run regularly; does not deploy
personal/flea-dev sync                 # latest stable release
# OR: personal/flea-dev sync --base main
```

The sync command prints a branch and worktree. Resolve conflicts and test there:

```sh
personal/flea-dev build --source .personal-worktrees/sync-YYYYMMDD-HHMMSS
personal/flea-dev smoke <candidate-commit>
personal/flea-dev integrate sync/YYYYMMDD-HHMMSS
# Rebuild and smoke-test the resulting personal merge commit before promotion.
```

No automatic timer is installed. A scheduled fetch can call `personal/flea-dev fetch`,
but scheduled merging/promotion is intentionally unsupported. Only `main` fast-forwards;
`personal` keeps merge history and never needs a routine force-push.

## Clean upstream contribution

```sh
personal/flea-dev fetch
personal/flea-dev feature my-feature
cd .personal-worktrees/feature-my-feature
# Edit, test and commit the feature here. It contains no personal tooling commits.
git push -u origin feature/my-feature
```

From the normal personal checkout, integrate the reviewed feature:

```sh
personal/flea-dev integrate feature/my-feature
# Build, smoke-test and promote the resulting commit.
git push origin personal
```

Open a PR only when you choose to publish the contribution:

```sh
gh pr create --repo thisisgm/flea --base main --head OldJobobo:feature/my-feature
```

The PR body should contain the required on-behalf-of signature. No PR is automatically
created. Existing fork branches are retained and are not automatically merged.

## Explicit desktop routing

Preview exactly what would change:

```sh
personal/flea-dev desktop plan --shortcuts --directory-default
```

After authorizing the listed user-level targets:

```sh
personal/flea-dev desktop install --shortcuts --directory-default --confirm
```

This installs `~/.local/bin/flea-custom`, a distinct `Flea Custom` desktop entry,
and optionally overrides the two file-manager shortcuts and directory MIME default.
It does not replace the stock package or alter system-owned Omarchy configuration.
Existing files/preferences are backed up into `.local-builds/desktop.json` before writes.
Hyprland errors trigger restoration; MIME routing is read back after setting it.
The script refuses symlinked preference files and an existing recorded installation.

Optional reveal/chooser routes can be included explicitly on a fresh installation:

```sh
personal/flea-dev desktop plan --shortcuts --directory-default --reveal --picker
personal/flea-dev desktop install --shortcuts --directory-default --reveal --picker --confirm
```

These are user-level overrides of the packaged FileManager1 and Flea portal service
names, not independently named parallel services. Only the chooser interface is
preferred; ScreenCast and other portal routing are preserved. The portal preference
chooses an existing `hyprland-portals.conf` if present, otherwise `portals.conf`.
Stock service owners may need to exit before activation uses the new override. Portal
installation restarts the user portal frontend; do not do this during a screen-share.
The `.portal` registration still comes from the installed stock Flea package.

Removal restores original files only if they still match installed content; it refuses
to overwrite changes made by you or another application since installation:

```sh
personal/flea-dev desktop remove --confirm
```

No service process is killed automatically. Native integration and shelf activation
are separate from the offscreen baseline checks. Configuration backups may contain
personal settings; `.local-builds/` is ignored and must not be published.

## Local tooling tests

```sh
python3 -B -m unittest discover -s personal/tests -v
```

The tests use scratch repositories and profiles under `.local-builds/tmp/`; they do
not install desktop entries, touch live preferences, submit PRs, or push branches.
