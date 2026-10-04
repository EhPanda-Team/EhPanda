---
phase: 17-localized-screenshot-capture-harness
plan: "01"
subsystem: testing
tags: [swift, snapshot-testing, native-rendering, vision, fixtures]
requires:
  - phase: 16-dynamic-type-accessibility
    provides: Native OS 27 views and accessibility layout contracts
provides:
  - Genuine app-hosted SnapshotTesting integration with offline dependency bootstrap
  - Full-content native capture verified on all 32 feasibility coordinates
  - Repeatable public fixture v2 materialization with source and asset provenance
affects: [17-24, 17-02, visual-regression, marketing-capture]
actuals:
  tokens: 56995
  tasks: 2
  commits: 39
tech-stack:
  added: [SnapshotTesting 1.19.6]
  patterns: [stationary render-server slices, native viewport sampling freeze, two-scale OCR census]
key-files:
  created:
    - AppPackage/Sources/VisualSnapshotSupport/FullContentHost.swift
    - AppPackage/Sources/VisualSnapshotSupport/RenderServerCapture.swift
    - AppPackage/Sources/VisualSnapshotSupport/RenderedContentInspection.swift
    - AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift
    - AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift
    - AppPackage/Tests/VisualSnapshotTests/RenderedContentInspectionTests.swift
    - Scripts/verify-full-content-capture.py
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan
    - EhPanda.xcodeproj/project.pbxproj
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Sources/AppComponents/GalleryViewport.swift
    - AppPackage/Sources/HomeFeature/HomeView.swift
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - .swiftlint.yml
key-decisions:
  - Use the actual app-hosted XCTest target, with isolated offline dependencies prepared before app state.
  - Read one stationary full-content layout in bounded render-server slices and prove exact overlapping pixels.
  - Freeze each view's native viewport measurement through an existing observable object; preserve native size classes.
  - Rotate simulators externally and use system Dynamic Type as the app's single category source.
  - Keep exact-once counting and make OCR robust through overlapping reads at two scales and location-based merging.
  - Keep generated fixture outputs separate from approved image baselines.
patterns-established:
  - Sequential real-device-family gates reject empty, skipped, repeated or failed test runs and source drift.
  - Canonical sRGB pixel storage is shared by composite output and rendered-content inspection.
  - Named XCTest attachments carry repeatable fixtures and structured capture evidence to host tooling.
requirements-completed: [CAP-17-02, CAP-17-03, CAP-17-06]
coverage:
  - id: D1
    description: Genuine app-hosted capture preserves native viewport pixels and captures all finite content on 32 coordinates.
    requirement: CAP-17-02
    verification:
      - kind: integration
        ref: Scripts/verify-full-content-capture.py; final-tree gate at 9b7074d2, 32/32 coordinates and 66/66 tests
        status: pass
    human_judgment: false
  - id: D2
    description: Missing or duplicated rendered markers remain detectable after two-scale OCR merging.
    requirement: CAP-17-03
    verification:
      - kind: integration
        ref: AppPackage/Tests/VisualSnapshotTests/RenderedContentInspectionTests.swift; all 11 tests on both families
        status: pass
    human_judgment: false
  - id: D3
    description: Public fixture v2 exports repeatable complete bytes with validated source and asset provenance.
    verification:
      - kind: integration
        ref: FullContentFeasibilityTests/testExportPublicFixtures and missing-fixture/asset/route rejection; 41 independently audited exports
        status: pass
    human_judgment: false
duration: multi-session
completed: 2026-10-04
status: complete
source_head: 9b7074d2
---

# Phase 17 Plan 01: Native full-content capture and public fixtures Summary

**Actual Home, Comments, Downloads and Reader views pass all 32 phone/tablet feasibility coordinates with exact native viewport parity and a complete rendered-item census.**

## Performance

- Started: 2026-10-02T17:16:59+09:00 (first plan implementation commit).
- Completed: 2026-10-04T09:14:37.429479+00:00.
- Duration: multi-session; roughly 49 hours of wall span, not an active-work estimate.
- Tasks: 2/2. Implementation/configuration files changed: 27.
- Actuals: 56,995 characters/4 diff units over the plan-owned implementation/configuration paths from `b7fc0c7e^` through `9b7074d2`; 39 implementation and checkpoint commits in that interval. These are not model usage tokens, and exclude the closing documentation commits.

## Accomplishments

- Registered genuine app-hosted VisualSnapshotTests with early offline bootstrap. SnapshotTesting is pinned exactly to 1.19.6; the support product and library are test dependencies, with both package lockfiles recorded.
- Captured four real content shapes across two families, two orientations and Large/AX5. Native/frozen/full viewport comparisons are exact; all expected items occur once, artwork retains its intended size and ratio, trailing content is complete, and geometry is restored.
- Exported fixture v2 deterministically. All 41 current-run exports pass independent 47-entry hash/size/provenance checks. The canonical export now occupies `.capture/regression`; the previous directory is backed up in the evidence root.

## Task Commits

Task 1: `b7fc0c7e` bootstrap RED, `7a9616d4` bootstrap integration, `09307e9e` Home census RED, `2ff07f8f` native Home GREEN. `bce7f714` retains genuine-host registration and intermediate feasibility work.

Task 2: `c9e7432e` exporter RED, `a51f8f81` deterministic exporter, `b9a768a5` fixture extraction. Subsequent owner-adopted revisions include:

