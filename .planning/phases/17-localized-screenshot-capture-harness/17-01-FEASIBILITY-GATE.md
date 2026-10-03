---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: partial-matrix-owner-viewport-decision
recorded: 2026-10-04
source_head: 8e2122c92b7fcd6dea4cb8ee1cdafd3490513f2a
---

# Task 2 actual-content feasibility gate

Owner handoff adds `3b4e460722` (render parity) and `8e2122c92b` (reader export at rendered
pixel width) above root's `a3f6adc422` checkpoint. Root reconciled the committed source,
standalone findings, xcresult summaries/trees, native attachments and fixture hashes.
The old Downloads one-byte mismatch, Reader black middle read and Reader top blur are
resolved in the supplied portrait captures. Architecture approval remains settled.
Task 2 is still incomplete: 1/2 tasks and 0/24 plans complete, no SUMMARY or baseline.

## Current committed capture behavior

- Viewport references must stay byte-identical for at least 500 ms, sampled approximately
  every 100 ms with a 40-sample bound. Layout convergence alone did not wait for the
  one-time Liquid Glass settling step. Failed settling throws renderDidNotSettle;
  geometry records renderSettleSamples and renderSettleMilliseconds.
- Replicant reads use a strict sub-8192-pixel ceiling: maximumSnapshotDimension is 8191,
  maximumSliceHeight is 2730 pt at 3x and 4095 pt at 2x. Exactly 8192 px can return true
  but opaque black on the measured iPad replicant path. Direct drawHierarchy's measured
  inclusive ceiling remains 8192 px. Width rejection and 64-point context/overlap remain.
- A full-screen non-key companion window at .normal mirrors the status-bar visibility
  measured at the native viewport while the capture window is tall. The convergence loop
  checks that state and throws on drift; restoration/dismissal removes the companion.
  This preserves the Reader's hidden status bar, safe area and native soft top-edge effect.
- The vertical Reader exports eight 8:11 pages at the coordinate's rendered pixel width,
  rounded to a whole-pixel height. Each coordinate gets a fresh fixture path after actual
  scene orientation is measured. Artwork width x scale must equal the exported width.
  Default export remains 800 x 1100; previews/covers and fixture version are unchanged.

The standalone findings are under
`/tmp/ehpanda-phase17-size-probe-evidence/probe4-9-render-parity/RESULTS.md`,
`tablet-window-width/` and `reader-page-geometry/`. Narrow iPad windows can also return
true with black content: the scene-width requirement remains essential. These findings
concern the measured iOS 27 Simulator runtime, not universal physical-device limits.

D-08 still produces one image from one stationary committed full-height layout. Slices
read that frame without scrolling; the entire overlap must match exactly and canonical
bytes are copied on the CPU. The 32768-pixel height limit is the composite memory budget.
Native parity, census, final-item/artwork completeness and restored geometry remain strict.

## Supplied builds and independently inspected test results

`/tmp/ehpanda-phase17-parity-build.log` and `-build-tablet.log` are incremental
build-for-testing invocations, both successful with zero compiler/deprecation/SwiftLint
diagnostics. They are not a new clean-build gate. The earlier clean proof at source
9906f9a619 remains historical; a current-source clean integration is still needed before
completion after any further implementation revision.

| Existing result under `/tmp/ehpanda-phase17-` | Inspected actual tests | Passed / failed / skipped | Repetition nodes |
|---|---:|---|---:|
| `parity-phone.xcresult` | 2 | 2 / 0 / 0 | 0 |
| `parity-tablet.xcresult` | 9 | 9 / 0 / 0 | 0 |
| `matrix-phone.xcresult` | 1 | 0 / 1 / 0 | 0 |
| `matrix-tablet.xcresult` | 1 | 0 / 1 / 0 | 0 |

The handoff reports an earlier phone 12/12 group (six feasibility, three renderer, three
Home tests). The current same-named phone log/bundle contains the later 2/2 Reader and
requested-width export tests. Earlier six named directory attachments survive separately
under `/tmp/ehpanda-phase17-parity-phone-attachments/`; do not describe the current
bundle as a twelve-test run. Root read a private copy when xcresulttool needed its report
cache; `/tmp/ehpanda-phase17-root-parity-review-hdb3wjhq/` preserves inspected summaries,
tree and current Reader attachment. The current phone Reader fixture provenance matches
source 8e2122c92b. Tablet's nine-test tree directly includes all six feasibility tests and
three renderer tests. VisualTracerTests.testHomeFullContentTracer still asserts phone
idiom and is phone-only; tablet Home evidence comes from the actual matrix.

