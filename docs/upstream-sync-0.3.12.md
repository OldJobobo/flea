# Tick upstream sync: Flea 0.3.12

Candidate base: Tick `88b72fb8`; upstream: `f21789e56cc4b0877caa3156fff7bce52a8dd9c2`
(`v0.3.12`, 368 newly reachable commits). This is a merge, not a rebase.

## Compatibility work

- Preserve Tick's icon families, installed desktop icons, mouse affordances,
  single-click path entry and save-dialog folder creation.
- Route tab menus through upstream's deferred `MenuHost`; keep visuals off the
  first frame. Installed desktop artwork takes priority over code marks.
- Keep upstream's picker answer/filter row alongside Tick's New Folder control.
- Update the fail-closed branding overlay for upstream's filled shelf mark.
- Regenerate the keymap and re-derive startup and per-file budgets.
- Bring isolated icon/settings test modules and headless Commons fixtures up to
  the current contracts. Menu input probes now locate actions by identity rather
  than assuming upstream's old row numbers.
- Use the equivalent bounded compare/exchange loop for copy-reader admission:
  it retains Rust 1.77 support without Rust 1.99's `fetch_update` deprecation.
  Existing worker-cap, slot-release, failed-spawn and stalled-close tests pass.

## Verification

Tests ran with a read-only host and repository-owned writable state under
Bubblewrap. On-disk repository fixtures were mapped to `/home/flea-sandbox`
inside the namespace; the real external sandbox and system files were untouched.
QuickJS-NG 0.17.0 and strace were extracted from signature-verified Arch packages
into repository-local test storage and exposed through a read-only namespace
overlay. The media fixture used the documented `COUNT=20` option; no performance
measurements or benchmark claims were made.

Passed:

- Debug and release builds and unit tests on Rust 1.99: **2,975 passed, two
  ignored in each profile**, with no build/test warnings after the admission-loop
  compatibility fix.
- The shared Clippy ratchet, static gates and file-budget gate.
- JavaScript: 17,043 standard checks, four Edmonton checks and 13 DST checks.
- All 51 personal-tooling tests, including the guarded branding transform.
- Startup inventories, including saved-OFF, cold/early menu demand and a hanging
  backend; focused Tick icon, mouse, path and picker suites.
- Ops, FAT-copy and protocol checks after rebuilding both executable profiles.

All **309 distinct headless suites** were exercised across the broad runner,
its continuation and focused reruns. There are **293 passing suites and 16
remaining failures**. This is not a fully green `tests/run-all.sh` result:
that single invocation timed out after 20 minutes, and its remaining suite
inventory was run separately with individual exit/output checks and logs.

Every remaining failing suite was also run against an unmodified upstream
v0.3.12 worktree in the same environment and failed there:

| Suite(s) | Observed failure |
| --- | --- |
| `charts` | Generated social preview PNGs differ from checked-in assets. |
| `gvfs` | Archive/FUSE fixture mount unavailable in the namespace. |
| `modes` | Vulkan availability assertions fail with isolated devices. |
| `settings-columns`, `permissions-skips`, `ring-bounds`, `rename-frame`, `dialog-board` | Font/geometry witnesses disagree with their recorded baselines. |
| `markdown-lazy` | Source-chunk round-trip completion times out. |
| `search-answered` | Search completion witness times out. |
| `quicklook-firstframe` | Maths first-frame readiness leg fails. |
| `rename-cost` | Held-row field accounting fails. |
| `mediasession` | Isolated audio services/devices are unavailable. |
| `preview-scroll`, `markdown-code` | Legacy QML lint gate fails. |
| `raildrop` | Healthy probe completes 69 checks but exits with owned SIGTERM (143), which its wrapper rejects. |

The standalone legacy QML lint gate likewise reports the same five failing
categories on Tick and pristine upstream: import-count drift plus four newly
reported diagnostic categories. It was not weakened or relabelled green.
The present-module static-gate allowance profile passes; the absent-module
profile was source-line remapped but was not exercised on this host.

Logs are retained locally under `.local-builds/logs/`, notably the initial
`1792217453037833127-sync-full.log`, the 223-suite continuation in
`1792220075306132367-suite-batch/`, pristine-upstream controls in
`1792220047684984629-suite-batch/` and `1792223282552892586-suite-batch/`,
and subsequent focused reruns. No deployment, desktop-routing change or push
is part of this source sync.
