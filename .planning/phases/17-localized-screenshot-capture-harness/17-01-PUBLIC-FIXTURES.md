---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: exporter-passed-partial-matrix
recorded: 2026-10-04
source_head: 723a117fd2193e30bdeffff737708d50fd7f0112
---

# Deterministic public fixture export

Committed generator: `AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift`. Schema 1, fixture version phase17-finite-v1.
The catalog retains six Home covers, sixteen download covers, twelve comments, eight
reader pages/previews, fixed recognition groups, metadata and four named replay routes.
It is the source of truth; .capture/regression remains disposable materialized output.

## Coordinate-specific reader page rendering

723a117f adds export(to:scenarios:readerPagePixelWidth:). Nil retains the canonical
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
c9e7432e. Earlier independent GREEN: public-export-green.xcresult, two passes, 45 entries,
aggregate fea2e358249a04ed6eab8ee553640d264ce41cb374cf636b36f117601f8c8a59;
it predates the visible comment markers and is historical. No historical source digest
is represented as current.

Both package pins were committed in cee1504a after the earlier clean integration. New
parity builds are incremental with zero diagnostics; current-source clean/full-matrix
acceptance is not complete. Current matrices capture 12/32 and stop at AX5 Home viewport
layout / iPad landscape rotation. No fixture output or screenshot is an approved baseline.
