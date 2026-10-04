---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: v3-source-content-verified-landscape-seam-pending
recorded: 2026-10-05
---

# Deterministic public fixture export

## Current v3 coordinate artwork revision (verification in progress)

Phase 17-02 extends the reader sizing contract to all displayed cover roles. The
exporter accepts `artworkPixelSizes`, keyed by existing image asset path. Sizes must
be positive, finite whole pixels; unknown paths and invalid sizes fail before any
file is written. Unspecified artwork retains the canonical dimensions. Fixture
version is `phase17-finite-v3`; schema 1 and the 47-entry inventory are unchanged.

The native test consumers derive Home hero/standard/compact and Downloads standard
cover dimensions from `GalleryCoverStyle` and the headline scaled metric. Production
and fixtures now share height-first pixel rounding at the coordinate's display scale.
The two carousel neighbors use hero dimensions;
they remain outside the census because their native visibility is intentionally
partial. Reader pages use the full scene pixel width. Reader controls are hidden in
these scenarios, so previews are not displayed. A post-capture check compares both
measured artwork dimensions to the actual exported PNG dimensions. An unexpected
carousel clamp or size mismatch is a failed test, not an exception to strict parity.

Each coordinate retains its own generated fixtures and manifest, plus
`artwork-sizing.json` and `artwork-verification.json`. The 576-coordinate runner still
validates the supplied canonical manifest and reads its metadata before deriving
coordinate artwork; the sizing record links that input aggregate to the derived
aggregate. Historical `.capture/regression` v2 output is preserved; the next canonical
export belongs in `.capture/regression-v3`. The canonical export is verified; full coordinate-sized artwork compatibility remains
unaccepted, and no result is an approved baseline.

Research: `/tmp/ehpanda-phase17-size-probe-evidence/seam-artwork/RESULTS.md`.
RED evidence: `/tmp/ehpanda-phase17-artwork-red-01/` (the missing per-image export API).
Focused verification passed in `/tmp/ehpanda-phase17-artwork-green-01/`: three tests
per family, covering every requested asset size, invalid sizes/paths and production
metrics at all twelve categories, plus the actual iPad portrait AX5 Downloads capture.
All seven tests passed without skips, repetitions or runtime warnings; the build had
zero diagnostics. Source hashes remained unchanged. `artwork-audit.json` records the
independent audit. Downloads retains its 834 x 5196 pt output and three original read
rectangles, with exact native parity, all sixteen census counts equal to one, and
sixteen exported/measured cover dimensions of 218 x 300 pixels. Both simulator states
were restored. The 32-coordinate compatibility run
`/tmp/ehpanda-phase17-artwork-gate-01/` stopped at iPhone portrait AX5 Home: two compact
covers export at 245 x 338 px but display at 245 x 337, while the third displays at
245 x 338. Its native parity, seams and census pass, but the new size assertion fails.
The subsequent production-sizing correction resolves these dimensions; see the
current content-verification checkpoint below and `17-02-INTEGRATION-NOTES.md`.
This v3 revision is not fully accepted. The successful
native canonical export was materialized in `.capture/regression-v3`; the old v2
output is preserved.

### Current content-verification checkpoint

Shared production pixel sizing and production-path-derived corner extents are
implemented. Source comparison excludes four 16 px / 23 px corner squares at
2x / 3x, where the continuous curve lies, and compares every other byte. Focused
verification passes 15/15, including original AX5 Home; a one-pixel interior shift
still fails. The full gate verifies 186 images (273,497,908 pixels), including the
original iPad AX5 portrait Downloads. It stops on a different read-to-read seam
failure: four one-level VD15 corner differences in iPad landscape AX5 Downloads.
The source mask does not apply to strict seam checks. See 17-02-INTEGRATION-NOTES.md
and /tmp/ehpanda-phase17-ipad-landscape-seam/. Compatibility remains incomplete;
no baseline is promoted.

## Historical v2 carousel fixture revision

Generator: `AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift`.
Schema remains 1; fixture version is now **phase17-finite-v2**. The six census galleries
VH1–VH6 remain unchanged. Separate homeCarouselNeighbors adds PEEK1/PEEK2, whose titles
have the same shape as VH1 and whose page counts remain 24. The Home fixture centers VH1
between these distinct native carousel peeks. Neighbor markers are disjoint from expected
markers, and the fixture asserts at least three popular galleries.

The neighbors are deliberately outside the exact-once census because their visibility is
partial and device-dependent. No production carousel, rendering or census code changes.
Both 160 × 220 covers join the export loop and home-finite scenario assets. Home metadata
includes the original six galleries followed by the two neighbors. Both default and
requested-reader-width export tests check the neighbor cover dimensions.

This changes metadata, scenario and artwork bytes. Earlier v1 digests below are historical.
Evidence: `/tmp/ehpanda-phase17-carousel-v2-gate-01/`. All three exporter tests pass within
the 16/16 native test run. The default export contains 47 entries; the repeatability test
compares complete manifest bytes and aggregate digests from two fresh exports. Extracted
exports independently pass file-size, SHA-256, generator-provenance and neighbor-cover-size
checks, recorded in fixture-verification.json at the run root.

Default v2 aggregate:
`a0a579a9633aca7fbdf10bd034e10c559b63f595d58cdd83655cd1bf15ab127a`.
Generator SHA-256:
`0af2e25968224950331b597bbf0ea995c52a9d00acf07d98c78fb88b325867b3`.

