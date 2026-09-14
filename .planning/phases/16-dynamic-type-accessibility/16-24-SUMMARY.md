---
phase: 16-dynamic-type-accessibility
plan: 24
subsystem: accessibility
tags: [accessibility-audit, xcuitest, performAccessibilityAudit, hit-region, element-description, d-31, d-22, d-25, ipados-27-beta]

# Dependency graph
requires:
  - phase: 16-23
    provides: "Asset-driven star and link colours (`RatingStar`, `CommentLink`) and the `Color.mix` / colorset idioms the reader placeholder fix reused"
  - phase: 16-16
    provides: "Round-2 VoiceOver label idioms (catalog-key labels, `accessibilityHidden` for decoration) the class-(a) fixes followed"
provides:
  - "`EhPandaUITests/AccessibilityAuditUITests.swift` on the non-default `UITests` plan: 28 tests over every fixture-reachable surface (27 on iPhone, one iPad-only), each surface audited with one `performAccessibilityAudit(for:)` call per kept type — `.hitRegion`, `.sufficientElementDescription`, `.trait`"
  - "`EhPandaUITests/Support/AccessibilityAuditReport.swift`: the report model (`AuditReport`, `AuditElement`, `AuditExclusion`, `SurfaceInventory`) every allow-list matcher judges"
  - "Allow-lists: `systemOwnedExclusions` = [`ContentUnavailableView.symbol`]; `ownerApprovedExclusions` = [`E-1.hidden-content`] (`E-1=approve`, 2026-09-13)"
  - "App fixes for the audit's findings: Show All hit regions (`SubSection`), Detail hit regions and combined elements (`DetailView+HeaderSection`, `DetailView+Subviews`), Gallery Infos rows as named copy buttons, Home cover-button labels, preview thumbnail labels (`accessibility.preview_page`), reader slider labels / values (`accessibility.scale_factor`), `Color.pagePlaceholder` (light 4.37:1)"
  - "`ShareSheetUITests` finds Safari's address field on iPad (`TabBarItemTitleContainer`) and types into the focused field"
  - "`16-CONTRAST-AUDIT.md § Automated audit (16-24)`: full classification history, `#### Scope change (2026-09-14)`, `#### Gate runtimes (2026-09-15)`, `#### Final gate (2026-09-15)` (per-surface table, both allow-lists, reachability assumption)"
  - "`deferred-items.md § Found during 16-24`: six observations plus the iPadOS 27 beta Gallery Detail stall"
affects: [16-25 (manual walkthrough covers Favorites, Watched, Archives, Torrents, EhSetting, FolderManager, Detail Search), 16-26 (D-25 row 14 Gallery Detail action row; Nutrition Label cites the two allow-list entries and the best-effort scope)]

# Actuals (#2632) — estimateTokens scale (chars/4 over the realized diff); commits measured from the plan ledger.
actuals:
  tokens: 29186
  tasks: 4
  commits: 13
plan_head_before: 8b6abc31c8d8e4947f606bbe567064cdeb1cbc3b

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Audit one `XCUIAccessibilityAuditType` per `performAccessibilityAudit(for:)` call, each wrapped in an `XCTContext` activity, with `continueAfterFailure` lifted for the audit calls only so one run logs a surface's complete list"
    - "Allow-list matchers judge a value parsed from the issue's description (surface, type, element name / type) and a pre-audit `SurfaceInventory`; the handler never queries the app mid-audit (a mid-audit frame read re-snapshots and drops later lazy elements)"
    - "Every allow-list entry carries its id, element, audit type, measured reason and, for owner-approved entries, the owner's reply with its date"

key-files:
  created:
    - EhPandaUITests/AccessibilityAuditUITests.swift
    - EhPandaUITests/Support/AccessibilityAuditReport.swift
    - AppPackage/Sources/AppComponents/Resources/Colors.xcassets/PagePlaceholder.colorset/Contents.json
  modified:
    - EhPandaUITests/ShareSheetUITests.swift
    - AppPackage/Sources/AppComponents/Placeholder.swift
    - AppPackage/Sources/AppComponents/SubSection.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift
    - AppPackage/Sources/ReadingSettingFeature/Resources/Localizable.xcstrings
    - .planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md
    - .planning/phases/16-dynamic-type-accessibility/16-SWEEP.md
    - .planning/phases/16-dynamic-type-accessibility/deferred-items.md

