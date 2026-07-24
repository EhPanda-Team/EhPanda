---
phase: 14-analytics-instrumentation
plan: 03
subsystem: infra
tags: [telemetrydeck, analytics, privacy, swift-testing, reflection, value-types]

# Dependency graph
requires:
  - phase: 14-analytics-instrumentation
    provides: "plan 14-01's AnalyticsClient source target, AnalyticsClientTests, and the CountBucket / DurationBucket vocabulary this plan's counters draw from"
  - phase: 14-analytics-instrumentation
    provides: "plan 14-02's owner decisions D-15 … D-19, which decide the Category case set, the exactness of tag counts, and where the D-09 type wall sits"
  - phase: 09-typed-error-surface
    provides: "the fifteen-case AppError enum that AppErrorKind mirrors"
provides:
  - Closed screen/tab/outcome vocabulary — HomeSection, AppTab, SearchSurface, DownloadOutcome, LoginFailureKind
  - Stable non-numeric analytics spellings for the Int-raw ReadingDirection and ListDisplayMode, plus all eleven Category cases per D-15
  - TagNamespaceCounts — the audited tag reduction, storing exact per-namespace Int counts per D-16
  - SearchShape — the audited keyword reduction, carrying D-19's single sanctioned String parameter
  - AppErrorKind and AnalyticsErrorCategory — a payload-free, exhaustiveness-guarded mirror of AppError with no SDK import
  - A shared reflection leak probe proving no content sentinel survives any reduction
affects: [14-05, 14-06, 14-11, 14-12, 14-17]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Reflection-based negative content testing: a distinctive sentinel goes into a reduction and every leaf of the constructed value's stored graph is asserted free of it"
    - "Implicit String raw values plus test-pinned spellings, so a case rename fails a test naming the dashboard column it would orphan"
    - "Exhaustive switches with no catch-all arm at every domain-to-vocabulary boundary, making a new upstream case a compile error rather than a silent bucket merge"

key-files:
  created:
    - AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift
    - AppPackage/Sources/AnalyticsClient/TagNamespaceCounts.swift
    - AppPackage/Sources/AnalyticsClient/SearchShape.swift
    - AppPackage/Sources/AnalyticsClient/AppErrorKind.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift
    - AppPackage/Tests/AnalyticsClientTests/TagNamespaceCountsTests.swift
    - AppPackage/Tests/AnalyticsClientTests/SearchShapeTests.swift
    - AppPackage/Tests/AnalyticsClientTests/AppErrorKindTests.swift
    - AppPackage/Tests/AnalyticsClientTests/ContentLeakProbe.swift
  modified: []

key-decisions:
  - "TagNamespaceCounts stores [TagNamespaceKey: Int] — exact counts per D-16, not CountBucket. The plan frontmatter still asserts bucketing in four places and is superseded by the decision record."
  - "TagNamespaceKey is a new closed enum (known / unrecognized) rather than a bare TagNamespace key, because a tag with an unrecognized rawNamespace needs a key and its scraped text may not become one"
  - "A namespace's count is the sum of its GalleryTag contents, not the number of GalleryTag values — a GalleryTag is one namespace holding many tags, and D-07 asks how many tags of each namespace"
  - "Category gained an analyticsName spelling rather than shipping its site-facing raw values, making the eleven-case set a compile-time commitment per D-15"
  - "Namespace qualification steps over a leading exclusion dash or opening quote before matching, so real E-Hentai search syntax is recognized while a URL scheme or a clock time is not"
  - "AnalyticsErrorCategory assignment follows where a failure originates: a failed operation is thrown-exception, an account or host gate is app-state, something the user supplied or asked for is user-input"

patterns-established:
  - "Content leak probe: Mirror.leafRenderings walks a value's whole stored graph and renders every leaf, so a leak parked in a private field is caught the same way a public one is"
  - "Vacuity guard on negative tests: every sentinel sweep asserts the rendering list is non-trivial and that the sentinel really was present on the way in"
  - "Audited reduction boundary: each content-accepting initializer carries a file header naming the decision that permits it and what it may store"

