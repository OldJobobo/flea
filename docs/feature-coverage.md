# Tick feature integration audit

The integration at `6ef90fa7` combines the deployed semantic/adaptive build
`ba8c54a1` with the remaining published listing-font fix. All five local
`feature/*` tips are ancestors of this integration; no feature branch is rebased,
reset or deleted. Tick can advance to it by fast-forward.

## Included runtime branches

| Branch | Audited tip | Coverage |
| --- | --- | --- |
| `feature/icon-packs` | `4f6ae27d` | Bundled interface icon families |
| `feature/desktop-icon-themes` | `9d671bb4` | Installed desktop file/folder icons |
| `feature/path-single-click` | `832646fc` | Single-click path editing and blur dismissal |
| `feature/tick-adaptive-icons` | `49384d3e` | Theme-derived adaptive artwork and zoom fixes |
| `feature/tick-semantic-colors` | `73680686` | Full semantic colours and persistent preference |
| `origin/fix/listing-full-font-hinting` | `b7407922` | Native full-hinted listing text and matching metrics |
| `origin/feat/save-picker-new-folder` | `f61e4fce` | New Folder in save dialogs; already integrated |
| `origin/refactor/dialog-card-tokens` | `dd6505e6` | Shared dialog styling; already integrated |

Every published `origin/codex/*` branch and the older release branch inspected
in this audit is already ancestral too. Freeside's previously unpublished source
tip `92c90539` is also included in the history.

The three `origin/evidence/*` branches contain screenshot/validation documents,
not missing runtime implementations. They remain separately published and are
not merged merely to make an ancestry count zero. The upstream-mirror `main`
branch is not a feature branch and is left untouched.

## Integration details

The font branch predates the extracted `RowDropTarget.qml`. Keep that lazy
component rather than restoring the older inline drop objects. A shared label
hinting alias lets the listing opt into full hinting without changing the rail's
existing typography. Existing focus, selection and semantic-colour behaviour
remain intact.

The inherited upstream-heavy `AGENTS.md` stays unchanged. Source-line tooling
allowances and source-byte pins are regenerated for the integrated tree; the
absent-module allowance profile is source-line remapped, not newly exercised.
No startup-object ceiling is raised.

Re-derived budgets: `ui/Row.qml` 477 and `ui/Theme.qml` 481 lines. The existing
186/183 first-frame inventories sum to 1,803,036/1,692,195 bytes.

## Verified integration checks

- Font hinting: 444 checks across all seven text-size stops, including lazy
  match, location, drop, tooltip and rename text and native width measurements.
- Semantic colours: 1,313 real-Qt checks and live preference/persistence proof.
- Adaptive plus semantic mode: lifecycle 20 checks, restart 3, catalogue 360 and
  zoom 176; all pass against the combined backend.
- Full pure-JS battery: 19,680 standard checks plus Edmonton and DST passes.
- Present-module static gates, file budget and runner-rule checks pass.
- Grid-caption geometry, row/column delegate costs and rename scrolling pass.

These checks do not replace the documented inherited broad-runner limitations
in `docs/semantic-colors.md`. The font merge changes no Rust implementation.

## Branch history versus installed bundles

Updating or pushing `tick` does not mutate a running immutable bundle. The local
and Freeside deployments remain pinned to their verified `ba8c54a1` bundle until
an explicit build/smoke/promotion of the newer source revision. Their semantic
and adaptive features remain enabled. A source audit must not relabel those
older manifests or smoke receipts as testing the newer font merge.

To repeat the local feature-ancestry proof after advancing Tick:

```sh
for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/feature); do
    git merge-base --is-ancestor "$branch" tick || exit 1
done
git merge-base --is-ancestor origin/fix/listing-full-font-hinting tick
```