key-decisions:
  - "Split audits, fix helper (owner, 2026-09-13): one `performAccessibilityAudit(for:)` call per audit type instead of one `.all` call, because a single `.all` call on the iPad (A16) hit the engine's ~600 s limit (error −56) and failed with no report; the scroll helper tests the presented sheet's frame, not the window's"
  - "E-1 … E-9 approved by id on 2026-09-13 and refined on 2026-09-13 / 2026-09-14 (E-2 by pre-audit frames then one geometric rule, E-3 and E-4 extended by name, O-2 element-less logging); all retired on 2026-09-14 except E-1, narrowed to the reader panel's hidden `ActivityIndicator`s"
  - "Stable types only (owner, 2026-09-14): \"我們不需要用測試擔保對比度\" and \"比較穩定的測試可以留下來，不穩定擋路的刪掉，因為本來就是 best effort 沒有要保證可以\" — `.contrast`, `.dynamicType`, `.textClipped`, `.elementDetection` removed; `.hitRegion`, `.sufficientElementDescription`, `.trait` kept"
  - "Gate runtimes (owner, 2026-09-15): \"iPad 改回 26.5，27 的問題先記進 deferred\" and \"但是注意現在的 27 還是 beta\" — gate on iPhone 17 iOS 26.5 and iPad (A16) iPadOS 26.5; iPadOS 27.0 (24A434) pre-release excluded; its Gallery Detail stall deferred, neither avoidance applied"
  - "Safari's iPad address field is found by the stable inner identifier `TabBarItemTitleContainer` and the URL is typed into the element holding keyboard focus, not judged by a visible keyboard"

patterns-established:
  - "A kept audit report that no allow-list claims fails the test whether or not the engine named its element; nothing is logged-only"
  - "A test-infrastructure finding that shapes a matcher is written into the matcher's doc comment and the audit record, with the run that measured it"

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Audit suite over every fixture-reachable surface on the `UITests` plan, no `#available`, no UDID in source, both allow-lists doc-commented"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "`grep -c performAccessibilityAudit` = 2, `grep -c '#available'` = 0, `grep -c 'func test'` = 28 in `AccessibilityAuditUITests.swift`; `grep -c '88B217DA\\|ADE09605\\|8250D97E'` = 0; `build-for-testing -testPlan UITests` TEST BUILD SUCCEEDED with the SwiftLint build plugin (Xcode 26.6, `final-gate/bft-iphone265.log`)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every reported issue classified (a) fixed / (b) system-owned / (c) owner candidate; owner replies applied by id; the 2026-09-14 scope change recorded with its evidence"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "`16-CONTRAST-AUDIT.md § Automated audit (16-24)` › Fixed (class a), System-owned (class b), Owner-approval candidates E-1…E-9, Classification of every report (248 distinct reports of `a11y-post-fix-iphone.xcresult`), Scope change (2026-09-14)"
        status: pass
    human_judgment: true
    rationale: "Exclusions are owner decisions by id (D-22); the owner's replies are quoted in the test file and the audit record"
  - id: D3
    description: "Idempotent gate: two sequential iPhone runs and one iPad run of the full `UITests` plan, every test single-run, kept-type reports identical between the iPhone runs"
    requirement: "A11Y-02"
    verification:
      - kind: automated_ui
        ref: "`final-gate/full-iphone265-1.xcresult` and `-2.xcresult` (iPhone 17 `73E148DA…`, iOS 26.5 23F77): 39 passed / 0 failed / 2 skipped, 41 test runs for 41 tests, 550.6 s / 540.9 s, the five `[a11y-audit]` lines identical; `ipad265-recheck/full-ipad265.xcresult` (iPad (A16) `B6679864…`, iPadOS 26.5 23F77): 41 / 0 / 0, 41 test runs, 740.3 s"
        status: pass
    human_judgment: false

# Metrics
duration: 2d 16h wall-clock, owner checkpoints included
completed: 2026-09-15
status: complete
---

