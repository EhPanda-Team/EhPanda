# Approved UI implementation — 2026-10-28

The owner selects **B1–B6**, including the Archives footer, after the native screenshot review.
The owner explicitly defers discussion of the three device-bound serialization exceptions; this
is not approval. Their runner settings and pending status remain unchanged.

The owner also requests integration of the earlier Library + Favorites/Downloads navigation title
menu. The saved prototype remains at `a7853729fb`, under
`.planning/quick/261015-duo-session-record/evidence/library-title-matrix/persistent/probe/CustomArrowProbe.swift`.
The owner clarifies that they want the final persistent large-looking title with the custom,
system-style arrow. Its preserved source uses a native `.title` slot and `.inline` mode with a
`.title2.bold()` label, native subtitle, browser role and navigation-bar minimization disabled. This
implementation detail was disclosed; the earlier `.inlineLarge` prototype scrolls away and is not
the final persistent design. After briefly requesting both controls, the owner changes their mind
and explicitly removes the bottom-right switch. The final UI retains only the title menu on compact
roots, preserving shared selection and the expanded sidebar's category navigation.

## Execution plan

1. Integrate the reviewed B1–B6 view patch. Preserve explicit soft top edges, native tab adaptation,
   search behavior, presentation boundaries and the accessibility Archives scrolling column.
2. Integrate the final persistent title menu. Use the existing source
   selection action and remembered Favorites/Downloads filters; do not add a parallel selection
   store or custom navigation/tab bar. Keep the menu on the compact Library root and the existing
   sidebar routing in expanded layouts. Preserve source-specific toolbar actions.
3. Run strict lint, a normal Debug build and focused existing UI tests in parallel workers on iPhone
   and iPad. Cover Library navigation/source switching, grid reachability, titles at standard/AX1/AX3/AX5,
   search/query return and root Home/Search/Settings behavior. Update existing interaction assertions
   only if the newly approved menu intentionally replaces their source-picker entry point.
4. Inspect native Archives standard/accessibility layouts and selected title-menu behavior, including
   scrolling, live text-size changes and orientation. Record actual evidence and any unavailable
   checks; do not turn a proposed full matrix into an unearned pass.
5. Review the final source against the SwiftUI skills, commit implementation separately from the
   updated evidence/checkpoint, and keep the serialization work pending for later discussion.

Execution is inline under the existing GSD quick-task continuation. No new subagent is dispatched.

## Implementation notes

- B2–B5 retain native placement-aware bottom effects on Library, Home, Search and Settings. Only
  actual bottom tabs request `.soft`; top/side tabs retain `.automatic`.
- B6 uses `safeAreaBar(edge: .bottom, spacing: 8)` for the standard Archives funds/action footer.
  The accessibility layout still scrolls the grid, funds and action together.
- The final Library title is shared by Favorites and Downloads through an optional root-title
  component. Its binding sends the existing Library selection action and carries the remembered
  category/filter. Expanded sidebar roots keep their existing titles. Root-only composition leaves
  pushed pages in charge of their own navigation title.
- The custom arrow preserves the final probe's 18-point circle, 10-point chevron and 8-point gap;
  circle and chevron use semantic scaled metrics. The Menu has localized labels and selected-source
  semantics, and its decorative arrow is hidden from accessibility.
- The Debug-only URL protocol now serves the reviewed artificial Archives fixture. The HTML lives
  in the UI-test bundle, so final-source native Archives checks do not require an edited app copy.
- Build integration caught a missing symbol-extension import and public import visibility; both
  were corrected. The final build-for-testing passes without compiler/lint warnings. Native inspection
  identifies the title as a popup control, so UI tests query its stable identifier across element roles
  and verify the visible native source subtitle.
- Initial iPhone native captures at standard/AX1/AX3/AX5 show the complete title, arrow and subtitle.
  The title control is `(16,64,99,26)` points both before and after scrolling, and remains available
  after switching to Downloads and rotating. These are observed frames, not hardcoded app geometry.

Automatic approval review rejected a proposed command containing
`-disable-concurrent-destination-testing`. The current verification uses two independent jobs
launched concurrently, each with `-parallel-testing-enabled YES`; no execution mode is disabled,
no single-worker cap is set, and the generated test manifest's retry policy is removed only in a
temporary copy so a repeated green result cannot count as acceptance.

## Verification and resulting corrections

- Final normal Debug build-for-testing succeeds in 17.147 seconds with zero compiler/lint warnings.
  Strict SwiftLint passes all 16 changed/new Swift files; whitespace checks pass.
- Initial UI selection: 11 methods on each device, with three active XCTest class workers per
  destination. Each device has 10 passes and one failure: `testSearchRootAudit` reports the existing
  18-point-high Search header actions. The original baseline outline also measures those labels at
  18 points. Library source switching, list/grid retention, pagination, title visibility at all four
  sizes, search return, Home, Settings and Library accessibility audits all pass.
- Search's native Show All and Remove All labels now provide a 24-point minimum hit region. Their
  text style, heading positions and content positions are preserved at standard size; button bounds
  expand from 18 to 24 points inside the existing 24-point heading row. Confirmation dialogs remain
  attached to the triggering buttons. No audit exclusion or expected-failure annotation was added.
- Corrected verification runs `testSearchRootAudit`, `testSearchRootAndQuickSearchRemainUsableAtAX5`
  and `testFavoritesLayoutPersistsThroughLibrary` on both devices: **6/6 passes**, no failures,
  skips, expected failures, runtime warnings or repetition nodes. Each case has exactly one run.
  The 20 initial passes and six corrected passes are separate runs, not a claim of a new full suite.
  Exact identities/results are in [UI-TEST-RESULTS.json](UI-TEST-RESULTS.json).