requirements-completed: []

coverage:
  - id: D1
    description: "The closed screen, tab, surface and outcome vocabulary exists with pinned spellings, and every Int-raw domain enum has a stable non-numeric analytics spelling (D-09)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift#homeSectionSpellsEveryCase, #appTabSpellsEveryCase, #searchSurfaceSpellsEveryCase, #downloadOutcomeSpellsEveryCase, #loginFailureKindSpellsEveryCase, #everyTabBarItemTypeMapsToItsTab, #tabMappingIsInjectiveOverEveryTabBarItemType, #readingDirectionSpellingsAreDistinctAndNonNumeric, #listDisplayModeSpellingsAreDistinctAndNonNumeric, #everySpellingIsDistinctWithinItsOwnEnum"
        status: pass
    human_judgment: false
  - id: D2
    description: "The gallery category vocabulary covers all eleven Category cases, imageSet and private included (D-15)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift#categorySpellsAllElevenCases"
        status: pass
    human_judgment: false
  - id: D3
    description: "TagNamespaceCounts reduces a gallery's tags to exact per-namespace counts (D-16), with unused namespaces absent rather than zero and unrecognized raw namespaces collapsed onto one anonymous key"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/TagNamespaceCountsTests.swift#anEmptyTagListYieldsNoCounts, #oneNamespaceWithOneTagCountsOne, #sixTagsInOneNamespaceCountExactlySix, #severalNamespacesAreCountedIndependently, #namespacesTheGalleryDoesNotUseAreAbsentRatherThanZero, #unrecognizedNamespacesCollapseOntoOneKey, #aTagCarryingNoContentsContributesNoKey, #everyNamespaceKeySpellingIsDistinct"
        status: pass
    human_judgment: false
  - id: D4
    description: "SearchShape reduces a keyword to a word-count bucket, a tag-syntax flag and the exact grapheme-count length, and stores nothing else (D-07/D-19)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/SearchShapeTests.swift#searchShapeReducesEveryKeywordShape, #wordCountFollowsTheSharedBucketBoundaries, #keywordLengthIsTheExactGraphemeCount, #anEmptyKeywordReducesToTheEmptyShape, #theReducedShapeStoresOnlyThreeValues"
        status: pass
    human_judgment: false
  - id: D5
    description: "No content text survives either reduction — proven by reflecting over the constructed value and asserting a distinctive sentinel appears nowhere in its stored graph (D-06, threat T-14-01)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/TagNamespaceCountsTests.swift#noTagTextSurvivesTheReduction, AppPackage/Tests/AnalyticsClientTests/SearchShapeTests.swift#noKeywordTextSurvivesTheReduction, AppPackage/Tests/AnalyticsClientTests/AppErrorKindTests.swift#noAssociatedValueSurvivesTheMirror"
        status: pass
    human_judgment: false
  - id: D6
    description: "AppErrorKind mirrors all fifteen AppError cases with no associated values and no catch-all arm, so a sixteenth case is a compile error (D-06, threat T-14-08)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AppErrorKindTests.swift#theMirrorHasOneCasePerAppErrorCase, #everySpellingIsTheCaseNameVerbatim, #everyAppErrorMapsToItsOwnKind"
        status: pass
      - kind: other
        ref: "grep -c 'default:' AppPackage/Sources/AnalyticsClient/AppErrorKind.swift — 0; grep -c '(let ' — 0; AppError case count 15 == AppErrorKind case count 15"
        status: pass
    human_judgment: false
  - id: D7
    description: "AnalyticsErrorCategory mirrors the vendor's three category spellings locally, with every kind's category pinned and no SDK import in the taxonomy layer"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AppErrorKindTests.swift#theCategoryVocabularyIsTheThreeSpellingsTheSdkUses, #everyKindCarriesItsPinnedCategory, #everyKindHasACategory"
        status: pass
    human_judgment: false
  - id: D8
    description: "The module declares no stored String property outside String-raw enum storage, and SwiftLint reports zero violations with no suppression directive added"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "swiftlint lint --strict over AppPackage/Sources/AnalyticsClient and AppPackage/Tests/AnalyticsClientTests — 0 violations, 0 serious in 11 files; grep for 'swiftlint:disable' — none; the four `: String` matches are computed properties returning literal spellings"
        status: pass
    human_judgment: false

