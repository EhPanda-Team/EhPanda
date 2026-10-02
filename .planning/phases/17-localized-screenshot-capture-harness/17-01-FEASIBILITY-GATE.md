---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: failed-awaiting-recovery-direction
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

The original native hierarchy strategy produced an all-black 1260 x 8394-pixel Comments
image, although the ordinary viewport rendered correctly. Native viewport comparison
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
