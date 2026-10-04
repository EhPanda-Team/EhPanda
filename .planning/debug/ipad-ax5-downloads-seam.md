---
status: resolved-with-follow-up-artwork-extent
trigger: Phase 17-02 native-first compatibility gate
created: 2026-10-05
updated: 2026-10-05
execution: inline
---

# iPad AX5 Downloads aligned-read seam

## Current Focus

hypothesis: Read rectangle size or origin still changes sampled artwork bytes despite 16-pixel origin alignment.
test: Offline comparison of the two saved raw PNG reads and their explicit seam rectangles.
expecting: Establish whether the failure violates the adopted geometry rules or demonstrates their fidelity limit.
next_action: Resolve byte fidelity for aligned reads of scaled fixture artwork before resuming the compatibility gate.
goal: diagnose_only

## Evidence

- Gate: `/tmp/ehpanda-phase17-read-geometry-gate-02/`.
- Device: pinned iPad Pro 11-inch (M5), iOS 27.0 / 24A434, 2x, portrait, AX5, light, English.
- Coordinate: `ipad-portrait-AX5-downloads`; error: `seamMismatch(sliceIndex: 1)`.
- Native viewport: 834 x 1210 pt. Converged output: 834 x 5196 pt (1668 x 10392 px).
- Requested heights: 4235, 5520, 5196, 5196, 5196 pt; two stable iterations.
- Native/frozen equivalence passed. Rendering fails before a composite is returned, so this coordinate has no final native/full parity or OCR census result.
- Read 1: `(0,1016,834,4095)` pt; ownership `(0,1210,834,3837)` pt.
- Read 2: `(0,4912,834,284)` pt; ownership `(0,5047,834,149)` pt.
- Compared band: `(0,4983,834,64)` pt; 1668 x 128 px.
- Both origins are multiples of 16 device pixels: 2032 and 9824 px. Both reads stay below 8191 px height.
- Band context: upper read 3967 pt above / 64 pt below; lower read 71 pt above / 149 pt below.
- Decoded raw PNG comparison: 120 differing pixels / 250 channels in the seam, maximum absolute channel delta 1. Both PNGs are RGB with no embedded ICC profile; alpha after RGBA conversion is 255 throughout.
- Difference bounds in view pixels: x [113,216), y [9994,10025). Visual inspection locates them inside the baked VD16 cover marker, not a toolbar/material region. Source artwork is 160 x 220 px; the displayed cover is enlarged.
- Full shared read range [4912,5111) pt has 469 differing pixels, all with maximum delta 1 and bounds x [112,265), y [9905,10025), within that artwork.
- Short evidence directory: `/tmp/ehpanda-phase17-read-geometry-seam-failure/` contains both original PNGs, geometry, failure/freeze records and `difference.json` with example pixels.

## What is established

The implemented geometry satisfies the proposed origin-grid and interior-band rules.
Those rules are therefore insufficient for byte equality on all actual fixture content.
The strict seam check rejected the capture as intended. No tolerance, pixel exclusion,
fallback or fixture modification was introduced. Read-size-dependent sampling is a
hypothesis supported by earlier probes, not independently proven for this coordinate.
No alternate geometry or repeated native probe has been run for this new failure.

## Verification boundary

The original dark xSmall Home failure is fixed: both themes pass strict native/frozen/
grown parity and census, and offline comparison confirms every viewport RGBA byte.
Focused geometry/device tests pass 7/7 per family; Python contracts pass 58/58.

Compatibility gate 02 has 22 captured coordinates, one executed capture failure and
nine unexecuted coordinates. Its summaries contain 76 passed native tests / one failed,
zero runtime warnings; partial-audit.json records these counts. Both simulators restored
portrait, original content size and original boot state. No native jobs remain.
The full 576 tracer was not started. Task 2 and its SUMMARY remain incomplete.

## Resolution and follow-up — 2026-10-05

Supplied seam-artwork research reproduces the failure and shows the read-dependent
bitmap resampling state. Coordinate-specific 218 x 300 artwork fixes the original
actual iPad AX5 Downloads capture with identical geometry and strict parity/census.
Evidence: `/tmp/ehpanda-phase17-artwork-green-01/artwork-audit.json`.
The generalized rounded-size export encounters a new 3x half-pixel-height problem
on Home, recorded in `iphone-ax5-artwork-extent.md`. The old seam is resolved at its
original coordinate; this does not establish full compatibility of proposal A.