## Supplied actual matrix outcomes

| Family | Captured | Failed | Pending | First failed coordinate |
|---|---:|---:|---:|---|
| iPhone Air | 4 | 1 | 11 | iphone-portrait-AX5-home |
| iPad Pro 11-inch (M5) | 8 | 1 | 7 | ipad-landscape-large-home |
| Combined | 12 | 2 | 18 | Both matrices stop at their first failure |

Phone captures all four portrait/large shapes. Tablet captures all eight portrait shapes
at large and AX5. Every completed capture has exact-once item/page census, matched strict
native viewport parity and the required restoration/completeness gates. Phone Comments
420 x 2798 pt uses two slices; Downloads 420 x 2788 pt uses two; Reader 420 x 4622 pt
uses two with statusBarHidden true. Tablet Comments 834 x 1963 pt uses one, Downloads
834 x 2743 pt uses one, Reader 834 x 9176 pt uses three with statusBarHidden true.
Tablet AX5 Reader also captures all eight pages exactly once at 834 x 9176 pt.

Native logs/results: `/tmp/ehpanda-phase17-matrix-phone.log` / `.xcresult` and
`/tmp/ehpanda-phase17-matrix-tablet.log` / `.xcresult`; summaries/trees use the same
prefix with `-summary.json` / `-tests.json`. Invocations are serial, parallel testing
disabled, without failure retries. Exact extracted outcomes and coordinate directories:

- Phone: `/tmp/ehpanda-phase17-matrix-phone-attachments/ex/phase17-feasibility-9CEB7131-A827-462F-B538-5DF819C0EBEE`.
- Tablet: `/tmp/ehpanda-phase17-root-matrix-tablet-evidence/phase17-feasibility-328C4AC3-698F-4A65-A2CA-9F43AE420B44`.

These are supplied informational runs, not root reruns. Their fixture manifests name
source hash `26da899c6796b56bd4e54e828d1c218c1b8c46a6bceaa461cb91d5b209feb3a5`, which differs from the current generator source hash.
The current later phone Reader attachment names the current hash. Do not claim an exact
current-source full matrix from those earlier manifests. Assets/digests are checked and
these runs remain valid evidence of the observed behaviors; pending coordinates and a
fresh final-source gate must still be completed. Root's observed source hashes are in
`/tmp/ehpanda-phase17-parity-reconciled-source-hashes.json`, not a pre-test freeze record.

## Remaining owner decision — AX5 Home logical viewport

Phone AX5 Home fails with 706625 changed viewport pixels, maximum channel delta 255,
inclusive bounds x0..1259, y554..2727. It is a layout change, not the prior glass rounding.
HomeView.maximumCardHeight uses its observed viewportSize through
GalleryViewport.maximumSlideshowHeight. GalleryCardCell uses ViewThatFits and that height
ceiling to select title lines. Growing the container raises the ceiling, allows another
title line and shifts the content below. This is the production container-responsive
rule behaving as designed, while the harness requires the original logical viewport.

Owner options recorded in the handoff: exclude AX5 Home from full-content coverage;
base the rule on scene size; or provide an injectable logical viewport while default app
behavior continues to use actual container size. No option is selected here. Exclusion
would change matrix acceptance; either production adaptation requires Task 2 ownership
revision. Scene sizing also has implications for windowed/container layouts, so it is
not an interchangeable source substitution. Preserve native navigation/search/edge rules.

## Remaining environment gate — iPad actual landscape

After eight successful portrait coordinates, the scene rejects the first landscape
request with UISceneErrorDomain 101: current windowing mode does not allow programmatic
orientation changes. No landscape capture or coordinate fixture export occurs there;
one failed and seven pending landscape coordinates remain. Native Full Screen Apps
selection alone was previously insufficient. A scene-accepted rotation mechanism and
measured landscape geometry are required; changing only the capture window size would
violate the measured scene-width prerequisite. Actual landscape remains unverified.

Tablet portrait AX5 now validates OCR band ownership for those four coordinates.
Phone AX5 and all landscape coordinates remain unverified, including OCR overlap and
reader budget/geometry. Eight phone-landscape 8:11 page bitmaps total 30096 px in height;
actual landscape output and host overhead have not been verified.

## Log and provenance boundaries

