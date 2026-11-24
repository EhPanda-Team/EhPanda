---
phase: quick-261123-355
verified: 2026-11-24T00:09:20Z
status: human_needed
score: 11/11 must-haves verified in code and records; pointer drawing and two unexplained captures await the owner
covered_files:
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-01-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-01-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-02-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-02-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-03-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-03-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-04-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-04-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-05-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-05-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-06-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-06-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-07-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-08-PLAN.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-08-SUMMARY.md"
  - ".planning/quick/261123-355-pointer-hover-effects-on-every-interacti/261123-355-SUMMARY.md"
  - "AppPackage/Package.swift"
  - "AppPackage/Sources/AppComponents/AppToggle.swift"
  - "AppPackage/Sources/AppComponents/CategoryView.swift"
  - "AppPackage/Sources/AppComponents/CheckboxToggleStyle.swift"
  - "AppPackage/Sources/AppComponents/ChoiceCard.swift"
  - "AppPackage/Sources/AppComponents/FirstLaunchContinueButton.swift"
  - "AppPackage/Sources/AppComponents/LibraryTitleMenu.swift"
  - "AppPackage/Sources/AppComponents/StateViews.swift"
  - "AppPackage/Sources/AppComponents/TagSuggestionView.swift"
  - "AppPackage/Sources/AppFeature/View/Library/LibraryView.swift"
  - "AppPackage/Sources/AppTools/InteractiveHover.swift"
  - "AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift"
  - "AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift"
  - "AppPackage/Sources/DetailFeature/Comments/CommentsView.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift"
  - "AppPackage/Sources/DetailFeature/DetailView.swift"
  - "AppPackage/Sources/DetailFeature/GalleryInfo/GalleryInfoView.swift"
  - "AppPackage/Sources/DetailFeature/Moderation/BlockedCommentCard.swift"
  - "AppPackage/Sources/DetailFeature/Moderation/CommentModerationMenu.swift"
  - "AppPackage/Sources/DetailFeature/Moderation/ReportFormView.swift"
  - "AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift"
  - "AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift"
  - "AppPackage/Sources/DownloadsFeature/DownloadGalleryItem.swift"
  - "AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift"
  - "AppPackage/Sources/DownloadsFeature/DownloadsView.swift"
  - "AppPackage/Sources/FiltersFeature/FiltersView.swift"
  - "AppPackage/Sources/GalleryListComponents/GalleryList.swift"
  - "AppPackage/Sources/HomeFeature/HomeGalleryInformation.swift"
  - "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
  - "AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift"
  - "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift"
  - "AppPackage/Sources/ReadingFeature/Support/ReadingToolbar.swift"
  - "AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift"
  - "AppPackage/Sources/SearchFeature/SearchRootView.swift"
  - "AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift"
  - "AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift"
  - "AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift"
  - "AppPackage/Sources/SettingFeature/Components/AboutView.swift"
  - "AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift"
  - "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift"
  - "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift"
  - "AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift"
  - "AppPackage/Sources/SettingFeature/Login/LoginView.swift"
  - "AppPackage/Sources/SettingFeature/SettingView.swift"
  - "AppPackage/Sources/SystemNotification/View+Toast.swift"
  - "AppPackage/Tests/AppToolsTests/HoverShapeTests.swift"
  - "AppPackage/Tests/AppToolsTests/PointerHoverAuditTests.swift"
  - "AppPackage/Tests/AppToolsTests/PointerHoverScanner.swift"
  - "AppPackage/Tests/AppToolsTests/PointerHoverScannerTests.swift"
covered_digest: "v4:sha256:1fcd2a0deb26db1899412c6f8f6d6489375568de4929a647158f4309dfa67fe4"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "11/11 in code, 1 documentation gap"
  gaps_closed:
    - "SUMMARY IN-01 wording (reader passes DragGesture) corrected"
  gaps_remaining: []
  regressions: []
---

# Quick task 261123-355: Pointer hover effects on every interactive element, Third Verification Report