# Phase 16 Plan 24: Automated accessibility audit gate Summary

**`AccessibilityAuditUITests` audits all 28 fixture-reachable surfaces on the `UITests` plan with the three audit types that give the same result on every run (`.hitRegion`, `.sufficientElementDescription`, `.trait`), one call per type. It passes, with no retries, twice on iPhone 17 iOS 26.5 and once on iPad (A16) iPadOS 26.5. The hit-region and description findings were fixed in app code (Show All, Detail and Gallery Infos targets; cover, preview and slider labels; the reader placeholder colour). The only exclusions left are one system-owned entry (`ContentUnavailableView.symbol`) and one owner-approved entry (`E-1.hidden-content`). The contrast, Dynamic Type, text-clipping and element-detection audits were dropped by owner decision as unstable. The iPadOS 27 beta Gallery Detail stall is deferred.**

## Performance

- **Duration:** 2 days 16 hours of wall-clock time (2026-09-12T01:07Z to 2026-09-14T16:40Z), including four owner checkpoints and the iOS 27 root-cause investigation
- **Started:** 2026-09-12T01:07:20Z
- **Completed:** 2026-09-15
- **Tasks:** 4 (Task 3 was an owner checkpoint, answered several times)
- **Files modified:** 18 (3 test sources, 11 app sources and resources, 1 colorset, 3 planning docs)

## Accomplishments

- D-31's automated half is a permanent gate. It has 28 tests: 5 tab roots (Favorites as its login placeholder), Frontpage, Popular, History, 3 toolbar sheets, 8 Setting children, Gallery Detail, Previews, Gallery Infos, Comments, Reading page, control panel, Reading Setting sheet, toast + error-info sheet, and the iPad Setting / Detail modals. Every test uses the hermetic launcher (`launchStubbed` / `openCold`, `-AppleLanguages (en)`, stub network).
- Every app-owned finding the audit could name was fixed or decided by the owner by id. No issue was excluded silently: every allow-list entry names its element, type, measured reason and, for owner-approved entries, the reply.
- The final gate is green and idempotent. Both iPhone runs return the same five kept-type reports in the same order, and allow-list entries claim all of them. No `judged` line appears in any of the three logs.
- The login-gated surfaces are recorded as an assumption and routed to 16-25 and the D-25 re-sweep.

## Test inventory and final results

Per surface, from `16-CONTRAST-AUDIT.md § Automated audit (16-24) › Final gate (2026-09-15)`:

| bundle | device / OS | passed / failed / skipped | test runs | duration |
|---|---|---|---|---|
| `final-gate/full-iphone265-1.xcresult` | iPhone 17 `73E148DA-26E4-4892-8C8A-7EDC6725D0E7`, iOS 26.5 (23F77) | 39 / 0 / 2 | 41 (single run each) | 550.6 s |
| `final-gate/full-iphone265-2.xcresult` | iPhone 17 `73E148DA-26E4-4892-8C8A-7EDC6725D0E7`, iOS 26.5 (23F77) | 39 / 0 / 2 | 41 (single run each) | 540.9 s |
| `ipad265-recheck/full-ipad265.xcresult` | iPad (A16) `B6679864-3783-4A3B-89B5-B0B010588C13`, iPadOS 26.5 (23F77) | 41 / 0 / 0 | 41 (single run each) | 740.3 s |

- iPhone skips: `AccessibilityAuditUITests.testPadSettingAndDetailModalsAudit` and `DeepLinkPadUITests.testPadTabModalReplacedByDeepLink`, both iPad-only by `XCTSkip`.
- The 13 pre-existing UI tests passed in the same runs: 12 passed + 1 skipped on each iPhone run, and 13 passed on the iPad.
- Kept-type reports (both iPhone runs, identical): `Favorites (login placeholder)` symbol image ×1 and `History` symbol image ×1 (`ContentUnavailableView.symbol`); `Reading › control panel` `ActivityIndicator` ×3 (`E-1.hidden-content`). The iPad log shows the same, with ×5 `ActivityIndicator`.
- The 2026-09-15 `build-for-testing` compiled nothing: no `SwiftCompile`, link or code-sign step, and no object file newer than the 2026-09-14 21:07 build. So the orchestrator's iPad run on the same products is the iPad leg.

