<p align="center">
  <img src="personal/branding/tick.svg" width="104" height="104" alt="Tick logo">
</p>

<h1 align="center">Tick</h1>

<p align="center"><strong>Keyboard-first file management for Omarchy.</strong><br>A personal Flea fork, with a little bite.</p>

Tick is OldJobobo's daily-use fork of **Flea**, GM's native Linux file manager.
It pairs Flea's Rust backend and Quickshell interface with a distinct identity,
selectable icon families, and an explicit build-and-rollback workflow. The UI
follows your Omarchy theme rather than introducing another theme to manage.

**This is a personal source fork, not an official Flea release or a published
Tick package.** It is maintained for an Omarchy desktop, not presented as a
cross-distribution installer.

## What you get

Flea provides the foundation: list, columns and grid views; tabs and dual panes;
Quick Look; search, tags and everyday file operations.

Tick adds or integrates:

- **Its own identity.** Tick window titles, app IDs, launcher, desktop icon,
  About panel and an in-app mark based on the segmented-antennae artwork.
- **Seven built-in icon families.** Flea, Tabler Outline, Lucide, Iconoir,
  Heroicons Outline, Phosphor Regular and Feather, plus a watched Custom JSON
  slot. Missing custom marks fall back to Flea; reserved brand marks stay intact.
- **New Folder in save dialogs.** Use the folder-plus button or `Ctrl+Shift+N`
  without losing the pending filename. Integrated from upstream Flea.
- **Omarchy-styled dialogs.** Dialog surfaces use Omarchy's tokens, also
  integrated from upstream Flea.
- **Controlled daily builds.** Immutable, fingerprinted bundles; explicit tests,
  smoke checks and promotion; a previous bundle and private-state snapshots for
  rollback. Building does not automatically switch your daily application.

Icon formats, licenses and customization are documented in `docs/icon-packs.md`.

## Build from source

Use the **`tick` branch** (the repository default) for Tick. `main` mirrors upstream Flea and is not the
Tick integration branch.

With GitHub CLI:

```sh
gh repo clone OldJobobo/tick -- --branch tick
cd tick
personal/tick-dev build
```

Build tooling requires Git, Rust/Cargo, Python 3 and Bubblewrap. Running the GUI
and its smoke checks requires Quickshell and the expected Omarchy environment.
The full test battery has additional dependencies documented in
`docs/development-checks.md`. Tools do not install dependencies automatically.

The default build runs both Rust unit-test profiles, personal-tooling tests,
the upstream battery and Tick's transformed-UI branding probe. A deliberately
narrower build is available:

```sh
personal/tick-dev build --checks quick
```

**Quick checks are not full verification.** Bundles record that distinction;
a successful native smoke check is startup evidence, not exhaustive UI testing.

After a successful build, use the full commit hash printed by the tool:

```sh
personal/tick-dev smoke --native <full-commit-hash>
personal/tick-dev promote <full-commit-hash>
personal/tick-dev doctor
```

Native smoke briefly opens a window using disposable files and a separate
profile. Close running Tick/custom service processes before promotion.

## Daily use

Once a bundle has been promoted:

```sh
personal/tick --gui
personal/tick --gui ~/Downloads
personal/tick --select ~/Downloads/example.txt
personal/tick --custom-info
personal/tick-dev status
```

Optional desktop integration provides the `tick` command and a **Tick** launcher
entry. Preview it before confirming any changes:

```sh
personal/tick-dev desktop plan
personal/tick-dev desktop install --confirm
```

Changing directory defaults, shortcuts, reveal handling or the file-picker
portal is separate and opt-in. See `personal/README.md` for those options,
existing-installation rebranding and removal.

Stock `/usr/bin/flea` is not replaced. Existing `flea-custom` launchers and the
legacy personal desktop ID remain compatibility aliases.

## Updates and rollback

Tick does not use Flea's packaged updater. Fetch and integrate upstream changes,
then build, test and promote deliberately:

```sh
personal/tick-dev fetch
personal/tick-dev sync
```

The sync command prepares a separate worktree; it does not silently merge or
deploy changes. See `personal/README.md` for the complete integration workflow.

To restore the previous daily bundle and its pre-promotion private state:

```sh
personal/tick-dev rollback
```

Rollback does **not** undo file operations or restore external desktop
preferences. Private builds, state, caches and logs live in `.local-builds/`;
that directory must not be published.

## Relationship to Flea

Tick is a personal fork, not a replacement name for the upstream project.

- **`main`** remains an upstream mirror; **`tick`** is the default branch and retains integration merges.
- Branding is applied deterministically when packaging personal bundles. The
  upstream source files are not globally renamed for branding.
- Rust crate names, wire commands, QML types, environment variables and existing
  state keys retain their Flea identities for compatibility.
- Custom icon data continues to use `$XDG_CONFIG_HOME/flea/icons/custom.json`,
  falling back to `~/.config/flea/icons/custom.json`.
- Upstream contribution branches start from `upstream/main`, without Tick's
  personal branding or deployment commits.

The preserved `UPSTREAM-README.md` contains Flea's original overview and
historical performance measurements. Those figures are **not Tick benchmarks**.
The branch and update policy is documented in `docs/personal-fork-plan.md`.

Tick fork:
https://github.com/OldJobobo/tick

Flea upstream:
https://github.com/thisisgm/flea

## Credits and license

Flea is by **GM and contributors**, under the MIT license; see `LICENSE`.
Tick retains the upstream attribution and license. Bundled icon families retain
their own license notices in `ui/icons/`.

Tick's original artwork is preserved unchanged in `personal/`. Its cleaned
vector derivation and regeneration notes are in `personal/branding/README.md`.