The tablet nine-test log contains one expected render-server refusal from the deliberate
direct-draw pin. The current phone two-test log contains no such pin or refusal. Both
matrix logs and the tablet gate also retain IOSurfaceClientSetSurfaceNotify messages.
They coexist with successful captures and are not established as remaining root causes.
The handoff notes InvalidTransition only on failed Reader teardown; the current inspected
passing gates and matrix logs contain no InvalidTransition. Historical logs remain saved.

The four reserved staged paths match the original patch byte-for-byte; .capture/ remains
untracked and no generated images become baselines. No production source was changed by
root during reconciliation. Obtain the Home viewport decision before production edits or
acceptance changes, then finish native orientation and final clean/full-matrix gates.

## Historical checkpoint — source 9906f9a619, superseded by the parity commits

The following records root's previous evidence and pending questions. Its Downloads/
Reader blockers, unresolved-cause statements and 4/32 accounting are historical. The
current findings and accounting above supersede them without deleting original evidence.

The owner adopted stationary render-server slices in `73bf3e4b59`; architecture approval
is settled and the former three-run recovery bound is superseded. Root completed the
requested clean integration and both actual matrix invocations on the source checkpoint
above. Clean build passes; both matrices fail strict native viewport parity at Downloads.
Task 2 remains incomplete: 1/2 tasks and 0/24 plans complete. No SUMMARY, approved
baseline, bulk recording or later-plan completion follows from this checkpoint.

## Final current-source verification

`/tmp/ehpanda-phase17-slice-final-clean.log`: clean build-for-testing exit 0,
46.355 seconds, zero compiler/deprecation/SwiftLint diagnostics in the complete log.
The earlier clean gate also passed (249.763 seconds). Both resolved lockfiles now record
SnapshotTesting 1.19.6 at revision `28e5de025e3fd98991791bfbf83023ab3708da03`;
every pre-existing package pin is unchanged. The existing Xcode provisioning-profile
loader message remains in the logs and is not a compiler/lint diagnostic.

| Final result prefix under `/tmp/ehpanda-phase17-` | Actual tests | Passed / failed / skipped | Matrix coordinates captured / failed / pending | Exit |
|---|---:|---|---|---:|
| `slice-final-phone` | 9 | 8 / 1 / 0 | 2 / 1 / 13 | 65 |
| `slice-final-tablet` | 1 | 0 / 1 / 0 | 2 / 1 / 13 | 65 |

Each prefix has `.log`, `.xcresult`, `-summary.json`, `-tests.json` and an
`-attachments/` directory. Both trees have zero Repetition nodes and nonzero actual
matched tests. Invocations were sequential, parallel testing disabled, without a failure
retry option. The phone includes FullContentFeasibilityTests x4, RenderServerCaptureTests
x2 and VisualTracerTests x3. Its eight non-matrix tests pass, including independent
`testCommentsNativeCapture`, both fixture-export tests and the three Home regression tests.
The tablet invocation selects only `testActualFullContentMatrix`.

Final simulator inventory is preserved in `/tmp/ehpanda-phase17-slice-gate-devices.json`:
Xcode 27.0.0, iOS 27.0 build 24A434; iPhone Air, 420 x 912 pt @3x, and iPad Pro
11-inch (M5), 834 x 1210 pt @2x. Source/pin hashes were frozen before the final clean
build in `/tmp/ehpanda-phase17-slice-final-source-hashes.json` and still match the
committed source. The matrix uses default window traits (`standardImageRange: false`);
the independent Comments test retains its opt-in true setting.

## What the final matrices establish

Both portrait/large Home coordinates pass with six markers exactly once. Both Comments
coordinates pass with twelve markers exactly once, strict native viewport parity and
restored native geometry. Phone Comments uses two slices; tablet Comments uses one.
Both Downloads coordinates stop at `nativeViewportPixelsChanged` before OCR census,
so their empty census objects mean not evaluated, not missing-marker evidence.

| Downloads coordinate | Output | Slices | Changed viewport pixels | Maximum channel delta | Inclusive difference bounds in pixels |
|---|---|---:|---:|---:|---|
| iPhone portrait/large | 420 x 2788 pt, 1260 x 8364 px | 2 | 147 | 1 | x1066..1201, y204..334 |
| iPad portrait/large | 834 x 2743 pt, 1668 x 5486 px | 1 | 55 | 1 | x1559..1648, y63..147 |