- `e9e183f6`, `cee1504a`, `aefc47df`: stationary native slices, canonical pixels, package pins and viewport parity.
- `723a117f`: Reader pages exported at native rendered pixel size.
- `8f84844b`: stable observation-based viewport freeze for Home and GalleryList.
- `040064f2`: validated composite area budget and shared canonical storage.
- `f7c3d2e0`: simulator lifecycle, external rotation and native size classes.
- `e8cd9abf`: fixture v2 distinct non-census carousel neighbors.
- `e56771df`: device-level Dynamic Type before each app invocation.
- `eb0a6a7e`, `9655f561`, `9b7074d2`: scale-robust OCR census, extraction and owner-approved array-literal lint correction.

Intermediate WIP/checkpoint commits remain in history; no commit was amended or pushed.

## Verification

Final implementation HEAD `9b7074d2`: `/tmp/ehpanda-phase17-census-final-gate-01/`. The run retains the four preexisting owner-staged entries, including the project file; source-hashes.json is the exact tested working-tree record. A clean build is verified here; clean-checkout/Release acceptance belongs to 17-14.

```sh
DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer \
python3 -B Scripts/verify-full-content-capture.py \
  --phone "$PHONE_UDID" --tablet "$TABLET_UDID" \
  --output /tmp/ehpanda-phase17-census-final-gate-01 \
  --derived-data "$HOME/Library/Developer/Xcode/DerivedData/EhPanda-bjhqwuemjjedwrfnzlznzjvcttjq"
```

Resolve fresh destination IDs; another invocation needs a new output directory. The actual run used iPhone Air and iPad Pro 11-inch (M5), iOS 27.0 build 24A434. Clean FeatureTests and rotation builds have no compiler/lint diagnostics. All 66 tests across 17 invocations pass: native 27 phone/24 tablet, eight matrix methods, one focused AX5 Comments case and six rotation/restore methods. There are no failed/skipped/expected-failure tests, Repetition nodes or runtimeWarnings.

`gate.json`, `matrix-outcomes.json` and `independent-audit.json` establish 32/32 captures and unchanged source hashes. Each Home/Comments/Downloads/Reader census has respectively 6/12/16/8 items exactly once. All native/freeze parity, size-class, content-size and diagnostic-read-index checks pass. The Vision canvas test still counts blanked VC5 as zero and duplicated VC3 as two.

Phone AX5 Comments converges to 420 × 15,663 pt, 1260 × 46,989 px, seven slices. Phone landscape Reader is 2736 × 30,096 px with 1:1 artwork. Both-device tests pin the 89,653,248-pixel allocation budget and reject the next row; per-read height remains 8191 native pixels. Census reuse and PNG encoding add no measured footprint after composition. All simulator content sizes and session ownership states are restored; both finish in portrait. No process interruption was needed.

Fixture aggregate: `a0a579a9633aca7fbdf10bd034e10c559b63f595d58cdd83655cd1bf15ab127a`.
Generator SHA-256: `0af2e25968224950331b597bbf0ea995c52a9d00acf07d98c78fb88b325867b3`.
`fixture-verification.json` checks every export; `fixture-materialization.json` identifies the copied named attachment, 48 files and previous-materialization backup. The four reserved staged entries remain byte-identical to their saved patch.

Inline review is recorded in `17-01-FEASIBILITY-REVIEW.md`; no new finding remains in the adopted census change. This is not independent or whole-phase review, and no image is an approved baseline.

## Decisions and Plan Revisions

The approved plan was amended through explicit owner direction and research handoffs, recorded chronologically in `17-01-PLAN.md`. The final architecture preserves actual production views while separating visible viewport inputs from the enlarged capture extent. A stable observation object avoids toolbar changes caused by replacing an environment value. Native size classes remain fixed to the original scene, while system Dynamic Type is selected externally before launch.

The render server's native-size ceiling required stationary reads of one committed hierarchy. An area budget replaced the unsupported height-only guard and canonical shared bytes removed redundant buffers. Reader fixture images match actual rendered pixel sizes. Distinct carousel neighbors remove native duplicate census markers without weakening the census. Two-scale overlapping OCR reads address small text and clipped-window ambiguity; merge conflicts fail explicitly, and raw reads survive failures.

These are owner-adopted revisions, not silent acceptance waivers. Historical failures and superseded assumptions remain in the gate/research documents with their original evidence.

## Issues Encountered

The original unhosted setup, offline initialization order, transparent over-limit hierarchy capture, viewport-dependent layout, native toolbar glyph changes, rotation persistence, carousel self-replication and OCR ownership/scale errors each blocked the gate until resolved. Their latest full-source integration now passes. Physical-device render ceilings and whole-phase snapshot/baseline/marketing acceptance remain outside this feasibility plan.

## User Setup Required

None for this completed feasibility plan. Final marketing gallery selection and baseline approval remain later phase checkpoints already recorded in the approved plans.

## Next Plan Readiness

Ready for **17-24**, then 17-02. The immutable rendering pin must be based on new real geometry measurements before matrix-runner production. Phase progress is 1/24 plans; shared CAP-17-02, CAP-17-03 and CAP-17-06 remain incomplete in REQUIREMENTS.md until every declaring plan finishes. The required frontmatter IDs identify this plan's contributions, not whole-phase completion.
