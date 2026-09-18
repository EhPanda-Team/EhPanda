# W-38 Reader page and indicator investigation

## Scope and status

W-38 was tested in four bounded WALK cases on iPhone 17, iOS 26.5 (23F77), portrait. The same installed binary was used throughout (SHA-256 `1b02f72e4aebb0d3dc7830e9c2e129ad4a96d3927d96c638217e9ac2709b6621`). Two VoiceOver cases show the divergence and two ordinary-touch cases show normal synchronization. The finding is root-cause confirmed for the tested vertical reading path and remains unimplemented; it is not a phase-pass or a claim about other orientations, devices, physical hardware, OS versions, custom rotors, or three-finger VoiceOver scrolling.

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

The planned next diagnostic—observing actual image position or geometry together with the model update boundary—was completed by the standalone probes below. Production position synchronization remains unselected.

## Standalone position probe evidence (2026-09-18)

The bounded standalone probe used 20 fixed vertical targets with alternating 700/400-point heights, zero spacing, `.scrollTargetLayout()`, and `.scrollPosition(..., anchor: .center)`. It was built with Xcode 26.6 for a generic iOS Simulator destination; the source and probe artifacts are outside the repository under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w38-position-probe/`. This evidence is diagnostic only and introduced no production change.

| Probe | Evidence | Result |
|---|---|---|
| Original optional-ID binding, PID 30834, binary `5c8d7f6ebb0631bfdbea6f234c1a86e82f53ccd7e2fc75c5b37baafe9c2ca937` | Ordinary touch from 10:30:29–10:30:32 JST advanced ID/model to 3. In the same JST run, native VoiceOver Next Element reached pages 1–5; geometry offsets included 300, 345, 895, 1445, and 1995 while ID/model stayed at 3. | Geometry changed without a phase callback or model update. |
| `ScrollPosition` binding, PID 33012, binary `ee4485d24dc08f2395ce4ca41a61be3e0cbfc8f3eb479e95603ce4471109de9d` | Ordinary touch from 10:36:58–10:37:01 JST advanced to 3. VoiceOver reached page 1 at 10:37:35.681 JST and page 2 at 10:37:40.207 JST while geometry changed and `viewID(type: Int.self)`/model stayed at 3. A small ordinary touch at 10:39:14 JST moved to offset 355/midpoint 715 and recovered model 2. | Changing only the binding API did not remove the tested VoiceOver mismatch. |
| Per-target center observer, PID 34480, binary `ec7bb70a34c8d3b0ffb4319d52b483eb6a3507f7f37ee0510b585c56ac6501c7` | Ordinary touch reported native ID 1→2 at offset 313 and ID 2→3 at offset 833, while the containment observer reported target 2 centered at 365. | Per-target containment is not equivalent to the native target-selection boundary. |
| Geometry-detail observer, PID 36190, binary `54df166f42341de4b61043f898ac734f30c8ff85d385393c473c736e71af5f73` | At 10:46:08 JST during VoiceOver page 2 at offset 345, the scroll sample reported container height 685, bottom content inset 34, and visible-rect height 719; target 1 reported local scroll-bounds midpoint 688 with height 700, while target 2 reported midpoint -12 with height 400. | The local `bounds(of: .scrollView)` values do not directly equal the `ScrollGeometry.visibleRect` used by the scroll container. |

The original setter observation was previously inconclusive because SwiftUI could bypass the setter. The standalone probes now add direct `onChange` observations: in both the optional-ID and `ScrollPosition` fixtures, the binding's observed ID remained unchanged during the tested VoiceOver movement while `onScrollGeometryChange` continued to report offset and visible-midpoint changes. This is evidence for these fixtures only; it does not infer private SwiftUI internals or generalize beyond the tested runtime.

The bounded root cause therefore has two layers: native SwiftUI scroll-position selection does not publish a corresponding ID/phase event for the tested VoiceOver auto-scroll, and the app's vertical `AdvancedList` updates `PageModel` only from the idle phase. The first layer leaves the native position observable stale; the second leaves the app indicator stale. A simple containment rule is rejected by the probe. Nearest-target-center remains a hypothesis for further design work. If a position-sync fix is selected, its implementation must validate native `.center` semantics, variable heights, spacing, first/last targets, jumps, and echo guards; the owner is choosing whether to pursue that app synchronization or retain native behavior. No production synchronization algorithm has been selected or implemented.

## Artifact provenance

The probe build logs and runtime logs are retained in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w38-position-probe/`, including `root-observer-runtime.log` (SHA-256 `36e0726f5dbb9034a7bf8f80930ea2c080db88bb716a8ca8276df83fbca4fd51`), `root-modern-runtime.log` (`da52ce7d99cc68ddd9f7c974ce76f993e4c7b9e4b863a325ee7af0ae147c5f43`), `root-modern-recovery.log` (`90cd92cbe35744785bee20c711406808f083c31f96668484ea2ab1c729f57d08`), `root-center-runtime.log` (`541ed8fee7b65c22a201f1c785a7ab256766cc88b367ba7327867615a2e47271`), and `root-geometry-detail-runtime.log` (`86d9e808f916d3e600daadd71d6e4b59434038946833767d90a8880b8dd2b024`). The matching build logs are `build.log` (`1ee1dc60a39b05ce13549c86c83a063cc8d5ef11a7cd890b8351514894bd3dfa`), `build-modern.log` (`09d88cca5d236c17e11c95768878148c7f5cf800400ecec3a35c43f6a0aa03cd`), `build-center-observer.log` (`929d0bf49ff653383a5da686a205cac24721b516e9593e9eb9036764d259e8f2`), and `build-geometry-detail.log` (`07e71b1ff03ebb2a89a0107a9639e064d2b0ba55afd4342e3c51e6065e7ebf64`). The saved variants are `baseline-id/`, `modern-position/`, and `center-observer/`. VoiceOver was off at cleanup, logging was stopped, all probe processes were terminated, and the original EhPanda PID 16531 remained in the foreground with its panel at 7/155; only the bounded WALK state changed. Hashes above identify the binaries used for the corresponding runtime evidence.
