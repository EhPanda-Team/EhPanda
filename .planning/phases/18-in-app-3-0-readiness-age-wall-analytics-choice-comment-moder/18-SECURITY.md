---
phase: "18"
slug: "in-app-3-0-readiness-age-wall-analytics-choice-comment-moder"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
open_total: 1
below_threshold_open: 1
accepted: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-11-05"
audited: "2026-11-05"
audited_source: c3ef39ac9
---

# Phase 18 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

The register is the `<threat_model>` of all twelve plans (18-01 to 18-12): T-18-01 to T-18-23, plus T-18-SC, which
every plan repeats with the same text. No SUMMARY has a `## Threat Flags` section.

The audit read the code at `c3ef39ac9`, the last commit that changes code. Every mitigation below was checked in the
code, test or tracked script itself, not only in the phase records. Commands run for this audit:

- `Scripts/check-cookie-logging.sh`: exit 0, "Cookie logging audit passed."
- `18-copy-check.py`: exit 0, 38 keys × 6 locales verbatim, 48 retired texts absent.
- `18-copy-check.py --readmes`: exit 0, 6 Analytics sections hold the three levels verbatim, no retired text.
- At `c3ef39ac9`: ParserFeatureTests + DetailFeatureTests 199/199 on the phone and 199/199 on the pad, and
  `CommentModerationUITests` 7/7 on each device, with 0 Repetition nodes.

The Release scan (`verify-release.py`) and both full test plans last ran at `e3c95a3bf` (18-12 gate,
18-REGRESSION-GATE.md). Since then, `git diff e3c95a3bf c3ef39ac9 -- . ':!.planning'` touches only
`Parser+Comment.swift` and its tests. That change adds no DEBUG, capture or launch-key code, so the Release scan was
not rerun.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| App process to the network, before the age wall is answered | Nothing may leave the device before the age confirmation | None allowed. Launch work is local only. |
| URL scheme / share extension to the app | A link may arrive before the answer | Gallery URLs |
| App to TelemetryDeck ingest | The only analytics egress; it must match the chosen level | The install signal (source only) at Minimal; SDK signals at Basic/Full |
| Build configuration to the binary | The app ID and salt exist only in the owner's local, git-ignored configuration | TelemetryDeck app ID and salt |
| Parsed gallery HTML to the report URL and the block list | Untrusted page data becomes a URL the app opens and a member ID the app stores | Gallery URL, comment author link |
| App cookie store to the report web view | The app's session crosses into WebKit for one host | Session cookies of the report host |
| User text to the site | A comment leaves only after the warning decision | Comment text |
| Block list to the rendered UI and analytics | Blocked names must not appear in collapsed rows, cards, labels or signals | Member IDs, names |
| Pager view to the reducer | Asynchronous scroll observations from a view that may have been rebuilt | Reading position |
| DEBUG automation to the Release product | Launch keys and capture code must not ship | Launch environment, compiled code |
| Approved copy and docs to users | The catalog and READMEs must say what is sent | Strings, README prose |

---

## Threat Register

