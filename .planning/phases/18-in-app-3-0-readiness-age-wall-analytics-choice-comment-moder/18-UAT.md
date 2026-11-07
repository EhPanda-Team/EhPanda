---
status: complete
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
source: 18-01-SUMMARY.md, 18-02-SUMMARY.md, 18-03-SUMMARY.md, 18-04-SUMMARY.md, 18-05-SUMMARY.md, 18-06-SUMMARY.md, 18-07-SUMMARY.md, 18-08-SUMMARY.md, 18-09-SUMMARY.md, 18-10-SUMMARY.md, 18-11-SUMMARY.md, 18-12-SUMMARY.md
started: 2026-11-07T02:37:49Z
updated: 2026-11-07T06:25:00Z
---

## Current Test

[testing complete]

## Tests

Agent-run UAT (owner rule msg 1652), one test per ROADMAP success criterion plus the SUMMARYs' four
`human_judgment: true` items (18-04 D6, 18-09 T3, 18-10 T3, 18-11 T4). Every other SUMMARY coverage entry is
automated and is covered by the runs below.

**Final runs** (`$TMPDIR/v18/`), phone = iPhone Air `FFE7E686…`, pad = iPad Pro 11-inch (M5) `B470DB46…`. Three
fixes landed after the first gate at `87a02f2dd`: `d8e82f4a7` (the revealed line's Hide pill, found re-capturing the
UI review), `57c809770` (a FeatureTests set-up race on the pad) and `856817c26` (the deep link UI tests' orientation,
an 18.1 gap that came back on the pad); each was gated again:

| Run | Phone | Pad |
|-----|-------|-----|
| FeatureTests at `57c809770` | 1811 tests: 1801 passed, 10 expected failures, **0 failed**, 0 Repetition nodes (`ft-phone3`) | 1811 tests: 1801 passed, 10 expected failures, **0 failed**, 0 Repetition nodes (`ft-pad3`) |
| UITests (full plan) | at `57c809770`: 131 tests: 110 passed, 21 skipped (device-specific), **0 failed**, 0 Repetition nodes (`ui-phone2`); `DeepLinkSchemeUITests` again at `856817c26`: 8/8 (`dl-phone`) | at `856817c26`: 131 tests: 113 passed, 18 skipped (device-specific), **0 failed**, 0 Repetition nodes (`ui-pad3`) |
| SwiftLint 0.65.1 `--strict --no-cache` (App, AppPackage/Sources, AppPackage/Tests, EhPandaUITests) | 0 violations in 817 files at `856817c26` | |
| `18-copy-check.py` / `--self-test` / `--readmes` | at `87a02f2dd` (no copy changed since): "36 keys x 6 locales verbatim; 60 retired texts absent" / 22/22 / "6 Analytics sections hold the three levels verbatim" | |
| `test_release.py` | at `87a02f2dd` (no release files changed since): 20 tests OK | |

The Phase 18 UI suites in the final UITests runs, phone / pad: `FirstLaunchUITests` 6/6 / 6/6,
`FirstLaunchTitleLayoutUITests` 6/6 / 6/6, `CommentModerationUITests` 8/8 / 8/8, `SettingsModerationUITests` 3/3 /
3/3, `BlockedUsersTitleLayoutUITests` 6/6 / 6/6, `ReaderRebuildUITests` 4/4 / 4/4, `ReaderPageSyncUITests` 8/8 /
8/8, `AccessibilityAuditUITests` 29 + 1 skip / 30/30.

What the earlier runs found:

- **FeatureTests on the pad, `ReaderListPositionTests`** (fixed, `57c809770`): the first test of the suite, the
  first to run in the host app, found no foreground-active scene after 0.18s at `87a02f2dd` and after 0.47s at
  `d8e82f4a7` (2 of 2 full-plan runs; 19/19 alone). Each test now waits up to 10s for the scene; the next full
  pad run passed and the same test took 3.1s, as on the phone.