## Classification per issue

The complete per-report classification of the first complete finding is recorded in `16-CONTRAST-AUDIT.md § Automated audit (16-24)`: `#### Fixed (class a)`, `#### System-owned (class b)`, `#### Owner-approval candidates` (E-1 … E-9 with measurements) and `#### Classification of every report` (248 distinct reports of `a11y-post-fix-iphone.xcresult`, one row per surface × type × class). In short:

- **(a) fixed:** the hit regions and missing or unreadable descriptions (table below), plus the reader page placeholder's contrast (2.14 → 4.37 in light).
- **(b) system-owned:** `UISearchBar.field` (`textClipped`), `UIDatePicker.parts` (`dynamicType`), `UIDatePicker.elementDetection`, `UISheetPresentationController.dimmed-presenting-content` (iPad sheet surfaces, "Approve, measure four now"), and `ContentUnavailableView.symbol`. The first four were retired with their audit types on 2026-09-14.
- **(c) owner candidates:** E-1 hidden state views, E-2 text under the glass bars or the toast, E-3 two-colour sampling artifacts, E-4 `.secondary` text, E-5 accent-tinted text, E-6 disabled controls, E-7 the namespace chip, E-8 size heuristics, E-9 the reader panel's approved Dynamic Type range. All nine were approved by id on 2026-09-13. Only `E-1.hidden-content` survives the 2026-09-14 scope change.

## Fixes per file

| file | fix | report it answers |
|---|---|---|
| `AppComponents/SubSection.swift` | Show All label `.frame(minHeight: 24)` inside its 24-pt heading row | `hitRegion` "Hit area is too small", Show All 58.7 × 18 (Home, Detail) |
| `DetailFeature/DetailView+Subviews.swift` | Gallery Infos ellipsis 44 × 44 target; action-row labels `minHeight: 24` (row +3.7 pt, D-25); rating count / value / stars one element; stats-strip value and unit one element (`c91c2b31`); preview thumbnail labels | `hitRegion` on the ellipsis, action row and rating group; `sufficientElementDescription` on the bare stats figure (iPad) and on the thumbnails |
| `DetailFeature/DetailView+HeaderSection.swift` | uploader `Text` label `minHeight: 24`; hero cover `accessibilityHidden(true)` | `hitRegion` uploader 49.7 × 19.3; `sufficientElementDescription` hero image |
| `DetailFeature/GalleryInfos/GalleryInfosView.swift` | the whole 44-pt row is the copy button, labelled by its title with the value as `accessibilityValue`; title `Color.primary` | `hitRegion` ×7 (14.3-pt copy buttons); `sufficientElementDescription` "Label not human-readable" ×5 on URL buttons |
| `DetailFeature/Previews/PreviewsView.swift`, `DetailFeature/Resources/Localizable.xcstrings` | `.accessibilityLabel(.accessibilityPreviewPage(page:))`, key `accessibility.preview_page` = "Page %#@page@" in six locales | `sufficientElementDescription` ×12 (Previews) and ×4 (Detail) |
| `HomeFeature/HomeView+Sections.swift` | `.accessibilityLabel(gallery.title)` on the cover-stack buttons | `sufficientElementDescription` ×8 (Home root) |
| `ReadingSettingFeature/ReadingSettingView.swift`, its `Localizable.xcstrings` | end labels hidden; slider labelled by its row title and valued with `accessibility.scale_factor` ("%@ times", six locales) | `textClipped` ×2 on "10.0x" / "5.0x" (Setting › Reading, Reading Setting sheet) |
| `AppComponents/Placeholder.swift`, `AppComponents/Resources/Colors.xcassets/PagePlaceholder.colorset`, `ReadingFeature/ReadingViewComponents.swift` | `Color.pagePlaceholder`: light `#5C5C60` (4.37:1 on `#D1D1D6`, light IC 4.97), dark entries unchanged | `contrast` "Contrast failed" on the unloaded page number, 2.14:1 |
| `EhPandaUITests/ShareSheetUITests.swift` | address field matched by `TabBarItemTitle` (iPhone) or `TabBarItemTitleContainer` (iPad); URL typed into the focused text field, tapping Safari's address-editor field once if the first tap opens the editor | iPad `testShareSheetHandoffLandsOnDetail`: Safari's regular-width tab bar has no `TabBarItemTitle` field (probed on iPadOS 26.5 and 27.0) |

