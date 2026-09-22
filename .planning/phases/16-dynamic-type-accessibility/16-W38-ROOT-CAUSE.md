# W-38 Reader page and indicator investigation

## Scope and status

**Current continuation (2026-09-22):** The owner approved the focus findings and requested an additive VoiceOver-only index update path, preserving the existing index logic. W-38 remains open. The iOS 26.5 root cause below remains valid historical evidence, but native VoiceOver checks on the current iOS/iPadOS 27 baseline did not reproduce the missing update. No production patch was made; the current-runtime evidence and limits are recorded at the end of this document.

W-38 was tested in four bounded WALK cases on iPhone 17, iOS 26.5 (23F77), portrait. The same installed binary was used throughout (SHA-256 `1b02f72e4aebb0d3dc7830e9c2e129ad4a96d3927d96c638217e9ac2709b6621`). Two VoiceOver cases show the divergence and two ordinary-touch cases show normal synchronization. The finding is root-cause confirmed for the tested vertical reading path and is unimplemented again, after the fix written on 2026-09-19 was withdrawn on 2026-09-21 (see Attempted fix, withdrawn); it is not a phase-pass or a claim about other orientations, devices, physical hardware, OS versions, custom rotors, or three-finger VoiceOver scrolling.

The mock run used PID 12418 and the live gallery run PID 16531. The launch script explicitly used `EHPANDA_UITEST_STUB_NETWORK=1` by default or `0` when overridden, with the same automation gallery URL. The mock used synthetic test data, 156 pages, and failed-image placeholders. The live gallery used its real gallery data, 155 pages, and successfully loaded images; the actual URL and title remain confined to local cache provenance.

## Four-case evidence

| Case | Observation |
|---|---|
| Mock touch | Page 1→2. Helper phase timestamps (UTC): `00:27:05.716` interacting, `00:27:05.742` decelerating, `00:27:08.142` idle, followed by `00:27:08.162` `PageModel.update`. The panel synchronized to `2 / 156`. |
| Mock VoiceOver | VOT timestamps (JST): native Move to Next Item (`VOTEventCommandNextElement`) reached pages 2 and 3 at `09:33:30` and `09:34:11`, then 4→5. The panel stayed at `2 / 156`; no new phase/PageModel hits occurred during VoiceOver auto-scroll. |
| Live touch | Starting at the second image, touch advanced to 4. Helper phase timestamps (UTC): `00:40:06.442` interacting, `00:40:06.931` decelerating, `00:40:09.260` idle, followed by `00:40:09.309` `PageModel.update`. The panel synchronized to `4 / 155`. |
| Live VoiceOver | The first focused image in this VoiceOver sequence was at `09:41:45` JST; subsequent images were reached at `09:42:09`, `09:42:21`, `09:42:35`, and `09:42:46`. The panel remained `4 / 155`, with no new phase/PageModel hits during VoiceOver auto-scroll. |

Re-entering the reader at `00:32:08` UTC produced the initial restore callback and is not VoiceOver movement. After VoiceOver was disabled, a 20-point ordinary swipe at the same location moved the loaded real image frame about 10 points (`(201,600)`→`(201,580)` over 0.5 s). Helper phase timestamps (UTC) were `00:44:14.351` interacting, `00:44:14.675` idle, followed by `00:44:14.689` `PageModel.update`; the panel then showed `7 / 155`. This confirms that VoiceOver had reached approximately image 7 while the model remained at 4, while ordinary touch restored synchronization. The loaded real gallery therefore also demonstrates the VoiceOver divergence; the synthetic mock is not a necessary condition.

## Root cause

The vertical `AdvancedList` publishes a page-model update only from `.onScrollPhaseChange` when the scroll phase becomes idle (`AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift:41--47`). VoiceOver's automatic scrolling changes the visible item without producing a corresponding phase/PageModel update in the tested vertical reading path. `ReadingView` then derives the control-panel slider from `pageModel.index` through its `onChange` path (`AppPackage/Sources/ReadingFeature/ReadingView.swift:303--318`), so the visible image position and the panel's model-backed index diverge. The `scrollPositionID` setter had no logged hit for either touch or VoiceOver; that absence does not prove the binding was not updated, because SwiftUI may bypass the setter observation.

