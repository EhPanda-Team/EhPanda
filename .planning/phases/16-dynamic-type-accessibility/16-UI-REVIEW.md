# Phase 16 — UI Review

## Current refresh — 2026-09-23

**Baseline:** Abstract six-pillar native SwiftUI standards, Phase 16 owner decisions, and the repository's native iOS 27 title/search and soft top scroll-edge policies. No UI-SPEC applies.
**Source:** `7675a7ac77301de9464a8e924c9fc8c70f691849` (orchestrator-supplied tested source); documentation baseline `5ef04717`.
**Method:** Source inspection and existing evidence only. No build, test, simulator operation, browser, dev-server launch, or new screenshot capture was performed by this reviewer. Screenshot-directory creation and dev-server detection were omitted under the explicit report-only scope; no media was written to the repository. The historical review below is retained as dated evidence, not current status.
**Status:** Whole-phase 16-26 Task 3 owner approval and remaining closing work are pending. This refresh does not complete Phase 16 or A11Y-02.

### Current pillar scores

| Pillar | Score | Current finding |
|---|---|---|
| Copywriting | 4/4 | PASS: localized task labels remain specific; W-33 ordinary P M and W-34 MiB pronunciation now have bounded owner verification. |
| Visuals | 3/4 | WARNING, accepted: historical Favorites AX5 blank native search capsule #39 remains a measured quality limitation; it is not a pass or a newly reproduced iOS 27 defect. |
| Color | 3/4 | WARNING, deferred: W-24's pale Delete glyph remains a documented salience limitation; current source still uses secondary styling. |
| Typography | 4/4 | PASS within reviewed evidence: semantic scaling and layout budgets remain; iOS 27 uses native title/search behavior, with no removed workaround credited. |
| Spacing | 4/4 | PASS within reviewed evidence: adaptive gallery layouts and persistent Detail action controls remain; Search Delete now has a 44-point minimum target. |
| Experience Design | 3/4 | WARNING, coverage: fifteen unreached surfaces, spoken Voice Control activation and nonreader native double-tap flows remain unverified. Accepted focus behavior and W-38 are closed within their exact scopes. |

**Overall: 21/24.** Scores are retained individually; acceptance of a limitation does not erase its observed quality cost. No new source defect or BLOCKER was established by this refresh. Passing scores describe the inspected scope, not every screen, device or assistive-technology flow.

### Top 3 priority follow-ups

1. **Complete current-source closing evidence and owner review.** Retain failed historical bundles and report final iPad results separately when available; do not infer a full gate pass from focused reader tests or the phone result. Present the bounded result for 16-26 Task 3 approval.
2. **Close the explicit interaction coverage gaps before making broader accessibility claims.** Exercise the fifteen unreached surfaces with their required fixtures/accounts, spoken Voice Control commands, and native VoiceOver double-tap in nonreader flows; record each action and outcome separately. These are evidence tasks, not proven product defects.
3. **Retain the deferred W-21/W-24 visual decisions.** If the owner later authorizes visible changes, review W-21's ContentUnavailableView symbol and strengthen the Search Delete glyph's salience, then compare light/dark and grayscale states. No palette or symbol change is authorized by this audit, and accepted #39 is not reopened.

### Current evidence by pillar

**1. Copywriting — PASS (4/4).** Search root now presents direct localized Quick Search and Filters toolbar actions (`AppPackage/Sources/SearchFeature/SearchRootView.swift`); the old generic More navigation assumption is obsolete. Keyword deletion retains the localized `Label(.RLocalizable.delete, systemSymbol: .xmark)` at `SearchRootView+Keywords.swift:118`. Reader slider semantics express current and total page values (`AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift:146`). The latest owner-disposition table in `16-SWEEP.md` closes W-33 for ordinary P M and W-34 for MiB only; neither is pending pronunciation work.

**2. Visuals — WARNING, accepted limitation (3/4).** The D-25 result remains exactly nine iPhone portrait cells: Search root, Favorites and Watched at XXL, AX3 and AX5; eight passes and accepted #39. Its September 17 cached images are historical, not new iOS 27 rendering measurements. No new blank-capsule reproduction is claimed. The reviewer directly inspected the September 23 W-38 `page-41-panel-check.png`: placeholder 41 and panel 41 / 156 are simultaneously visible, with separated native upper controls and a bottom slider. A still image proves that final visual agreement only; continuous native VoiceOver behavior and owner acceptance come from the dated recording provenance in `16-W38-ROOT-CAUSE.md`.

