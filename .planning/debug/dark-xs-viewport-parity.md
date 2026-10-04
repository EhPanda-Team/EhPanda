---
status: awaiting-capture-design-resolution
trigger: Phase 17-02 full tracer matrix dark xSmall parity failure
created: 2026-10-04
updated: 2026-10-04
execution: inline
---

# Dark xSmall native viewport parity

## Current Focus

hypothesis: The replicant read rectangle height changes rounding independently of the stationary hierarchy.
test: On the same tall hierarchy, compare viewport-sized, integral-point-height and full-height read rectangles; then restore the native window and capture again.
expecting: A viewport-sized or integral-point-height read matching native isolates read geometry; a restored native match establishes reversibility.
next_action: Resolve read-size-dependent pixel fidelity; source restored and no jobs remain.
goal: diagnose_only

## Symptoms

- Expected: Native and grown-window viewport images are byte-identical in canonical sRGB RGBA.
- Actual: `home-populated__en__xSmall__portrait__iphone__dark` fails; the immediately preceding light coordinate passed.
- Primary saved error: `FullContentHostError.nativeViewportPixelsChanged` in capture-error.json.
- XCTest also reports `InvalidTransition idle -> failed(deinit)`; its relation to error unwinding is unproven.
- Native/frozen parity passes. The source tree has no Swift changes since Task 1 GREEN.

## Evidence

- `.capture/tracer-matrix-02/`: one capture accepted, 575 failed/not executed with explicit reasons; all 576 outcomes retained.
- Four native environment geometries passed. Phone category and boot state restored after failure.
- `/tmp/ehpanda-phase17-dark-xs-parity/difference.json`: only pixel (1101,232), R 31 -> 32; G/B/A unchanged. All other viewport pixels match.
- Output 1260 x 4039 px, one render slice, three equal requested heights, two stable layout iterations.
- The native reference settled for 649 ms after 23 samples; frozen reference is byte-identical. OCR was never reached.

## Eliminated

- Slice seam duplication: the failed capture has one slice.
- Native viewport freeze changing layout: the frozen image is byte-identical to native.
- Localized OCR acceptance: failure occurs before any OCR requests.

## Resolution

root_cause: Read rectangle height changes one pixel through the replicant/drawHierarchy path; internal mechanism unproven.
fix: none
verification: Two diagnostic invocations reproduce the stable difference; viewport-height read and restored native window match exactly.
files_changed: Both temporary FullContentHost variants are restored byte-for-byte; no capture fix applied.

- First diagnostic: twenty reads over 196–3934 ms all reproduce the identical single-pixel mismatch, and all grown images are mutually byte-identical. This refutes a short render-settling delay for that invocation. FullContentHost was restored before the next diagnostic. Evidence: `/tmp/ehpanda-phase17-dark-xs-stability-probe/pixel-analysis.json`.

- Second diagnostic: viewport-height 912 pt read from the tall hierarchy matches native exactly; integral 1346 pt and full 1346.333 pt reads both differ at the original one pixel. Restored native window also matches. Evidence: `/tmp/ehpanda-phase17-dark-xs-rect-probe/pixel-analysis.json`.