- **UITests on the pad, `DeepLinkSchemeUITests` page links** (fixed, `856817c26`): both cases failed 3 of 3
  attempts at `57c809770` (0 failed at `87a02f2dd`), as in 18.1, on a clone that had run `GalleryCardUITests`:
  the reader showed "1 / 156" for page 2, a landscape two-page spread. A temporary class leaving the device in
  landscape before them reproduced it every time; with each test starting in portrait, both pass after it. The
  test that leaves the clone in landscape was not identified.
- **FeatureTests at `87a02f2dd` and `d8e82f4a7`**: otherwise the same counts as above, 0 Repetition nodes. **UITests
  at `87a02f2dd`**: 0 failed on both devices (a first pad run was cut off by the agent harness's 30-minute task
  limit, not by a test, and was run again in full).

**Gap fixes** (`$TMPDIR/v18g/`, after this UAT at `4674bf703`): the four gaps below are resolved, and with them
two of the UI review's warnings. Each fix landed test first; the code ends at `18e85bd92`.

| Gap | Test | Fix |
|-----|------|-----|
| FeatureTests reach e-hentai.org live (major, test 10) | `78a52bf19` | `175baa4f2` |
| Comment filter: short CJK terms inside ordinary words (test 11) | `7744f3916` | `2f11d7e29` |
| AX5 comment-link scroll stops short (test 6) | `bc18ca733` | `b48e5d0ec` |
| A revealed comment's date truncates at AX5 (test 6) | `77a5e6e8a` | `18e85bd92` |
| UI review warning: dark collapsed-card pills (C-8 rev 1.1) | `1aaddb87e` | `75ed2912e` |

UI-SPEC rev 1.1 from design is `2bb5352ed`. The other UI review warning, the Blocked Users large title at AX5, is
**not** resolved: rev 1.1 asks for an inline title at accessibility sizes on C-11 and C-12, but AGENTS.md forbids
text-size-dependent title modes and no owner exception covers the screen (18-UI-REVIEW.md, Pillar 4). UI-SPEC
rev 1.2 from design then kept the plain large title at every size and accepted the system's AX5 truncation, so
the warning is closed as accepted by design, with no code change.

| Run at `18e85bd92` | Phone | Pad |
|-----|-------|-----|
| FeatureTests | 1819 tests: 1810 passed, 9 expected failures, **0 failed**, 0 Repetition nodes (`final-ft-phone`) | 1819 tests: 1810 passed, 9 expected failures, **0 failed**, 0 Repetition nodes (`final-ft-pad`) |
| `CommentModerationUITests` + `AccessibilityAuditUITests` | 40 tests: 39 passed, 1 skipped (device-specific), **0 failed**, 0 Repetition nodes: 10/10 and 29 + 1 skip (`final-ui-phone`) | 40 tests: 40 passed, **0 failed**, 0 Repetition nodes: 10/10 and 30/30 (`final-ui-pad`) |
| Sockets to 172.66.132.196, 172.66.140.62 or 2606:4700:3034::6815:38ca | 0 lines: every process (`lsof -nP -i`, nsurlsessiond included) sampled every 0.25s from 05:55:08Z to 06:19:04Z, across all four runs; the EhPanda and xctest sampler also 0 | |
| SwiftLint 0.65.1 `--strict --no-cache` (App, AppPackage/Sources, AppPackage/Tests, EhPandaUITests) | 0 violations in 819 files | |

The new tests account for the 8 extra FeatureTests. The tenth expected failure,
`SettingReducerTests.defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges`, was the live
`EhProfileRequest` still in flight at `skipInFlightEffects(strict: false)`; the guard now fails it at once, so
usually nothing is left to skip.

### 1. The age wall comes first and gates the app
expected: On a fresh install or an upgrade, the first screen is the age wall, before any content or network request. Continue stays dimmed until the statement is ticked; there is no skip; the answer is kept on the device.
result: pass
source: automated
evidence: "FirstLaunchUITests.testAFreshLaunchShowsOnlyTheAgeWallAndMakesNoRequest, testTickingTheStatementGatesContinue, testContinueStaysPinnedAtTheLargestTextSize, testAnUpgraderWithTheAgeAnsweredOpensOnTheAnalyticsChoice and testALinkOpenedAtTheGateOpensItsGalleryAfterBothAnswers passed on both devices; FirstLaunchGateTests in FeatureTests. The UI review saw the wall unticked, ticked and at AX5 in light and dark (18-UI-REVIEW.md). The live network side (nothing reaches TelemetryDeck before the analytics choice) is the separate check 2c, planned and not run."

