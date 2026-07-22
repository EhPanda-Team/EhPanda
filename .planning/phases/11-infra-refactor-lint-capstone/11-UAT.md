---
status: complete
phase: 11-infra-refactor-lint-capstone
source: [11-VERIFICATION.md]
started: 2026-07-21T00:00:00Z
updated: "2026-07-22T03:39:43Z"
---

<!--
verify:pre gate override (2026-07-21): the `api-coverage.verify-pre` gate blocked with
`detected: true, signals: [{verb: "(surface)", noun: "api"}]`. Traced to a single
branch-(b) regex hit on the phrase "the existing Colorful API" in 11-07-PLAN.md:78 —
an internal SwiftUI library's API surface, not an external-API integration. Phase 11
integrates no external API. Confirmed a detector false positive by independent review;
gate treated as overridden so UAT could proceed. Reported upstream against
`gsd-core/bin/lib/api-coverage.cjs` (`SERVICE_SURFACE_API_RE`, no verb required).
-->

## Current Test

[testing complete]

## Tests

### 1. Owner batch review of the 8 lint exceptions (D-01/D-02)

expected: |
  Read `11-EXCEPTIONS.md`. Confirm all 8 phase-created disables are warranted:
  6 `lifecycle_modifiers` (per-page fetch/prefetch, image `.task(id:)` cancellation,
  reader teardown, toast timer, alert focus hop, thumbnail decode) and 2
  `unchecked_subscript_index_access` (PreviewSupport subscript, GalleryHistory op).
  Decide the surfaced option: narrow `lifecycle_modifiers` to exempt `.task(id:)`
  (would remove 3 of the 6). This is a config decision left explicitly to you.
result: pass
decision: "All 8 exceptions accepted as warranted. Surfaced config option declined —
  `lifecycle_modifiers` stays as-is; `.task(id:)` is NOT exempted, so all 6 lifecycle
  disables remain."

### 2. Animated image (GIF / WebP) still renders as animated

expected: |
  11-17 rewrote 14 unchecked byte reads in `AnimatedImageFeature/AnimatedImage+.swift`,
  which has NO test target — correctness rests on argument, not automated coverage.
  Open a gallery whose pages are animated GIFs (or an animated WebP), enter the reader,
  and confirm frames still animate and the first frame is not mis-detected as static.
result: pass

### 3. Detail page for a gallery with zero favourites parses

expected: |
  `parseInfoPanel`'s all-eight-fields-non-empty contract rejects the whole detail
  parse rather than degrading one field. Open the detail page of a gallery with
  zero favourites and confirm it loads (title, tags, rating, favourite count = 0)
  rather than failing to parse.
result: pass
source: code-inspection
resolution: "Live sourcing is infeasible — even the newest-posted gallery already carries 400+
  favourites (owner, 2026-07-22). Resolved by reading the parser instead, which is the stronger
  evidence here. Parser+Detail.swift:266-271 maps E-Hentai's zero-favourite rendering
  'Favorited: Never' to '0' (alongside 'Once'->'1'). So favoritedCount = '0', which is non-empty,
  so the all-eight-fields guard at :275 passes and the detail parses. The 'Never'->'0' mapping
  exists precisely because the developer already handled this case. A live test on a 400+-fav
  gallery would render 'Favorited: N times' and never exercise the 'Never' path, so inspection
  covers the edge case that device testing structurally could not reach."

### 4. Reader opens on the saved page in LTR and RTL, slider works

expected: |
  11-09 migrated reader scroll seeding into an `.onChange(initial: true)`. Open a
  part-read gallery in a left-to-right reading direction, confirm it opens on the
  saved page; repeat in right-to-left; then drag the page slider and confirm the
  preview tray thumbnails populate on first reveal and keep filling as you drag.
result: pass

### 5. GalleryCardCell colour bloom on the Home carousel

expected: |
  11-07 folded the card's colour bloom into `.onChange(of: colors, initial: true)`.
  Scroll the Home carousel and confirm each card's gradient blooms in rather than
  popping abruptly on first appearance.
result: pass

### 6. Tab-reselect and pop-back loads behave