The causal chain is therefore: visible list position changes → idle-only `AdvancedList` update is not emitted for VoiceOver auto-scroll → `PageModel.index` remains stale → `ReadingView`'s slider synchronization remains stale → the panel displays the old page. This identifies the missing actual-position-to-model synchronization boundary; it does not select an API or claim that `accessibilityScrollAction` alone would solve it.

## Provenance

The local artifact matrix is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w33/rootcause-20260918/reader-matrix/`. It contains the copied helper, logs, PNGs, and mock touch settled image. The helper SHA-256 is `7140b1b18acfd217e89b7111f43b1dafa309f9d373f429be34653cca15d96bc1`; it only reads SBValues, auto-continues, and performs no expression evaluation. The full hash manifest is in the adjacent cache provenance file `reader-matrix-provenance.md`.

The source remained unchanged. The app was launched and its UI/VoiceOver state was operated as part of the test; no source, build, or install change occurred, and no other test was interrupted. The helper breakpoints were deleted and the debugger was detached after the run; VoiceOver was off at cleanup. Two phase-41 locations explain duplicate idle records; they are not two independent events.

## Follow-up boundary

The planned next diagnostic—observing actual image position or geometry together with the model update boundary—was completed by the standalone probes below. A production position synchronization was selected and written afterwards, then withdrawn (see Attempted fix, withdrawn), so none is in the app today.

## Standalone position probe evidence (2026-09-18)

The bounded standalone probe used 20 fixed vertical targets with alternating 700/400-point heights, zero spacing, `.scrollTargetLayout()`, and `.scrollPosition(..., anchor: .center)`. It was built with Xcode 26.6 for a generic iOS Simulator destination; the source and probe artifacts are outside the repository under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w38-position-probe/`. This evidence is diagnostic only and introduced no production change.

| Probe | Evidence | Result |
|---|---|---|
| Original optional-ID binding, PID 30834, binary `5c8d7f6ebb0631bfdbea6f234c1a86e82f53ccd7e2fc75c5b37baafe9c2ca937` | Ordinary touch from 10:30:29–10:30:32 JST advanced ID/model to 3. In the same JST run, native VoiceOver Next Element reached pages 1–5; geometry offsets included 300, 345, 895, 1445, and 1995 while ID/model stayed at 3. | Geometry changed without a phase callback or model update. |
| `ScrollPosition` binding, PID 33012, binary `ee4485d24dc08f2395ce4ca41a61be3e0cbfc8f3eb479e95603ce4471109de9d` | Ordinary touch from 10:36:58–10:37:01 JST advanced to 3. VoiceOver reached page 1 at 10:37:35.681 JST and page 2 at 10:37:40.207 JST while geometry changed and `viewID(type: Int.self)`/model stayed at 3. A small ordinary touch at 10:39:14 JST moved to offset 355/midpoint 715 and recovered model 2. | Changing only the binding API did not remove the tested VoiceOver mismatch. |
| Per-target center observer, PID 34480, binary `ec7bb70a34c8d3b0ffb4319d52b483eb6a3507f7f37ee0510b585c56ac6501c7` | Ordinary touch reported native ID 1→2 at offset 313 and ID 2→3 at offset 833, while the containment observer reported target 2 centered at 365. | Per-target containment is not equivalent to the native target-selection boundary. |
| Geometry-detail observer, PID 36190, binary `54df166f42341de4b61043f898ac734f30c8ff85d385393c473c736e71af5f73` | At 10:46:08 JST during VoiceOver page 2 at offset 345, the scroll sample reported container height 685, bottom content inset 34, and visible-rect height 719; target 1 reported local scroll-bounds midpoint 688 with height 700, while target 2 reported midpoint -12 with height 400. | The local `bounds(of: .scrollView)` values do not directly equal the `ScrollGeometry.visibleRect` used by the scroll container. |

