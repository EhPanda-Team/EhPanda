---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "04"
subsystem: comment-moderation
tags: [moderation, ugc, filter, cookies, sharing, swift-testing]

requires: []
provides:
  - "`CommentFilter.matches(_:terms:)` and `CommentFilter.normalized(_:)`: the pure posting filter (DD-04)"
  - "`CommentFilterTerms` with `bundled` (loaded once from `DetailFeature/Resources/CommentFilterTerms.json`) and `load(from:)`"
  - "`CommentReportTarget.reportURL(for:)`, `site(for:)`, `siteName(for:)`: the gallery's report page on its own host (D-10)"
  - "`CommentOwnership.isOwn(_:didLogin:displayName:)`: the own-comment rule (A-10)"
  - "`@Shared(.blockedCommentAuthors)` plus `[String].block(author:)`, `unblock(author:)`, `isBlocked(author:)` (DD-10)"
  - "`CookieClient.sessionCookies(for:)`: the read-only, host-scoped session read for the report sheet (A-5)"
affects: [18-05, 18-10, 18-11, comment-moderation, settings-blocked-users]

actuals:
  tokens: 10200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Script-aware term matching: whole words for spaced scripts, substrings for Han, kana and Hangul"
    - "Bundled data resource loaded once through `static let` with a throwing `load(from:)` the tests call directly"

key-files:
  created:
    - AppPackage/Sources/DetailFeature/Moderation/CommentFilter.swift
    - AppPackage/Sources/DetailFeature/Moderation/CommentFilterTerms.swift
    - AppPackage/Sources/DetailFeature/Resources/CommentFilterTerms.json
    - AppPackage/Sources/DetailFeature/Moderation/CommentReportTarget.swift
    - AppPackage/Sources/DetailFeature/Moderation/CommentOwnership.swift
    - AppPackage/Sources/AppModels/Moderation/BlockedCommentAuthors.swift
    - AppPackage/Tests/DetailFeatureTests/CommentFilterTests.swift
    - AppPackage/Tests/DetailFeatureTests/CommentReportTargetTests.swift
    - AppPackage/Tests/DetailFeatureTests/CommentOwnershipTests.swift
    - AppPackage/Tests/AppModelsTests/BlockedCommentAuthorsTests.swift
  modified:
    - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
    - AppPackage/Sources/CookieClient/CookieClient.swift
    - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
    - AppPackage/Package.swift

key-decisions:
  - "The report URL is rebuilt, not edited: `https://<host>/g/<gid>/<token>/?report=select`. Only an http(s) URL whose host is exactly a `GalleryHost` host (no user info, no port) and whose path is a gallery page `/g/<numeric gid>/<alphanumeric token>` has a target. Anything else, look-alike hosts and `s.exhentai.org` included, returns nil (T-18-09)"
  - "`siteName(for:)` returns nil off-site, with no fallback inside it. An off-site gallery has no report action, so a caller only needs a fallback (`setting.galleryHost`, research §5.2) if it shows the label without a target"
  - "Block helpers take an `author:` label (`block(author:)`), so the generic `[String]` extension reads as block-list operations at every call site. An empty name is never added or reported as blocked"
  - "`sessionCookies(for:)` reads through the existing `cookiesForURL` closure, so `.noop`, `.previewLoggedIn` and `.testing()` already return their store's cookies or `[]`, with no new closure. It also drops cookies past their expiry date"
  - "Bundled entries are stored in natural form and normalised on load; the test checks idempotence and uniqueness after normalisation. Storing them pre-normalised would strip the dakuten from the Japanese entries and make the data hard to maintain"
  - "All six groups apply to every comment, whatever the app language, because a comment can be written in any of them"

patterns-established:
  - "Moderation core lives in `DetailFeature/Moderation/`; the block list's model helpers live in `AppModels/Moderation/` so SettingFeature (Blocked Users, 18-10) can share them"

requirements-completed: [UGC-18-01]

coverage:
  - id: D1
    description: "Pure posting filter (case, width, diacritic, apostrophe and whitespace folding; word boundaries for Latin; substrings for CJK and Hangul) with a bundled six-language list"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentFilterTests (18 @Test functions, 48 cases)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Report target on the gallery's own host, nil for any other host"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentReportTargetTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "Own-comment rule (five-case truth table plus exact-name cases)"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentOwnershipTests"
        status: pass
    human_judgment: false
  - id: D4
    description: "Ordered, de-duplicated, exact-name block store under @Shared(.blockedCommentAuthors)"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "AppModelsTests/BlockedCommentAuthorsTests"
        status: pass
    human_judgment: false
  - id: D5
    description: "Host-scoped, read-only session cookie read"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "CookieClientTests/sessionCookiesAreOnlyThoseOfTheRequestedHost, sessionCookiesReadWithoutWriting, theNoopClientHasNoSessionCookies"
        status: pass
    human_judgment: false
  - id: D6
    description: "Bundled filter list content: whether its terms are the right conservative set per language (DD-04)"
    verification: []
    human_judgment: true
    rationale: "The tests prove the list's shape, and that it matches its own entries and leaves ordinary comments alone. Whether the chosen terms are adequate and not over-broad in each language is a judgement no test makes."

