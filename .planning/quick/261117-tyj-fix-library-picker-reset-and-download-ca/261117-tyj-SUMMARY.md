---
quick_id: 261117-tyj
status: complete
date: "2026-11-17"
subsystem: library-picker-persistence, continued-download-session
requirements: [A-1, A-2, B-1, B-2, B-3]
commits: 3
plan_head_before: 493ed2f4700cf369c65447c812b4419710ab0408
plan_head_after: 93a0663762f5dffa6397dbb733cef91a47c4e4c2
key-decisions:
  - "The compact Library picker's last group is remembered in its own optional record, never in the live selection (A-1, A-2)."
  - "A user-deleted gallery is withdrawn at the deletion boundary, not by the retirement reconcile (B-1, B-2)."
  - "The session seed moves ahead of the client start's hop (B-3)."
---

# Quick task 261117-tyj: Summary

One-line: the compact Library picker reopens on its last choice (a versioned `LibraryPickerChoice`, written only
from the compact layout), and a user-deleted gallery, singly or by folder, leaves the continued-processing card's
X, Y and N entirely, including inside the session start's client hop.

## Commits (all signed, `G`, UTC+8 on both dates)

| Task | Commit | Message |
| ---- | ------ | ------- |
| 1 | 02b8ea594 | Remember the Library picker choice |
| 2 | 25e0a23f9 | Seed continued session before client start |
| 3 | 93a066376 | Drop deleted galleries from the session |

The lint-fix commit 493ed2f47 (owner-approved, made by the orchestrator before this run resumed) is the baseline.

## Baselines (HEAD 493ed2f47)

- LINT: clean. `swiftlint lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension`
  exits 0 with empty output. The first attempt at the earlier HEAD (74d94c62f) had 7 pre-existing violations, which
  stopped the run until they were fixed.
- BUILD: `TEST BUILD SUCCEEDED`. `warnings-baseline.txt` is empty only because the baseline build was fully
  incremental (nothing recompiled, so no warning was re-emitted). Builds that recompile show exactly three warnings,
  all in files this plan does not touch: BlockedCommentPresentationTests and RevealedCommentLineLayoutTests
  (`init(frame:)` deprecation) and ScenarioCatalog+Library (`quickSearch` never mutated). No warning came from a file
  this plan touched.

## Gate results

| Task | BUILD | LINT | TEST |
| ---- | ----- | ---- | ---- |
| 1 | ok | exit 0, empty | AppModelsTests 130 passed, AppFeatureTests 209 passed, DownloadsFeatureTests 519 passed + 6 expected failures; 0 failed (`task1.xcresult`) |
| 2 | ok | exit 0, empty | DownloadsFeatureTests 519 passed + 6 expected failures; 0 failed (`task2.xcresult`); seed-before-start awk gate ok; touched files all at most 1000 lines |
| 3 | ok | exit 0, empty | DownloadsFeatureTests 524 passed + 6 expected failures; 0 failed (`task3.xcresult`); presence gates (3) and absence gates (3) ok; touched files at most 1000 lines (SourceInventoryTests exactly 1000) |

Final whole-plan run (`final.xcresult`, FeatureTests with `-skip-testing:VisualSnapshotTests`, which was compiled
by every BUILD gate): result Passed, 1858 test cases passed, 0 failed, 9 expected failures (`withKnownIssue`),
2980 test runs passed. Per target, passed: AppModelsTests 130, AppFeatureTests 209, DownloadsFeatureTests 524 (+6
expected failures), DetailFeatureTests 199, ReadingFeatureTests 121, NetworkingFeatureTests 117, AnalyticsClientTests
102 (+2), ParserFeatureTests 92, SettingFeatureTests 84 (+1), LiveTextTranslationTests 77, HomeFeatureTests 74,
CookieClientTests 19, FavoritesFeatureTests 18, SearchFeatureTests 16, AppToolsTests 15, GalleryListComponentsTests 13,
TagTranslationFeatureTests 12, MarkdownExtTests 11, ImageClientTests 9, FileClientTests 8, SystemNotificationTests 4,
ImageColorsTests 4.

Simulator `EhPanda iPhone Air` was created by this run and deleted after the final run.

## Deviations from Plan

All recorded from orchestrator rulings or forced by evidence; no design change.

1. **[Evidence] Clearing the key stores JSON `null`; it does not remove the data.** For
   `AppStorageKey<LibraryPickerChoice?>`, both `appStorage<Value: Codable>` overloads in swift-sharing are
   `@_disfavoredOverload`, and the plain Codable one (with `Value = LibraryPickerChoice?`) wins. It uses
   `CodableLookup`, so a `nil` write stores 4 bytes (`null`) instead of calling `removeObject`. Reads still return
   `nil`. Ruling: keep the key and record design (option a). The key doc and the `LibraryPickerChoice` doc now say a
   cleared key stores a JSON `null` that reads as nothing remembered. `writingNilRemovesTheStoredData` became
   `aNilWriteReadsBackAsNothingRemembered`, and the stored-record helper decodes `LibraryPickerChoice?`.
   Evidence: `LibraryPickerChoiceTests.writingNilRemovesTheStoredData` failed on `defaults.data(forKey:) == nil`
   (4 bytes) in the first Task 1 run.
