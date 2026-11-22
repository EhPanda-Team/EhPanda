# 19-19 tall window

The matrix takes each coordinate in the hosted key window resized to the scene's width and the coordinate's
committed height, and fails with `page-height: needs <n> pt, committed <m> pt` any page that needs more. A
coordinate whose committed height is at the device height takes the unchanged screen-sized path (design section 2).
Runs below are local candidate runs on the project simulators; `$W` is `$MAIN/.capture/agent-work/phase19-19`
(ignored by git, no picture is in the repository).

## Task 1: tracer, iPhone, direct path

`settings-root` at `en-large`, iPhone, both orientations, light and dark.

| run | heights | portrait (912 pt screen) | landscape (420 pt screen) |
| --- | --- | --- | --- |
| `tracer-1` | `.screen` | `recorded`, no `page-height` error | `error`: `page-height: needs 633 pt, committed 420 pt` (light and dark; the 420 px picture is kept as `actual`) |
| `tracer-2` | committed | `recorded`, 912 px | `recorded`, 633 px |

The need is the same in light and dark. `tracer-2` per key (committed height equals the picture's pixel height where
the page is taller than the screen):

| key | status | picture height | taller than the screen | SHA-256 (first 8) |
| --- | --- | --- | --- | --- |
| `settings-root__en__large__portrait__iphone__light` | `recorded` | 912 | no | `098431aa` |
| `settings-root__en__large__portrait__iphone__dark` | `recorded` | 912 | no | `92c3d612` |
| `settings-root__en__large__landscape__iphone__light` | `recorded` | 633 (committed 633) | yes | `f312e771` |
| `settings-root__en__large__landscape__iphone__dark` | `recorded` | 633 (committed 633) | yes | `83d12eb6` |

Portrait fits the screen at every text size (`probe-ax5` recorded it without a `page-height` error at xSmall and AX5
too), so by design section 2 ("a page shorter than the screen keeps the screen height") its pictures stay
912 px, and they are byte-identical to the `.screen` capture of `tracer-1` (same SHA-256 per key). Orchestrator
decision: the check "taller than the screen" applies per coordinate, where the observed need exceeds the device
height.

Landscape needs, from `probe-ax5` (same code, heights at the device height, `en-xSmall,en-accessibility5`):
xSmall 633 pt, AX5 850 pt (AX5 is committed in Task 2). The committed iPhone values are tracer-only: landscape
xSmall and Large 633, every other value the device height (912 / 420 iPhone, 1210 / 834 iPad); 19-26's `apply`
replaces them with the measured proposal.

Safe area in the tall window (recorded, not checked; attached to
`testAPageTallerThanItsCommittedHeightFailsWithTheHeightItNeeds`, read from the result bundle): a 420 x 1000 pt window
on the 420 x 912 pt iPhone Air in portrait has top 68, left 0, bottom 34, right 0. Top, left and right equal the pin
(the attempt fails with `tall-window-geometry` otherwise); the bottom inset is the home indicator's 34 pt.