These counts come from independent saved-PNG RGBA inspection; the live strict
SnapshotTesting comparison is the acceptance gate and reports matched:false. Original
viewport, full image, viewport crop, slices, geometry, parity and inspection JSON remain
in each Downloads coordinate directory. The differences lie in the glass toolbar button.
The tablet fails below the native dimension ceiling in a single read, so this remaining
failure is not evidence of a slice seam or the 8192-pixel ceiling. The exact cause is
unproven; no tolerance, pixel mask, device scale or native appearance was relaxed.

Phone matrix root: `/tmp/ehpanda-phase17-slice-final-phone-attachments/matrix/phase17-feasibility-681C4D93-BFF1-44CA-975E-DA0BC66AD037`.
Tablet matrix root: `/tmp/ehpanda-phase17-slice-final-tablet-attachments/matrix/phase17-feasibility-5BCEF646-3DE2-4FD4-975E-06DEBE9BB0B3`.
Each `outcomes.json` preserves all sixteen coordinates. Combined final accounting is
4 captured, 2 failed and 26 pending. Reader, AX5 and landscape coordinates are not
reached in these final invocations. In particular, AX5 has not validated the 128-point
OCR overlap assumption, and actual tablet landscape orientation remains unverified.
Pending is not N/A or a pass.

## Retained same-frame implementation refinements

The following changes are within Task 2's capture/test ownership and retain the adopted
stationary full-height hierarchy. They are committed as WIP, not a passed Task 2:

- Native viewport and full capture use the same checked replicant path and standard
  8-bit renderer range. Native screen scale is unchanged; matrix window traits remain
  default. This removed the initial default-traits Comments failure.
- Multi-slice reads reserve 64 pt of context above/below each owned slice within the
  8192-native-pixel ceiling, then crop CGImage pixels without redrawing. The complete
  64-point overlap still compares byte-for-byte. This fixed the observed two-pixel
  Downloads crop-edge seam difference. Owned frames and readFrame are both recorded.
- CPU composition copies the canonical 8-bit sRGB RGBA bytes used by seam verification.
  It does not redraw the slices. The remaining phone toolbar difference was also present
  in the raw first slice, so CPU composition is not claimed to fix its cause.
- Failed seam and parity gates retain original slice PNGs and rect diagnostics.
- Orientation setup requests an update only when measured scene orientation or bounds
  need to change. It still measures actual orientation/bounds and fails required requests.
  This allows an already-correct iPad portrait scene to proceed without a redundant
  request rejected with UISceneErrorDomain 101. It does not establish landscape success.

## Reader evidence from earlier diagnostic runs

These diagnostics preceded the frozen final source and do not count as final-coordinate
passes. Explicit standardImageRange was tried as a matrix experiment and reverted because
it did not reliably pass Downloads across both families. Preserving the source-window
position of replicants also failed to resolve Downloads and was reverted.

`/tmp/ehpanda-phase17-slice-common-tablet.xcresult` reached Reader after three captured
coordinates with default traits. Reader output is 834 x 9174 pt @2x in three slices.
The first/second 64-point overlap differs at all 213504 pixels, maximum channel delta
217: the first band is cyan artwork and the second is opaque black. The draw Boolean
had succeeded; checked draws are necessary but do not establish fidelity. The strict
seam gate rejects the image. Original slices and extracted overlap/diff PNGs are under
`/tmp/ehpanda-phase17-slice-common-tablet-attachments/matrix/phase17-feasibility-F82CED84-2BA7-4A67-8198-CD05B30C3CA5/ipad-portrait-large-reader/`.

`/tmp/ehpanda-phase17-slice-sdr-phone.xcresult` reached Reader with the temporary
standardImageRange matrix setting. The 420 x 4620 pt @3x output uses two slices and
fails native viewport parity; its top region is visibly blurred compared with the normal
red VRP1 viewport. Differences extend over a broad region, not just one-byte toolbar
rounding. Original full/viewport images and inspection crops remain under
`/tmp/ehpanda-phase17-slice-sdr-phone-attachments/matrix/phase17-feasibility-015718BE-5523-439E-8F3A-0BBDA9AA91ED/iphone-portrait-large-reader/`.

Read-only review identifies a viewport-design risk in ReadingView: onGeometryChange
writes the hosted size to gestureHandler.containerSize, and isLandscape derives from
that size. Enlarging output height can change a production logical-layout input, notably
in landscape. This is not proof that this code causes the observed blur or black reads.
No production source was changed. Any required production viewport adaptation is outside
Task 2's listed files and requires an orchestrator plan revision.