expected: |
  Lifecycle migration changed several loads from view-appearance to presentation.
  Confirm: Favorites/Search re-run their guarded load on tab re-selection without a
  visible double-load; popping back from a Detail push into Downloads still shows the
  right folder contents; returning from the login flow refreshes the account screen's
  login state.
result: pass

### 7. List pagination — fetch-more on scroll to end

expected: |
  Scrolling a gallery list (front page, and presumably every list) to the bottom
  fetches the next page and appends more galleries.
result: pass
initially: issue
reported: "frontpage list (probably all lists) fetch more feature is broken, it just reach the end and won't fetch more"
severity: blocker
found_during: out-of-band observation while testing (not a scripted checkpoint)
retest: "Owner device re-test 2026-07-22 after 11-30. Confirmed: paginates past three pages in
  BOTH .detail (the fix) and thumbnail (the control) display modes. The .onScrollVisibilityChange
  primary form fires correctly inside a List row — the runtime unknown is resolved, fallback not
  needed."

### 8. Gallery cell page-count symbol sizing

expected: |
  The page-count indicator symbol in the gallery cell renders at its prior size.
result: pass
initially: issue
reported: "the symbol indicating page count looks larger before it became label — i meant the symbol in gallery cell"
severity: cosmetic
found_during: out-of-band observation while testing (not a scripted checkpoint)
retest: "Owner visual re-check 2026-07-22 after 11-31. Confirmed: page-count symbol back to prior
  size in the gallery cell; Torrents sheet stat icons also correct. .imageScale(.medium) is right."

### 9. Detail-list row separator inset

expected: |
  The `List` row separator in the gallery list (detail mode) spans from the text-column leading
  edge (past the thumbnail) across to the trailing edge.
result: pass
initially: issue
reported: "the list row separator became extremely short ... expected separator expands to the
  trailing edge of the gallery image from the trailing edge of the cell, but currently it only
  extends like ten px from the trailing edge of the cell"
severity: cosmetic
found_during: out-of-band observation after phase completion (post-verification regression)
retest: "Owner verified 2026-07-22 in the live iPhone Air Simulator (sim-use screenshot): separators
  span the full width, no sliver. Gallery list AND torrents list both pass — TorrentsView was NOT
  modified and renders correctly on its own (its rows carry a leading Label that anchors the
  separator correctly), so the earlier regression-#4 hypothesis for TorrentsView was falsified."

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0
blocked: 0

<!--
Final tally: 9/9 pass.

- Tests 1,2,4,5,6: passed during initial UAT.
- Tests 7 (G-11-7 blocker) and 8 (G-11-8 cosmetic): found as issues, diagnosed, fixed by plans
  11-30/11-31, confirmed on device 2026-07-22.

- Test 3: pass by code inspection (live sourcing infeasible — no zero-favourite gallery exists in
  the wild; parser handles the 'Favorited: Never' rendering at Parser+Detail.swift:266-271).

- Test 9 (G-11-9 cosmetic): found AFTER phase completion — a post-verification regression from the
  same 6dd51b00 "Overall UI adjustments" HStack->Label sweep that caused G-11-8. Fixed directly
  (commit 141e3d56, not a gap-closure plan) and verified in-Simulator. Phase left complete.
Gaps G-11-7, G-11-8, G-11-9 status: resolved.
-->

## Gaps

