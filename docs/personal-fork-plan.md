# Personal Flea fork: plan and operating contract

## Goal

Run OldJobobo's customized Flea daily, keep it maintainable against upstream,
and offer individual features upstream without including personal deployment code.
The system package remains installed and unchanged as a fallback.

## Repository and branches

- Checkout: `/home/oldjobobo/Projects/flea`.
- `origin`: `https://github.com/OldJobobo/flea.git`, the only push destination.
- `upstream`: `https://github.com/thisisgm/flea.git`, fetched for source updates.
- `main`: clean upstream `main`; fast-forward only, no personal commits.
- `personal`: persistent integration branch; merge updates, do not rewrite published history.
- `feature/<name>`: one contribution, based on upstream `main` unless a maintainer requests another base.
- `sync/<date>`: candidate upstream merge, validated before integration and deployment.
- Additional worktrees live under `.personal-worktrees/`, ignored by Git.

Existing fork branches are preserved. They are not automatically integrated. The initial
personal branch starts at the latest release available at setup, `v0.3.10`.

## Contribution workflow

1. Create a feature worktree from `upstream/main`.
2. Implement focused commits and tests in that worktree.
3. Merge the feature into `personal` after review and verification.
4. Push its branch to `origin`; optionally open a PR to `thisisgm/flea:main`.
5. Keep deployment tools, personal appearance, and desktop routing out of that feature branch.

Upstream acceptance is not a prerequisite for running a feature. If upstream squash-merges
it, reconcile duplicate code during the next upstream merge; do not assume Git can identify
squashed equivalents. Personal commits and upstream contributions stay separately reviewable.

## Upstream updates

Fetch changes automatically if desired, but never merge or deploy unattended. Default daily
updates target the latest stable release; use `upstream/main` deliberately for unreleased fixes.

1. Fetch upstream and fast-forward local `main` in its own worktree.
2. Create a sync worktree from `personal` and merge the selected upstream ref.
3. Resolve conflicts in that worktree, keeping the daily deployment unchanged.
4. Run local tooling tests, Rust unit tests in both profiles, and `tests/run-all.sh`.
5. Record failed and skipped checks; do not claim full verification over a partial run.
6. Merge the tested sync branch into `personal`, then build a fresh verified bundle.
7. Promote that bundle explicitly; keep the previous bundle and state snapshot.

## Deployment

Never launch the daily version directly from a mutable development checkout.
Store complete bundles under `.local-builds/releases/<commit>/`, with the binary,
UI, shelf sources, runtime helpers, license, and build/test metadata from one clean commit.
`current` and `previous` select complete bundles. Deployment fails on a dirty source tree.

The launcher resolves `current` once, pins absolute `FLEA_UI` and `FLEA_BIN`, and pins
`FLEA_GIO_AUTH`, `FLEA_UDISKS`, and `FLEA_SHELF` to the same bundle. This is necessary:
upstream UI discovery prefers packaged `/usr/share/flea/ui` before its development fallback.
No files in `/usr/bin`, `/usr/lib/flea`, `/usr/share/flea`, or `/usr/share/omarchy` are changed.

The custom profile keeps its state and caches inside `.local-builds/profiles/daily/` using
`XDG_STATE_HOME` and `XDG_CACHE_HOME`, with `FLEA_UNDO_DIR` keeping its journal private. HOME, XDG_CONFIG_HOME, XDG_DATA_HOME, and the session
bus/runtime directory remain real so Omarchy themes, MIME defaults, GVfs and the desktop
session still work. Test fixtures use separate state, cache and disposable files.
This is application-state isolation, not a security sandbox: opening real files still acts on them.

Promotion snapshots the private state and atomically selects the bundle. Rollback restores
the previous selection and its state snapshot only when no custom processes are running.
It does not undo file operations or restore external application state. Do not run old and new
custom bundles concurrently during promotion/rollback. A checkout branch change never alters
an already deployed bundle's source files.

## Desktop integration

Phase one: a distinct `flea-custom` launcher and desktop entry, then explicit user-level
shortcut and directory MIME routing with backups. Keep stock Flea available separately.
No shell alias or PATH shadowing of `flea` is required.

Phase two: optional user-level FileManager1 and FileChooser activation wrappers that launch
this deployment's helpers with the pinned environment. D-Bus services must not keep a stale
backend binary after promotion; restart only our service when changing versions. Do not call
upstream `--default` or `--picker` to configure this layout: those verbs target stock package
registration and can change multiple unrelated preferences. The same caution applies to
Settings > About's default switch and its update button, which are upstream package workflows.

The shelf's sources are bundled, but activating the Omarchy bar plugin and making it inherit
the custom profile requires separate routing verification. It is not silently enabled.

## Verification and provenance

- Local Python tooling tests cover pinning, dirty-tree refusal, bundle validation,
  failed-check/promotion safety, state snapshots, rollback, and clean feature branches.
- Rust tests cover both debug and release; retain zero-warning visibility.
- Upstream `tests/run-all.sh` is the broad integration command, with its skip list retained.
- Offscreen and native smoke tests use disposable files and this deployment's UI/backend.
- Record the complete source commit, upstream release/base, profile, checks and helper hashes.
- A bundle is promoted only after successful checks and an explicit verified promotion.
- No first customization is invented: select existing feature branches or request a new feature.

## Implementation order

1. Record this plan and configure fork/remotes/branches.
2. Build an unmodified released Flea baseline plus personal tooling.
3. Add versioned deployment, explicit launcher, state snapshots, and rollback.
4. Add safe update and clean contribution-worktree commands.
5. Verify the bundle and tooling, including a disposable-file UI/backend smoke test.
6. Publish the personal branch to the existing fork.
7. Install desktop routing only with authorization for the named user-level targets.
8. Add optional reveal/portal/shelf routing only after their own verification.

## Maintenance principles

Keep the patch set small. Prefer upstream settings and extension seams over broad source
rewrites. Separate features from local deployment mechanics. Fetch often; promote deliberately.
A failed sync or test must leave the current daily build usable.