**3. Color — WARNING, deferred (3/4).** The Delete glyph still has `.imageScale(.small)` and `.foregroundStyle(.secondary)` (`AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift:120-121`). Historical light grayscale W-24 evidence remains relevant as a carried limitation, not a newly measured contrast ratio. The added target frame at line 122 addresses touch area, not glyph contrast. Historical contrast-remediation proposals and owner-reverted palettes are not counted as installed fixes. No web 60/30/10 token distribution or Tailwind accent count is applicable to this native interface; no new quantitative palette measurement was performed.

**4. Typography — PASS (4/4).** `GalleryThumbnailCell.swift:21,50,91` and `GalleryDetailCell.swift:181,204` retain scaled metrics, line budgets and intrinsic fitting. The reader control cap at `ControlPanel.swift:53` remains the specific owner-approved exception. `FavoritesView.swift:67` retains `.inlineLarge`; current Search root uses native search/title behavior. The migration removed both AccessibilityNavigationTitleWorkaround and AccessibilitySearchableWorkaround: historical claims that those implementations are present are superseded. Native titles require independent standard/AX1/AX3/AX5 cold-entry and live-size evidence; D-25's nine cells do not substitute for that broader matrix.

**5. Spacing — PASS (4/4).** `GalleryDetailCell.swift:124,129,204` preserves responsive vertical/horizontal arrangements; `GalleryThumbnailCell.swift:91` uses intrinsic fitting. Detail uses persistent `HeaderActionsLayout` controls (`DetailView+HeaderSection.swift:273`), rather than the removed alternate view trees. Search Delete explicitly has `minWidth: 44, minHeight: 44` (`SearchRootView+Keywords.swift:122`). The migration inventory records all 46 page roots and their effective scroll hosts, including independent presentations; Search root's direct soft/top policy and Favorites/Watched logged-out policy remain in source. That inventory proves source coverage, not visible blur on every page or fresh runtime spacing verification.

**6. Experience Design — WARNING, bounded coverage (3/4).** W-8/W-35 were accepted on September 22 with their recorded focus behavior. VO-3/W-13 Comments remain the September 20 Apple-bug disposition with no local workaround. W-38 was accepted and closed September 23 after the page 1→41 native VoiceOver recording; production reader index logic is unchanged. Reader panel reveal now has bounded native double-tap evidence, so the older blanket statement that double-tap was never measured is obsolete. It does not establish activation in other walkthrough flows. The fifteen unreached surfaces and spoken Voice Control remain explicit gaps. W-21/W-24 stay deferred. Loading/error/empty/retry and Reduce Motion coverage documented below is retained without claiming these gaps are covered.

### Current validation provenance and limits

The orchestrator reports FeatureTests at 1,055 passes plus eleven expected failures, Repetition 0; strict SwiftLint at zero violations across 586 files; and a fresh code review of 98 files with zero findings. The final phone UI gate reports 52 passes, zero failed attempts and two expected skips. The final iPad gate was pending when this refresh was prepared. These are supplied orchestrator results, not runs executed by the UI reviewer. Earlier failed iPad bundles remain historical failures; corrected probe geometry and the autoplay menu postcondition are test-helper changes, not reader production fixes. See the dated continuation at the end of `16-SWEEP.md` for the preserved diagnostic chain.

The directly inspected current reader image is `$HOME/.codex/visualizations/2026/09/22/01a0c704-1c73-75c1-ba0d-1c1acd596cdf/w38-recording/page-41-panel-check.png`. Other cached images and contrast measurements cited below retain their original dates. The native iOS 27 migration summary and `SCROLL-EDGE-INVENTORY.md` in `.planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/` supersede historical workaround/stall implementation descriptions; they do not supply universal runtime acceptance.

Registry safety: not applicable; no shadcn component registry is in scope. Review output changes only this report. No source fixes, test changes, index changes, commits, new SUMMARY or VERIFICATION, or phase-completion claim are part of this refresh.

### Refresh files audited