The original setter observation was previously inconclusive because SwiftUI could bypass the setter. The standalone probes now add direct `onChange` observations: in both the optional-ID and `ScrollPosition` fixtures, the binding's observed ID remained unchanged during the tested VoiceOver movement while `onScrollGeometryChange` continued to report offset and visible-midpoint changes. This is evidence for these fixtures only; it does not infer private SwiftUI internals or generalize beyond the tested runtime.

The bounded root cause therefore has two layers: native SwiftUI scroll-position selection does not publish a corresponding ID/phase event for the tested VoiceOver auto-scroll, and the app's vertical `AdvancedList` updates `PageModel` only from the idle phase. The first layer leaves the native position observable stale; the second leaves the app indicator stale. A simple containment rule is rejected by the probe. Nearest-target-center remains a hypothesis for further design work. If a position-sync fix is selected, its implementation must validate native `.center` semantics, variable heights, spacing, first/last targets, jumps, and echo guards; the owner chose to pursue that app synchronization on 2026-09-19 and withdrew the result on 2026-09-21, so no production synchronization algorithm is in the app today. The list of properties above is what the withdrawn attempt had to satisfy, and a second attempt inherits it along with the last-page jitter that ended the first.

## Attempted fix, withdrawn (2026-09-19 to 2026-09-21)

An app-side position synchronization was implemented on 2026-09-19 after the owner selected it, verified on the simulator, and withdrawn by the owner on 2026-09-21. W-38 is open again and this document describes an unfixed finding. The branch no longer carries the fix. The withdrawn commits are kept reachable under the local tag `withdrawn/w38-fix-20260921` so a second attempt can read the design back rather than rediscover it.

### Why it was withdrawn

The owner found a degraded behavior that the simulator verification did not cover: scrolling to the last page jitters. That is the whole reported symptom. No cause is established or claimed here, and the withdrawal was not conditional on finding one. A second attempt should look first at the two places where the withdrawn design touches the end of the content, both described below: the sync published a page from geometry on every settled change, including at a content end where there is no further page to settle onto, and the last child of each lazy stack was a zero-size sentinel whose spacing was taken back with a negative bottom padding on the stack itself.

### What the withdrawn design was

| Piece | What it did |
|---|---|
| `ScrollTargetTracker` | A pure state machine, `following(target, hasArrived)` or `free`. `observe` classified a reported page as `.userScrolled` or `.displaced`; `follow` suppressed the echo of a jump without a timer. |
| `PageScrollTarget` | A per-page preference claiming "this page covers the container center". A preference rather than an action, because a lazy page that leaves the stack never reports the claim as false. |
| `PageScrollSync` | The shared modifier. Observers only recorded into `@State` and acted from `onChange`, because mutating the model inside `onPreferenceChange` makes VoiceOver lose focus. After `.displaced` the pager renamed the page and the strip released its anchor. |
| `PageScrollLookAheadSentinel` | A zero-size final child, added because a lazy stack's look ahead never realizes its own last child, so VoiceOver's Move to Next Item could not reach the last page. |

Designs rejected along the way, which a second attempt does not need to retry: focus-driven sync (`AccessibilityFocusState` arrives one element late), stateless geometry publishing (it publishes jump and launch transients and oscillates at the content ends), and `onScrollTargetVisibilityChange` (it drops the final event).

### What was kept

The reader's page-change routes are now under automated test, and that coverage does not depend on the withdrawn fix, so it stayed:

| Route | Coverage |
|---|---|
| Scrolling, the slider, the pager's tap zones, auto-play | `EhPandaUITests/ReaderPageSyncUITests`, each under the vertical strip and the left-to-right pager |
| Entering the reader: page link, direction switch, reading again from saved progress | The two `DeepLinkSchemeUITests` page-link tests, which now also read the screen, and `testReadingAgainResumesOnThePageLeft` |
| Auto-play cadence, restart, stop, stop from inside a tick, invalidation | `AutoPlayHandlerTests` on a `TestClock`, after `AutoPlayHandler` moved from `Timer.scheduledTimer` to the injected `continuousClock` |
| An assistive technology's own scrolling, the W-38 route itself | Not drivable from XCTest, which neither turns VoiceOver on nor issues Move to Next Item. On screen it is covered only by the simulator walks recorded above |