## Logs and test environment boundaries

The phone's one `Render server returned error` belongs to the intentional direct-render
failure test, not a failed sliced draw. Both final matrix logs also contain
`IOSurfaceClientSetSurfaceNotify failed e00002c7`; preserve this unresolved diagnostic.
Empty runtimeWarnings arrays do not erase full-log messages or prove their cause.

Using agent-device, root selected and verified native Settings > Multitasking & Gestures
> Full Screen Apps on the chosen iPad simulator. Evidence is preserved in
`/tmp/ehpanda-phase17-tablet-fullscreen-setting.png`. That setting alone did not resolve
the rejected orientation request; the no-op request correction above did. General Apple
scene/window adaptivity guidance: https://developer.apple.com/videos/play/wwdc2025/282/ .
No app plist, production orientation logic or fake landscape window size was introduced.

After failed XCTest engines completed, root stopped only identified matching optional
post-test simctl diagnose collectors (`--timeout=600`) that blocked Xcode finalization.
Failed results and attachments remain intact; xcodebuild finalized exit 65. The optional
diagnostic collection is partial. No active test engine was cancelled.

## Continuation gate

The requested clean/full-matrix work is now concrete and reviewable. The adopted slicing
choice is not pending approval. Task 2 still fails its feasibility criteria; stop before
bulk capture or later plans. Obtain direction for a scoped investigation/plan revision of
Downloads native parity and Reader fidelity, preserving every strict gate. Do not infer
permission to change production viewport semantics from the prior slicing approval.

## Historical evidence boundary

The sections below retain pre-adoption research and recovery evidence. Their pending
architecture, Comments failure and three-run-limit wording describe historical states;
the current-source status above supersedes them.

## Historical actual matrix result (before 73bf3e4b59)

`/tmp/ehpanda-phase17-feasibility-phone.xcresult`: three actual tests, two exporter tests
passed and one matrix test failed, zero skipped/Repetition nodes, exit 65. The summary's
runtimeWarnings array is empty; the full log contains a render-server error. The matrix
recorded Home as captured, Comments as failed, and the other fourteen phone coordinates
as pending. All sixteen tablet coordinates are unstarted. Pending is not N/A.

Candidate attachment manifest:
`/tmp/ehpanda-phase17-feasibility-phone-attachments/manifest.json`.
Matrix attachment: `38BED32C-818F-4E4F-BEEE-FA85BA59BE92.zip`.
The extracted `outcomes.json` retains every phone coordinate and its actual disposition.

The original native hierarchy strategy produced a visually blank 1260 x 8394-pixel Comments
image (displayed as black in inspection), although the ordinary viewport rendered correctly. Native viewport comparison
failed. This is evidence about this strategy/run; it does not establish that the library
lacks custom dimensions or that 8192 pixels is a framework limit.

## Three bounded default-library probes

The library's default layer strategy is exercised explicitly in a separate probe.
The matrix is not silently switched to it. It produces a long image containing the
twelve actual comment rows and VCEND, but has not passed the strict capture gate.

| Result prefix under `/tmp/ehpanda-phase17-` | Actual tests | Passed / failed | Outcome |
|---|---:|---:|---|
| `comments-library-default` | 1 | 0 / 1 | InvalidTransition; appearance messages |
| `comments-library-default-2` | 1 | 0 / 1 | Fresh output controller; same failure and appearance message |
| `comments-explicit-vision` | 4 | 3 / 1 | Home 3/3 passed; Comments still failed |

Every row has exit 65, zero skipped tests and zero Repetition nodes. Summary runtimeWarnings
arrays are empty, but appearance-transition messages in the full logs remain unresolved.
The latest build log is `comments-explicit-vision-build.log`, exit 0 with no compiler,
deprecation or lint diagnostic. This is an incremental build, not Task 2 clean integration.
Latest XCTest failure text:

```text
InvalidTransition { phase: idle targetPhase: failed(deinit) }
```

The latest default probe uses a fresh UIHostingController for the library-owned output
Window, keeping the real active-scene controller separately for viewport measurement.
The library's default Window is not represented as a foreground-active scene window.
No production screen, threshold, fixture count or output resolution was relaxed.