- Phase 16 plans 01–26, summaries 01–25, CONTEXT, existing UI review, current SWEEP dispositions/continuation, FOCUS-INVESTIGATION, W38-ROOT-CAUSE, CONTRAST-AUDIT, and deferred-items.
- iOS 27 migration summary and SCROLL-EDGE-INVENTORY.
- Current SearchRootView and SearchRootView+Keywords; FavoritesView; WatchedView; GalleryDetailCell; GalleryThumbnailCell; DetailView+HeaderSection; ReadingFeature ControlPanel.
- Repository AGENTS and SwiftLint policy; GSD UI review workflow, Swift accessibility and SwiftUI review guidance.



### Orchestrator closing-gate addendum — 2026-09-23

The earlier 52-pass phone count was an in-progress snapshot supplied to the reviewer. Final bundles now
show iPhone 54 passes/two expected iPad-only skips and iPad 56 passes/no skips; both have zero failures
and zero Repetition nodes. Evidence: `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260923/uitests-{iphone,ipad}-final.*`.
This updates test provenance only; the review scores, visual evidence limits and pending whole-phase
owner checkpoint are unchanged.

## Historical review — September 17, with earlier follow-up annotations

The following material preserves its original scores and evidence. Pending owner decisions, workaround implementations and runtime status in this historical section are superseded by the dated current refresh above.

Pre-owner review prepared on immutable source b01add4c11b1f9c355ac8f2e055ed8b24fe8146c; owner 16-26 Task 3, verifier, and completion remain pending; no new source or test was added.

**Audited:** 2026-09-17  
**Baseline:** Abstract six-pillar native iOS/SwiftUI standards, constrained by Phase 16 context, AX policy, sweep ledger, contrast audit, and owner rulings  
**Screenshots:** Existing cached evidence inspected; no new captures (scope explicitly excludes browser/dev-server, simulator/device actions, and repository screenshot storage)
**Status:** Awaiting owner disposition; this report records evidence and bounded recommendations only.

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | User-facing empty, login, error, retry, and accessibility labels are specific and contextual; no generic CTA pattern found in the audited UI. |
| 2. Visuals | 3/4 | AX5 layouts retain hierarchy and readable controls, but Favorites AX5 has a large blank native search capsule while title and metadata remain reachable. |
| 3. Color | 3/4 | Historical contrast measurements exist, but the current palette retains owner-reverted/default treatments and the Search Delete glyph remains pale/low-salience in light grayscale. |
| 4. Typography | 4/4 | Dynamic Type sizing, line budgets, and inline-large title policy are consistently implemented; inspected AX5 evidence preserves readable hierarchy. |
| 5. Spacing | 4/4 | Adaptive stacks, measured width gates, scaled metrics, and deliberate accessibility spacing preserve usable bounds in the reviewed states. |
| 6. Experience Design | 3/4 | Loading/error/empty and Reduce Motion coverage is substantial, but VoiceOver focus can reset on Detail and Voice Control command activation was not directly measured. |

**Overall: 21/24**

## Current Owner Follow-up Priorities

1. **Owner decisions for the Detail focus findings (W-8/W-35)**: both are explained as of 2026-09-19 (`16-FOCUS-INVESTIGATION.md § Root-cause round (2026-09-19)`). W-8 is a system-side deferred `Screen Changed` with no app-side lever found and awaits an owner disposition; W-35 follows the platform first-element rule and awaits an owner choice among three recorded options.
2. **Search/Comments dismissal findings (VO-3/W-13 Comments)**: decided 2026-09-20 as Apple-bug handling with no local fix. The cause is SwiftUI bridging a `Label`-labeled toolbar control to a native bar button item that drops the focus binding; the evaluated `Image`-label workaround was not adopted (`16-FOCUS-INVESTIGATION.md § Root-cause round (2026-09-19)`).
3. **Reader reachability (W-38)**: the app fix implemented on 2026-09-19 was withdrawn by the owner on 2026-09-21 after it made scrolling to the last page jitter, so the page/indicator mismatch is open and unfixed (`16-W38-ROOT-CAUSE.md § Attempted fix, withdrawn`).


## Detailed Findings

### Pillar 1: Copywriting (4/4)

**PASS.** The reviewed state strings use meaningful labels such as Search, Favorites, Watched, Not Found, Retry, Give a Rating, Similar Gallery, and accessibility-specific values for ratings, page positions, balances, and download states. The Search and Favorites implementations use localized resources and explicit toolbar labels (`AppPackage/Sources/SearchFeature/SearchRootView.swift:57-69`, `AppPackage/Sources/FavoritesFeature/FavoritesView.swift:55-67`). Empty and error surfaces are represented by contextual system views and retry actions rather than bare “Submit”, “OK”, or “No data” copy.