Every UI check reads both sides through `EhPandaUITests/Support/ReaderPageProbe`: the page the indicator names, and the page number nearest the center of the page list. An assertion on the indicator alone cannot see W-38, because the indicator is computed from the page model, which is the side that goes stale.

`ScrollTargetTrackerTests` was not kept. It tested the withdrawn state machine and has nothing left to test.

This coverage was run once more on 2026-09-21 with the fix gone, and passed 13 of 13 on the first attempt, 5 reader tests and 8 deep-link tests (`withdraw-uitest.log`). It therefore stands on the unfixed reader, which is what makes it safe to keep here, and it is not evidence about W-38: the routes it drives all settle the scroll, and settling is exactly what the unfixed reader already synchronizes on.

## Artifact provenance

The probe build logs and runtime logs are retained in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w38-position-probe/`, including `root-observer-runtime.log` (SHA-256 `36e0726f5dbb9034a7bf8f80930ea2c080db88bb716a8ca8276df83fbca4fd51`), `root-modern-runtime.log` (`da52ce7d99cc68ddd9f7c974ce76f993e4c7b9e4b863a325ee7af0ae147c5f43`), `root-modern-recovery.log` (`90cd92cbe35744785bee20c711406808f083c31f96668484ea2ab1c729f57d08`), `root-center-runtime.log` (`541ed8fee7b65c22a201f1c785a7ab256766cc88b367ba7327867615a2e47271`), and `root-geometry-detail-runtime.log` (`6917376c4263781d0fd7beace2cfef4fe6fa4f85e09bc6c4061a7c8fdc38692c`). The matching build logs are `build.log` (`1ee1dc60a39b05ce13549c86c83a063cc8d5ef11a7cd890b8351514894bd3dfa`), `build-modern.log` (`09d88cca5d236c17e11c95768878148c7f5cf800400ecec3a35c43f6a0aa03cd`), `build-center-observer.log` (`929d0bf49ff653383a5da686a205cac24721b516e9593e9eb9036764d259e8f2`), and `build-geometry-detail.log` (`07e71b1ff03ebb2a89a0107a9639e064d2b0ba55afd4342e3c51e6065e7ebf64`). The saved variants are `baseline-id/`, `modern-position/`, and `center-observer/`. VoiceOver was off at cleanup, logging was stopped, all probe processes were terminated, and the original EhPanda PID 16531 remained in the foreground with its panel at 7/155; only the bounded WALK state changed. Hashes above identify the binaries used for the corresponding runtime evidence.

## Current iOS 27 baseline (2026-09-22)

The owner request is recorded verbatim in `16-SWEEP.md § Owner focus approval and W-38 continuation`. The permitted repair is an additional index update path active only for VoiceOver. Existing ordinary scrolling, scroll bindings, slider, tap, autoplay, resume and page mapping must remain intact. The withdrawn global synchronization, sentinel and negative spacing adjustments remain withdrawn.

The unchanged source at documentation HEAD `2b9ea67c` built successfully with Xcode 27.0.0. The same executable was installed on two task-owned simulators: iPhone Air (`8E3EA338-4F93-40A7-BE4F-1F6E7C855F32`) and iPad Pro 11-inch M5 (`55C7BED8-A301-4C4B-94F7-1959B45EBE27`), both OS 27.0. Executable SHA-256: `2f27b1c1d79bc473ab126e49bb57d357e0791770567a645f30ca8eee7fa0f5d3`. The build retained an unrelated existing ShareExtension `loadItem` deprecation warning. No test gate was rerun or reclassified as passing.

The local evidence root is `/tmp/ehpanda-w38-20260922/`. Native VoiceOver ran in the simulator; single-finger right swipes resolved to `Built-in: Next Item` / `OneFingerFlickRight` in the native VoiceOver log. These were not XCTest scroll actions.

| Baseline case | Bounded observation | Evidence |
|---|---|---|
| iPhone, numbered failed-image placeholders, controls shown | Native VoiceOver movement advanced the indicator to 3 and 4 while VoiceOver remained active. | `baseline-step-*.txt`, `baseline-voiceover.log` |
| iPhone, cold entry with VoiceOver enabled, controls hidden | Focus reached page 4. After disabling VoiceOver and revealing controls without a scroll gesture, the indicator and visible placeholder were 4. This alone cannot exclude reconciliation during the reveal. | `baseline-cold-step-*.txt` |
| iPhone, near-end placeholders, entry at 154 | Native next-item traversal reached 156; after controls were revealed, indicator and placeholder both read 156. No jitter was observed in this bounded walk; physical-device end behavior is not established. | `baseline-end-step-*.txt`, `baseline-end-indicator.txt` |
| iPhone, debugger observation during native VoiceOver movement | At `03:19:33.794` UTC, the read-only logger recorded `PageModel.update` called from the existing `AdvancedList.body` closure at line 44, before any control-panel reveal. The missing idle-path update from the old runtime was present in this case. | `baseline-tall-lldb.log` (despite the filename, this was still a placeholder case), `baseline-voiceover.log` |
| iPhone, loaded tall synthetic image, 1:4 aspect ratio | Native next-item movement scrolled the image and changed the visible indicator from 2 to 3 with controls shown and VoiceOver active. Further next-item attempts stopped advancing at the lazy content boundary; they do not prove a stale index. | `tall-after-launch.png`, `tall-next-*.txt`, `baseline-voiceover.log` |
| iPhone, loaded short synthetic images, 2:1 aspect ratio | Native movement advanced the indicator through 4, 5 and 6. Each recorded value matched the image at the viewport center in the observed sequence; multiple images remained visible. | `short-next-*.txt`, `baseline-voiceover.log` |
| iPad, loaded short synthetic images | Native movement changed the visible image frames and advanced the indicator from 2 to 3 while VoiceOver remained active. This is a limited sequence, not a complete page-route or end-of-content check. | `ipad-short-next-*.txt`, `baseline-ipad-voiceover.log` |

The loaded-image fixtures were temporary copies, not repository edits. Their Gallery Detail thumbnail links used ordinary `/s/` page URLs to reach the existing stub's supported route; `GallerySinglePage.html` then supplied a generated local PNG through the existing image loader. The original fixture's `/mpv/` links instead hit an unsupported stub route and produced placeholders. No production network or parser behavior was changed.

The debugger helper read primitive SBValues, evaluated no expressions and changed no application state. Its breakpoints were deleted and it detached cleanly before the later loaded-image checks.

Cleanup verified VoiceOver disabled on both task-owned simulators, stopped both task-owned native log streams and shut down both task-owned simulators. The pre-existing user simulator and debugger processes were left untouched. Repository source and fixtures remained unchanged.

### Migration failure interpretation

The prior iPad automated test remains a failure. In `/tmp/ehpanda-ios27/final-reader-native-toolbar27-summary.json`, the final failure text reports indicator 2 and screen 2, which fails the test's additional requirement to advance beyond the starting page. The same bundle's `topInsights` reports two earlier runs with indicator 2 and screen 3. Therefore neither "all failures were only failure to advance" nor "the final assertion proves the VoiceOver stale-index defect" is justified. `ReaderPageSyncUITests` drives ordinary touch with VoiceOver off. Its failures must remain recorded and cannot be treated as evidence for a VoiceOver-only repair.

### Next diagnostic boundary

No current stale-index case was reproduced in the bounded native VoiceOver checks, so no additional observer was added speculatively. This is not a claim that iOS 27 fixes every W-38 case, an acceptance of W-38, or phase approval. A question remains with the owner for the currently affected OS/device and exact VoiceOver action (next-item movement or three-finger scrolling), so the authorized additional path can be tested against an actual failing case. Three-finger scrolling, physical devices, landscape, and a full loaded-image end sequence were not verified here. Any implementation must first preserve the ordinary routes and then show the failing VoiceOver case passing without last-page jitter.