duration: 14 min
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 04: Comment moderation core Summary

**This plan adds the pure moderation core. It has a posting filter with a bundled six-language list, a report URL
rebuilt only on the gallery's own E-Hentai/ExHentai host, the own-comment rule, an ordered exact-name block store under
`@Shared(.blockedCommentAuthors)`, and a read-only, host-scoped `CookieClient.sessionCookies(for:)`. It has no reducer
and no UI.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-11-05T07:32:33Z
- **Completed:** 2026-11-05T07:46:59Z
- **Tasks:** 2
- **Files modified:** 14 (10 created, 4 modified)

## Accomplishments

- **`CommentFilter`** (DetailFeature/Moderation):
  - `normalized(_:)` folds case, width and diacritics, recomposes Hangul, maps typographic apostrophes to `'` and
    collapses whitespace runs to one space. It is idempotent.
  - `matches(_:terms:)` matches a term containing Han, kana or Hangul as a substring. Any other term matches only as
    whole words, so "slur" does not match "slurry". Han, kana and Hangul count as word boundaries, so "slur" still
    matches in "这是slur吧".
  - Blank terms are dropped, so they can never match every text.
- **`CommentFilterTerms`:**
  - `groups: [String: [String]]`, with matchers built once per list.
  - `bundled` is loaded once from `CommentFilterTerms.json`. If the load fails, it logs and matches nothing. The test
    suite loads the same resource with the throwing `load(from:)`, so a broken list fails the tests (T-18-10).