| Plan | Threat ID | Category | Component | Severity | Disposition | Mitigation (evidence in code, test or tracked artifact) | Status |
|---|---|---|---|---|---|---|---|
| 18-01 | T-18-01 | Information disclosure | `verify-release.py` | medium | mitigate | `captureSystemOverlay` is in `FORBIDDEN_CONTENT` (`Scripts/visual/verify-release.py:31`, beside `EHPANDA_` at `:20`). `test_release.py:128` (`test_capture_system_overlay_key_in_release_fails`) seeds the token and expects a failure. This closes the Phase 17 scanner gap (17-SECURITY IN-02). | closed |
| 18-02 | T-18-02 | Elevation of privilege | `AppReducer` launch and scene phase | high | mitigate | While locked, `onLaunchFinish` runs only the log pump and cookie maintenance (`AppReducer.swift:269-292`). The deferred launch (liveness, settings load, phase report, stored level) runs once, after both the unlock and the preparation (`deferredLaunchEffect`, `:484-492`). A scene phase is recorded, not reported, while locked (`downloadPhaseEffects`, `:517-520`). `FirstLaunchGateTests` (`AppFeatureTests`) leaves the download and analytics clients `unimplemented`, so any call while locked fails the test (`aLockedLaunchRunsOnlyLocalWork`, `aLockedBackgroundTransitionIsRecordedNotReported`, `aStaleDeclarationVersionKeepsTheLaunchLocked`, `aSecondConfirmationReceivesNothing`). | closed |
| 18-02 | T-18-03 | Spoofing | Deep link while locked | medium | mitigate | `openURL` while locked stores the link in one slot, and the latest link wins (`AppReducer.swift:250-253`). It is routed only once both `isUnlocked` and `hasLoadedInitialSetting` hold, and the slot is cleared (`:221-225`). Tests: `aLinkOpenedWhileLockedIsQueuedAndTheLatestWins`, `aQueuedLinkWaitsForTheSettingsToLoad`, `aQueuedLinkIsRoutedOnceAfterTheSettingsLoad`, `anUnlockedLinkRoutesAtOnceAndReplacesAQueuedOne`. | closed |
| 18-02 | T-18-04 | Information disclosure | DEBUG first-launch preset | medium | mitigate | `EHPANDA_UITEST_FIRST_LAUNCH` and the preset are read only inside the `#if DEBUG` block of `UITestAutomation.swift` (`:37-476`; key at `:86`). `AppLaunchAutomation.current` returns `nil` outside DEBUG (`AppLaunchAutomation.swift:63-67`). Every other `EHPANDA_` read outside `UITestSupport` is DEBUG-gated: `ReportPageSheet.swift:47-51`, `ReadingView.swift:655-674` and `AppDelegateReducer.swift:50-60`. The Release scan at `e3c95a3bf` found 0 `EHPANDA_` findings. | closed |
| 18-03 | T-18-05 | Information disclosure | `apply`/`send` before the choice | high | mitigate | `apply(nil)` returns before any SDK call or install signal (`AnalyticsClient.swift:85`). `send` reads the stored level live, and `isSent(at: nil)` is `false` (`AnalyticsSignal+Level.swift:37`). No SDK call is made unless `isRunning` (`AnalyticsClient.swift:116-117`). The live client is `.noop` without an app ID (`:51`). Tests: `AnalyticsLevelGateTests.noLevelMakesNoSDKCallAndNoInstallSignal`, `aSignalSentBeforeAnyApplyIsDropped`, `theStoredLevelGatesSignalsBeforeApplyCatchesUp`. | closed |
| 18-03 | T-18-06 | Information disclosure | Minimal payload / SDK start under Minimal | high | mitigate | `.minimal` never calls `sdk.initialize`; it only terminates a running SDK (`AnalyticsClient.swift:89-96`). The install signal has its own sender. Its body is a fixed seven-field `Encodable` (`InstallSignalSender.swift:216-236`), and its payload has one key, the install source (`:93`). Tests: `minimalSendsTheInstallSignalAndNeverInitialisesTheSDK`, `minimalNeverInitialisesTheSDKAcrossARelaunch`, `InstallSignalSenderTests.theFirstSendIsOneRequestInTheSDKWireFormat`. Full-only parameters are empty below Full (`AnalyticsDefaultParameters.swift:29`). | closed |
| 18-03 | T-18-07 | Information disclosure | Repeated or linkable install signal | medium | mitigate | A persisted `settled` flag stops any later send (`InstallSignalSender.swift:73`). An `isSending` flag allows one send in flight (`:71`). `clientUser` is the SHA-256 of a random UUID plus the salt, and it is cleared once the signal settles (`:78`, `:120-123`). Tests: `aSecondSendOnTheSameSenderMakesNoRequest`, `aRelaunchOverTheSameStorageMakesNoRequest`, `twoConcurrentSendsMakeOneRequest`, the retry tests reusing the same user. | closed |
| 18-03 | T-18-08 | Spoofing / misconfiguration | Endpoint and credentials | medium | mitigate | The endpoint is the SDK's fixed ingest URL (`InstallSignalSender.swift:31`). The transport is an ephemeral session with no cookies, no cookie storage and no cache (`:241-246`). A nil app ID returns before the transport is called (`:71`; test `aNilAppIDNeverCallsTheTransport`). The app ID and salt come only from `$(TELEMETRYDECK_*)` (`App/Info.plist:136-139`). The tracked `Config/Analytics.xcconfig` leaves them empty, and the local override is git-ignored (`.gitignore:8`) and in no commit (`git log --all -S` on its app ID: none). | closed |
| 18-03 | T-18-21 | Information disclosure / tampering | Install-source value | medium | mitigate | Fixed `InstallSource` enum. A marketplace ID is kept only when it is 1 to 155 characters of ASCII letters, digits, `.` or `-`; anything else is `.unknown` (`InstallSourceClient.swift:59`, `:66-99`). A simulator build answers `.unknown` and any other DEBUG build `.other`, without asking MarketplaceKit (`:105-109`). Tests: `InstallSourceTests` (`anImplausibleMarketplaceIDIsUnknown`, `everyMappedValueMatchesTheWireAlphabet`, `theLiveClientReportsUnknownOnTheSimulator`). | closed |
| 18-04 | T-18-09 | Spoofing | `CommentReportTarget` | medium | mitigate | A report URL is rebuilt only from an `http(s)` gallery URL with no user, password or port, whose host is exactly a `GalleryHost` host (`CommentReportTarget.swift:42-47`), with a digits-only gid and an alphanumeric token. It is always `https` with exactly `report=select` (`:13-20`). Tests: `CommentReportTargetTests.anyOtherHostOrSchemeHasNoReportTarget`, `aURLThatIsNotAGalleryPageHasNoReportTarget`, `anHTTPGalleryURLReportsOverHTTPS`. | closed |
| 18-04 | T-18-10 | Denial of service | Filter list load | low | mitigate | The bundled list loads once (`static let bundled`, `CommentFilterTerms.swift:46`). A load failure logs and matches nothing (`:49-51`). `CommentFilterTests` ("The bundled list", `:108`) loads the same resource and fails on a broken list. | closed |
| 18-04 | T-18-11 | Information disclosure | `sessionCookies(for:)` | medium | mitigate | A read-only, host-scoped read through `HTTPCookieStorage.cookies(for:)`, with expired cookies dropped (`CookieClient.swift:221-226`). Tests: `CookieClientTests.sessionCookiesAreOnlyThoseOfTheRequestedHost` (isolated storage, sibling-host cookies excluded) and `sessionCookiesReadWithoutWriting`. | closed |
| 18-05 | T-18-12 | Information disclosure | Collapsed state / analytics | medium | mitigate | The collapsed row and card take only `commentID` and two actions, with no author field (`BlockedCommentRow.swift:13`, `BlockedCommentCard.swift:14`). No moderation action sends a signal; `CommentModerationReducerTests` (`:522-527`) proves it with a recording analytics client. | closed |
| 18-05 | T-18-13 | Tampering | Post path | medium | mitigate | `postTapped` checks `CommentFilter.matches` before any effect and only shows the warning (`CommentsReducer.swift:136-142`, `DetailReducer+Fetch.swift:185-191`). The post goes out only through `postAndDismiss`, from `postTapped` with no match or the warning's `.post` delegate. The views send only `.postTapped` (`CommentsView.swift:91`, `DetailView.swift:236`). Tests cover new, edit and detail (`CommentModerationReducerTests.postAnywaySendsThenCloses`, `aCommentWithNoMatchPostsAndCloses`, `detailPostAnywaySendsThenCloses`, `detailPostsACommentWithNoMatch`). | closed |
| 18-06 | T-18-14 | Repudiation / integrity | Catalog copy drift | medium | mitigate | `18-copy-check.py` compares the catalog byte for byte and checks the retired texts. It was rerun for this audit: exit 0, 38 keys × 6 locales, 48 retired texts absent. | closed |
| 18-07 | T-18-15 | Tampering / integrity | Reading progress from a stale observation | low | mitigate | Every pager observation carries a generation, and stale ones return `nil` (`ReaderPosition.swift:84`, `:107`). Tests: `ReaderPositionTests` "Stale generations" (`:239-272`). | closed |
| 18-08 | T-18-16 | Elevation of privilege / tampering | DEBUG launch keys reaching Release | high | mitigate | Every `EHPANDA_UITEST_*` key, including the first-launch preset, the block list and the display name (`UITestAutomation.swift:86`, `:114-115`), is read inside the file's `#if DEBUG` block (`:37-476`). `EHPANDA_` is a forbidden Release token (`verify-release.py:20`). The Release scan at `e3c95a3bf` passed with 0 findings (18-REGRESSION-GATE.md). | closed |
| 18-09 | T-18-17 | Elevation of privilege | Content rendered or a deep link opened behind the gate | high | mitigate | The root switches views instead of using an overlay. Until both answers exist, only `FirstLaunchGateView` is in the hierarchy, and `TabBarView` is not built (`RootView.swift:37-48`). Links at the gate go to `AppReducer.openURL`, which queues them while locked (T-18-03). UI tests: `FirstLaunchUITests.testAFreshLaunchShowsOnlyTheAgeWallAndMakesNoRequest` (no tab bar, empty request log) and `testALinkOpenedAtTheGateOpensItsGalleryAfterBothAnswers`. Review IN-03 (a link routed after the age wall but before the analytics choice) is accepted by the lead; see below. | closed |
| 18-10 | T-18-18 | Information disclosure | Lowering the level in Settings not stopping the SDK | high | mitigate | `analyticsLevelPicked` stores the level and then calls `apply` in the reducer (`GeneralSettingReducer.swift:147-150`). Only this reducer and `AppReducer` call `apply`. `.minimal` terminates a running SDK (`AnalyticsClient.swift:89-96`), and `send` reads the new level live (`:111-114`). Tests: `loweringToMinimalTerminatesTheSDKAndDropsEverySignal`, `raisingFromMinimalInitialisesTheSDKAgain`, and the Settings reducer's recording-client tests. | closed |
| 18-11 | T-18-19 | Information disclosure / spoofing | Report sheet session | high | mitigate | `SessionWebView` uses `WKWebsiteDataStore.nonPersistent()` (`SessionWebView.swift:79-84`). It is seeded only with `sessionCookies(for:)` of the report URL (`ReportPageSheet.sessionInput`). Each cookie is awaited before `load`, and a cancelled seed loads nothing (`:113-122`). It never reads or writes the app's store. The default-store `WebView` is used only by Settings screens (`AccountSettingView`, `EhSettingView`, `LoginView`), never by the report sheet. Tests: `BlockedCommentPresentationTests.theSheetOpensTheReportPageWithTheSessionForItsHostOnly`, `theWebViewWritesEveryCookieBeforeItLoads`, `theWebViewsStoreIsNotPersistent`. | closed |
| 18-11 | T-18-20 | Information disclosure | Collapsed row and card, menu labels | medium | mitigate | As T-18-12: the row and card take no author. Tests: `theCollapsedRowHoldsNoAuthorOrText`, `theCollapsedLabelIsTheCatalogString`. `CommentModerationUITests` asserts that no static text carries the author while collapsed (7/7 on each device at `c3ef39ac9`). | closed |
| 18-12 | T-18-22 | Repudiation / integrity | README Analytics sections overclaiming | medium | mitigate | `18-copy-check.py --readmes` checks the three level descriptions verbatim and the retired claims. It was rerun for this audit: exit 0, 6 sections. | closed |
| 18-12 | T-18-23 | Elevation of privilege / information disclosure | DEBUG launch keys or capture code in the Release product | high | mitigate | `verify-release.py` checks the `EHPANDA_` and `captureSystemOverlay` tokens, linkage and the launch probe (`:19-36`; `test_release.py`). Release scan at `e3c95a3bf`: PASS, 0 findings. The only later code change (`c3ef39ac9`, parser) adds no DEBUG or capture code. | closed |
| 18-01 to 18-12 | T-18-SC | Tampering | Package installs | low | accept | The plans' disposition is `accept`: no plan installs a package. Checked: across the phase (`43333aae0~1..HEAD`), no `Package.resolved` changed, and `Package.swift` adds only the local `InstallSourceClient` target and local module edges. No third-party dependency was added or bumped. **Needs owner acceptance.** In plain words: the phase added no outside code, and the plans chose to accept the small leftover risk of package tampering rather than add a check; only the owner can sign that off. | open — below high threshold (non-blocking), needs owner acceptance |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (high) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

