---
phase: 13-deep-link-hardening-code-review-the-current-deep-link-implem
verified: 2026-07-23T12:45:00Z
status: passed
score: 38/38 must-haves verified
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "Hacky/fragile spots resolved at root (SC-1) — ShareExtension app hand-off"
    reason: "No public route exists on iOS 26.5 — NSExtensionContext.open(_:) is honoured only for Today/iMessage extension points, the deprecated responder-chain openURL: is force-failed by UIKit, and _UIHostedWindowScene accepts openURL:options:completionHandler: without ever opening anything. This build does not ship to the App Store, and ShareSheetUITests drives the real share sheet end to end so the route turns red the moment it breaks."
    accepted_by: "Chihchy"
    accepted_at: "2026-07-23T13:10:00Z"
---

# Phase 13: Deep Link Hardening Verification Report

**Phase Goal:** Code-review the current deep-link implementation (`GalleryDeepLink.swift`, `AppRouteReducer.swift`) and make it less hacky and more durable at navigating the user to the correct destination screen, backed by UI automation tests.
**Verified:** 2026-07-23
**Status:** passed (1 override applied; no gaps)
**Re-verification:** No — initial verification (retroactive; execute-phase never emitted a report)

## Goal Achievement

### Observable Truths — ROADMAP Success Criteria

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Hacky/fragile spots resolved at root, destination routing unchanged for supported links | ✓ VERIFIED (1 override) | `GalleryURLParser.swift` replaces the spoofable substring host check with an exact-host set (`:26-30`, `:86-93`); `URLClient` module fully deleted (zero references repo-wide); both magic-number sleeps gone from the routing path; ShareExtension scheme rewrite is `URLComponents`-based. The extension's private-API app hand-off is PASSED (override) — accepted by Chihchy on 2026-07-23 (see Accepted Trade-offs). |
| SC-2 | UI automation tests exercise deep-link navigation end-to-end for supported routes | ✓ VERIFIED | `EhPandaUITests` target exists in `project.pbxproj` (id `A13080000000000000000006`), driven by the non-default `UITests.xctestplan`; 13 XCUITests across 5 files cover /g/, /s/, #c, malformed × cold/warm, clipboard, comment-link, share sheet, iPad tab-modal. |
| SC-3 | Malformed/unresolvable deep links fail gracefully — no crash, no unrecoverable silent no-op | ✓ VERIFIED | `PresentationFeature.swift:175-183` emits `.error(ErrorInfo(.unsupportedDeepLink, .unsupportedLink(url:)))` on parse failure; toast is tappable → `error_info_view`; asserted in `DeepLinkSchemeUITests.assertMalformedLinkDestination` (:177-208) for both lifecycles. Clipboard stays deliberately silent by pre-validating (`PresentationFeature.swift:158`). |

### Observable Truths — Plan `must_haves`