## Exclusion lists (current)

- `systemOwnedExclusions`:
  - `ContentUnavailableView.symbol`: the symbol `Image` that `ContentUnavailableView` draws, exposed under its SF Symbol name (`person.crop.circle.badge.questionmark.fill`, `rectangle.and.text.magnifyingglass`). `accessibilityHidden(true)` in both `Label` forms was verified ineffective.
- `ownerApprovedExclusions`:
  - `E-1.hidden-content`: the reader's slider-preview strip at opacity 0 through `visible(false)`. Its `ActivityIndicator`s are reported as `sufficientElementDescription` on `Reading › control panel`. Owner: `E-1=approve` (2026-09-13).

## Simulators used

- iPhone 17e `4293F269-149A-47EB-A718-4AE54272B9E6`, iOS 26.5: Task 1 and Task 2 runs and the diagnostics.
- iPhone 17 `73E148DA-26E4-4892-8C8A-7EDC6725D0E7`, iOS 26.5 (23F77): `stable-types`, `iphone265-gate`, and the final gate.
- iPad (A16) `B6679864-3783-4A3B-89B5-B0B010588C13`, iPadOS 26.5 (23F77): the iPad diagnostics (`diag-25` … `diag-29b`, `a11y-final-ipad`), `ipad265-recheck`, and the final iPad leg.
- A11y Audit iPad A16 (27) `5C21368C-FA5C-47AF-B4DF-1A1D747E09D0`, iPadOS 27.0 (24A434) pre-release: 2026-09-14 runs (`stable-ipad27`, `ios27/`, `share-fix/`, root-cause work). It is excluded from the gate since 2026-09-15.
- iPhone runs on iOS 27 are recorded under `ios27/`. No D-09 simulator (`ADE09605…`, `8250D97E…`) appears in any run log under the evidence root, and no simulator was created.

## Task Commits

1. **Task 1: audit suite:** `5d5844ba` (test)
2. **Task 2: class-(a) fixes, class-(b) entries, candidates E-1…E-9:** `9a3cd7ce` (fix)
3. **Task 3 → Task 4: owner replies applied:**
   - `53aad22a` (fix): E-1…E-9 approved
   - `57cf05c4` (fix): E-2 matched by frames, "Approve both"
   - `45e8c8f9` (fix): O-2 logging and the dimmed-sheet entry
   - `c91c2b31` (fix): stats strip value + unit
   - `d20cf7bb` (fix): replies A–E, the per-type split, the report model moved to Support
   - `eb71c4e7` (fix): redundant remainder call dropped; E-4 by name
4. **Scope change (2026-09-14):**
   - `d67192f5` (test): stable types only
   - `42f18a73` (docs): stable-only scope recorded
5. **iPad share test:** `7e4bb963` (fix): Safari address field on iPad
6. **Runtime decision (2026-09-15):** `e82c6835` (docs): iPadOS 27 beta Detail stall deferred
7. **Task 4 record:** `7ef11be2` (docs): Gate runtimes, Final gate, allow-lists, reachability

**Plan metadata:** the final `docs(16-24)` commit.

## Decisions Made

See `key-decisions` in the frontmatter. In short:

- Split audits by type.
- E-1…E-9 approved, then retired except a narrowed E-1.
- Only the stable audit types are run.
- The gate runs on iOS / iPadOS 26.5, and iPadOS 27 beta is deferred.
- The Safari address field is found on iPad and the URL is typed into the focused field.

## Deviations from Plan

No Rule 4 case was decided by the executor. Every structural change below is an owner decision quoted by date.