There are 24 threat IDs: T-18-01 to T-18-23 and the shared T-18-SC. 23 have disposition `mitigate`, and all 23 are
closed. T-18-SC (`accept`) stays open until the owner accepts it. The agent did not add it to the Accepted Risks Log.

---

## Review Items With Security Weight

**IN-01: `parseMemberID` accepted look-alike hosts (fixed in `c3ef39ac9`).** A member ID is what the block list
stores. A comment author link on a host such as `fake-e-hentai.org` could make the app attribute an ID that the site
did not issue. The parser now accepts only the exact contact link `Defaults.URL.forum`: `https`, the host
`forums.e-hentai.org` and the path `/index.php`, with no user, password or port, and digits only
(`Parser+Comment.swift:96`, `:107`). Tests: `GalleryCommentParserTests.aLookAlikeContactLinkHasNoMemberID`,
`theContactLinkHostMatchesWhateverItsCase`. Recorded as F-18-01 below.

**IN-03: a link opened after the age wall but before the analytics choice is routed (accepted by the lead).** The
lead accepted this on 2026-11-05. No analytics is sent before the choice (T-18-05), and nothing of the app is shown
(T-18-17). D-04 and DD-07 allow the content fetch after the age confirmation. Not a threat under the register.

**IN-02 (naming)** has no security weight.