**Task goal:** Pointer hover effects on every interactive element of the app's iOS code, with nothing moved at rest.
**Verified:** 2026-11-24T00:09:20Z (UTC), source HEAD ac9604b23 (unchanged since the last pass)
**Status:** human_needed. No gap remains. Pointer drawing cannot be checked here, and two captures the base code does not clearly explain are for the owner to accept or reject.
**Re-verification:** Yes. Earlier reports: initial (2 gaps, closed by plan 08), second (1 documentation gap, now closed).

## What I checked this pass

1. **IN-01 entry** (`261123-355-SUMMARY.md` line 351, "Review findings not acted on (plan 08)"). It now reads: `previewControlPanel()` passed a `TapGesture()` before this task and passes a `DragGesture()` now, the type `ReadingView` passes (`controlPanelDismissGesture`), and was left. That matches the code: `ReadingView+Gestures.swift:53-54` is `DragGesture().onEnded {...}`; `ControlPanel.swift:418` is `dismissGesture: DragGesture()`. **Correction to my second report:** I wrote that the preview change was made in plan 07. `git show 0873fa450` (plan 01, `hover: add helpers and plain-button hovers`) is the commit that replaces `TapGesture()` with `DragGesture()`, and `git log -S'dismissGesture: DragGesture()'` finds only that commit. The summary is right and my attribution was wrong. Gap closed.
2. **Counts and Known limits.**
   - Summary section 2's `diag2 p08` (8 lines) and `diag3 p08` (16 lines) are identical, line for line, to `.capture/261123-355/logs/counts.txt` lines 41-64.
   - The "what each was" text matches the result files: in `p08/diag2`, `base-2` changed four `settings-pages-general` pictures (`-basic` and `-full`, light and dark) and `tree-4` changed `search-clear-confirmation`; the other six runs changed nothing. In `p08/diag3` all sixteen runs are `passed=32`, and the only second-attempt pictures are `search-typing-suggestions` in base-7, base-8 and tree-3.
   - **front-page-search** (`...accessibility5__portrait__iphone__light`): `p08/diag2/base-1` shows `passed`, attempts 2, flaky; its `first-actual` is pixel-identical (`getbbox()` is `None`) to the `first-actual` in `p08/phone.failed-1`. So the base code draws that picture too, and A-08-3's first rule ("seen in a base run: the base code does it too; recorded, accepted") applies. Verified. The differing hashes I noted earlier (`fdeffa69`, `8779be55` against `e634370a`) are the same instability family, and the summary's statement that no cause is claimed is right.
   - **search-clear-confirmation** (`...accessibility5__portrait__iphone__light`): I tallied every `results.jsonl` under `p07` and `p08`. Tree: 16 observations (p07 phone and failed-1, p08 phone and failed-1, diag2 tree-1..4, diag3 tree-1..8), 15 passed with hash `73a78ebb` and 1 changed (`diag2/tree-4`, attempts 2, hash `df1977a7`). Base: 12 observations (diag2 base-1..4, diag3 base-1..8), 12 passed, all `73a78ebb`. This equals the summary's "tree 15 passed and 1 changed, base code 12 passed and 0 changed". The sixteen `SearchSnapshotTests` repeats all passed it at the first attempt with one hash, so A-08-4's last rule applies ("not seen: recorded as one unexplained tree capture, for the owner"). The summary says exactly that, and states the caveat that the repeats ran one class and the changed capture came from a run of all classes. Verified; this is not a gap but an open owner decision (human item 6).
3. **Cleanup line** (summary line 316: P8 done). `git worktree list` shows no base worktree for this task (only the repository root and three other worktrees, one being this one); `.capture/261123-355/` has no `base` directory and keeps `candidate`, `logs`, `p01`-`p08`, `scratch` and the probe and udid files; `xcrun simctl list devices` finds 0 devices with this task's `(261123-355)` id. Two other simulators listed belong to other work and are not this task's. The app tree is clean (`git status` shows no change under `App` or `AppPackage`). Info: `261123-355-08-SUMMARY.md` line 67 still reads "Cleanup (P8): pending"; it is a plan-level record written before P8 and the consolidated summary has the final state, so I do not count it.

## Standing results (unchanged, re-confirmed)

