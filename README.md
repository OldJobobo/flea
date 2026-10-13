# Save-picker New folder evidence

Fork-only evidence for `feat/save-picker-new-folder`; these artifacts are not in the upstream code diff. See VALIDATION.md for results and limitations.

The screenshot shows the actual isolated native picker: synthetic Downloads content, complete Cancel/Create folder frames, and the borderless Nerd Font folder-plus toolbar mark. Device/network entries are omitted, the filesystem status strip is cropped out, and image metadata is stripped.

## Try the isolated copy

Check out `feat/save-picker-new-folder` and build with `cargo build --locked`. Save `run-save-demo.sh` from this evidence branch into `.review/run-save-demo.sh` in that checkout, then run:

```bash
bash .review/run-save-demo.sh
```

To open directly into the new-folder card:

```bash
FLEA_FOLDER_DEMO_OPEN=1 bash .review/run-save-demo.sh
```

The launcher requires the existing Flea/Omarchy runtime. It does not install a package or replace the browser portal. Each run creates a fresh marker-managed fixture under `/home/flea-sandbox`, isolates HOME and XDG state/cache, and copies the candidate UI. Its demo copy hides machine device/network rows and restricts the folder action to its synthetic home.

Folders created during testing persist. Save only writes the simulated request's reply JSON; no browser writes a downloaded file. The launcher does not remove fixtures when the dialog closes. Use the repository's sandbox guard for any later cleanup, never unrestricted recursive deletion.
