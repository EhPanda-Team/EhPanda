---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: failed-awaiting-scale-direction
recorded: 2026-10-03
---

# Task 2 actual-content feasibility gate

Task 1 remains complete. Task 2 is incomplete; zero of 24 plans are complete.
The deterministic exporter passed its two tests, but actual full-content capture stopped
at phone portrait/large Comments. No SUMMARY, bulk recording or baseline approval exists.
The root executes inline under existing owner authorization; no new executor ran.

## Actual matrix result

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
current selector is testCommentsNativeLibraryStrategy. Candidate files are not references.

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

### Proposed next decision — output scale

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
