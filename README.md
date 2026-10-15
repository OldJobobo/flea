<p align="center">
  <img src="personal/branding/tick.svg" width="104" height="104" alt="Tick">
</p>

<h1 align="center">Tick</h1>

<p align="center"><strong>A personal Flea fork for Omarchy.</strong><br>Keyboard-first file management, with a little bite.</p>

Tick is OldJobobo's daily file manager, built on GM's Flea: a Rust backend and a
native Quickshell interface that follows your Omarchy theme. This fork keeps its
personal identity and deployment separate from the stock Flea package, while
remaining practical to update from upstream.

## What's personal

- **Tick identity.** A distinct window/app identity, launcher, desktop icon and
  in-app mark, derived from the supplied segmented-antennae artwork.
- **Selectable icons.** Flea's original marks, Tabler Outline, stock Lucide,
  Iconoir, Heroicons Outline, Phosphor Regular, Feather and a watched Custom slot.
  See `docs/icon-packs.md`. Other libraries' brand marks remain intact.
- **Save-dialog New Folder.** Create a folder with the folder-plus button or
  `Ctrl+Shift+N` without discarding the pending filename.
- **Omarchy dialog styling.** Dialog surfaces follow Omarchy's tokens.
- **Versioned daily builds.** Immutable bundles, explicit verification and
  promotion, a previous build and state snapshots for rollback.

Flea's list, columns, grid, dual panes, tabs, Quick Look, file operations, tags and
search remain the foundation. Original upstream documentation and its historical
benchmark results are preserved in `UPSTREAM-README.md`; those measurements are
not new Tick benchmarks.

## Run the personal build

From this checkout:

```sh
personal/tick --gui
personal/tick --gui ~/Downloads
personal/tick --custom-info
personal/tick-dev status
```

After the explicitly confirmed desktop installation, `tick` is also available on
PATH and **Tick** appears in the application launcher. Existing `flea-custom`
launchers and the legacy desktop ID remain compatibility aliases. Stock
`/usr/bin/flea` is never replaced.

This is a personal source/deployment workflow, not a published `tick` package.
Installing an upstream Flea package installs Flea, not this Tick build. Runtime
requirements remain Flea's Rust, Quickshell and Omarchy environment.

## Build and maintain

```sh
personal/tick-dev build --checks quick
personal/tick-dev smoke --native <full-commit-hash>
personal/tick-dev promote <full-commit-hash>
personal/tick-dev doctor
```

Quick checks cover both Rust unit-test profiles and the personal tooling; they
are not a full upstream battery. Use the default full build, or `verify`, for
broader evidence. Do not promote a failed or untested candidate.

`personal/README.md` documents installation, refresh, rollback, test isolation and
optional routing. `docs/personal-fork-plan.md` records the branch/update contract.
Tick's About panel directs updates/default changes to this workflow rather than
running stock package-management actions.

## Upstream compatibility

- `main` remains a clean upstream mirror; `personal` is the integration branch.
- Tick branding is a deterministic personal-bundle overlay. It does not rename
  Rust crates, wire commands, QML types, environment variables or state keys.
- Existing personal preferences, icon selections and undo state retain their
  locations. Custom icon data still uses `flea/icons/custom.json`.
- Clean upstream contribution branches do not contain the Tick overlay.
- The local checkout remains `/home/oldjobobo/Projects/flea`; no filesystem rename
  is necessary, and existing scripts/worktrees keep working.

Tick fork:
https://github.com/OldJobobo/tick

Flea upstream:
https://github.com/thisisgm/flea

## Attribution

Flea is by GM and contributors, under the MIT license; see `LICENSE`. Tick retains
that attribution and the original upstream sources. Bundled icon families retain
their own license notices in `ui/icons/`. Tick's artwork comes from the supplied
PNG, preserved unchanged in `personal/`; its cleaned vector derivation and
regeneration notes are in `personal/branding/README.md`.