The large-font cached states preserve full user-facing headings and empty-state explanation text. No copy defect is promoted from accepted or owner-routed findings.

### Pillar 2: Visuals (3/4)

**ACCEPTED OWNER RULING — finding #39.** The cached Favorites AX5 image shows the title and top controls with a very large empty rounded search capsule beneath them. The native search affordance is visually blank in that state, even though the screen remains navigable and its full metadata is reachable. This is the current D-25 rendered finding from the existing prep evidence, recorded in `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/16-26-prep-draft-20260917.md`; the exact Favorites AX5 image and UI evidence are `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-bottom.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-first-row-end.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top-ui.json`, and `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-bottom-ui.json`. Task 26 is the owner/orchestrator destination; `16-SWEEP.md § Re-sweep closure` records finding #39 as an accepted Apple native-search bug with no app fix requested; this UI report records review evidence and bounded recommendations.

**PASS WITH LIMIT.** Existing Detail, Reader, Favorites, Watched, and Search captures show clear focal hierarchy, native glass/capsule controls, readable action rows, and preserved tab navigation at large accessibility sizes. The reader upper control panel remains one line under its owner-approved Dynamic Type cap (`AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift:51-55`), and Detail action buttons remain visually bounded in the inspected AX5 evidence.

### Pillar 3: Color (3/4)

**WARNING — W-24 carried.** `SearchFeature/SearchRootView+Keywords.swift:118-121` renders the icon-only Delete control with `.foregroundStyle(.secondary)`. The cached light-mode grayscale evidence shows the pale green glyph nearly disappearing. Its VoiceOver and Voice Control names are correct, so this is a visual salience/contrast defect rather than an activation blocker.

The contrast audit’s measurements are historical evidence; the current checkout does not retain those proposed color remediations. The checked sources show the default treatments: `RatingView.swift:85,92,96,100` uses .yellow; `CommentsView.swift:171,176` uses .tint without the proposed underline; and `DownloadsView.swift:220,226,231,247` retains its existing action tints. The proposed RatingStar colorset is absent. Owner-reverted/accepted palette decisions, including Read-on-accent, remain closed and are not represented as current implementation claims. W-24 remains deferred pending owner disposition.

### Pillar 4: Typography (4/4)

**PASS.** The implementation uses Dynamic Type environment values, scaled metrics, width-based layout decisions, explicit line limits where the design budget requires them, and the documented inline-large title workaround policy. Representative evidence includes `GalleryThumbnailCell.swift`, `GalleryDetailCell.swift`, `HomeFeature/GalleryCardCell.swift`, `CategoryView.swift`, and `SettingFeature/SettingView.swift`. Cached AX5 images retain readable titles, headings, badges, page controls, and empty-state copy without promoting a new clipping finding.

The reader panel’s `.dynamicTypeSize(.large... .xxLarge)` is the explicitly authorized owner exception and is documented at the call site (`ControlPanel.swift:51-55`); it is not treated as a general Dynamic Type failure.

### Pillar 5: Spacing (4/4)

**PASS.** Accessibility layouts use deliberate vertical spacing and restored horizontal insets, scaled corner radii, measured width gates, and adaptive stacks. The implementation avoids relying on a single fixed portrait/orientation branch for gallery rows (`GalleryDetailCell.swift:148-175`) and preserves the two-column floor for thumbnail layouts. Existing large/AX5 evidence shows controls remain separated from neighboring cards, the tab bar remains reachable, and the reader slider row retains room for both single-line page values.

No fresh spacing regression is supported by the cached evidence. Historical spacing findings are represented by their closed or accepted dispositions in `16-SWEEP.md`.

### Pillar 6: Experience Design (3/4)

**WARNING — W-8 is system-side; owner disposition required.** The final walkthrough reproduced a VoiceOver `Screen Changed` event that moved focus from the uploader to More in 2 of 4 Detail listening launches. The issue remains open in `deferred-items.md` and `16-SWEEP.md`. The 2026-09-19 round characterizes it as one deferred SpringBoard `Screen Changed` per app activation, landing at a nondeterministic time, with no app-side lever found (`16-FOCUS-INVESTIGATION.md § Root-cause round (2026-09-19)`); it can interrupt a user’s reading order and is not accepted as a system limit by this review.