- **`CommentFilterTerms.json`:** de 30, en 43, ja 25, ko 22, zh-Hans 23 and zh-Hant 23 entries. They cover slurs
  (racial, ethnic, homophobic, transphobic, ableist), hate speech (Nazi slogans), threats ("I will kill you", "kill
  yourself") and harassment and doxxing phrases. There is no sexual vocabulary (DD-04).
- **`CommentReportTarget`:**
  - Builds `https://e-hentai.org/g/3103480/0000000000/?report=select`, and the same form on exhentai.org.
  - An existing query or fragment is replaced, the host is lowercased and the trailing slash is restored.
  - It returns nil for any other host, scheme, user info, port or non-gallery path (T-18-09).
  - `siteName` is `GalleryHost.rawValue` ("E-Hentai" / "ExHentai").
- **`CommentOwnership.isOwn`:** true when the comment is `editable`, or when the user is signed in and `displayName`
  equals the author exactly. An empty display name matches nothing.
- **`@Shared(.blockedCommentAuthors)`:** an `AppStorageKey<[String]>` with default `[]` and key `blockedCommentAuthors`.
  The helpers `block(author:)`, `unblock(author:)` and `isBlocked(author:)` keep it ordered, unique and exact
  (case-sensitive, no trimming).
- **`CookieClient.sessionCookies(for:)`:** returns the unexpired cookies that `HTTPCookieStorage.cookies(for:)` gives
  for that URL. It is read-only. On an isolated store holding e-hentai, exhentai and s.exhentai cookies, it returns
  only the e-hentai ones (T-18-11).

## Task Commits

1. **Task 1: Posting filter and bundled list:** `8030dd640` (feat)
2. **Task 2: Report target, own-comment rule, block store, session cookies:** `d9a61fa7f` (feat)

Lead-authorised follow-up to 18-07 before this plan: `cbd6685a2`
(`fix(18-07): re-derive the reduce-motion inventory after the reader rework`). It is recorded in 18-07-SUMMARY.md
under "Follow-up".

TDD: each task's tests were written first and run red before the implementation:
- Task 1 failed to compile: `cannot find 'CommentFilter' in scope`.
- Task 2 failed to compile: `[String] has no member 'block'`, `.blockedCommentAuthors` missing.

Each task was then committed once, with tests and code together, as in 18-07.

## Files Created/Modified

- `DetailFeature/Moderation/CommentFilter.swift`: the normalisation, the per-script matcher and the script ranges.
- `DetailFeature/Moderation/CommentFilterTerms.swift`: the list type, the bundled load and its error logging.
- `DetailFeature/Resources/CommentFilterTerms.json`: the six-language term list.
- `DetailFeature/Moderation/CommentReportTarget.swift`: the report URL and site.
- `DetailFeature/Moderation/CommentOwnership.swift`: the own-comment rule.
- `AppModels/Moderation/BlockedCommentAuthors.swift`: the block-list helpers on `[String]`.
- `AppModels/Persistence/AppSharedKeys.swift`: the `blockedCommentAuthors` key.
- `CookieClient/CookieClient.swift`: `sessionCookies(for:)`.
- `Package.swift`: `AppModelsTests` gains the `ComposableArchitecture` dependency. Its test uses
  `withDependencies`/`@Shared`, as `CookieClientTests` already does.
- Tests: `CommentFilterTests`, `CommentReportTargetTests`, `CommentOwnershipTests`, `BlockedCommentAuthorsTests`, and
  three new `CookieClientTests` cases.

## Decisions Made

See `key-decisions` above. In short:
- The report URL is rebuilt from the gallery's gid and token on an allow-listed host, and is always https.
- `siteName` has no internal fallback.
- The block helpers are labelled `author:`.
- `sessionCookies` reuses the existing `cookiesForURL` seam.
- The list is stored in natural form and normalised on load.
- Every language group applies to every comment.

## Deviations from Plan

1. **[Rule 3, blocking] `Package.swift` changed for AppModelsTests, not for the JSON resource.** DetailFeature already
   has `resources: [.process(.resources)]`, which picks up `Resources/CommentFilterTerms.json` with no edit (the plan
   said to add one only if missing). `BlockedCommentAuthorsTests` needs `withDependencies` and `@Shared` to prove the
   key, and `AppModelsTests` linked only `AppModels`. So the target gained `.targetDependency(.composableArchitecture)`,
   as `CookieClientTests` already has. `Package.swift` is in the plan's `files_modified`. Commit `d9a61fa7f`.
2. **Bundled-list normalisation test.** The plan says "every entry is unchanged by normalisation applied twice
   (idempotent)". The test checks exactly that, and also that no two entries collide after normalisation. It does not
   require entries to be stored pre-normalised (see key-decisions). Commit `8030dd640`.
3. **`sessionCookies` adds no closure to `.noop`/test values.** It is backed by the existing private `cookiesForURL`,
   which `.noop` already answers with `[]`, so the plan's intent is met without a second seam. As with the existing
   `cookies(for:)`, `.unimplemented` reports an issue if it is called.

**Total deviations:** 3 (1 Rule 3 blocking, 2 interpretation notes). **Impact:** none on behaviour or scope.

## Issues Encountered

- One xcodebuild run aborted (`DVTInvalidation` assertion), because test files were added while it was building. The
  run was repeated with the tree unchanged, and it passed. No code impact.
- `swiftlint` is not on PATH in this environment. Lint ran with the package's SwiftLint plugin binary
  (`AppPackage/.build/artifacts/swiftlintplugins/.../macos/swiftlint`, 0.65.1) and the root `.swiftlint.yml`.

## Verification

- Task 1: `-only-testing:DetailFeatureTests/CommentFilterTests` on the phone gave TEST SUCCEEDED, with 48 case runs
  passed and 0 failed. The JSON check printed `['de', 'en', 'ja', 'ko', 'zh-Hans', 'zh-Hant'] [30, 43, 25, 22, 23,
  23]`. Strict lint of DetailFeature and its tests found 0 violations.
- Task 2: the four suites on the phone gave TEST SUCCEEDED, with 56 case runs passed and 0 failed. Strict lint of
  `AppPackage/Sources` and `AppPackage/Tests` found 0 violations in 741 files.
- Plan `<verification>` ran `-only-testing:DetailFeatureTests -only-testing:AppModelsTests -only-testing:CookieClientTests`:
  - Phone FFE7E686: TEST SUCCEEDED, 375 passed, 0 failed.
  - Pad B470DB46: TEST SUCCEEDED, 375 passed, 0 failed.
- The full FeatureTests plan on the phone gave TEST SUCCEEDED, with 2457 case runs passed and 0 failed. This includes
  AppToolsTests, so the 18-07 follow-up holds.

## User Setup Required

None.

## Next

Ready for 18-05 (moderation reducers). It builds on `CommentFilter`, `CommentReportTarget`, `CommentOwnership` and
the block store. 18-11's report sheet seeds its web view from `sessionCookies(for:)`.

## Self-Check: PASSED

- Every created file exists on disk.
- Commits `8030dd640` and `d9a61fa7f` are on `feature/gsd-phase-18`.
- The acceptance criteria were re-run:
  - The six groups are printed, each with a count above 0.
  - The boundary, width, diacritic, CJK and Hangul cases pass.
  - The off-site-nil test is present and passes.
  - The five-case ownership truth table passes.
  - The `sessionCookies` host-scoping test passes.
