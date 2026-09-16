# Phase 16 — UI Review

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

## Top 3 Priority Fixes

1. **Owner disposition for Favorites AX5 blank native search capsule (finding #39)** — visible discoverability is degraded in one current D-25 cell; retain as an owner packet item and decide whether a future native-search workaround is warranted after cause is established.
2. **Owner follow-up on reproduced Detail VoiceOver focus reset (W-8)** — focus moved from the uploader to More after a Screen Changed event in 2 of 4 listening launches; cause is unproven and requires targeted investigation.
3. **Owner disposition for Search recent-keyword Delete glyph contrast (W-24)** — the icon nearly disappears in light software grayscale although it is named correctly; this remains deferred pending the owner’s visible-change decision.

## Detailed Findings

### Pillar 1: Copywriting (4/4)

**PASS.** The reviewed state strings use meaningful labels such as Search, Favorites, Watched, Not Found, Retry, Give a Rating, Similar Gallery, and accessibility-specific values for ratings, page positions, balances, and download states. The Search and Favorites implementations use localized resources and explicit toolbar labels (`AppPackage/Sources/SearchFeature/SearchRootView.swift:57-69`, `AppPackage/Sources/FavoritesFeature/FavoritesView.swift:55-67`). Empty and error surfaces are represented by contextual system views and retry actions rather than bare “Submit”, “OK”, or “No data” copy.

The large-font cached states preserve full user-facing headings and empty-state explanation text. No copy defect is promoted from accepted or owner-routed findings.

### Pillar 2: Visuals (3/4)

**WARNING — finding #39.** The cached Favorites AX5 image shows the title and top controls with a very large empty rounded search capsule beneath them. The native search affordance is visually blank in that state, even though the screen remains navigable and its full metadata is reachable. This is the current D-25 rendered finding from the existing prep evidence, recorded in `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/16-26-prep-draft-20260917.md`; the exact Favorites AX5 image and UI evidence are `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-bottom.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-first-row-end.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top-ui.json`, and `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-bottom-ui.json`. Task 26 is the owner/orchestrator destination; repository closure is recorded in `16-SWEEP.md § Re-sweep closure`, where finding #39 remains recorded and owner-pending; this UI report records review evidence and bounded recommendations.

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

**WARNING — W-8 carried.** The final walkthrough reproduced a VoiceOver `Screen Changed` event that moved focus from the uploader to More in 2 of 4 Detail listening launches. The issue is recorded as an unresolved owner-packet item in `deferred-items.md` and `16-SWEEP.md`; its cause is unproven and it can interrupt a user’s reading order.

**WARNING — measurement coverage.** Voice Control spoken-command activation and VoiceOver double-tap activation were not directly measured; the walkthrough contains native-label/Voice Control proxy evidence. The native labels and accessibility actions are present across the audited surfaces, and actual VoiceOver focus and speech work on the simulator, but direct command success is an evidence limit.

**PASS WITH LIMIT.** Loading/error/empty coverage, retry actions, disabled states, Reduce Motion gates, and title/search rendering workarounds are present across the source. Current carried items include W-35 (first More target), VO-3 (Filters dismissal focus), W-13 (Comments dismissal target), W-38 (Reader page/indicator reachability), and W-33/W-34 (phonetic owner judgments). These are retained as carried limits and are not counted as new findings. Duplicate native Close labels in the Reader and the rating DragGesture without an adjustable accessibility action remain documented owner follow-ups.

## Selected Cached Evidence

- **Finding #39 / Favorites AX5:** `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-bottom.png`, `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-first-row-end.png`, and matching `*-ui.json` files; the prep interpretation is in `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/16-26-prep-draft-20260917.md`.
- **W-8:** `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.vot.log` and `L-2.report.txt`, with the reproduction count summarized in `deferred-items.md`.
- **W-24:** `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F2/grayscale-software.png`, with source location `AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift:118-121`.
- **AX typography/layout:** `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F3/ax5.png`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F4/ax5.png`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F8/ax5.png`, and `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`.

## Applicable Accepted and Deferred Limits

- The D-25 rendered scope is the nine-cell Search root, Favorites, and Watched set. Existing resweep evidence records 8 passes and one current #39 finding.
- W-8 is current and reproduced; W-35, VO-3, W-13, W-38, W-33, and W-34 remain carried owner or evidence limits.
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
