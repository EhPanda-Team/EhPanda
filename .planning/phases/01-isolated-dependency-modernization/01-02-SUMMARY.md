---
phase: 01-isolated-dependency-modernization
plan: 02
subsystem: testing
tags: [swift-testing, swiftcommonmark, markdown, domain-fronting, tag-translation, parity, wave-0, xcodebuild]

# Dependency graph
requires:
  - Confirmed simulator destination and corrected AppPackage-Package test command (01-01)
provides:
  - MarkdownExtTests target locking current CommonMarkExt.MarkdownUtil parseTexts/parseLinks/parseImages behavior
  - TagTranslationFeatureTests target locking markdown-derived TagTranslation computed properties
  - DFRequestSemanticsTests locking D-14 domain-fronting request semantics (host swap, Host header, cookies, POST body, original-domain recovery)
  - Wave 0 complete for the phase (nyquist_compliant true) covering DEP-01/02/03/06 baselines
affects: [01-05, 01-06, isolated-dependency-modernization]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave 0 golden-master fixtures freeze current dependency-backed behavior before a local swap"
    - "Name the future helper target (MarkdownExtTests) up front but exercise the current module (CommonMarkExt) so migration retargets fixtures without changing expected values (D-09)"
    - "Domain-fronting semantics tested via pure request transforms + header-assembly observation, never opening a socket (resume() not called)"

key-files:
  created:
    - AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift
    - AppPackage/Tests/MarkdownExtTests/.swiftlint.yml
    - AppPackage/Tests/TagTranslationFeatureTests/TagTranslationMarkdownTests.swift
    - AppPackage/Tests/TagTranslationFeatureTests/.swiftlint.yml
    - AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan
    - .planning/phases/01-isolated-dependency-modernization/01-VALIDATION.md

key-decisions:
  - "Wave 0 markdown fixtures target the current CommonMarkExt.MarkdownUtil (not a not-yet-existing MarkdownExt) so the swift-markdown migration has a locked baseline; the MarkdownExtTests name reserves MarkdownExt per D-09 without creating an app-owned Markdown module."
  - "Locked two current MarkdownUtil limitations on purpose (D-07): paragraph-only block traversal (headings ignored) and top-level-.text-only inline traversal (strong/emphasis/code text dropped); each is documented in a named test as a known limitation, not a bug fix."
  - "DF semantics tested through pure URLRequest transforms and DFRequest header assembly with resume() never called, so no live networking and no China/SNI conditions are needed (D-13); real-world DF behavior remains a manual verification."
  - "Used a slash-free request path to lock path preservation through the host-to-IP swap, sidestepping the URLComponents host-replace trailing-slash normalization quirk."

patterns-established:
  - "Future-named test target exercising the current module: register MarkdownExtTests now, retarget to MarkdownExt at migration time."
  - "Original-domain recovery is the DF invariant that redirect rebuilding and TLS trust both depend on; lock it via domain/domainWithScheme after IP replacement."

requirements-completed: [DEP-03, DEP-06]

coverage:
  - id: D-03A
    description: "DEP-03 parser parity: parseTexts (plain, multi-paragraph, heading-ignored, top-level-text-only), parseLinks (single/multiple/none), parseImages (valid URL, title-URL fallback, full-string rejection, invalid)"
    requirement: DEP-03
    verification:
      - kind: unit
        ref: "AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift (11 tests)"
        status: pass
    human_judgment: false
  - id: D-03B
    description: "DEP-03 feature-boundary parity: TagTranslation displayValue/valuePlainText/valueImageURL, descriptionPlainText backtick-stripping, descriptionImageURLs, links defaults"
    requirement: DEP-03
    verification:
      - kind: unit
        ref: "AppPackage/Tests/TagTranslationFeatureTests/TagTranslationMarkdownTests.swift (6 tests)"
        status: pass
    human_judgment: false
  - id: D-06A
    description: "DEP-06 D-14 semantics: host-to-IP replacement, unresolvable passthrough, no duplicate Host, original-domain recovery for redirect/TLS trust, Host-header precedence, POST body (data + stream) preservation, original-URL cookie attachment"
    requirement: DEP-06
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift (7 tests)"
        status: pass
    human_judgment: false
  - id: D-06B
    description: "DEP-06 real-world domain-fronting behavior under China/SNI filtering"
    requirement: DEP-06
    verification:
      - kind: manual
        ref: "01-VALIDATION.md Manual-Only Verifications (tester in China); not locally feasible per D-13"
        status: deferred
    human_judgment: true