---

## Unregistered Findings

| ID | Severity | Where | Finding | Status |
|---|---|---|---|---|
| F-18-01 | low | `ParserFeature/Parser+Comment.swift` (`parseMemberID`) | A host-suffix match accepted look-alike hosts as the site's contact link (review IN-01). | fixed in `c3ef39ac9` |

Other checks:

- Phase 18 added no entitlement, and its only `Info.plist` change is `MKSellsDigitalGoods = false`.
- The ShareExtension did not change.
- The new log lines carry no cookie, URL token or user text: error values and HTTP status only
  (`InstallSignalSender.swift`, `CommentFilterTerms.swift`).
- The block list (`BlockedCommentUser`) is stored on the device only and is never sent.

---

## Accepted Risks Log

None. T-18-SC is planned as `accept`, but the owner has not accepted it, so it is open in the register above and is
not logged here.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-05 | 24 | 23 | 1 (T-18-SC, low, below the high threshold; needs owner acceptance) | gsd-security-auditor (inline in /gsd-secure-phase 18, no subagents; ASVS L1, block_on high; the effort setting could not be set, so the audit was run as thoroughly as possible) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [ ] Accepted risks documented in Accepted Risks Log: T-18-SC is waiting for owner acceptance
- [x] `threats_open: 0` confirmed (no open threat at or above high)
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-05 (threat register). T-18-SC is still open, below the threshold: it needs owner
acceptance.