2. **[Evidence] Settling in non-exhaustive persistence tests.** With `exhaustivity = .off`, a bare
   `await store.finish()` leaves received actions queued (an exhaustive step then failed with "Must handle 9
   received actions", and cold-launch cases read `favoritesIndex == -1`). Ruling: call
   `await store.skipReceivedActions(strict: false)` before `await store.finish()`, only in non-exhaustive tests
   (the carry-over case's exhaustive step does not skip).
3. **[Evidence] Where `phoneEntryUsesRememberedFavoritesWithoutResettingItsNavigation` asserts the shared write.**
   The first run failed inside `TestStore.send` for the `deviceChanged` step: the shared `pickerChoice` reads the
   restored value at that step, because the `.send(.showInitialSelection)` effect has already run its reducer (the
   hook writes in the `showInitialSelection` step, since it fires only when the selection changes) and the persisted
   `@Shared` reference is live, while `TestStore.send` yields about 20 times before comparing. The test now asserts
   the write exhaustively as `$0.libraryState.$pickerChoice.withLock({ ... })` in the `send` closure, with the
   selection assertion kept in the `showInitialSelection` receive. Production code is unchanged and correct; the
   test stays exhaustive.
4. **Tests and implementation for Task 1 were written together, not tests first.** The plan's red step would have
   been a compile failure only (the API under test did not exist).
5. **Tolerated pre-existing lint violations first.** HEAD 74d94c62f had 7 SwiftLint violations; the run stopped and
   the orchestrator fixed them in 493ed2f47 before this run resumed.
6. **[Plan literal] Terminal pair after deleting the last gallery.** The plan said `"0 / 1 pages · 0 galleries"`.
   The real subtitle pluralizes one page as `"0 / 1 page · 0 galleries"`; the pair (0 of 1, zero galleries,
   `finishSuccesses == [true]`, no rejected updates) is exactly the plan's intent. The deletion suite pins the pair
   as `PushedPair(completedUnitCount: 0, totalUnitCount: 1, subtitle: "0 / 1 page · 0 galleries")`. Evidence: the
   first Task 3 run failed with the actual subtitle `0 / 1 page · 0 galleries`.
7. **[Scope] Task 2 also touched `DownloadContinuedSessionRunProofTests.swift`** (one doc paragraph that described the
   "POST-start merges"), because the plan's required grep over the doc contracts hit it. Task 3 also reworded three
   suite headers (Basis, LedgerRefusal, Reconciliation) that said the manual index-patch seam "stays private to that
   file", which stopped being true once the seam moved to `DownloadFeatureManifestPatching.swift`.
8. **Task 3 trimmed prose in `DownloadSourceInventoryTests` to stay at exactly 1000 lines** (it dropped the sentence
   recounting the round that added a fourth bracket caller).

## Stub scan, threat flags

No stubs. No new network, auth or file-access surface: the deletion boundary performs no file operation and runs only
after the removal succeeded (T-261117-tyj-04). Nothing was added to the broken-windows ledger.

## Human checks for the owner (on devices)

- iPhone: choose Downloads > a folder in the title menu, force-quit, relaunch, open Library: the same folder shows.
  Choose Favorites, then a category inside the Favorites screen, and repeat: the same category shows. Delete the
  remembered folder in Files and relaunch: Downloads / All shows.
- iPad: pick a sidebar row, force-quit, relaunch: the sidebar opens with nothing selected, as before the fix.
- Download card: queue three galleries, start, background the app; delete one (finished or mid-run) from the app
  (and try once by deleting its folder). The card's "N galleries" drops by one and stays there, X / Y no longer
  include it, and the bar keeps rising with the remaining work.

## Not run

- VisualSnapshotTests was compiled by every BUILD gate but not run (it needs the pinned regression environment).
- No device or UI-test run.

## Orchestrator verification (2026-11-18)

- Hop-deletion discrimination, confirmed. On HEAD 93a066376, with only the three seed statements of
  `ensureContinuedSession` moved back after `startContinuedSessionHeartbeat` (comments unchanged, so `file_length`
  holds), `testADeletionInsideTheClientStartHopLeavesTheSession()` failed (1 test, 1 failed: the first post-start
  pair and the later "2 / 4 pages · 1 gallery" expectation). Restored from git, it passed (1 test, 1 passed). Run on a
  project-named simulator created and deleted for the probe. An earlier probe attempt without the `()` suffix in
  `-only-testing` ran 0 tests; that result was discarded.
- `final.xcresult` read directly: result Passed, 1867 total, 1858 passed, 0 failed, 9 expected failures.
- Commits verified: 493ed2f47 (lint baseline fix), 02b8ea594, 25e0a23f9, 93a066376, each signature G and +08:00 on
  both dates; working tree clean apart from this task folder.
- Pre-existing, out of scope: the UITests target build reports Swift concurrency warnings (main-actor-isolated
  properties used from nonisolated contexts) in several `EhPandaUITests` files on lines this task did not touch.

## Self-Check: PASSED

Created files exist (`LibraryPickerChoice.swift`, `DownloadClient+ContinuedSessionDeletion.swift`, the three new test
files), and the three commits are ancestors of HEAD.