# Metrics
duration: 8min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 02: Wave 0 Markdown & Domain-Fronting Parity Lock Summary

**Fixture-based Swift Testing targets that freeze the current SwiftCommonMark-backed `MarkdownUtil` and `TagTranslation` markdown behavior (DEP-03) and the domain-fronting request semantics of `DFRequest`/`URLRequest` extensions (DEP-06, D-14) before any parser or `DeprecatedAPI` swap, completing phase Wave 0.**

## Performance

- **Duration:** ~8 min
- **Tasks:** 2
- **Files modified:** 8 (5 created, 3 modified)

## Accomplishments
- Added `MarkdownExtTests` (11 tests) locking `MarkdownUtil.parseTexts`/`parseLinks`/`parseImages` current behavior, including the two intentional current limitations (paragraph-only, top-level-text-only) and the full-string image-URL validation with title-URL fallback (T-01-02-01 security lock).
- Added `TagTranslationFeatureTests` (6 tests) locking the app-level markdown-derived `TagTranslation` computed properties end to end.
- Added `DFRequestSemanticsTests` (7 tests) to the existing `NetworkingFeatureTests` target, locking D-14: host-to-IP replacement, Host-header behavior and precedence, no-duplicate-Host, original-domain recovery (`domain`/`domainWithScheme`) that redirect rebuilding and TLS trust depend on, POST body preservation (explicit data + body stream), and original-URL cookie attachment on `DFRequest`.
- Registered the two new markdown targets (Module case + `.testTarget` + parent-linked `.swiftlint.yml` + `FeatureTests.xctestplan` entry); reserved the `MarkdownExt` name per D-09 with no app-owned `Markdown` module.
- No production source under `AppPackage/Sources/NetworkingFeature` (or anywhere) was changed — Wave 0 is fixtures only.
- Updated `01-VALIDATION.md`: DEP-03/DEP-06 rows marked passed, Wave 0 requirement checklist checked off, feedback latency recorded, `wave_0_complete: true`, `nyquist_compliant: true`, sign-off approved.
- Full package suite green after the additions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fixture-lock markdown and TagTranslation behavior** - `dab4317f` (test)
2. **Task 2: Fixture-lock domain-fronting request semantics** - `9dfa7aff` (test)

**Plan metadata:** see final `docs(01-02)` commit.

## Files Created/Modified
- `AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift` - DEP-03 parser parity (11 tests)
- `AppPackage/Tests/MarkdownExtTests/.swiftlint.yml` - parent-linked lint config
- `AppPackage/Tests/TagTranslationFeatureTests/TagTranslationMarkdownTests.swift` - DEP-03 feature-boundary parity (6 tests)
- `AppPackage/Tests/TagTranslationFeatureTests/.swiftlint.yml` - parent-linked lint config
- `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` - DEP-06 D-14 semantics (7 tests)
- `AppPackage/Package.swift` - two new `Module` cases and `.testTarget` declarations for the markdown targets
- `AppPackage/Tests/FeatureTests.xctestplan` - `MarkdownExtTests` and `TagTranslationFeatureTests` entries
- `.planning/phases/01-isolated-dependency-modernization/01-VALIDATION.md` - passed rows, Wave 0 completion, latency, sign-off

