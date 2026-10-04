---
status: checkpoint-half-pixel-artwork-extent
trigger: Phase 17-02 v3 fixture compatibility gate
created: 2026-10-05
updated: 2026-10-05
execution: inline
---

# iPhone AX5 compact artwork pixel extent

Current question: how to derive a 1:1 source image size when the production compact
cover height is 337.5 device pixels and identical role dimensions produce 337- and
338-pixel displayed extents at different row positions. The source/capture interior
comparison rules out a mere one-row error in the colored-boundary measurement, but
does not identify the internal renderer mechanism. No further native probe or change
to production layout has been attempted.

## Coordinate artwork / half-pixel extent checkpoint — 2026-10-05

The supplied seam-artwork research exactly reproduces the 120-pixel iPad Downloads
failure and demonstrates stable 1:1 artwork at 2x. The orchestrator adopted A in the
fixture/test scope. PublicVisualFixtures v3 accepts per-image integral pixel sizes;
FixtureArtwork uses production cover roles and the headline metric. Both actual
capture consumers export per coordinate and compare source PNG dimensions with
pixel-derived artwork frames. Canonical inputs remain validated; derivative exports
retain their own manifest, source aggregate and sizing/measurement records. The
Reader guard now checks both dimensions. No production view or strict seam rule changed.

RED: `/tmp/ehpanda-phase17-artwork-red-01/`, missing export API.
Focused GREEN: `/tmp/ehpanda-phase17-artwork-green-01/`, seven actual passes: three
export/metric tests on each family plus iPad portrait AX5 Downloads. All twelve
categories match SwiftUI GalleryCoverMetrics. Downloads remains 834 x 5196 pt with
three unchanged reads; sixteen covers measure exactly 218 x 300 px, census 16/16,
and native parity and seams pass. Zero build diagnostics or runtime warnings; source
hashes unchanged and devices restored. Independent record: artwork-audit.json.
Python contracts pass 30 + 28 = 58; strict no-cache SwiftLint passes changed Swift files.

Compatibility: `/tmp/ehpanda-phase17-artwork-gate-01/` stops at iPhone portrait AX5
Home. Phone native tests pass 37/37; the Large portrait invocation passes all four
coordinates. The AX5 invocation produces all four images but fails two new size
assertions on Home. Gate-accepted matrix rows are therefore 4/32; independent artifact
inspection finds seven of the eight produced coordinates pass all checks, one fails,
and twenty-four remain unexecuted. Native totals: 41 passed / one failed / no skips,
repetitions or runtime warnings. Both builds have zero diagnostics; sources unchanged.
Phone restored portrait/Large/Shutdown; this compatibility run never used the iPad.
No diagnostic process was interrupted and no native job remains.

Home's compact role is 81.818181... x 112.5 pt at AX5. At 3x the nominal height is
337.5 px; all three sources are rounded to 245 x 338 px. Measured frames:

| Item | Pixel origin | Exported size | Measured size |
|---|---|---|---|
| VH4 | 60,4179 | 245 x 338 | 245 x 337 |
| VH5 | 60,5070 | 245 x 338 | 245 x 338 |
| VH6 | 60,5962 | 245 x 338 | 245 x 337 |

Strict native/frozen/full viewport parity, seams and census still pass for this Home
capture (1260 x 7986 px). Direct center-column inspection finds sharp colored-to-white
edges without an extra faint row. An offline source-versus-capture interior comparison
(excluding a 20 px border for diagnosis only) finds VH5 exact across 61,090 pixels;
VH4/VH6 differ at 1,461/1,545 of 60,885 pixels, max channel delta 134. A one-row source
shift is not exact either. This is more than a flood-fill bounding-box discrepancy;
rounding the common role size does not preserve source pixels at every row position.
The internal rasterization mechanism and correct export contract remain unresolved.
No capture acceptance exclusion or tolerance was added.

Short evidence: `/tmp/ehpanda-phase17-artwork-rounding/`, including original capture,
fixtures, edge-analysis.json, source-interior-comparison.json and research-prompt.txt.
The full run's partial-artwork-audit.json distinguishes produced images from accepted
coordinates. The original 2x research has not established the 3x half-height case.
B (all reads native viewport height) was separately presented to the owner and has no
answer yet; it remains unapplied. Task 2 and the full 576 matrix remain incomplete.

Canonical v3 output is `.capture/regression-v3` (47 assets plus manifest), copied
byte-for-byte from the successful phone native export attachment. Its aggregate is
`a0a579a9633aca7fbdf10bd034e10c559b63f595d58cdd83655cd1bf15ab127a`; unchanged default
asset bytes do not imply unchanged version or generator. Generator SHA-256 is
`2013618b4ba572eeb1d9d5b2fa1960d1caa4c9e85b55ec1f2b09e68272065e09`. The prior v2
`.capture/regression` is preserved. No baseline promotion or Task 2 source commit.