- Xcode takes ten additional minutes collecting simulator diagnostics after the initial tests finish.
  Process sampling identifies `collectSimulatorDiagnostics` waiting for `simctl diagnose` with a
  600-second timeout. The test bundles subsequently close normally with their genuine audit failure;
  no process was killed to manufacture a result. The corrected iPhone run logs an unused-worker
  launch error; its scheduler runs all three cases on Clone 1. The iPad run uses two active workers.
  Both destinations still run concurrently with parallel execution enabled, and no cap or serial flag
  is configured. All selected cases execute once and pass; the original logs are retained. The initial
  run separately proves three active class workers on each device.
- A full native accessibility outline omits the Library title after a live text-size update. The
  screenshot still shows it, and direct point-subtree inspection returns the native Library popup
  and its stable identifier. The initial claim that the title disappeared is corrected: this is an
  outline-tool limitation, not a rendering defect. No app workaround is introduced.
- The first Archives capture inspected SpringBoard before the launch transition finished. The
  helper now waits for launch completion before observing. Native inspection also caught an iPad
  AX5 capture before the footer reached the smaller sheet's scroll boundary; it was recaptured at
  the actual end and the complete button is visible. Neither event changed production layout.

Native evidence:

- `/tmp/ehpanda-261028-ui-adoption-iphone.xcresult` and `-ipad.xcresult` — initial 20 passes / 2 failures.
- `/tmp/ehpanda-261028-ui-hit-region-iphone.xcresult` and `-ipad.xcresult` — corrected 6/6 passes.
- `/tmp/ehpanda-261028-ui-hit-region-build.log` — final compilation.
- `/tmp/ehpanda-search-audit-attachments/` — retained initial failure evidence.

## Final screenshot list

Open `implemented.html` in the local gallery folder, or
`http://127.0.0.1:8756/implemented.html` while the review server runs. The gallery folder is:

```text
$HOME/.codex/visualizations/2026/10/28/01a18093-35bb-7490-9bee-b93c0bc77dd8/bottom-bars/
```

All 36 implemented images are original native screenshots, with matching accessibility outlines.
[UI-IMPLEMENTATION-MANIFEST.json](UI-IMPLEMENTATION-MANIFEST.json) records dimensions, hashes and
capture app binaries. Source is `25649f32c2` plus `adaf3d6017`; the Search pair was refreshed after the
hit-region correction. The remaining captures use the identical UI code before that isolated Search
correction. Baseline images retain their original [manifest](SCREENSHOT-MANIFEST.json) provenance.
No image is checked into Git or retouched. Home slideshow content can differ across captures.

| Before / implemented pairs | iPhone | iPad |
|---|---|---|
| Library cold entry | Standard, AX1, AX3, AX5 | Standard, AX1, AX3, AX5 |
| Home, Search, Settings | Standard for each | Standard for each |
| Archives | Standard, AX5 at footer | Standard, AX5 at footer |

Paths are `before/<device>-<page>[-<size>].png` and `implemented/<device>-<page>[-<size>].png`.
The 18 additional originals are:

| Additional capture | iPhone suffixes | iPad suffixes |
|---|---|---|
| Live Library text-size changes | `library-live-ax1`, `library-live-ax3`, `library-live-ax5` | Same |
| Dark Library | `library-dark` | Same |
| Library persistence and interaction | `library-scrolled`, `library-menu`, `library-downloads`, `library-landscape` | — |
| Archives live sizes and rotation | `archives-ax1`, `archives-ax3`, `archives-landscape` | Same |

Devices return to portrait, Large and light appearance. The Archives download action is never
invoked. These checks cover the selected iPhone/iPad states; they do not claim a full Duo,
multitasking, right-to-left, every sheet, or VoiceOver walkthrough. Device-bound serial workflows
were not run or approved. The earlier size results remain tied to the size-only source revision.

## Commits and remaining work

- `25649f32c2` restores the persistent Library title menu and updates existing navigation assertions.
- `adaf3d6017` adopts bottom effects and the Archives bar, adds the Debug-only archive fixture route,
  and corrects the Search header hit regions found during verification.

The selected UI work is implemented and verified within the stated bounds. The quick task remains
incomplete only for the deferred serial-runner decision and resulting runner migration. Phase 17's
existing owner-review gate is unchanged.

## Final Library control choice

The owner first asks to retain both controls, then explicitly withdraws that request: remove the
bottom-right switch. The uncommitted restoration and its test-only assertions are removed. App and
UI-test source match the previously verified title-menu-only implementation at `96f4276c27`; no new
selection state or layout behavior remains. AGENTS.md records the final choice.

The current `implemented.html` again shows the original title-menu-only captures and their existing
manifest provenance. The withdrawn both-controls screenshots remain outside Git for comparison.
The iPad test run for that withdrawn design finished with three passes; the iPhone job was canceled
after the owner changed scope, then terminated when log finalization stalled. Neither is claimed as
verification of the final source. Existing title-only UI results above remain the applicable tests.

A fresh Debug build-for-testing succeeds in 17.493 seconds with zero compiler/lint warnings. The
rebuilt app is installed on the review iPhone; native inspection confirms the bottom switch is absent
and the title menu still switches Favorites → Downloads → Favorites. Fresh originals and matching
accessibility outlines are `final-title-only/iphone-library` and
`final-title-only/iphone-library-downloads` under the same external gallery folder. The current
gallery's Library comparison and its title-only image links are verified in the browser.