The attempted explicit modern Vision ImageRequestHandler did not fix this error. The
latest attachment contains the full image, its viewport crop and geometry, but no
`native-viewport-parity.json`, which is written only after strict image comparison succeeds.
The flow therefore has not reached OCR. The earlier hypothesis that Vision caused the
error is withdrawn. The source retains this unsuccessful experiment as WIP; it is not
credited as a verified fix. The exact origin of InvalidTransition remains unresolved.

Latest attachment manifest:
`/tmp/ehpanda-phase17-comments-explicit-vision-attachments/manifest.json`.
Comments attachment: `5E74E2D4-DEFE-44A7-BF80-6A8E6BF91BED.zip`.
Activities: `/tmp/ehpanda-phase17-comments-explicit-vision-activities.json`.

## Independent saved-image inspection

Offline CoreGraphics inspection normalized both saved PNGs to 8-bit premultiplied sRGB
and found 20,284 differing pixels in a 1260 x 2736-pixel viewport. Difference bounds are
x=60...1207, y=202...636. The saved normal PNG has 16-bit components / 48 bits per pixel;
the saved layer crop has 16-bit components / 64 bits per pixel. Format and lifecycle
handling are concrete next diagnostic leads, not established root causes.

Inspection source/result: `/tmp/ehpanda-phase17-compare-png.swift` and
`/tmp/ehpanda-phase17-comments-default-png-comparison.json`. This compares saved images
and does not replace the SnapshotTesting gate or its live-image comparison.
Visual inspection confirms twelve rows and VCEND; automated census, tail and restoration
acceptance remain unproven for Comments because its gate has not reached those steps.

## Preserved successes and remaining direction

The Home tracer was extracted to the committed public fixture generator without changing
its six IDs, titles, order, URLs or artwork. Three actual Home tests passed again in the
latest mixed result. The fixture exporter and current generator hashes are documented in
`17-01-PUBLIC-FIXTURES.md`. Disposable `.capture/regression` matches the current generator;
generated bytes are not staged. Existing dependency pins are unchanged, with only the exact
SnapshotTesting 1.19.6 revision added in both lockfiles; those lockfiles remain uncommitted
pending clean integration and the full gate.

No test driver or diagnostic collector remains active. Optional simulator diagnosis
collectors were terminated individually only after the test engine completed. Failed
results and exit 65 are retained. No test engine was interrupted or retry flag used.

The execute-phase skill loads execute-plan.md, whose deviation rule says:
"Fix attempt limit: max 3 retries per deviation before escalating". The three default
strategy probes have reached that bound. Task 2 also requires unresolved hosting/layout
semantics to halt for orchestrator direction. The proposed next recovery stays within
the same native SnapshotTesting APIs and exact file ownership, focuses on PNG comparison
formats and controller appearance cleanup, preserves all acceptance criteria, and allows
at most three further runs after owner direction. No stitching decision is proposed.

Do not run later waves, complete Task 2 or create a plan SUMMARY from these partial results.

## Owner-authorized recovery cycle 2

The owner selected option 1 on 2026-10-03: one further bounded native-API diagnosis
cycle, at most three runs, preserving all acceptance criteria. Existing app-hosting and
inline authorization remain valid. The first diagnosis keeps the original raw PNGs and
normalizes only comparison inputs to explicit 8-bit premultiplied sRGB, the same format
used by the library's strict comparison. This gives the library's four-byte difference
attachment reader a compatible format without reducing resolution or pixel precision.
It also records comparison completion and the caught error type, and pins the diagnostic
Comments time zone to UTC as the matrix already does. No new GREEN is inferred.

### Recovery cycle 2 results — three of three runs used

Each of the following has four actual tests: three Home tests passed, one Comments
probe failed, zero skipped/Repetition nodes and exit 65. Summary runtimeWarnings arrays
are empty; complete logs remain authoritative for render-server/appearance messages.
All three build-for-testing logs have exit 0 and no compiler/deprecation/lint diagnostic.
These are incremental builds; clean Task 2 integration and the matrix remain incomplete.

| Result prefix under `/tmp/ehpanda-phase17-` | Strategy | Concrete result |
|---|---|---|
| `recovery2-format` | Default layer, normalized strict comparison | `matched:false`; caught error is FullContentHostError.nativeViewportPixelsChanged; XCTest still reports InvalidTransition; one appearance message |
| `recovery2-native-sdr` | UIViewController key-window hierarchy, sRGB/SDR | 32-bit full/normal images; visually blank full image (displayed as black; opacity not inspected for this run) and render-server error; native pixel failure; no appearance message |
| `recovery2-swiftui-native` | Direct SwiftUI .device custom-size API, same native key window and sRGB/SDR | Fully transparent full image (alpha inspected after owner image review) and render-server error; native pixel failure; one appearance message |