| Plan | Truth | Status | Evidence |
|------|-------|--------|----------|
| 13-01 | Exact host match rejects `evil.com/...?ref=https://e-hentai.org/` | ✓ | `GalleryURLParser.swift:28-30`; regression `GalleryURLParserTests.swift:83` |
| 13-01 | `www.` variants parse; `s.exhentai.org` does not | ✓ | `:86-93` inserts `www.` variants only; `GalleryURLParserTests.swift:19-27, 84` |
| 13-01 | Parse failure returns nil — no empty-string sentinel | ✓ | `parse(_:) -> Route?`, all failure paths `return nil` (`:30, 37, 54, 65`) |
| 13-01 | `ehpanda://` parses identically to `https://` | ✓ | `normalizedURL(from:)` `:95-106`; fixture pair `GalleryURLParserTests.swift:33-37` |
| 13-02 | `AppError.unsupportedDeepLink` with description + recovery suggestion | ✓ | `AppError.swift:21, 61-62, 99-100, 126-127`; non-retryable at `:35` |
| 13-02 | 3 new keys × 6 locales | ✓ | `Localizable.xcstrings` — all three keys carry `de, en, ja, ko, zh-Hans, zh-Hant` |
| 13-02 | Sanitized link context — no query/fragment/userinfo/full path | ✓ | `AppError+Context.swift:93-112` rebuilds scheme+host+first path component only |
| 13-03 | Every former URLClient call site resolves via `GalleryURLParser`, no injected ceremony | ✓ | `grep -r URLClient` over `AppPackage/ App/ ShareExtension/` → 0 hits |
| 13-03 | URLClient module gone (dir, target, deps, imports) | ✓ | `AppPackage/Sources/URLClient` absent; no `Package.swift` entry |
| 13-03 | Destination routing byte-for-byte unchanged in that plan | ✓ | Commit `29b9388c` is a seam swap; policy change lands separately in `80f6b563` |
| 13-04 | Explicit unsupported open surfaces persistent tappable error toast | ✓ | `PresentationFeature.swift:175-183`; test `unsupportedExplicitDeepLinkSurfacesErrorToast` (passes) |
| 13-04 | Non-gallery clipboard URL stays a silent no-op | ✓ | `PresentationFeature.swift:158` pre-validates; test `unsupportedClipboardURLStaysSilentAfterPersistingChangeCount` (passes) |
| 13-04 | Well-formed link whose fetch fails keeps existing error mapping | ✓ | `PresentationFeature.swift:248-256` unchanged `Context.galleryFailure` path; parameterized test at `:210-221` |
| 13-04 | ShareExtension rewrite mutates only the scheme | ✓ | `ShareViewController.swift:22-29` — `URLComponents.scheme = "ehpanda"`, replacing the old `absoluteString.replacingOccurrences(of: scheme…)` |
| 13-05 | Deep link over the modal sheet re-presents only after dismissal completion | ✓ (behavioral) | `PresentationFeature.swift:166-178, 240-247`; `fetchedReplacementWaitsForDetailDismissalCompletion` + `dismissalCompletingBeforeFetchPresentsWhenFetchFinishes` — both ran green this verification |
| 13-05 | User-initiated dismissal with no pending link is a no-op | ✓ (behavioral) | Guard at `:167`; `userDismissalWithoutPendingLinkIsSilent` (passes) |
| 13-05 | Fetch still starts immediately; only presentation gates | ✓ | `.send(.fetchGallery…)` issued in the same reduce as the dismissal request (`:184`) |
| 13-06 | Loading→error toast is a direct state replacement, no 500ms gap | ✓ | No `Task.sleep` remains in `PresentationFeature`; `CommentsReducer` sleeps that remain (`:118, 144, 148, 152`) are keyboard-focus and scroll-highlight animation, not routing sequencing |
| 13-06 | Replacement animates keyed on toast identity; per-id timer preserved | ✓ | `View+Toast.swift:67 .id(id)`, `:80 .task(id:)`, `:93 .animation(_, value: item?.state.id)` |
| 13-06 | No timing-based sequencing anywhere in the routing path | ✓ | Only `Task.sleep` left in `AppFeature` is the login-push delay (`AppReducer.swift:260`), off the deep-link path |
| 13-07 | Stub serves every URLSession request from fixtures when armed | ✓ | `UITestStubURLProtocol.canInit` claims all http/https (`:8-14`); unmatched → 404, never network |
| 13-07 | Seam compiles out of release | ✓ | `UITestStubURLProtocol.swift` is wholly `#if DEBUG`; `UITestAutomation` bodies `#if DEBUG` (`:7-18, 20-116`) |
| 13-07 | Clipboard stubbable from launch env; routing stays real | ✓ | `UITestAutomation.swift:61-73, 94-106` overrides only `url`/`changeCount`, live `saveText/saveImage*` |
| 13-07 | Parsing/routing NOT stubbed | ✓ | Only `URLProtocol` + `clipboardClient` are overridden |
| 13-07 | Destination screens carry stable accessibility identifiers | ✓ | 7 identifiers: `detail_view`, `reading_view`, `reading_page_indicator`, `comments_view`, `comment_cell_<id>`, `toast_message`, `error_info_view` |
| 13-08 | XCUITest target on a second non-default plan; default run stays unit-only | ✓ | `EhPanda.xcscheme:31-37` — `FeatureTests` `default="YES"`, `UITests.xctestplan` without it |
| 13-08 | Hermetic cold smoke test reaches detail with the fixture marker | ✓ | `DeepLinkSmokeUITests.testColdGalleryDeepLinkUsesHermeticFixture` |
| 13-08 | Warm via `XCUIDevice.shared.system.open`; cold mechanism probed and pinned | ✓ | `DeepLinkLauncher.swift:12-27`, with the iOS 26.5 probe result documented in-source |
| 13-09 | All three routes land on locked destinations, cold + warm | ✓ | `DeepLinkSchemeUITests.swift:11-69` (6 tests) with per-destination assertions `:91-175` |
| 13-09 | Malformed open shows persistent toast → ErrorInfoView, both variants | ✓ | `:71-89`, `:177-208` |
| 13-09 | Deep links never skip detail and jump to the reader | ✓ | `assertGalleryDestination` asserts `reading_view` absent (`:105-111`); `assertReaderDestination` requires `detail_view` first (`:120`) |
| 13-10 | Clipboard happy path on cold launch lands on detail, no real pasteboard | ✓ | `DeepLinkEntryUITests.swift:9-26` via `EHPANDA_UITEST_CLIPBOARD_URL` |
| 13-10 | Comment gallery-link tap pushes the linked gallery's detail | ✓ | `DeepLinkEntryUITests.swift:28-54`, asserted on the Alt marker |
| 13-10 | ShareExtension tested E2E through the real share sheet | ✓ | `ShareSheetUITests.swift` (205 lines) drives Safari → share → extension → `detail_view` |
| 13-10 | iPad tab-modal entry covered incl. deep-link replacement | ✓ | `DeepLinkPadUITests.swift:14-61`, idiom-gated by `XCTSkipUnless` |