### 2. The analytics choice: three levels, none picked, each sends only what it says
expected: After the age wall, Minimal, Basic and Full are equally prominent, nothing is picked, Basic carries "Recommended"; Continue stays dimmed until a level is picked. No SDK call before the choice, none under Minimal beyond the one install signal, and each level sends only what its description says.
result: pass
source: automated
evidence: "FirstLaunchUITests.testTheAnalyticsChoiceStartsEmptyAndRecommendsBasicOnly on both devices; AnalyticsLevelGateTests, AnalyticsClientGateTests, InstallSignalSenderTests and the per-feature AnalyticsEmissionTests in FeatureTests, 0 failed on the phone. Not verified against the live endpoint: see the 2c plan."

### 3. Settings analytics picker
expected: Settings → General has a Share Analytics Data picker with Minimal, Basic and Full, a Privacy Policy row, and a footer showing the selected level's description; the old "installation is still counted" footer is gone.
result: pass
source: automated
evidence: "SettingsModerationUITests.testTheAnalyticsPickerChangesTheLevelAndItsDescription passed on both devices; the UI review captured Minimal, the open picker and Full, default and AX5, light and dark."

### 4. Report on {site}
expected: Every other user's comment offers "Report on E-Hentai" (or ExHentai). Since Phase 18.1 it opens EhPanda's own report form directly (owner msg 1931), with the site's report page as the fallback; there is no email or other contact path.
result: pass
source: automated
evidence: "CommentModerationUITests.testTheMenuOffersReportThenBlockAndReportOpensTheReportForm and testReportOnAStripCardOpensTheReportForm, and ReportFormUITests 8 + 1 device skip, on both devices. The prefill now keeps each run of the comment on its own line (38bae2250)."

### 5. Posting warning
expected: Posting or editing a comment that matches the filter shows "Post this comment?" with Edit (default) and Post Anyway, never names the matched word, and keeps the typed text.
result: pass
source: automated
evidence: "CommentModerationUITests.testAMatchingCommentWaitsForTheSecondTap on both devices; CommentFilterTests and CommentModerationReducerTests (edit path, text kept) in FeatureTests."

### 6. Blocking, collapse, Show / Hide / Unblock, Blocked Users
expected: Blocking a user collapses their comments in the list and the Detail strip into "Comment from a user you've blocked" with Show and Unblock and no name; Show reveals one comment with Hide; the block is stored on the device and matches the member ID; Settings → Account lists blocked users, with a count, an empty state and swipe to unblock.
result: pass
source: automated
evidence: "CommentModerationUITests testBlockCollapsesTheAuthorsCommentsAndShowHideAndUnblockWork, testABlockedAuthorsCardIsCollapsedAndShowAndUnblockWork, testTheUsersOwnCommentOffersNoModeration; SettingsModerationUITests testBlockedUsersCanBeUnblockedBySwipeAndContextMenu and testTheRowCountsZeroAndOpensTheEmptyList; on both devices. The UI review's revealed-line and Detail-card defects were fixed (7bdb55c3f, c2b7d9d5d, d8e82f4a7 and 87a02f2dd, with layout tests); one remains open (Gaps, test 6)."

### 7. Copy in six languages and the READMEs
expected: Every new string is verbatim from the approved copy files, every key is filled in all six locales, and the six READMEs' Analytics sections describe the three levels.
result: pass
source: automated
evidence: "18-copy-check.py exit 0 (36 keys x 6 locales; 60 retired texts absent), --self-test 22/22, --readmes exit 0."

### 8. Reader page tracking (G1/G2)
expected: The reader keeps one current page; the indicator follows the page shown after Reload All Images then a turn, a direction change during Auto-Play, and a left-to-right / right-to-left switch.
result: pass
source: automated
evidence: "ReaderRebuildUITests 4/4 and ReaderPageSyncUITests 8/8 on both devices; ReaderPositionTests in FeatureTests."