## Decisions Made
- **Future-named target, current module:** `MarkdownExtTests` exercises today's `CommonMarkExt.MarkdownUtil`. Naming the target `MarkdownExt`-forward up front reserves the D-09 name (external swift-markdown product/target is `Markdown`; the app helper must be `MarkdownExt`, never an app-owned `Markdown`), while the fixtures stay valid across the later migration by only asserting output values.
- **Intentional limitations locked, not fixed:** `parseTexts` visits only top-level `paragraph` blocks and only top-level `.text` inlines. Two named tests (`parseTextsIgnoresNonParagraphBlocks`, `parseTextsCollectsOnlyTopLevelTextInlines`) document these as known current behavior per D-07, so the migration must consciously choose to keep or fix them.
- **DF without networking:** DF invariants are exercised through the pure request transforms (`domainIPReplaced()`, `domain`, `domainWithScheme`, `HTTPBody()`) and by constructing a `DFRequest` solely to observe cookie/header assembly; `resume()` (which schedules the stream) is never called, so the tests are deterministic and need no China/SNI conditions (D-13). Real-world DF behavior stays a manual verification.
- **Slash-free path for the swap lock:** the `URLComponents`-based host replacement normalizes away a trailing path slash, so the host-swap fixture uses a slash-free path to lock path preservation unambiguously (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dropped the invalid `-testPlan FeatureTests` flag from the plan's verify commands**
- **Found during:** Tasks 1 and 2 (running the plan's embedded verify commands)
- **Issue:** The plan (and its `<verify>` blocks) embed `xcodebuild ... -scheme AppPackage-Package -testPlan FeatureTests ... test`, which fails: the `FeatureTests` test plan is bound to the app's shared `EhPanda` scheme, not the SwiftPM `AppPackage-Package` scheme. This is the exact correction 01-01 discovered and the executor prompt pre-flagged.
- **Fix:** Ran the `AppPackage-Package` scheme without `-testPlan` (it already includes every package test target); used `-only-testing:` to select `MarkdownExtTests`, `TagTranslationFeatureTests`, and `NetworkingFeatureTests`. `FeatureTests.xctestplan` is kept in sync (new targets added) since it still drives the `EhPanda` scheme.
- **Files modified:** none beyond the planned `01-VALIDATION.md`/`FeatureTests.xctestplan` updates (the correction is to the command, already documented in `01-VALIDATION.md` by 01-01).
- **Verification:** targeted run EXIT 0 (11 + 7 + pre-existing 4 tests); full suite `** TEST SUCCEEDED **`.
- **Committed in:** `dab4317f` / `9dfa7aff`.

**2. [Rule 1 - Characterization tuning] Adjusted the host-swap path fixture to lock actual behavior**
- **Found during:** Task 2 (first verify run)
- **Issue:** The initial fixture asserted the swapped URL kept a trailing-slash path (`/g/123/abc/`). The `URLComponents`-based `replaceHost` normalizes the URL such that `URL.path` returns `/g/123/abc` (no trailing slash). A characterization test must lock the *actual* current output.
- **Fix:** Changed the fixture request path to a slash-free `/g/123/abc` and asserted it is preserved through the swap, which locks path preservation without depending on the trailing-slash normalization edge. No production code changed.
- **Files modified:** `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift`
- **Verification:** re-run targeted set EXIT 0; full suite green.
- **Committed in:** `9dfa7aff` (Task 2 commit).

---

**Total deviations:** 2 auto-fixed (1 blocking command correction, 1 characterization expectation correction)
**Impact on plan:** No scope creep. No production dependency was swapped and no `AppPackage/Sources` file was modified. The DEP-03 and DEP-06 baselines are now locked, completing phase Wave 0.

## Issues Encountered
- One DF test initially failed on a trailing-slash path expectation (see Deviation 2); corrected to the actual current output. A single `xcodebuild` invocation was used at a time and always allowed to finish — no `testmanagerd` wedge.
- Full-suite run prints expected `[DownloadCoordinator] Download failed ... Network Error` logs from the offline download tests; these are deterministic and the suite passes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Wave 0 is complete: DEP-01, DEP-02, DEP-03, and DEP-06 baselines are locked and `nyquist_compliant: true`.
- The later swift-markdown migration (DEP-03) can retarget `MarkdownExtTests`/`TagTranslationFeatureTests` to `MarkdownExt` and prove parity against these fixtures.
- The DEP-06 `DeprecatedAPI` removal spike can proceed with `DFRequestSemanticsTests` as its failing-signal guard; real-world DF verification remains manual (D-13).
- No production dependency was swapped in this plan.

## Self-Check: PASSED

All 5 created source files and both task commits (`dab4317f`, `9dfa7aff`) verified present.

---
*Phase: 01-isolated-dependency-modernization*
*Completed: 2026-07-10*