1. **Per-type audit split (owner: "Split audits, fix helper", 2026-09-13).**
   - The plan calls `performAccessibilityAudit(for: .all)` once per surface. On the iPad (A16) a single `.all` call over Frontpage, Popular, Date Seek, Filters and the iPad modals ran past the engine's ~600 s limit (error −56, `a11y-final-ipad`, `diag-25`), so the test failed with no report at all.
   - The audit now runs one call per type, each as an XCTest activity.
   - The scroll helper tests the presented sheet's frame, because the 580-pt Detail form sheet sits inside an 820-pt window.
   - `eb71c4e7` dropped the remainder call (owner "yes", 2026-09-14).
2. **Complete logging instead of first-failure stop.** `continueAfterFailure` is lifted inside the audit calls only. With the class-wide `false`, each surface stopped at its first report (run 1 was the red list, not the finding).
3. **E-1…E-9 history.**
   - All nine were approved by id on 2026-09-13 (`53aad22a`).
   - E-2 moved from iPhone-17e name lists to pre-audit frames ("Approve both", `57cf05c4`), then to one geometric rule for anything hidden when audited (`d20cf7bb`).
   - E-3 gained the iPhone 17 and iPad sampling artifacts and the toast body ("Approve both", "Approve, measure four now").
   - O-2 ("O-2: log, never fail", then "Extend O-2 to them") logged element-less reports without failing.
   - E-4 was extended by name ("Extend E-4 by name (Recommended)", 2026-09-14).
   - On 2026-09-14 E-2…E-9, O-2 and four class-(b) entries were retired with their audit types, and E-1 was narrowed to `E-1.hidden-content`.
4. **Stable-types scope change (owner, 2026-09-14).** "我們不需要用測試擔保對比度" (we do not need tests to guarantee contrast) and "比較穩定的測試可以留下來，不穩定擋路的刪掉，因為本來就是 best effort 沒有要保證可以" (keep the stable tests, delete the unstable ones that block; this was always best effort). The plan's "every audit type" truth and its contrast-exclusion expectations are superseded. Evidence per type is in `#### Scope change (2026-09-14)`.
5. **Runtime decision (owner, 2026-09-15).** The 2026-09-14 "ios 26.5 + ipados 27" was superseded for the iPad by "iPad 改回 26.5，27 的問題先記進 deferred" and "但是注意現在的 27 還是 beta". The gate is iPhone 17 iOS 26.5 + iPad (A16) iPadOS 26.5, and iPadOS 27.0 (24A434) is excluded as pre-release.
6. **Deferred iPadOS 27 stall.**
   - On iPadOS 27.0 beta only, presenting Gallery Detail intermittently pins the main thread for minutes. The trigger is a glass-styled `Menu` inside the header's inner `ViewThatFits` when the sheet is laid out at 0×0; it is a SwiftUI / AttributeGraph regression reproduced standalone.
   - Two avoidances were found (bordered menus on iPad 27+, or an explicit width-based arrangement). Neither is applied.
   - The item and its re-run schedule are in `deferred-items.md` (`e82c6835`). The Feedback draft is not submitted.
7. **[Rule 1 - Bug] Safari address-field lookup on iPad (`7e4bb963`).** `ShareSheetUITests` pinned the iPhone-only `TabBarItemTitle` identifier and waited for a software keyboard.
   - On iPad, Safari nests the field as `TabBarItemTitleContainer`. A restored tab opens an address editor instead of focusing the field, and a hardware keyboard can hide the software one.
   - The test now accepts either identifier and types into the element with keyboard focus, tapping the editor's field once if needed.
   - Verified: `testShareSheetHandoffLandsOnDetail` passed first try on the iPad (A16) iPadOS 26.5 run and on both iPhone runs.
8. **Simulators differ from the plan text.** The plan names the spare iPhone `88B217DA-A166-4BAD-820D-DE13B1C4EB54`, which does not exist on this machine, and an iPad created with `xcrun simctl create`. The runs used the existing simulators listed above, and none was created.
9. **iPad leg reused.** The `build-for-testing` at `7e4bb963` compiled nothing, so the orchestrator's `ipad265-recheck/full-ipad265.xcresult` (same products, same sources) is the iPad leg instead of a fresh run.
10. **Skip count.** Each iPhone run skipped 2 tests (39 passed + 2 skipped), not the orchestrator's expected 40 + 1. The second skip is `DeepLinkPadUITests.testPadTabModalReplacedByDeepLink`, which is iPad-only by design (`XCTSkip`) and predates this plan.
11. **Retry setting.** The plan's `retryOnFailure` configuration in `UITests.xctestplan` is unchanged. Single-run execution is shown by the bundles (41 test runs for 41 tests), not forced by configuration.

