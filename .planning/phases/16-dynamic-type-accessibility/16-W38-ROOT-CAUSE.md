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

The next diagnostic should observe actual image position or geometry together with the model update boundary. No implementation or workaround has been selected in this record.
