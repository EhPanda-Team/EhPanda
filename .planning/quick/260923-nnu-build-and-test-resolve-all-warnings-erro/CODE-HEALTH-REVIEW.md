# Code health follow-up — 2026-09-23

The repository builds and lints cleanly under its configured rules, but it still contains unresolved
behavior, test-isolation debt, and cleanup work. Expected-failure counts alone do not describe that
state.

## Scope and evidence

Inspected the current source, test plans, previous run logs, and recorded deferred items. Searched all
591 tracked Swift files for unfinished-work markers and test/lint exceptions; parsed all 23 tracked
string catalogs. Followed candidate findings into current implementation to reject stale notes.
This is a targeted debt audit, not an exhaustive correctness or security review of every code path.
No application code changed and no new test execution was needed for these source findings. The
Auto-Play finding uses the preceding full UI run and its retained evidence.

## Confirmed actionable findings

### 1. Thumbnail pagination can remain disarmed after a fetch adds no galleries

- Source: `AppPackage/Sources/GalleryListComponents/GalleryList.swift:313` and `:341`.
- Priority: P2, functional correctness.
- `lastAutoFetchCount` records the current count before fetching and permits another automatic fetch
  only when that count changes. An empty, deduplicated, or failed fetch can leave the same count and
  block subsequent automatic requests even when another page exists. Manual footer retry is the
  recorded recovery. The existing G-11-7 note in `.planning/STATE.md:948` remains applicable to the
  current code; this audit did not perform a new device reproduction.
- Remedy: model pagination request/re-arm state explicitly around the page cursor and request
  outcome, preserving the guard against endless bottom-of-list fetch loops. Verify both thumbnail
  and detail modes, including no-new-item responses, failures, and underfilled viewports.

### 2. iPad Auto-Play still has an unexplained failed first attempt

- Sources: `EhPandaUITests/ReaderPageSyncUITests.swift:56`,
  `EhPandaUITests/Support/ReaderPageProbe.swift:240`, and `UITests.xctestplan:12`.
- Priority: P2, unresolved behavior/test reliability.
- The preceding full run failed to select Off; the selection remained at 1 second and pages kept
  advancing. The retry passed. The plan permits up to three attempts, so a final green result does
  not establish first-attempt reliability. Whether the root cause is app behavior, SwiftUI, or input
  delivery remains unproven.
- Remedy: resolve the selection failure and require a gate with no failed attempts. Do not treat
  the successful retry as a fix. Detailed evidence is preserved in `260923-nnu-SUMMARY.md`.

### 3. The profile-routing unit test starts a live network side effect

- Sources: `AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift:32`,
  `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift:84`, and
  `AppPackage/Sources/NetworkingFeature/Request+Account.swift:247`.
- Priority: P2, test isolation and coverage.
- Receiving `.createDefaultEhProfile` launches a live POST. The test cancels in-flight effects
  without asserting request completion. Its comment says the request has no injectable session,
  but the request initializer already accepts `urlSession`; the missing seam is at the reducer.
- Remedy: expose the operation through a controllable dependency, provide an offline test response,
  and assert the originating host and completion without racing a live request. This replaces
  `skipInFlightEffects(strict: false)` as the method of terminating this finite operation.

### 4. Empty cookie rows claim to be valid

- Sources: `AppPackage/Sources/AppModels/Support/CookieValue.swift:14` and
  `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift:244`.
- Priority: P2, misleading account-state presentation; also recorded in Phase 16 deferred items.
- `CookieValue.empty.isInvalid` is false. The view interprets every non-invalid value as Valid and
  shows a checkmark, including an absent cookie. The boolean conflates absence with validity.
- Remedy: distinguish missing, invalid, and present states in the presentation; do not infer
  authenticated validity merely from the absence of a known invalid marker.

### 5. Download validation contains unused and ineffective animation code

- Source: `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:130`.
- Priority: P3, cleanup and misleading implementation comments.
- `progressAnimation` has no references. The spinner uses `.visible(isValidating)`, an opacity
  modifier, while the comment promises an insertion/removal scale transition. The view remains in
  the hierarchy, so that transition is not activated by the visibility toggle.
- Remedy: remove unused code and either implement the intended transition through actual view
  insertion/removal while preserving layout, or remove the inactive transition and describe the
  opacity behavior accurately. Keep the accepted Reduce Motion behavior.

### 6. Two Traditional Chinese translations are still English

- Source: `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings:5526` and `:5567`.
- Priority: P3, localization.
- `vote_down` and `vote_up` in `zh-Hant` contain `Vote down` and `Vote up`, both marked translated.
- Remedy: supply Traditional Chinese translations and retain the catalog's locale coverage.

## Existing accepted limitation, separate from newly actionable findings

The user-rating control remains drag-only in
`AppPackage/Sources/DetailFeature/DetailView+Subviews.swift:286`, with no adjustable accessibility
action. This limitation was explicitly retained in the Phase 16 walkthrough and best-effort closure;
it is not a newly discovered regression or a reason to undo that sign-off. It remains a real
capability limitation for assistive interaction if future work expands the accepted scope.

## Test and lint exceptions are not a bug count

- Nine of the eleven expected-failure results are intentional negative tests. Two are skipped-effect
  reports; only the live finite request above establishes isolation debt from that pair. Ending the
  separate account subscription is legitimate when its lifecycle is covered elsewhere.
- There are 149 `.exhaustivity = .off` sites in 44 Swift files and 28 SwiftLint disable directives
  in 21 Swift files. These are existing exception sites, not 177 confirmed defects. Examples include
  focused analytics assertions, teardown of view-owned tasks, and frozen preview fixture data.
  Individual justification must be assessed before changing them.
- The two iPhone UI skips are for iPad-only presentations, not unfinished tests.
- The accessibility audit intentionally covers three audit categories and uses documented
  owner-approved/system-owned exceptions. Passing it is not a claim of complete accessibility
  coverage; preserve the approved best-effort scope.

## Stale records and checks that passed

- Zero TODO/FIXME/HACK/XXX/WIP markers were found in tracked Swift files. Deferred work is recorded
  mainly in `.planning`, so a clean marker search is not evidence of no debt.
- All 23 string catalogs parse as strict JSON; no `shouldTranslate: false` entry lacks a locale
  used elsewhere in its catalog. The old malformed-catalog note is stale.
- `.planning/STATE.md:947` still lists removed legacy haptics symbols as an open task. Neither
  symbol exists in current source. `.planning/PROJECT.md:107` calls the private-category fix pending,
  while the same document correctly records its completion at line 37.
- The old observer-batching flake note is superseded by the frozen clock in
  `AppPackage/Tests/DownloadsFeatureTests/DownloadObserverBatchTests.swift:75`.
- The Phase 15 deferred-items introduction says DEF-15-07 remains open, but the entry itself says
  CLOSED, NOT A DEFECT. Reconcile these records before deriving a backlog mechanically.

Prioritize pagination, the Auto-Play failure, and the live-request test seam. Follow with account
status semantics, animation/localization cleanup, and reconciliation of stale planning records.