# Metrics
duration: ~17min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 03: Analytics vocabulary and audited content reductions Summary

**The D-09 type wall in concrete form: eight closed vocabulary and reduction types whose content-free-ness is proven by reflecting over constructed values rather than by reading the source.**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-07-24T03:40:25Z
- **Completed:** 2026-07-24T03:57:00Z
- **Tasks:** 3 (each RED → GREEN)
- **Files modified:** 9 (9 created, 0 modified)

## Accomplishments

- Five closed screen/tab/outcome enums (`HomeSection`, `AppTab`, `SearchSurface`, `DownloadOutcome`, `LoginFailureKind`) exist with every spelling pinned case by case, so renaming a case fails a test that names the dashboard column the rename would orphan.
- `ReadingDirection`, `ListDisplayMode` and `Category` gained internal `analyticsName` spellings behind exhaustive switches with no catch-all arm — no ordinal reaches a payload, and a new case upstream breaks the build at the point someone has to name it. The `Category` spelling covers all eleven cases per D-15.
- `TagNamespaceCounts` reduces a gallery's tags to exact per-namespace counts keyed by a closed `TagNamespaceKey`, with unused namespaces absent rather than zero and every unrecognized scraped namespace collapsed onto one anonymous key.
- `SearchShape` reduces a keyword to a bucket, a flag and an exact length, and is marked in source as D-19's single sanctioned exception to D-09's no-bare-`String` rule.
- `AppErrorKind` mirrors all fifteen `AppError` cases with zero associated values; `grep` confirms no `default:` arm and no `(let ` binding anywhere in the file, so a sixteenth case is a compile error rather than a silent merge.
- The plan's most important deliverable landed and passes: three reflection-based negative tests drive distinctive sentinels through every reduction and assert they appear nowhere in the constructed value's stored graph — including private fields the public API never exposes.
- 39 tests across 5 suites in `AnalyticsClientTests`; SwiftLint `--strict` reports 0 violations across all 11 files in the module and its test target, with no suppression directive added.

## Task Commits

Each task was committed atomically:

1. **Task 1: Closed screen, tab, outcome and setting-spelling vocabulary** — `fafaee9c` (test, RED) → `335082dc` (feat, GREEN)
2. **Task 2: The two audited content-reduction types** — `fb41d830` (test, RED) → `6c334d56` (feat, GREEN)
3. **Task 3: AppErrorKind, a String-free exhaustiveness-guarded mirror** — `cc321853` (test, RED) → `354da97c` (feat, GREEN)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift` — the five closed enums, `AppTab(_ type: TabBarItemType)`, and internal `analyticsName` spellings for `ReadingDirection`, `ListDisplayMode` and `Category`
- `AppPackage/Sources/AnalyticsClient/TagNamespaceCounts.swift` — `TagNamespaceKey` plus the tag reduction, headed by a comment naming it as an audited boundary
- `AppPackage/Sources/AnalyticsClient/SearchShape.swift` — the keyword reduction and its closed namespace-prefix set, headed by a comment naming D-19's exception explicitly
- `AppPackage/Sources/AnalyticsClient/AppErrorKind.swift` — the payload-free `AppError` mirror and the SDK-free `AnalyticsErrorCategory`
- `AppPackage/Tests/AnalyticsClientTests/ContentLeakProbe.swift` — `Mirror.leafRenderings`, the shared reflection probe all three negative tests use
- `AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift` — 11 tests pinning counts, spellings, mappings and the eleven-case `Category` set
- `AppPackage/Tests/AnalyticsClientTests/TagNamespaceCountsTests.swift` — 8 tests including the tag-text sentinel sweep
- `AppPackage/Tests/AnalyticsClientTests/SearchShapeTests.swift` — 7 tests including a 15-fixture keyword-shape table and the keyword sentinel sweep
- `AppPackage/Tests/AnalyticsClientTests/AppErrorKindTests.swift` — 7 tests including a per-payload-case sentinel sweep and the pinned category table

## Decisions Made

- **Per-namespace counts ship as exact `Int`s (D-16).** `TagNamespaceCounts.countsByNamespace` is `[TagNamespaceKey: Int]`. `CountBucket` remains correct and required for every other counter in the module, `SearchShape.wordCount` included; `DurationBucket` is untouched. This is stated here because the plan's own text asked for it to be.
- **`TagNamespaceKey` is a new closed enum, not a bare `TagNamespace`.** The plan asked for a dictionary keyed by `TagNamespace` *and* for unrecognized tags to land under "a single dedicated key" — `TagNamespace` has no such case, so the two requirements needed a key type. `known(TagNamespace)` / `unrecognized` satisfies both without letting a scraped raw namespace become a key.
- **A namespace's count is the number of tag *contents*, not the number of `GalleryTag` values.** A `GalleryTag` is one namespace holding the individual tags scraped under it; D-07 asks "how many of each namespace", which is the tag count. Summing rather than assigning also keeps the answer right if a gallery ever presents one namespace twice.
- **A `GalleryTag` carrying no contents contributes no key at all.** Counting it would have produced a zero-valued entry, contradicting the plan's requirement that unused namespaces be absent rather than present with a zero.
- **`Category` gained a spelling rather than shipping its raw values.** `Category` is already `String`-raw, but its raw values are the site's display strings ("Artist CG", "Non-H"). A separate spelling keeps one dashboard house style and, more usefully, makes the eleven-case set a compile-time commitment: a twelfth category breaks the build.
- **Raw values are left implicit throughout.** SwiftLint's `redundant_string_enum_value` is on by default, so `case frontpage = "frontpage"` is a violation. The spellings are pinned in tests instead, which is the stronger place: a rename becomes a failing test naming the column it would have orphaned, rather than a silently-preserved literal.
- **Tag-syntax detection steps over a leading `-` or `"`.** Both are real E-Hentai search syntax (exclusion, quoted phrase) and both can precede the namespace. Matching against the closed set of names and abbreviations is what keeps `https://…` and `10:30` from reading as tag syntax.
- **Error categories follow origin, not presentation.** `thrown-exception` for an operation that failed on its own terms (networking, parsing, web image, file operations, the Cloudflare challenge exchange, unknown); `app-state` for an account, gallery or session gate (copyright claim, IP ban, expunged, quota, authentication required, no updates); `user-input` for something the user supplied or asked for (login captcha, unsupported deep link, not found).

## Deviations from Plan

### Plan frontmatter superseded by D-16 (recorded, not fixed here)

D-16 postdates this plan's frontmatter. Four entries in `14-03-PLAN.md` still assert that per-namespace tag counts are bucketed; the implementation follows D-16 instead, and the plan file was deliberately **not** edited. Named here so the phase verifier and plan 14-17 reconcile the contract rather than reading the divergence as a defect:

| Superseded entry | What it asserts | What shipped |
|---|---|---|
| `must_haves.truths` #2 | "reduces a gallery's tags to per-namespace **bucketed** counts" | exact `[TagNamespaceKey: Int]` counts |
| `must_haves.truths` #1 | "Every analytics payload value originates from a closed enum, a Bool, or **a bucket**" | …or one of D-08's two documented exact-`Int` exceptions |
| `must_haves.key_links` | `via: "per-namespace counts pass through CountBucket per D-16"`, `pattern: "CountBucket"` | `TagNamespaceCounts.swift` takes no `CountBucket` edge; the link is now a documentation edge to `Buckets.swift`'s header comment |
| task 2 test coverage | "one namespace with six tags (**bucket boundary**)" | `sixTagsInOneNamespaceCountExactlySix` asserts the count value; there is no bucket boundary left for tag counts |

The "retains no tag text" half of truth #2 still holds and is proven by `noTagTextSurvivesTheReduction`.

Two smaller plan-internal inconsistencies, resolved in favour of the majority reading:

- Task 3's `<action>` step (d) names the property `errorCategory` while its `<behavior>` block and `<acceptance_criteria>` both name it `category`. Shipped as `category`.
- Task 2's `<read_first>` points at `AppPackage/Sources/AppModels/Tags/GalleryTag.swift`, which does not exist — `GalleryTag` is declared in `AppModels/Gallery/GalleryState.swift`. Content matched; no impact.

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical] `Category` spelling added under D-15**
- **Found during:** Task 1 (closed vocabulary)
- **Issue:** D-15 assigns the eleven-case `Category` vocabulary to this plan, but the plan's task list — written before D-15 was answered — names no artifact for it. Left unaddressed, D-15 would have had no owner and the next plan to touch a category payload would have reached for `Category.rawValue`, whose spellings are the scraped site's display strings and whose case set nothing pins.
- **Fix:** `Category.analyticsName` added to `AnalyticsVocabulary.swift` as an exhaustive switch with no catch-all arm, plus `categorySpellsAllElevenCases` pinning the count at eleven and every spelling.
- **Files modified:** `AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift`, `AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift`
- **Verification:** `categorySpellsAllElevenCases` passes; a twelfth `Category` case would fail to compile.
- **Committed in:** `fafaee9c` / `335082dc` (Task 1)

**2. [Rule 3 — Blocking] `TagNamespaceKey` introduced to carry the unrecognized bucket**
- **Found during:** Task 2 (content reductions)
- **Issue:** The plan asked for `[TagNamespace: …]` storage *and* for unrecognized-namespace tags to be counted "under a single dedicated key". `TagNamespace` has twelve cases and none of them means "unrecognized", so the two requirements could not both be met with that key type. Widening the key to `String` would have re-admitted the scraped raw namespace D-06 forbids.
- **Fix:** A closed `TagNamespaceKey` enum with `known(TagNamespace)` and `unrecognized`, carrying its own `analyticsName`. The dictionary key set stays closed vocabulary.
- **Files modified:** `AppPackage/Sources/AnalyticsClient/TagNamespaceCounts.swift`, `AppPackage/Tests/AnalyticsClientTests/TagNamespaceCountsTests.swift`
- **Verification:** `unrecognizedNamespacesCollapseOntoOneKey`, `everyNamespaceKeySpellingIsDistinct` and the sentinel sweep all pass.
- **Committed in:** `fb41d830` / `6c334d56` (Task 2)

**3. [Rule 2 — Missing Critical] Zero-content tags excluded from the counts**
- **Found during:** Task 2 (content reductions)
- **Issue:** Counting `contents.count` unconditionally would enter a zero-valued key for a `GalleryTag` that carries no contents, contradicting the plan's own requirement that a namespace absent from the gallery be absent from the dictionary rather than present with a zero.
- **Fix:** `for tag in tags where tag.contents.isEmpty == false`.
- **Files modified:** `AppPackage/Sources/AnalyticsClient/TagNamespaceCounts.swift`, `AppPackage/Tests/AnalyticsClientTests/TagNamespaceCountsTests.swift`
- **Verification:** `aTagCarryingNoContentsContributesNoKey` asserts it directly.
- **Committed in:** `fb41d830` / `6c334d56` (Task 2)

