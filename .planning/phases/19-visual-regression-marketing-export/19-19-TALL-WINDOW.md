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

## Task 3: the iPad

### Turning the iPad

The first iPad landscape run failed every coordinate with `geometry`: the device was still portrait. The turn step ran
`VisualCaptureOrientationUITests/testRotateToLandscape` in a parallel-testing clone of the iPad, which turned the
clone and never the device that captures (the hosted `run-shard.sh` passes `-parallel-testing-enabled NO` for its
turn step, the local runner did not). Owner decision (2026-11-22): approved for the turn step only. The runner now
passes `-parallel-testing-enabled NO` to that one call (commit `8b30ec452`); every other test stays parallel. After
the fix `pad-landscape-1/orientation.log` names no clone (0 occurrences of "Clone"), the destination is the phase
iPad's own UDID, and the turn reads: `Device orientation changed to Landscape Left`, `Interface orientation changed to
Landscape Right`, `Test Case '-[EhPandaUITests.VisualCaptureOrientationUITests testRotateToLandscape]' passed (0.387
seconds).`

### `settings-root`, iPad, `en-large` and `en-accessibility5`

`pad-portrait-1` and `pad-landscape-1` (heights at the device height):

| orientation | en-large | en-accessibility5 |
| --- | --- | --- |
| portrait (1210 pt screen) | `recorded`, fits | `recorded`, fits |
| landscape (834 pt screen) | `recorded`, fits | `page-height: needs 865 pt, committed 834 pt` (light and dark) |

Only iPad landscape AX5 is taller than the screen, so that pair is the only tall iPad pair of this scenario;
nothing is above 4095 pt, so no iPad picture used the render-server path. Committed: iPad landscape AX5 865, every
other iPad value the device height (1210 / 834). Runs `pad-portrait-2` and `pad-landscape-2`: 8 of 8 `recorded`.

| key (en, light and dark) | picture (px) | committed | width = scene width |
| --- | --- | --- | --- |
| large, portrait | 834 x 1210 | 1210 | yes |
| accessibility5, portrait | 834 x 1210 | 1210 | yes |
| large, landscape | 1210 x 834 | 834 | yes |
| accessibility5, landscape | 1210 x 865 | 865 | yes |

### The black-slice check (orchestrator-approved reading)

The plan's check, "the picture's top and bottom 64 rows are not all one colour", cannot hold for this page: it ends in
blank background, so its bottom 64 rows are one colour in every picture, also at the device height (white in light,
black in dark). What the check exists for is the Phase 17 failure past the render limit: a picture that comes back
transparent, or with a black band where content or background should be. Raw colour alone cannot tell that from a
dark-mode page whose real background is black. Reading (orchestrator decision): a tall picture passes when
1. every pixel is fully opaque (alpha 255);
2. its bottom 64 rows equal the page's own background at that theme, sampled from the same picture's left-margin pixel
   (x = 3) at mid-height;
3. the picture as a whole is not one colour, and its top 64 rows are not one colour.

Result: all 8 iPad pictures above and the 4 tall iPhone pictures (`settings-root` landscape at Large, 633 pt, and at
AX5, 850 pt) pass all three. Sampled background: `(255, 255, 255)` in light, `(0, 0, 0)` in dark, in every
picture. The bottom 64 rows equal it, the top 64 rows hold 201 to 234 distinct colours, the picture as a whole 244 to
256. Every picture is an opaque RGB PNG. The iPhone portrait pictures are at the device height, not tall, and
are not judged by this check (their top 64 rows are one colour because the inline-large title starts below them).

### Sheet probe: does a form sheet grow with the window?

`app-wide-error-info` (the Error Info sheet over the Search root), iPad, `en-accessibility5`, portrait. Finding only,
nothing committed (the state's file was restored with `git checkout --`, no change to `ErrorInfoViewSnapshot.swift`).

| committed | window growth | need measured by the check |
| --- | --- | --- |
| 1210 pt (the device height) | 0 | 1570 pt |
| 1570 pt (one-off local value) | 360 pt | 1930 pt |

The second need is the first plus the growth (1570 + 360 = 1930), so the form sheet does not grow with the window:
it keeps its own size (about 660 pt tall in the 1570 pt picture, its content clipped with the Suggested Solution cut
off) while the page behind it grows. Finding for 19-20's probes and 19-26's owner decision: a taller window does not
make a form sheet show more of its content, and the check's need for such a state follows the window, so a committed
height can never satisfy it. The harness is unchanged for this.

### iPad regression proof

The 19-18 sample without `settings-root` (20 classes) at `en-large` portrait (`regress-pad`), against 19-18's
`after-pad`:

```
regress-keys 40
regress-differs 0
regress-other-errors 0
statuses: recorded 30, error 10 (all "page-height: needs <n> pt, committed <m> pt")
```

The 10 `page-height` errors, each light and dark: `app-wide-error-info` 1242 pt, `home-populated` 1858 pt,
`quick-search-list` 1242 pt, `reader-vertical` 9265 pt, `search-root-history` 1242 pt (committed 1210 for all). Their
pictures are kept, and equal 19-18's. `reader-vertical` shows that the reader's list, which the design lists among the
pages that "never scroll", needs 9265 pt on the iPad: a note for 19-20's measuring mode and 19-26.