- gap_id: G-11-7
  truth: "Scrolling a gallery list to the end fetches and appends the next page"
  status: resolved
  resolved_by: 11-30-PLAN.md
  resolved_at: 2026-07-22
  confirmed: "Owner device re-test 2026-07-22 — paginates past three pages in both .detail and
    thumbnail modes. Runtime unknown resolved; primary .onScrollVisibilityChange form works."
  fix_shipped: "PRIMARY form, not the fallback. `.onScrollVisibilityChange` on the row Button
    inside DetailList's ForEach; `.autoLoadNextPage(...)` deleted from that List.
    AutoLoadNextPage's body, guards, thresholds and state are untouched — it was rescoped by
    deleting its DetailList call site plus a doc-comment rewrite. No reducer, no
    Setting.listDisplayMode, no @State on DetailList. Commits: 8325c5c5, d7b90d8a, 96592d0d."
  unverified: "COMPILE-LEVEL AND STRUCTURAL ONLY. Not runtime-confirmed: whether the trigger
    fires on arrival at the trailing row, paginates past three pages, holds on a second surface,
    and leaves thumbnail mode unchanged. All four need an owner device re-test in BOTH display
    modes. If the row-level callback turns out never to fire inside a List, the sanctioned
    fallback is `.onScrollTargetVisibilityChange(idType:)` + `.scrollTargetLayout()`."
  reason: "User reported: frontpage list (probably all lists) fetch more feature is broken, it just reach the end and won't fetch more"
  severity: blocker
  test: 7
  hypothesis_refuted: "Original hypothesis (paginate migrated to a presentation-time reducer
    action) is REFUTED. `.fetchMoreGalleries` is still a per-scroll view-driven send and the
    reducers are correct. The defect is trigger substitution, not reducer hoisting."
  root_cause: "Commit ebc99f5e 'refactor(11-11): drop component lifecycle hooks' deleted
    DetailList's per-row trailing-cell trigger — `.onAppear { if gallery == galleries.last
    { fetchMoreAction?() } }` — and replaced it with `.autoLoadNextPage(…)`, a scroll-geometry
    heuristic lifted verbatim out of ThumbnailList. That heuristic was designed, tuned and
    device-validated in Phase 2 under D-36 for ONE layout only: a single eagerly-measured
    masonry List row with FetchMoreFooter INSIDE that row. D-36's record states the constraint
    explicitly and scoped itself out of detail mode. DetailList has precisely the structure
    D-36 forbids: many lazy rows with estimated heights, and FetchMoreFooter as a standalone
    sibling row. The proximate kill switch is the one-shot latch `lastAutoFetchCount !=
    galleryCount` (GalleryList.swift:296) — the only guard in the chain that cannot
    self-recover, since re-arming needs galleries.count to change and only a fetch can change
    it. Once consumed without a net append (deduped insertGalleries, empty page, failed fetch,
    or a spurious fire during transient underfilled-viewport geometry while lazy rows are still
    materializing), pagination for that list is permanently dead. Setting.listDisplayMode
    defaults to .detail, so this is the path essentially every user is on — hence 'all lists'."
  artifacts:

    - path: "AppPackage/Sources/GalleryListComponents/GalleryList.swift"
      issue: "PRIMARY. DetailList.body (L124-150): last-cell .onAppear trigger deleted, replaced by .autoLoadNextPage (L144-149). AutoLoadNextPage (L253-302): guard chain L292-299; non-recoverable latch lastAutoFetchCount != galleryCount (L296) + assignment (L298). DetailList also emits FetchMoreFooter as a SIBLING row (L139-141) — the exact structure D-36 records as breaking geometry-keyed pagination."

    - path: "AppPackage/Sources/AppModels/Persistent/Setting.swift:91"
      issue: "listDisplayMode default .detail — not a defect, but why the blast radius is every list."

    - path: ".planning/phases/11-infra-refactor-lint-capstone/11-11-SUMMARY.md:86"
      issue: "Asserts 'Strictly fewer redundant fetches, never fewer pages' — the incorrect assumption that let this ship. L168 correctly flagged detail-mode pagination as needing device UAT."
  cleared_not_implicated: "FrontpageReducer.swift (fetchMoreGalleries guards + insertGalleries
    correct); PageNumber.hasNextPage() / isNextButtonEnabled parsing; Gallery.id (= gid, stable
    String cursor); Request+Gallery.swift lastID plumbing."
  affected_lists: "All seven surfaces rendering through GalleryList in the default .detail mode:
    Frontpage, Watched, Favorites, Search, Toplists, History, Detail Search. Thumbnail mode is
    NOT a phase-11 regression (validated on device since Phase 2) but shares the latent latch."
  missing:

    - "Restore an edge-triggered trailing-cell signal in DetailList's ForEach row body: `.onScrollVisibilityChange { isVisible in guard isVisible, gallery == galleries.last else { return }; fetchMoreAction?() }` — the faithful per-scroll-arrival analogue of the deleted trigger. Works on individual List rows, needs no scrollTargetLayout()."
    - "Remove .autoLoadNextPage from DetailList (L144-149) — do not run both triggers, that reintroduces double-fetching"
    - "Do NOT add a view-local re-entrancy latch. FrontpageReducer.swift:140-143 and siblings already guard hasNextPage() + footerLoadingState != .loading and set .loading synchronously before returning the effect, so a duplicate send is a no-op. This is what made the original .onAppear correct without a view-side guard."
    - "Restore AutoLoadNextPage to thumbnail-only scope (its D-36 home), or gate it on display mode — stop applying it to a layout D-36 records as incompatible"
    - "SEPARATE, PRE-EXISTING: harden the latch for thumbnail mode — re-arm on the server cursor (pageNumber) rather than galleries.count, so a deduped or empty page cannot permanently disarm pagination. Today only the manual FetchMoreFooter retry recovers, and in DetailList that footer renders only while footerLoadingState != .idle."
    - "Add a standing UAT item: verify pagination in BOTH display modes — .detail being the default masked the thumbnail path and now vice versa"
  rule_compliance: "The lifecycle_modifiers rule (.swiftlint.yml:138-145) is
    regex `\\.(onAppear|onDisappear|task)\\s*(\\(|\\{)` at severity error. Verified against the
    live regex: `.onScrollVisibilityChange {`, `.onScrollTargetVisibilityChange(idType:) {` and
    `.scrollTargetLayout()` produce NO match, while `.onAppear {` and `.task {` do. The fix needs
    no disable, no rule edit, no severity change — clean at error by construction. It also
    respects the rule's intent rather than routing around it: the rule targets view-appearance
    lifecycle, and scroll-visibility is a genuinely different signal (what is on screen in a
    scroll container, not when SwiftUI mounts a view) — the same distinction the repo already
    relies on at PreviewsView.swift:62-69. NOTE: this is one case where 11-07's stated pattern
    ('make the PRESENTING reducer fire the child's former effect') is the WRONG migration target
    — pagination is per-scroll-arrival, not per-presentation."
  confidence: "High that ebc99f5e is the regression and that removing DetailList's last-cell
    trigger is the cause (unambiguous diff, .detail verified default, all seven lists share the
    path, D-36 independently documents the layout incompatibility). Medium on the precise failing
    guard — could not run the app, so (A) trigger fires but the latch permanently one-shots vs
    (B) the geometry predicate is never satisfied in DetailList's lazy estimated-height List
    remains undistinguished. The proposed fix resolves both, since it discards the geometry
    heuristic for this layout entirely."
  falsification_test: "RUN 2026-07-22. Set Appearance -> list display mode to `thumbnail` and
    scrolled a multi-page list. RESULT: thumbnail mode paginates correctly; only .detail is
    broken. This CONFIRMS the layout-structural mismatch and raises confidence on the mechanism
    from medium to HIGH. AutoLoadNextPage's guard set is not generally defective — it is
    incompatible with DetailList's lazy estimated-height layout, exactly as D-36 recorded.
    Consequence for planning: trigger substitution in DetailList is the PRIMARY fix; hardening
    the `lastAutoFetchCount` latch is a separate pre-existing robustness follow-up, not a
    blocker for this gap."
  confidence_final: high
  debug_session: ".planning/debug/g-11-7-fetch-more-broken.md"

- gap_id: G-11-8
  truth: "The page-count symbol in the gallery cell renders at its prior size"
  status: resolved
  resolved_by: 11-31-PLAN.md
  resolved_at: 2026-07-22
  confirmed: "Owner visual re-check 2026-07-22 — symbol back to prior size in gallery cell and
    Torrents sheet. .imageScale(.medium) confirmed correct over the plan's .small default."
  fix_shipped: "All six sites ship `.imageScale(.medium)` — NOT the `.small` the plan defaulted to
    and this gap's `missing` list recommended as repo precedent. Settled by measuring inked glyph
    bounds in a real List, not by eye: baseline (pre-6dd51b00 bare Image) 16.25x13.25; unfixed
    Label 21.0x17.25 (~29% wider); `.small` 13.0x10.75 (undershoots baseline by 3.25pt);
    `.medium` 16.25x13.5 (matches). `.small` would have traded one appearance regression for
    another. Commits: 01b79ff7, 66f08295, 5c58d3e2, 23db6fcd."
  diagnosis_corrected: "The recorded mechanism in this gap's root_cause was FALSIFIED by
    measurement. Free-standing, a Label's icon is pixel-identical to a bare Image (both 20x16 at
    .footnote) — titleAndIcon does not inflate the icon on its own. The inflation is LIST-SPECIFIC.
    The six-sites conclusion still holds but for a different reason: ThumbnailList wraps the whole
    MasonryLayout in one eager List row, so the masonry grid is inside a List too. Had the
    list-specific mechanism been known first, the thumbnail cell would have looked exempt and been
    missed. Debug note corrected in commit ab19f888."
  no_regression_test: "This plan ships NO automated regression test. A parity test measuring glyph
    ink bounds in a real List was built and RED/GREEN-verified (fails on .small, passes on .medium)
    — it produced every number above — then removed: rendering a List needs a UIWindow
    (ImageRenderer draws an unsupported-content placeholder), every scene-free UIWindow initializer
    is deprecated on iOS 26, and the test host exposes no UIWindowScene. Keeping it meant shipping
    a deprecation warning, which policy forbids. Remaining protection is the grep gate plus the
    owner's visual check."
  unverified: "Dynamic Type at accessibility sizes not empirically confirmed — the structural
    guarantee holds (relative scale, zero absolute point sizes, gate-verified) but the AX3 fixture
    could not fit four rows in the render frame. Also unverified without a device: the Torrents
    sheet and the download-badge branch. CAUTION: re-checking in a free-standing #Preview will show
    NO difference at all — the effect exists only inside a List."
  reason: "User reported: the symbol indicating page count looks larger before it became label (symbol in gallery cell)"
  severity: cosmetic
  test: 8
  root_cause: "Commit 6dd51b00 (phase-11 UI sweep) rewrote the page-count indicator from
    `HStack(spacing: 2) { Image(systemSymbol:); Text(...) }` into
    `Label(...).labelIconToTitleSpacing(2)`, driven by the custom `label_text_image_shorthand`
    rule (error). The ambient font is unchanged (`.footnote` before and after) and neither
    version sized the icon explicitly — so the diff isolates the cause: a bare `Image`
    renders an SF Symbol at the ambient font's default symbol scale (.medium), whereas a
    `Label` icon under the default `titleAndIcon` style is sized from the label's own
    font/line metrics, yielding a visibly larger glyph at the identical font. The project's
    `Label(_:systemSymbol:)` shim is ruled out (composes Text + Image verbatim, no sizing)."
  artifacts:

    - path: "AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift:82"
      issue: "Reported site (masonry/thumbnail grid). Label icon unconstrained; only .labelIconToTitleSpacing(2). Font .footnote from enclosing HStack:90."

    - path: "AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift:133"
      issue: "Same regression, list/detail cell style. Also reached via DownloadsView+Subviews (2 sites), so it shows on Downloads too."

    - path: "AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift:74-95"
      issue: "Sibling regression, 4 icons (seed/peer/download counts, file size), identical mechanism."
  sibling_sites: "6 conversions total share the mechanism. NOT affected (checked and cleared):
    DetailView+HeaderSection, DetailView+Subviews, ToolbarItems, CommentsView, FolderManagerView,
    QuickSearchView — all carry .labelStyle(.iconOnly) with an explicit .font(...), which pins
    icon size. The regression class is confined to inline `titleAndIcon` Labels that replaced
    an HStack { Image; Text }."
  missing:

    - "Reassert explicit relative icon scale on GalleryThumbnailCell:82 and GalleryDetailCell:133"
    - "Same on the 4 TorrentsView labels — one .imageScale on the shared HStack:95 covers all four"
    - "Do NOT revert to HStack — reintroduces a `label_text_image_shorthand` error (.swiftlint.yml:103); suppression is forbidden by project policy"
    - "Prefer the icon-closure form (Label { Text } icon: { Image().imageScale(.small) }) — innermost, so it beats any ambient default. Lint-legal: the rule's regex needs Image(systemSymbol:) followed immediately by `}`, so an interposed .imageScale breaks the match. Precedent: ListNoticeView.swift:22"
    - "Pick .small vs .medium by visual A/B against 6dd51b00^ using the existing #Preview in each cell file (renders pageCount: 1234, .sizeThatFitsLayout). Repo precedent is .small; .medium is theoretical parity with a bare Image"
    - "Consider extracting the shared icon+count shape into one view in GalleryListComponents — the construct is now duplicated across both cells and can drift again"
  dynamic_type_note: ".imageScale is relative — it selects a symbol scale variant against the
    resolved font size rather than imposing a point size. With the surrounding font staying
    .footnote (a Dynamic Type text style), the symbol keeps scaling across all content size
    categories incl. AX1-AX5, matching pre-change behaviour. MUST NOT pin .font(.system(size:))
    on the icon — that would freeze the glyph and fail the later Dynamic Type phase."
  confidence: "High on the causal chain (single introducing commit, font held constant, shim
    ruled out, no ambient labelStyle above the cells). Medium on the precise enum value —
    settled by one visual A/B. Icon-closure form is recommended regardless, since it sidesteps
    the open question of whether .imageScale on a Label propagates into the icon under the
    default titleAndIcon style on iOS 26."
  debug_session: ".planning/debug/g-11-8-page-count-symbol-size.md"

- gap_id: G-11-9
  truth: "The detail-list row separator spans from the text-column leading edge (past the thumbnail) to the trailing edge"
  status: resolved
  resolved_by: "direct fix, commit 141e3d56 (not a gap-closure plan — post-completion cosmetic one-liner)"
  resolved_at: 2026-07-22
  severity: cosmetic
  test: 9
  found_post_completion: true
  reason: "User reported the detail-mode gallery-list separator collapsed to a ~10pt right-side sliver instead of spanning past the thumbnail."
  root_cause: "The 6dd51b00 'Overall UI adjustments' HStack->Label sweep (same commit as G-11-8)
    opted the page-count element into a default-styled `Label`. A default-styled `Label` in a
    `List` row publishes a `.listRowSeparatorLeading` anchor at its title's leading edge; because
    this Label sits at the row's TRAILING edge, that anchor collapsed the separator to a sliver.
    Confirmed by pixel measurement in a List render harness: bug = leading 349.7 / length 11.3;
    correct = 119.3 / 241.7. The anchor is NOT intrinsic to the `Label` type — it is published
    only by the Label's default/automatic style-resolution path; routing the Label through ANY
    explicit `.labelStyle(...)` drops the anchor."
  artifacts:

    - path: "AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift:137-147"
      issue: "Page-count Label (default style) at the row's trailing edge hijacked the separator inset."
  fix_applied: "Added `.labelStyle(.titleAndIcon)` to the page-count Label, with a comment marking
    it load-bearing (NOT a redundant restatement of the default style — a future 'remove redundant
    modifiers' pass would silently regress the separator). Restores the separator to 119.3 / 241.7,
    pixel-identical to correct; icon appearance unchanged (keeps .imageScale(.medium)). Considered
    alternatives: `.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }` (documented, states
    intent directly), a custom LabelStyle (works, more code), and a whole-row-as-Label restructure
    (empirically rejected — mispositions the inset AND overlaps the thumbnail)."
  verification: "Built + launched in the live iPhone Air (iOS 26.5) Simulator via sim-use; owner
    confirmed the gallery list separators span full width. Owner also confirmed the Torrents list
    renders correctly WITHOUT any change — TorrentsView (also a List with trailing stat Labels) was
    NOT modified; the regression-#4 hypothesis for it was falsified."
  reusable_lesson: "The `label_text_image_shorthand` lint rule pushes `HStack { Image; Text }` ->
    `Label`. In a `List` row, a default-styled `Label` at the TRAILING edge hijacks the row
    separator's leading inset (collapses it) — and, per G-11-8, its icon also inflates vs a bare
    Image. Any future HStack->Label sweep on List-row content must account for both side effects.
    Fixes: an explicit `.labelStyle(...)` (drops the separator anchor) and/or an explicit
    `.imageScale(...)` on the icon (restores glyph size)."
