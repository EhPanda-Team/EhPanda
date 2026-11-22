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

## Task 2: pictures above the render-server limit, determinism, iPhone regression proof

### The render-server path

A committed height whose device pixels are above `RenderServerCapture.maximumSnapshotDimension` (8191 px, so 2730 pt
on the 3x iPhone Air and 4095 pt on the 2x iPad Pro 11) is settled on owned-row digests and composed from reads of the
native viewport size, with the window itself as the drawn view (sheets, alerts and menus stay in the picture). The
window has no `window` of its own, so `RenderServerCapture` rejected it with `detachedView`; both entry points now
resolve the host as `view as? UIWindow ?? view.window` (orchestrator-approved, nothing else in that file changed; a
detached plain view still throws `detachedView`, a window passed as the view is its own host).

Proven on synthetic hosted pages in `HostedWindowCaptureTests` (a non-scrolling page 200 pt over the limit: recorded,
exactly the committed height at 1x, two captures in a row give identical bytes, no direct `capture(_:)` draw after the
user step; a page under the limit keeps the direct path) and in `RenderServerCaptureTests` (a window as the view,
the detached view).

### AX5, iPhone, `settings-root` (`en-accessibility5`)

`ax5-1` (heights at the device height): portrait `recorded`, landscape `page-height: needs 850 pt, committed 420 pt`.
Committed: landscape AX5 850, portrait AX5 912 (the page fits the screen). Runs `ax5-2` and `ax5-3`:

| key | status | picture height | path | SHA-256 (first 8), runs 2 and 3 |
| --- | --- | --- | --- | --- |
| `settings-root__en__accessibility5__portrait__iphone__light` | `recorded` | 912 (device height) | direct | `566fbbeb`, identical |
| `settings-root__en__accessibility5__portrait__iphone__dark` | `recorded` | 912 (device height) | direct | `ebc099a9`, identical |
| `settings-root__en__accessibility5__landscape__iphone__light` | `recorded` | 850 (committed 850) | direct | `b74dd133`, identical |
| `settings-root__en__accessibility5__landscape__iphone__dark` | `recorded` | 850 (committed 850) | direct | `9e5b9224`, identical |

`ax5-not-recorded 0`, `ax5-nondeterministic 0`. No `settings-root` coordinate is above 8191 px on the iPhone (the
largest is 850 pt = 2550 px), so none took the render-server path. The sliced path is therefore proven only by the
synthetic pages above; a real-page proof is owed by 19-20's probes or 19-26's verification sample.

### iPhone regression proof

The 19-18 sample without `settings-root` (20 classes) at `en-large,ja-accessibility5` (`regress-phone`), against 19-18's
`after-phone`:

```
regress-keys 160
regress-differs 2
regress-other-errors 0
statuses: error 126 (all "page-height: needs <n> pt, committed <m> pt"), recorded 34
```

Every non-recorded line is a `page-height` error (the `.screen` pages that are longer than the screen), and its
picture is kept. The two keys whose SHA-256 differs from `after-phone` are the two that 19-18 recorded as flipping
between runs on unchanged code (19-18's open input 2); each current picture is byte-identical to a capture the
old sources already produced:

| key | before (old sources) | after | diag-phone (new sources) | diag2-phone (old sources) | now |
| --- | --- | --- | --- | --- | --- |
| `app-wide-error-info__en__large__portrait__iphone__dark` | `85bc4bdc` | `89859e2e` | `85bc4bdc` | `89859e2e` | `85bc4bdc` |
| `detail-pages-archives__ja__accessibility5__landscape__iphone__light` | `2963dfea` | `3068d9f8` | `3068d9f8` | `3068d9f8` | `2963dfea` |

Decoded 8-bit RGBA, the current picture against `after-phone`: the error-info picture differs in 1 pixel of 383040
with a largest channel difference of 1; the archives picture differs in 0 pixels, so its SHA-256 difference is in the
PNG encoding only. Orchestrator decision: accepted without a rerun. Conclusion: 0 differences attributable to the
change over 160 keys.