### 9. IN-02, IN-03, MKSellsDigitalGoods
expected: verify-release.py forbids captureSystemOverlay and test_release.py covers it; RootView imports AppComponents only in DEBUG; MKSellsDigitalGoods is NO.
result: pass
source: automated
evidence: "verify-release.py:31 b'captureSystemOverlay'; test_release.py 20 OK; RootView.swift:3-5 `#if DEBUG import AppComponents #endif`; App/Info.plist:132-133 `<false/>`."

### 10. Phase gate: UI matches the spec; tests pass on phone then pad; strict lint
expected: The UI matches 18-UI-SPEC.md; FeatureTests and UITests pass on the phone, then the pad, with 0 failures and 0 Repetition; strict no-cache lint is clean.
result: issue
reported: "The final runs pass: FeatureTests and UITests 0 failed and 0 Repetition on both devices, lint 0 violations. Two set-up defects in the tests failed the pad on the way and are fixed (57c809770, 856817c26). Still open: the FeatureTests processes reach e-hentai.org's addresses live on both devices (major gap). The UI review found three layout defects at AX5, one at the default size and one content defect; four are fixed here, one is open (test 6 gap)."
severity: major
source: automated
evidence: "Runs table above. UI review: 20/24 (18-UI-REVIEW.md)."

### 11. Filter list content (18-04 D6, human judgement)
expected: The bundled terms are a conservative set per language: they catch slurs, threats and harassment and do not flag ordinary comments.
result: issue
source: agent review
reported: "Chinese, Japanese and Korean terms match as substrings, and some two-character terms sit inside ordinary words: 去死 is inside 过去死 (as in 我过去死活不信, 'I never believed it before'); and 害児 is inside 障害児, the neutral Japanese word for a disabled child. A match only shows the dismissible warning, so the cost is a false warning, never a blocked post."
severity: minor

### 12. Title line breaks (18-09 T3, 18-10 T3)
expected: The first-launch titles and the Blocked Users empty title never end on a single word (two characters in zh/ja/ko) in any language or size.
result: pass
source: automated
evidence: "FirstLaunchTitleLayoutUITests 6/6 and BlockedUsersTitleLayoutUITests 6/6 on both devices at 87a02f2dd and in the final runs; the line tables in 18-09/18-10 were accepted (owner msg 1903, lead). The UI review saw 'Choose what / EhPanda shares' on the phone and the pad."

### 13. Comment moderation against the mockups (18-11 T4)
expected: The comment menu, Block alert, collapsed row and card, revealed row, posting warning match mockups 05–11 on both devices.
result: pass
source: agent review
evidence: "18-UI-REVIEW.md: default size matches. The revealed line (C-7) was fixed in three steps; the last, d8e82f4a7, keeps Hide on one line beside the wrapping label at the default size, where c2b7d9d5d had left the iPhone Air a three-line 'Hi/d/e'. Re-captured at d8e82f4a7 on the iPhone Air (light and dark default, light AX5) and the iPad (light default). The Detail card (C-8) was fixed at AX5 in 87a02f2dd and re-captured on the iPhone Air (light default, light and dark AX5)."

## Summary

total: 13
passed: 11
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "A revealed comment's header wraps at AX5, as it does before the author is blocked"
  status: resolved
  reason: "UI review: at AX5 the revealed row shows '+7 10/27/24, 3…' (truncated) where the same comment's date wraps to two lines before the block. Seen on the phone, light and dark, at 7bdb55c3f and 38bae2250."
  severity: minor
  test: 6
  artifacts: [AppPackage/Sources/DetailFeature/Comments/CommentsView.swift]
  missing: ["a reproduction outside the List, and the row re-measuring after Show"]
  resolved_by: [77a5e6e8a, 18e85bd92]
  resolution: "The row did re-measure (863pt, with 52pt to spare). The revealed cell's VStack, offered its own height, shared it out equally between the C-7 line and the comment, so the comment's header gave up the date's second line. Each now takes its ideal height. RevealedCommentCellLayoutTests reproduces it outside the List (52pt short at AX5, 40pt at AX3, at phone widths); CommentModerationUITests.testARevealedCommentsDateWrapsAsBeforeTheBlockAtTheLargestTextSize compares the date's frame before the block and after Show at AX5 (190x105pt before, 243x53pt after, until the fix). Passes on both devices."