Result bundles, logs, summary/tests JSON and attachment directories use each prefix above.
Each run independently records `capture-progress.json`, `native-viewport-parity.json`
with `matched:false`, and `capture-error.json` with the actual error type/description.
Only the first run uses the old test selector testCommentsDefaultLibraryStrategy; the
current selector is testCommentsNativeCapture. Candidate files are not references.

The latest attachment manifest is
`/tmp/ehpanda-phase17-recovery2-swiftui-native-attachments/manifest.json`;
Comments directory attachment `A551CA09-B88B-4F0F-9FE1-6F6D9E07AB1D.zip`.
The native viewport is still 420 x 912 points at 3x, output 420 x 2798 points / 1260 x
8394 pixels, measured content height 2590 points and stableIterations 2. No OCR/census
or restoration success is inferred after comparison fails.

Offline CoreGraphics inspection of the latest PNG records zero nonblack pixels, 32 bits
per pixel and eight bits per component in
`/tmp/ehpanda-phase17-recovery2-swiftui-native-pixels.json`. Its inspection source is
`/tmp/ehpanda-phase17-black-png-inspection.swift`. That inspection tested RGB only.
Subsequent alpha inspection confirms every pixel in the latest 1260 x 8394 full PNG is
fully transparent (alpha zero); the earlier black-image description is corrected.
See `17-01-UPSTREAM-RENDERING-RESEARCH.md` and
`/tmp/ehpanda-phase17-recovery2-swiftui-native-alpha.json`. This does not establish an
8192-pixel framework limit or that custom dimensions are unsupported.

Comparison-input normalization did not resolve parity failure: both library inputs
now use the same explicit 8-bit premultiplied sRGB format and strict comparison returns
false. This does not identify the capture rendering root cause. The first run catches
the correct FullContentHostError before it leaves the
capture operation. Reporting that actual failure through XCTFail, as the matrix already
does, avoids the unrelated InvalidTransition reporting in the last two runs. The exact
origin of that secondary error remains unproven and is not credited as a framework fix.
The direct UIViewController key-window path has clean appearance logging; the direct
SwiftUI wrapper still reports an imbalance. Neither strategy passes Comments capture.

The diagnostic Comments probe now freezes the global/SwiftUI UTC time zone. Its sRGB/SDR
and direct SwiftUI options are explicit opt-in diagnostics; the actual matrix and default
Home path have not been silently switched to failed candidates. Library checkout sources
remain untouched. The source and evidence remain WIP, with strict failures visible.

### Historical proposed decision — output scale (withdrawn)

Recovery cycle 2 is exhausted. The owner-approved scope preserved native 3x output.
The concrete next proposal is to separate measured device viewport/scale from capture
output scale and test the library at an explicit 1x first, using the same 420-point width,
actual view/Store, typography, safe areas, content and 420 x 912 logical viewport.
The Comments bitmap would be 420 x 2798 pixels. Capture scale must be recorded separately
from the native device's measured 3x; a rendering override must not be reported as native
hardware geometry. Ordinary/full images must use the same configured output scale and
still require a 100% pixel match, complete census/tail, convergence and restored native
geometry. No fixture count reduction, production-view replacement or stitching is proposed.

This changes the currently accepted output resolution and therefore requires an explicit
owner decision before implementation or further native runs. A 1x probe is a testable
hypothesis about raster size, not a promised remedy. If approved, amend the plan's capture
scale contract and run at most three bounded probes before any matrix expansion. If not,
hold the incomplete task at its current 3x gate. No SUMMARY or completion counter changes.

## Owner-requested upstream research

`17-01-UPSTREAM-RENDERING-RESEARCH.md` records official transparent glass/toolbar reports,
maintainer guidance, a current iOS 27 scene/safe-area report and supported custom-size
scroll capture. The latest saved full image is now confirmed fully transparent, not
opaque black. Our native app host, scene-backed window and explicit hierarchy flag already
meet the principal posted remedy. No identical long-image failure or proven resolution
limit was established. Research is complete; no native run or approved scale revision
is added, and the incomplete gate/checkpoint remain in force.