**Score:** 37/38 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `AppPackage/Sources/AppTools/GalleryURLParser.swift` | Pure parser | ✓ VERIFIED | 107 lines, `enum GalleryURLParser`, imported by PresentationFeature/CommentsReducer/DownloadClient |
| `AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift` | Exhaustive suite | ✓ VERIFIED | 142 lines, 3 parameterized tests / 21 cases; ran green |
| `AppPackage/Tests/AppToolsTests/.swiftlint.yml` | Lint coverage | ✓ VERIFIED | present |
| `AppPackage/Sources/AppModels/Support/AppError.swift` | `unsupportedDeepLink` | ✓ VERIFIED | 4 switch sites |
| `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` | 3 keys × 6 locales | ✓ VERIFIED | confirmed by JSON parse |
| `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` | Parser routing + policy + coordination | ✓ VERIFIED | `GalleryURLParser.parse` at :158/:176/:196; `detailDismissalCompleted` at :60/:166 |
| `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` | `onDismiss` report | ✓ VERIFIED | `:84` sends `.presentation(.detailDismissalCompleted)` |
| `AppPackage/Sources/SystemNotification/View+Toast.swift` | Identity-keyed animation | ✓ VERIFIED | `:93` |
| `ShareExtension/ShareViewController.swift` | URLComponents scheme swap | ✓ VERIFIED | `:22-35` |
| `AppPackage/Sources/AppFeature/UITestSupport/*` | DEBUG stub seam | ✓ VERIFIED | 2 files, both DEBUG-gated |
| `App/EhPandaApp.swift` | Arm point | ✓ VERIFIED | `:8 UITestAutomation.prepareIfNeeded()` |
| `UITests.xctestplan` | Second plan, retrying | ✓ VERIFIED | `maximumTestRepetitions: 3`, `retryOnFailure`, target `EhPandaUITests` |
| `EhPandaUITests/**` | 5 test files, 2 support, 4 fixtures | ✓ VERIFIED | all present and substantive |
| `EhPandaUITests/.swiftlint.yml` | Lint coverage | ✓ VERIFIED | present |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `GalleryURLParser` | `Defaults.URL` | recognized-host derivation | ✓ WIRED (`:87`) |
| `FeatureTests.xctestplan` | `Package.swift` | `AppToolsTests` registered in default plan | ✓ WIRED (plan `:32-33`, package `:113`) |
| `AppError.swift` | `Localizable.xcstrings` | `appErrorUnsupportedDeepLink*` symbols | ✓ WIRED |
| `PresentationFeature` | `GalleryURLParser` | direct static calls | ✓ WIRED |
| `PresentationFeature` | `AppError.unsupportedDeepLink` | toast `.error(ErrorInfo(...))` | ✓ WIRED (`:176-181`) |
| `TabBarView` | `PresentationFeature` | `onDismiss` → `detailDismissalCompleted` | ✓ WIRED |
| `EhPanda.xcscheme` | `UITests.xctestplan` | non-default TestPlanReference | ✓ WIRED |
| `DeepLinkLauncher` | `UITestAutomation` | `EHPANDA_UITEST_*` env keys | ✓ WIRED (constants match on both sides) |
| `ShareSheetUITests` | `ShareViewController` | real share sheet → `detail_view` | ✓ WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real Data | Status |
|----------|------|--------|-----------|--------|
| `PresentationFeature.detail` | `DetailReducer.State` | `GalleryReverseRequest.response()` seeded from the parsed route | yes | ✓ FLOWING |
| `UITestStubURLProtocol` | fixture bytes | `Data(contentsOf:)` on the runner-bundled HTML | yes (4 fixtures present, non-empty) | ✓ FLOWING |
| `ErrorInfo.context` | sanitized link string | `URLComponents` rebuild of the offending URL | yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Deep-link parser + policy + dismissal coordination + toast replacement | `xcodebuild test -scheme AppPackage-Package -only-testing:AppToolsTests -only-testing:AppFeatureTests/PresentationFeatureTests -only-testing:AppFeatureTests/UITestStubTests -only-testing:AppModelsTests/UnsupportedDeepLinkErrorTests -only-testing:DetailFeatureTests/CommentsReducerTests` | 21 tests, all passed | ✓ PASS |
| Full unit suite | `xcodebuild test -scheme AppPackage-Package -destination 'iPhone Air, OS=26.5'` | 1 failure: `DownloadObserverBatchTests.testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush` | ⚠️ see Anti-Patterns (unrelated, load-dependent) |
| That test in isolation | `-only-testing:DownloadsFeatureTests/DownloadObserverBatchTests` | 5 tests passed | ✓ PASS (flake confirmed) |
| UI plan | not re-run | — | ? SKIP — phase gate ran it green at `31b2772e`; UAT items 17/19/20/22/23/24 human-confirmed |