- Source is unchanged since the last pass; the earlier checks stand: the helpers use system effects only, audit census 21 with seven reasoned allowances and floor 10, RED and bite proofs, scanner moved verbatim apart from the two new kinds and the three behaviour-equivalent rewrites, `clippedAt` removed everywhere, footer gated by `.hoverEffectDisabled(!footerLoadingState.is(\.failed))`, header title and uploader buttons in SL-08, 1589 tests passed on the final tree, lint equal to the baseline (3 pre-existing errors in untouched files), commits dated `+0800`.
- At-rest compare against the unmodified candidate: phone 1614, pad landscape 810, pad portrait 802 plus the two A-07-5 keys, which are pixel-identical to the base code's captures (checked in plan 07 and again for plan 08). `changed=0` is not met literally for pad portrait; the exception is disclosed.

## Human Verification Required

Hover drawing cannot be observed by any method available here, so every item is open until the owner's iPad pass (summary section 11), in light and dark: the hover shape matches the visible corners, no second effect, nothing moved.

1. **Footer flat while loading.** In a gallery list, hover the spinner footer during fetch-more: no highlight; in the failed state: highlight. This tests that the outer `.hoverEffectDisabled(!failed)` wins over the helper's inner `hoverEffectDisabled(false)`, which the summary says follows SwiftUI's documentation and which I could not show. If it still lights, use another mechanism (gate `cellRowHover` itself, or `.disabled`).
2. **Failed footer tap area versus highlight.** The highlight is the whole row; the retry Button's label is only the icon. Check that a tap anywhere in the highlighted row retries, or that the highlight is not misleading.
3. **Exclusion glyphs.** 44 pt circles inside their own cell, overlapping no row above or below; tap area is a circle, not the full column; VoiceOver still reads each as a Toggle "Exclude <language> <category>".
4. **Date-seek buttons.** Whether `ButtonBorderShape.buttonBorder` draws the glass capsule as a hover shape.
5. **front-page-search AX5 portrait.** Recorded and accepted by A-08-3 because the base code draws the same picture; the owner may note the instability.
6. **One unexplained Search capture (owner accepts or rejects).** `search-clear-confirmation__en__accessibility5__portrait__iphone__light` changed in both attempts in `p08/diag2/tree-4`: the "Remove All" dialog's glass background was not drawn. Over all compare runs holding the key: tree 15 passed, 1 changed; base code 12 passed, 0 changed. Sixteen single-class repeats did not reproduce it, and the run that changed it covered all classes (the base code has four such runs at this text size). Search's only source change in this task is one `hoverShape` on the history cards. Neither this task nor the base code is shown to be the cause; it is a glass background missing from one capture, not a layout move.
7. Everything else on the section 11 checklist: Reading settings rows (every row highlights, not cut at the row's text), first launch cards and Continue, error toast, reader (Live Text circle, SL-01, page zones flat), Library title menu and sidebar rows full-screen and in a narrow window (where the highlight ends relative to the chevron), Comments (linked image, moderation circle, pills), Settings (root rows, Laboratory SL-02, switches with the label flat, Language buttons, SL-09, SL-10, Copy Cookies), Archives, the Detail header (SL-04, read circle, Retry capsule, the title and uploader buttons in SL-08, tag chips, Post Comment, Torrents magnet, Gallery Info values), Home, Search, gallery list rows and grid tiles, Downloads, Filters and Quick Search, Report Form, state views, Login chevron, the highlight extent (8 pt inside the cell where the side margin is 20 pt, 4 pt where it is 16 pt, inferred), and the Reading switch bypassing `AppToggle`.

## Info

- `261123-355-CONTEXT.md` (D-03, D-06, D-08, D-13) still describes `clippedAt`; D-13 has no line for plan 08's removal. Bookkeeping only.
- `ControlPanel.swift:185-189`: `.hoverShape(.capsule)` followed by `.visible(!showsSliderPreview)` (opacity only).
- `261123-355-08-SUMMARY.md:67` still says Cleanup is pending (see above).

---

_Verified: 2026-11-24T00:09:20Z_
_Verifier: Claude (gsd-verifier)_