**Total deviations:** 1 Rule 1 fix, 5 owner decisions applied, 5 environment / record differences.
**Impact on plan:** every remaining plan truth is met under the owner's 2026-09-14 and 2026-09-15 decisions. The gate covers every fixture-reachable surface with the stable audit types. No exclusion exists without a system owner or an owner reply.

## Issues Encountered

- A frame read inside the audit handler re-snapshots the app, after which lazy-container elements no longer resolve (diag-9: 111 of 267 reports lost their element). Matchers read the description and a pre-audit inventory only.
- The iOS 26.5 iPad `.dynamicType` / `.textClipped` sweep triggers UIKit's `_UIFloatingTabBar` layout loop, which ends in −56 timeouts. This is one reason those types were removed.
- iPadOS 27 beta: every contrast failure was a false positive, and the Gallery Detail stall was traced to the runtime (deferred).
- `LoginReturnObservationTests.cookieLoginTriggersReloadWithoutAViewCallback` flaked once in a package run (`package-tests-1.log`) and passed on re-run. It is logged in deferred-items.

## Evidence (never committed, D-32)

`$HOME/Library/Caches/ehpanda-phase16/round2/audit/`:

- Task 1 / 2 bundles:
  - `a11y-audit-iphone.xcresult`
  - `a11y-audit-iphone-2.xcresult`
  - `a11y-post-fix-iphone.xcresult`
  - `diag-1` … `diag-29b-ipad.xcresult`
- Approval-round bundles:
  - `a11y-approved-iphone-1.xcresult`
  - `a11y-final-iphone-1` / `-2.xcresult`
  - `a11y-final-ipad.xcresult`
  - `approved-1.log`, `final-*.log`
- Directories:
  - `stable-types/`: the 2026-09-14 scope-change runs
  - `iphone265-gate/`
  - `ios27/`: iOS / iPadOS 27 runs
  - `share-fix/`, `share-commit/`: the Safari fix
  - `rootcause-ios27-comments/` (incl. `followup-20260914/`), `rootcause-ios27-contrast/`, `rootcause/`: root-cause investigations
  - `ipad265-recheck/`: the iPad leg
  - `final-gate/`: the 2026-09-15 build log and both iPhone runs

## Known Stubs

None.

## Threat Flags

None: no new network, auth, file or schema surface; the audit runs in UI tests only.
- T-16-03 mitigated: explicit UDIDs, no D-09 destination, no UDID in source, no credential.
- T-16-15 mitigated: two allow-lists, each entry doc-commented, owner replies by id.
- T-16-16 mitigated: every `xcodebuild` ran inside the shared lock, sequentially, and none was killed.

## User Setup Required

None.

## Next Phase Readiness

- 16-25 (manual walkthrough) covers the seven login-gated surfaces the audit cannot reach: Favorites, Watched, Archives, Torrents, EhSetting, FolderManager and Detail Search.
- 16-26:
  - D-25 row 14 (Gallery Detail action row, +3.7 pt) is open.
  - The Nutrition Label should state that the automated gate is best effort over the stable types.
  - Its documented exceptions are `ContentUnavailableView.symbol` and `E-1.hidden-content`.
- Owner items in `deferred-items.md § Found during 16-24`: Toplists placeholder rows, `ContentUnavailableView` symbol, Setting row clip report, Comments anchor under the bar, History fixture, the Favorites cookie-guard flake, and the iPadOS 27 beta Detail stall (re-run on each new seed and on release).

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-15*

## Self-Check: PASSED

SUMMARY, both new test sources and the `PagePlaceholder` colorset present; all 13 plan commits (`5d5844ba` … `7ef11be2`) found in history; ledger count 13 from `8b6abc31`; 0 absolute home paths in the SUMMARY, `16-CONTRAST-AUDIT.md` and `deferred-items.md`; 0 image files in `git status`; both gate simulators Shutdown; shared xcodebuild lock released.