Note: the destination named in the task brief (`iPhone 17 Pro`) does not exist on this machine; `iPhone Air, OS=26.5` was substituted.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| SC-1 | 13-01, 13-03, 13-04, 13-05, 13-06 | Hacky spots resolved at root, routing unchanged | ✓ SATISFIED (1 open decision) | See SC-1 row above |
| SC-2 | 13-07, 13-08, 13-09, 13-10 | UI automation covers deep-link navigation E2E | ✓ SATISFIED | 13 XCUITests, real target + plan |
| SC-3 | 13-01, 13-02, 13-04, 13-09 | Malformed links fail gracefully | ✓ SATISFIED | Dedicated error case + recoverable toast + UI proof |

**Orphaned requirements:** none. **Registry gap:** `.planning/REQUIREMENTS.md` contains no `SC-1/SC-2/SC-3` entries and ROADMAP Phase 13 records `Requirements: TBD`, so the SC IDs live only in ROADMAP Success Criteria and plan frontmatter. Traceability holds, but the registry is not the source of truth for this phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | `TODO`/`FIXME`/`TBD`/`XXX`/`HACK` across the 45 Swift files changed in this phase | ℹ️ INFO | none found |
| `ShareExtension/ShareViewController.swift` | 63-85 | Private API (`LSApplicationWorkspace` via `NSSelectorFromString` + `unsafeBitCast`) | ✓ ACCEPTED | Owner-accepted 2026-07-23 (see Accepted Trade-offs). Documented, measured against three dead public routes, and covered by `ShareSheetUITests` so breakage is loud. |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadObserverBatchTests.swift` | 65 | Load-dependent flake in the full-suite run | ℹ️ INFO | Unrelated to Phase 13 (last touched in Phase 11); passes in isolation |
| `.planning/ROADMAP.md` | 731, 742-743 | Bookkeeping drift: `Plans: 9/10 executed`, `13-10-PLAN.md` left unchecked | ⚠️ WARNING | `13-10-SUMMARY.md` is complete and commit `94ac4956` closed the plan; ROADMAP should read 10/10 |
| `EhPandaUITests/*` + `AppPackage/Sources/*` | — | 7 identifier literals mirrored by 18 literal call sites, no compile-time link | ℹ️ INFO | Already recorded as a deferred follow-up in `13-UAT.md` |

### Accepted Trade-offs

#### 1. Private-API share-extension hand-off — ACCEPTED 2026-07-23 by Chihchy

**Item:** `ShareExtension/ShareViewController.swift:50-85` routes the extension→app hand-off through the private `LSApplicationWorkspace` API (`NSSelectorFromString` + `unsafeBitCast`).
**Decision:** Accepted as satisfying SC-1. Recorded as a frontmatter override; SC-1 closes explicitly rather than implicitly.
**Rationale:** No public route exists on iOS 26.5 — `NSExtensionContext.open(_:)` is honoured only for the Today and iMessage extension points, UIKit force-fails the deprecated responder-chain `openURL:`, and the terminating `_UIHostedWindowScene` accepts `openURL:options:completionHandler:` without ever opening anything. This build does not ship to the App Store, so the private-API prohibition does not bind it, and `ShareSheetUITests` drives the real share sheet end to end, so the route turns red the moment it stops working.
**Revisit if:** distribution intent changes (any App Store submission), or a sanctioned extension→app route appears in a later iOS release.

### Gaps Summary

No gaps. Every plan artifact exists, is substantive, is wired, and carries real data flow. The three ROADMAP Success Criteria are each backed by code plus tests: SC-1 by the parser rewrite, the URLClient deletion, and the removal of both magic-number sleeps from the routing path; SC-2 by a real XCUITest target on a second test plan with 13 tests across all supported routes and entry paths; SC-3 by a dedicated non-retryable error case with six-locale strings, a sanitized diagnostic context, and a tappable toast proven to reach `ErrorInfoView` in both lifecycles.

The one decision item — private API in the share extension — was resolved on 2026-07-23: the owner accepted it, and it is now recorded as a frontmatter override rather than an unsigned executor assumption. The two bookkeeping items (ROADMAP plan count, REQUIREMENTS SC entries) close with phase completion.

---

_Verified: 2026-07-23_
_Verifier: Claude (gsd-verifier)_
