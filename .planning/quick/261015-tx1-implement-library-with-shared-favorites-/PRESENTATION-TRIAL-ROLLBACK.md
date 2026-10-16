# Presentation trial rollback — D88

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner decision and reasons

The owner explicitly requests reverting every non-documentation change from “試做一下看看”
(D86) onward. Both D86 and D87 are rejected, not pending acceptance:

- The sheet effect is unsatisfactory.
- The inspector's transparent background is unsatisfactory.
- Introducing the inspector causes the earlier background-not-extending-to-the-top problem to recur.

The last item records the owner's observed top-background regression. It is distinct from the
separately deferred native sidebar header-displacement issue; this rollback does not claim to fix
that deferred issue. Functional test passes did not establish visual acceptance.

## Exact scope

The clean worktree was reverted newest first with `git revert --no-commit`:

1. `658ba665b2fd5976f17878b22d53a6fcd9093aaf` — actual SwiftUI inspector trial (D87).
2. `cb029d6db0f10c42750041b15a1571ad6abe64ed` — native trailing sheet trial (D86).

All tracked non-documentation files match pre-trial commit `019b598a66`. Trial-only presentation
state, view/modifier plumbing and tests are removed; original routing and lifecycle tests return.
Downloads Details again uses the pre-trial app navigation route; Pages uses its original sheet.
The native Library sidebar, working toggle and top-safe-area extension return unchanged.

All docs, original trial screenshots and manifests remain as historical evidence. D82–D84 remain
active: grid metadata has no horizontal padding, Library grids hide ratings, and Downloads grids
use context menus. Earlier accepted cover, title, layout and Library changes also remain.

Rollback implementation: `b20b6ff8a43d45d8c05d04dcdfb203699201fb9c`. The rollback is a new commit; original trial commits remain in history.

## Verification

| Check / evidence under `.build/library/` | Result |
|---|---|
| `git diff 019b598a66 -- . ":!.planning"` | Empty: every tracked non-docs file is byte-identical to the pre-trial tree. |
| `panel-rollback-features-01` | 32/32 existing tests pass: detail routing, presentation lifecycle, download actions and analytics. |
| `panel-rollback-ipad-01` | 1/1 existing UI test passes: row/grid management, Pages open/close, folder move, local reading, deletion cancellation/confirmation and relaunch persistence. |
| Both native build gates | Zero warnings and errors; enumerated tests run once without skips or retries. |
| `panel-rollback-lint.log` | Strict SwiftLint: zero violations in all 10 restored existing Swift files. |
| Source hashes and whitespace | Both validation manifests match the final restored source; `git diff --check` is clean. |

The original review iPad was updated in place and launched into Library. A native screenshot at
`/tmp/ehpanda-presentation-rollback-review-ipad.png` confirms the restored sidebar background reaches
the top at this entry state. The screenshot remains local because it belongs to the review device;
no fixture/auth override or account-file reset was used. This is not a fresh full scroll/rotation,
Dynamic Type or physical accessibility matrix, nor a resolution of the deferred header issue.
The disposable rollback-test iPad was removed after validation. The existing proposal preview
remains untouched. Phase 17 status is unchanged.