- truth: "Opening a comment link at AX5 scrolls the linked comment to the top"
  status: resolved
  reason: "Known since 18.1-04 (deviation 8): CommentsView's proxy.scrollTo(…, anchor: .top) after 0.75s sometimes stops short at AX5; the UI tests swipe to work around it (a1afdc81c)."
  severity: minor
  test: 6
  artifacts: [AppPackage/Sources/DetailFeature/Comments/CommentsView.swift]
  missing: ["a scroll that lands at AX5"]
  resolved_by: [bc18ca733, b48e5d0ec]
  resolution: "The list aimed the animated scroll at unbuilt rows by their estimated heights, far below the real ones at AX5, and stopped a row and a half short (1 of 3 cold launches on the iPhone Air, the same offset each time). After the travel the scroll is made again without animation on three turns of the main queue, 0.1s apart. CommentModerationUITests.testACommentLinkAtTheLargestTextSizeLandsOnTheComment, with no swipes: 6/6 cold launches on the phone, then passed on both devices in the final runs. ReportFormUITests keeps its swipe fallback; it no longer has to swipe."
- truth: "The comment filter's CJK terms do not flag ordinary words"
  status: resolved
  reason: "Agent review (test 11): 去死 and 害児 match inside ordinary or neutral words."
  severity: minor
  test: 11
  artifacts: [AppPackage/Sources/DetailFeature/Resources/CommentFilterTerms.json]
  missing: ["an owner or native-speaker decision on the CJK terms (DD-04 is a content call)"]
  resolved_by: [7744f3916, 2f11d7e29]
  resolution: "No term was removed or weakened. CommentFilterTerms.json can now list, for a term, the ordinary words that hold it; an occurrence inside one of them does not match, and the term anywhere else in the same text still does. 去死 lists 过去死/過去死; 害児 lists 障害児/被害児/加害児. CommentFilterTests cover the four ordinary sentences (both scripts; 障害児, 被害児童) as non-matches, and 去死 and 害児 on their own and beside an exception word as matches; 47/47 with CommentModerationReducerTests. The five exception words are content too: they still want the owner's or a native speaker's look (DD-04)."
- truth: "FeatureTests make no live network connection"
  status: resolved
  reason: "Seen again at 87a02f2dd, now on both devices: the phone run's DownloadsFeature, AppFeature and SettingFeature test processes held TCP 443 connections to e-hentai.org (172.66.132.196) from 02:38:37Z to 02:38:46Z; the pad run's test processes to the same address and a Cloudflare IPv6 address from 02:57:19Z to 02:57:29Z. Carried from 18.1. Seen again at 57c809770: the phone run's test processes to 172.66.132.196, 172.66.140.62 and 2606:4700:3034::6815:38ca, port 443, from 04:01:14Z to 04:01:24Z; the pad run's to the same addresses from 03:57:27Z to 03:57:40Z."
  severity: major
  test: 10
  artifacts: []
  missing: ["the test that reaches a live dependency"]
  resolved_by: [78a52bf19, 175baa4f2]
  resolution: "The request types default to URLSession.shared and the reducers build them inline, so effects a test started without a stub went out live: the Home front page, popular and toplist fetches, the gallery detail fetch, the settings sign-in cascade (profile, igneous, user info, favourite categories; SettingReducerTests' default-profile case among them), and a download coordinator on the shared session fetching the latest gallery page. Before the fix, the SettingFeature, AppFeature, HomeFeature and DownloadsFeature test targets alone opened 12, 6, 1 and 61 sampled sockets to 172.66.132.196 and 2606:4700:3034::6815:38ca. A TestNetworkGuard target, linked into every test target and never the app, installs a URL protocol at bundle load for the shared session and every default and ephemeral configuration, and fails any request no test stubbed with a not-connected error (a test's own stub is asked first; loopback is left alone). TestNetworkGuardTests is the regression guard. Final runs: 0 sockets to the three addresses from any process, nsurlsessiond included, on both devices."