**WARNING — measurement coverage.** Voice Control spoken-command activation and VoiceOver double-tap activation were not directly measured; the walkthrough contains native-label/Voice Control proxy evidence. The native labels and accessibility actions are present across the audited surfaces, and actual VoiceOver focus and speech work on the simulator, but direct command success is an evidence limit.

**PASS WITH LIMIT.** Loading/error/empty coverage, retry actions, disabled states, Reduce Motion gates, and title/search rendering workarounds are present across the source. W-35 requires the owner decision recorded in SWEEP; VO-3 and the W-13 Comments slice are handled as an Apple bug with no local fix by owner ruling (2026-09-20); W-38 is open again after its implemented fix was withdrawn on 2026-09-21; W-33 is in revision for ordinary “P M” pronunciation. W-34 is an implemented fix with owner phonetic verification passed. Apart from the VO-3 and W-13 Comments ruling, these current items are not accepted system limits. Duplicate native Close labels in the Reader and the rating DragGesture without an adjustable accessibility action remain documented owner follow-ups.

## Selected Cached Evidence

- **Finding #39 / Favorites AX5:** `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-bottom.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-first-row-end.png`, and matching `*-ui.json` files; the prep interpretation is in `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/16-26-prep-draft-20260917.md`.
- **W-8:** `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.vot.log` and `L-2.report.txt`, with the reproduction count summarized in `deferred-items.md`.
- **W-24:** `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F2/grayscale-software.png`, with source location `AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift:118-121`.
- **AX typography/layout:** `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F3/ax5.png`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F4/ax5.png`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F8/ax5.png`, and `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`.

## Applicable Accepted and Deferred Limits

- The D-25 rendered scope is the nine-cell Search root, Favorites, and Watched set. Existing resweep evidence records 8 passes and one accepted #39 finding; the owner identifies #39 as an Apple native-search bug with no app fix requested.
- W-8 and W-35 are explained and await owner decisions, and VO-3 and the W-13 Comments slice are handled as an Apple bug with no local fix by owner ruling of 2026-09-20 (`16-FOCUS-INVESTIGATION.md § Root-cause round (2026-09-19)`); W-38 is open again after its implemented fix was withdrawn on 2026-09-21; W-33 is in revision for ordinary “P M” pronunciation; W-34 is confirmed within the MiB pronunciation scope and is not a carried limit.
- W-24 remains an owner-visible-change decision. Accepted platform/native rulings and the owner’s contrast reversions are preserved.
- The iPadOS 27 Gallery Detail stall remains deferred on the beta runtime; the evidence does not establish a CPU or glass-menu cause, so this report records it without causal attribution.
- No registry audit applies: this is a native SwiftUI project with no shadcn/third-party component registry in scope.
- No source, test, git, repository planning, or screenshot files were changed by this audit.

## Files Audited

- `.planning/phases/16-dynamic-type-accessibility/16-CONTEXT.md`
- `.planning/phases/16-dynamic-type-accessibility/16-AX-POLICY-REVIEW.md`
- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md`
- `.planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md`
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md`
- `.planning/phases/16-dynamic-type-accessibility/16-01…16-26-PLAN.md`
- `.planning/phases/16-dynamic-type-accessibility/16-01…16-25-SUMMARY.md`
- `AppPackage/Sources/AppComponents/AccessibilitySearchableWorkaround.swift`
- `AppPackage/Sources/AppComponents/AccessibilityNavigationTitleWorkaround.swift`
- `AppPackage/Sources/AppComponents/CategoryView.swift`
- `AppPackage/Sources/AppComponents/RatingView.swift` (current `.yellow` treatments checked at lines 85, 92, 96, 100)
- `AppPackage/Sources/DetailFeature/Components/LinkedText.swift` and `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` (current link styling checked; no proposed underline claim)
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift` (current action tint sites checked at lines 220, 226, 231, 247)
- `AppPackage/Sources/AppComponents/ViewModifiers.swift`
- `AppPackage/Sources/DetailFeature/DetailView.swift`
- `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift`
- `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift`
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift`
- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift`
- `AppPackage/Sources/HomeFeature/Watched/WatchedView.swift`
- `AppPackage/Sources/SearchFeature/SearchRootView.swift`
- `AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift`
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift`
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift`
- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift`
- `AppPackage/Sources/SettingFeature/SettingView.swift`
- `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift`
- `AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift`