The final-source run is `/tmp/ehpanda-phase17-census-final-gate-01/` at f12ecb8333.
All 32 coordinates pass under matching requested/app/scene Dynamic Type. Both native suites
include the three exporter tests; 41 extracted exports independently pass all 47-entry
byte-count, file hash, aggregate and generator-provenance checks. Every Home keeps the six
expected markers exactly once; the two native carousel neighbors remain outside the census.

After that gate passed, the canonical 800 × 1100 Reader export from the phone's named
`testExportPublicFixtures` attachment was copied byte-for-byte into `.capture/regression`.
The materialization contains 48 files including manifest.json. Its default v2 aggregate
and generator hash are those recorded above. The older directory is retained under the
final evidence root's `previous-regression/`; fixture-materialization.json identifies the
exact source attachment and manifest hash. Other capture outputs were not altered.
`.capture/regression` remains disposable; the committed generator is authoritative.
No output is an approved baseline.

## Historical v1 exporter evidence

The previous generator used schema 1, fixture version phase17-finite-v1.
The catalog retains six Home covers, sixteen download covers, twelve comments, eight
reader pages/previews, fixed recognition groups, metadata and four named replay routes.
It is the source of truth; .capture/regression remains disposable materialized output.

## Coordinate-specific reader page rendering

8e2122c92b adds export(to:scenarios:readerPagePixelWidth:). Nil retains the canonical
800 x 1100 reader PNGs. A supplied width renders 8:11 pages with height rounded to whole
pixels. Covers and previews remain 160 x 220. Fixture IDs/version, metadata/route shape
and eight-page count are unchanged; the manifest has no image-dimension fields.

The vertical reader ignores safe areas, so the harness uses actual scene width x native
screen scale after setOrientation. Each matrix coordinate exports into its own fresh
fixtures directory, preventing reuse of cached bytes from a previous size/orientation.
The capture asserts measured artwork width x scale equals the exported pixel width.
Existing 8:11 checks retain the two-pixel rounding allowance; no aspect change is approved.

Measured pages: phone 1260 x 1733 px; tablet 1668 x 2294 px. This removes the observed
resampling-dependent glyph-edge differences between clipped viewport and tall captures.
The owner rejected 2:3 because eight phone-landscape pages alone exceed the composite
budget (32832 px); retained 8:11 totals 30096 px before host overhead. Landscape output
and budget remain unverified until the actual scene rotates.

## Verified digests and provenance

All exports have 45 asset entries with independently checked byte counts and SHA-256.
Default export aggregate remains:
`ee48f8faf6b828a2068f4790f30623341d78fe8e4a9d5d60938f154dc975a547`.
Coordinate-specific reader exports change the eight reader PNGs and aggregate:

| Export | Reader PNG size | Aggregate digest |
|---|---|---|
| Default | 800 x 1100 | ee48f8faf6b828a2068f4790f30623341d78fe8e4a9d5d60938f154dc975a547 |
| Phone portrait | 1260 x 1733 | 3f29b9c5a72c2aa10f33964939ddb7030b5b9802d164fe3e3a4a986ab4b98d74 |
| Tablet portrait | 1668 x 2294 | 86f5abdd99ccef9e8e5d3a6bde73ed4cc4127a994a7abe54aa570eb86347fc09 |

Current generator source SHA-256: `5c7e4901568b478dbba633b7152226a080ff122a9134f62e1642193406295b25`.
The supplied earlier matrix/default-export manifests record `26da899c6796b56bd4e54e828d1c218c1b8c46a6bceaa461cb91d5b209feb3a5`;
the current phone Reader attachment records the current hash. Default asset bytes and
aggregate are unchanged, while complete manifest bytes necessarily reflect updated
generator provenance. Do not equate an unchanged asset aggregate with unchanged source
provenance or an identical complete manifest across source revisions.

Current phone Reader attachment and inspected tree:
`/tmp/ehpanda-phase17-root-parity-review-hdb3wjhq/current-reader/`.
Earlier/default tablet export extracted under
`/tmp/ehpanda-phase17-root-parity-tablet-evidence/`.
Both supplied matrix reader export entries were checked independently after extraction.

## Test evidence and completion boundary

Current parity-tablet.xcresult has nine actual passes, zero failures/skips/Repetition,
including testExportPublicFixtures, testExportRejectsMissingFixtureAssetAndRoute and
new testExportRendersReaderPagesAtRequestedPixelWidth. The last test verifies all eight
1260 x 1733 pages, canonical 800 x 1100 pages and unchanged cover/preview dimensions.
Current parity-phone.xcresult has two actual passes: requested-width export and Reader.
The handoff's earlier 12/12 phone report is distinct from that current two-test bundle.
Paths under `/tmp/ehpanda-phase17-`; detailed counts/provenance in the feasibility gate.

The repeatability test compares two fresh exports at the same source revision and checks
all entry hashes. Unknown fixtures/assets/routes are rejected before output creation;
nonempty destinations remain rejected. Historical RED: 17-01-PUBLIC-EXPORT-RED.json,
1902bfd987. Earlier independent GREEN: public-export-green.xcresult, two passes, 45 entries,
aggregate fea2e358249a04ed6eab8ee553640d264ce41cb374cf636b36f117601f8c8a59;
it predates the visible comment markers and is historical. No historical source digest
is represented as current.

Both package pins were committed in 9906f9a619 after the earlier clean integration. New
parity builds are incremental with zero diagnostics; current-source clean/full-matrix
acceptance is not complete. Current matrices capture 12/32 and stop at AX5 Home viewport
layout / iPad landscape rotation. No fixture output or screenshot is an approved baseline.