**4. [Rule 2 — Missing Critical] Vacuity guards on every negative content test**
- **Found during:** Task 2 (content reductions)
- **Issue:** A sentinel sweep that iterates an empty rendering list passes without inspecting anything, and a sweep over a fixture that never carried the sentinel proves nothing either. Both failure modes are silent and would leave the phase's primary privacy control asserting nothing at all.
- **Fix:** Each sweep asserts the rendering list is non-trivial; `AppErrorKindTests` additionally asserts the sentinel is present in the error on the way in.
- **Files modified:** all three sentinel-bearing test files
- **Verification:** The guards are themselves `#expect`s in the passing tests.
- **Committed in:** `fb41d830`, `cc321853`

**5. [Rule 3 — Blocking] `-skipMacroValidation -skipPackagePluginValidation` added to every verify gate**
- **Found during:** Task 1 (first verification run)
- **Issue:** This plan's `<automated>` gates omit both flags. Phase 14's TelemetryDeck dependency changed the resolved package-graph fingerprint and invalidated Xcode's macro trust approvals, so every unflagged build fails at `ComputeTargetDependencyGraph`. `14-01-SUMMARY.md` flagged this as carry-forward for every remaining plan in the phase.
- **Fix:** Both flags added to all six `xcodebuild` invocations, matching `.github/workflows/test.yml`.
- **Files modified:** none — invocation-level only
- **Verification:** Every run reached `** TEST SUCCEEDED **`.
- **Committed in:** n/a

---

**Total deviations:** 5 auto-fixed (3 missing critical, 2 blocking) plus one recorded plan-frontmatter conflict resolved in favour of the decision record
**Impact on plan:** No scope creep. Four of the five auto-fixes are correctness or provability requirements the plan's own text implied but did not spell out; the fifth is a known phase-wide build-invocation carry-forward. One extra file was created beyond the plan's `files_modified` list — `ContentLeakProbe.swift`, the shared reflection probe — because three suites need the same walker and duplicating it three times would have made the phase's primary control three things to keep in sync instead of one.

## Issues Encountered

- **Key paths do not reach tuple members.** `Mirror.Child` is a tuple, so `children.compactMap(\.label)` does not compile; the closure form is required. Caught at the RED build.
- **`redundant_string_enum_value` shaped the vocabulary's declaration style.** The plan specified explicit raw values equal to the case names, which SwiftLint rejects as redundant. Rather than suppress the rule, the spellings moved into the tests — a better home for them anyway, since a test failure names the dashboard column at risk.

## User Setup Required

None — no external service configuration required by this plan. The TelemetryDeck app ID and salt are plumbed in plan 14-04.

## Next Phase Readiness

- Plan **14-05** (`AnalyticsSignal`) can be authored against a module in which no free-form payload type exists: every value a signal case might carry is now a closed enum, a `Bool`, a bucket, or one of D-08's two documented exact-`Int` exceptions.
- Plan **14-06** owns the single SDK call site and must translate `AnalyticsErrorCategory` into the vendor's own type there; nothing in the taxonomy layer imports the SDK.
- Plan **14-11** owns mapping `HomeSectionType` and `HomeMiscGridType` onto `HomeSection` at the emission site — `AnalyticsClient` deliberately takes no `HomeFeature` dependency.
- Plan **14-17** carries two corrections this plan surfaced but does not own: `Buckets.swift`'s header comment still says there is a single documented exception to D-08 (there are two), and `ANALYTICS-01` in `REQUIREMENTS.md` says the same. Neither file was touched here.
- Carry-forward, unchanged: every `xcodebuild` invocation in this phase needs `-skipMacroValidation -skipPackagePluginValidation`.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*

## Self-Check: PASSED

All 9 source and test files exist on disk; all 6 task commits (`fafaee9c`, `335082dc`, `fb41d830`, `6c334d56`, `cc321853`, `354da97c`) resolve in `git log`. No absolute home path appears in this document.
