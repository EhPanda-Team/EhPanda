# Phase 18: In-App 3.0 Readiness — Research

**Researched:** 2026-11-05
**Domain:** iOS app launch gating (TCA), analytics consent and SDK lifecycle (TelemetryDeck 2.14.2), comment moderation
(E-Hentai), reader page-state redesign (SwiftUI paging), release isolation tooling
**Confidence:** HIGH for the code facts (read from the tree at `43333aae0`); MEDIUM for the E-Hentai report-link
question (fixture evidence only, see Open Item OI-1).

**How this file was made.** The plan-phase roles (researcher, pattern mapper, planner, checker) were run inline, in
sequence, by the developer, as the user asked for this run; no subagents were spawned. Interactive questions were
replaced by recorded defaults (section 9). `/gsd-ui-phase` was not run, on the user's instruction. The designer
(Colo) supplied `18-UI-SPEC.md` with 24 mockups (msgs 1791, 1803, 1807, 1820; final 1826), committed unchanged; every UI task reads
it as its design contract (D-17a).

**Revised 2026-11-05 during planning** for the owner's analytics change (Minimal replaces None; msgs 1795, 1796,
1805), the developer decision on what Minimal sends (CONTEXT D-06b), Blocked Users in Account settings (D-14a), and
the three technical questions the designer asked (§5.6). Sections 4, 5, 8, 9, 10, 11 and 12 carry the changes.
**Revised again the same day** for D-06c (owner msgs 1812, 1818): the install signal carries the install source,
produced by a new `InstallSourceClient` (§4.6); the Minimal description is Revision 2 of `18-COPY-MINIMAL.md`, and
the UI-SPEC refreshes (msg 1820; msg 1826 adds the title line-break rule, C-3) are committed.
**Revised a third time the same day** for D-06d (owner msgs 1830, 1839): Basic's description is Revision 3 of
`18-COPY-MINIMAL.md` ("Everything in Minimal, plus ..."), superseding the first-launch Basic description; what Basic
sends is unchanged. The UI-SPEC and mockups refresh for it (msg 1843) is committed. Only User Constraints, §8, Validation Architecture and Sources change.
**Revised a fourth time the same day** for D-06e (owner msgs 1844, 1854, 1864): `consent.body` is Revision 5 of
`18-COPY-MINIMAL.md` ("Anonymous analytics. Your searches and the galleries you view are never sent."), superseding
the msg-1805 intro; the purpose and TelemetryDeck's name move to the Privacy Policy (website, Phase 20). Revision 4
(msg 1847) was not approved. The same sections change.
**Revised a fifth time the same day** for D-06f (owner msgs 1869, 1880, 1882; developer mapping msg 1878): the
screen and feature signals move from Full to Basic and `cloudflareChallengeEncountered` is Basic (§4.3, A-3; OI-3
closed); Basic's and Full's descriptions are Revision 6 of `18-COPY-MINIMAL.md`, which also adds
`consent.level.recommended` (Basic marked Recommended, nothing pre-selected). §4.3, §8, §9, §11, User Constraints,
Validation Architecture and Sources change.

<user_constraints>
## User Constraints (from 18-CONTEXT.md)

### Locked decisions (binding; summarised, CONTEXT wins on any difference)

- **D-01/D-02:** three phases; this one is in-app only. ANALYTICS-02 (new signals, install source on Basic/Full) is
  the last plan of Phase 20. This phase gates the *existing* ANALYTICS-01 vocabulary by level and adds one signal,
  the install signal (D-06b), whose only parameter is the install source (D-06c); Phase 20 reuses and verifies the
  `InstallSourceClient` created here.
- **D-03/D-04/D-05:** two first-launch screens (age wall, then analytics choice), shown once to everyone including
  upgraders. Before the age wall is confirmed: no content, no network request, no analytics SDK start, nothing else
  works. No skip and no "No"; Continue dimmed until the checkbox is ticked; footnote always visible; nothing suggests
  the age was checked; the answer is stored on the device. The declaration is the approved sentence, unchanged.
- **D-06/D-06a/D-06b/D-07/D-08/D-09:** Minimal / Basic / Full (D-06a), equally prominent, none pre-selected
  (Basic carries a "Recommended" label, D-06f);
  nothing starts or is sent before the choice; each level sends only what its approved description says. Minimal
  sends one install signal through the app's own sender and never initialises the SDK; its payload is exactly one
  key, the install source (D-06c); the same one-time install signal goes out at every level; the SDK starts at
  Basic and Full (D-06b). Basic sends the screen, feature and error signals, Full adds reading, download and the
  settings parameters (D-06f, §4.3). Settings gets a
  picker (row label `shareAnalyticsData`), a footer with the selected level's description, a Privacy Policy row;
  `shareAnalyticsDataFooter`, `consent.level.none` and its description are retired. ANALYTICS-01's vocabulary rules
  stay. Strings verbatim from `18-COPY-FIRST-LAUNCH.md` as superseded in part by `18-COPY-MINIMAL.md` (its
  Revision 2 for Minimal's description, its Revision 6 for Basic's and Full's and `consent.level.recommended`,
  D-06f, its Revision 5 for `consent.body`, D-06e).
- **D-10..D-16:** "Report on {site}" on every comment → confirmation → the gallery's report page on E-Hentai/ExHentai;
  no email or contact fallback. No in-app contact option. The filter warns (Edit default, Post Anyway), never names
  the word, applies to edits. Blocking collapses the comment into "Comment from a user you've blocked" with Show and
  Unblock (no name), in the comments list and the Detail preview; device-local. Blocked Users list in **Account**
  settings (D-14a) with a footer, empty state and swipe to unblock. Strings verbatim from `18-COPY-COMMENTS.md`.
  Ships in every build.
- **D-17/D-17a:** `18-UI-SPEC.md` (final, msg 1826) is the design contract for every UI task; layout choices are the
  designer's.
- **D-18/D-19:** one source of truth for the reader's page, as one task; committed UI tests for G1/G2 (Reload All
  Images then a turn, direction change during Auto-Play, LTR/RTL switch).
- **D-20/D-21:** IN-02, IN-03, `MKSellsDigitalGoods = NO`.
- **D-22:** persisted models stay at v1 and are edited in place; SwiftLint as error, no suppressions; every
  `.xcstrings` key filled for six locales; agent-run UAT allowed; closing gates need 0 failures and 0 Repetition.

### Developer defaults (DD-01..DD-12; changeable by the owner)

Slider scrub preview then snap (DD-01); follow-the-screen after the retry limit (DD-02); iPad spread stays a known
limit (DD-03); filter targets slurs/hate/threats/harassment in six languages, no sexual vocabulary, pure function with
case/width/diacritic normalisation and a bundled list (DD-04); `.marketplace` suffix recorded for Phase 20 (DD-05);
root gate in RootView/AppReducer with only local work in `onLaunchFinish` (DD-06); deep links and the share extension
queued until confirmation (DD-07); age answer plus wording version, analytics level stored the same way, old flag
ignored (DD-08); SDK lifecycle by level with unit proof of no SDK call before consent (DD-09, amended by DD-09a:
SDK at Basic/Full only, terminated on lowering to Minimal); block list is an
`@Shared` set of author names, actions in the cell's menu (DD-10); `ReaderPosition` in reducer state with a
generation counter (DD-11); README Analytics sections rewritten in six languages (DD-12).

### Deferred / out of scope

Contact option and support mailbox (Phase 20); new signals and the install source on Basic/Full, plus verifying the
install-source mapping on the real marketplace build and a device (ANALYTICS-02, Phase 20), including
reconciling the SDK's `newInstallDetected` with the app's install signal at Basic/Full (carry, D-06b); iPad
two-page spread test; keeping comment styles on edit; snapshot coverage of the new screens (Phase 19).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (short) | Research support |
|----|---------------------|------------------|
| AGE-18-01 | First-launch age wall before any content or network | §2 launch-path inventory, §3.1 gate design, §3.2 storage |
| CONSENT-18-01 | No analytics until the user chooses; three levels; Settings picker | §4 SDK facts, §4.3 level gating, §4.4 lifecycle |
| UGC-18-01 (report, warning, blocking) | Report on E-Hentai, posting warning, collapsed blocking, Blocked Users list | §5 comment code map, §5.2 report target, §5.3 filter, §5.4 block store |
| DIST-18-01 (`MKSellsDigitalGoods` only) | `App/Info.plist` declares `MKSellsDigitalGoods = NO` | §7.3 |
| (carried) reader rework + G1/G2 | One source of truth for the page; committed UI tests | §6 |
| (carried) IN-02, IN-03 | Release scanner token; RootView DEBUG import | §7.1, §7.2 |
</phase_requirements>

## 1. Summary

The launch path today starts work in three places that must move behind the gate: `AppReducer`'s
`.appDelegate(.onLaunchFinish)` (activity-log pump, download-liveness observation, cookie prep then
`.setting(.loadUserSettings)`), `AppDelegateReducer.onLaunchFinish` (history prune, image-cache init, analytics
`start`), and `.onScenePhaseChange(.active)` (download client `setIsInBackground`, and — once settings are loaded —
the greeting fetch and clipboard detection). Every network-capable path is reached either through
`loadUserSettings` or through the live `DownloadClient`, whose construction itself runs `reconcileDownloads()` and
`resumeQueue()`. So the gate has two jobs: hold `loadUserSettings`, and keep the first `downloadClient` access behind
the gate. The local work (cookie maintenance, history prune, web-image configuration, log pump) may stay.

The analytics client already has part of the shape the level gate needs: a live `send` closure that re-reads
`@Shared(.setting)` per signal, a `started` latch, and a default-parameters closure that re-reads settings per signal.
What it lacks is a seam: the SDK is called directly, so "no SDK call before consent" can only be proven by a test
after the SDK calls are moved behind an injectable `TelemetrySDK` value (§4.4). Phase 14's opt-out cannot serve as
Minimal: it kept the SDK running, and every SDK signal carries the full device/OS/locale/app-version payload. So
Minimal never initialises the SDK, and the app sends one install signal whose only parameter is the install source
through a small sender of its own, once per install, at every level (D-06b, D-06c, §4.5, §4.6). The SDK runs at Basic and Full and is terminated when the
level drops to Minimal.

Comments have no per-comment report link in either captured gallery page; the only report link is the gallery-level
`?report=select` ("Report Gallery"). That matches the copy's assumption, so `comment.report.confirm_body` keeps both
sentences (OI-1 records the residual uncertainty). The report page opens in an in-app sheet whose private web view is
seeded with the app's own session cookies (§5.2). Comment cells today have swipe actions only, no menu; Phase 16
found that context menus are not exposed to VoiceOver in this app (`CONTEXTMENU=not-exposed`), so the report and
block actions also need accessibility custom actions, which the UI-SPEC adopts (C-4).

The reader rework is already designed in `17-READER-ROOT-CAUSE.md` §3; this research confirms the code anchors and
the tests to port, and maps the throwaway Phase 17 UAT harness (kept outside the repo) onto the committed tests.

**Primary recommendation:** land the non-UI work first in five independent plans (carries, gate logic and storage,
moderation core, localisation, reader rework), then analytics lifecycle with the install sender, moderation reducers
and the reader UI tests, then the three UI plans against the committed UI-SPEC, then the README rewrite and the
phase gate.

## 2. Launch path inventory (what runs before the user could see the age wall)

Read from `App/EhPandaApp.swift`, `AppFeature/RootView.swift`, `AppFeature/DataFlow/AppDelegateReducer.swift`,
`AppFeature/DataFlow/AppReducer.swift`, `DownloadClient/DownloadClient.swift`.

| # | Site | What it does | Network? | Gate verdict |
|---|------|--------------|----------|--------------|
| L1 | `AppDelegate.init` | `UITestAutomation.prepare` (DEBUG), builds the store | no | stays |
| L2 | `didFinishLaunching` → `.appDelegate(.onLaunchFinish)` (skipped when `AppInfo.isTesting`) | fans out to L3–L5 | — | stays (dispatch only) |
| L3 | `AppDelegateReducer.onLaunchFinish` | history prune; `libraryClient.initializeWebImage()`; `analyticsClient.start()` | start: **yes** (SDK session signal) | prune and image init stay; **`start` moves behind the analytics choice** |
| L4 | `AppReducer` `.appDelegate(.onLaunchFinish)` | `.appLogsPump(.startPump)`; `downloadClient.observeContinuedSessionLiveness()`; `cookieClient.prepareForLaunch()` → automation cookies → `.setting(.loadUserSettings)` | **yes**: first `downloadClient` access builds the live client, whose init task runs `reconcileDownloads()` + `resumeQueue()` (may start queued transfers); `loadUserSettings` starts igneous, user info, greeting, favourites, profile and tag-translator requests | pump and cookie prep stay; **liveness observation and `loadUserSettings` move behind the age wall** |
| L5 | `.onScenePhaseChange(.active)` | `downloadClient.setIsInBackground(false)` (first-access risk as L4); then, only if `hasLoadedInitialSetting`: greeting fetch, log pump, clipboard detection, download reconcile | **yes** via the download client | **download-client calls behind the age wall** (record the latest phase in state and forward it on confirmation); the rest is already behind `hasLoadedInitialSetting` |
| L6 | `.windowSizeClassesChanged` → `.runLaunchAutomation` | launch automation, deep link from automation | via L4 | already guarded by `hasLoadedInitialSetting`; no change |
| L7 | `TabBarView.onOpenURL` → `PresentationFeature.handleDeepLink` | opens a gallery | **yes** | the root must own `onOpenURL` while gated and queue the URL (DD-07) |
| L8 | Share extension (`ShareExtension/ShareViewController.swift`) | opens the app with an `ehpanda://` URL through the responder chain | via L7 | covered by L7's queue |
| L9 | Tab root presentation actions (Home fetch etc.) | sent when the tab root activates | **yes** | not reachable while the gate replaces `TabBarView` at the root |
| L10 | `handleEventsForBackgroundURLSession` | hands the OS completion handler to `DownloadBackgroundSessionEvents` | OS-owned transfer | stays: it only reattaches a transfer the system already ran; see Pitfall P-3 |

`BackgroundProcessingClient` registers its continued-processing handler per download burst (post-launch, by design,
`ContinuedTaskScheduling.swift:75-99`), so deferring the download client does not break a launch-time BGTask
registration rule.

## 3. First launch: gate and storage

### 3.1 Gate shape (DD-06, DD-07)

- A `FirstLaunchReducer` (AppFeature) owns a three-state progression: `ageWall` → `analyticsChoice` → `complete`,
  derived from storage (§3.2), so a relaunch mid-flow resumes at the right screen.
- `AppReducer.State` carries `firstLaunch` and a computed `isUnlocked` (age confirmed). The gate rules:
  - `.appDelegate(.onLaunchFinish)` runs only L4's local work while locked, and records `didFinishLaunching`.
  - The unlock transition (age confirmed, or already confirmed at launch) runs the deferred work once: the liveness
    observation, `loadUserSettings`, and the recorded scene phase forwarded to the download client.
  - The analytics choice completing (or a stored level at launch) triggers `analyticsClient.apply(level)` (§4.4).
  - `onOpenURL` URLs received while locked are queued (latest wins, one slot) and routed through
    `presentation(.handleDeepLink)` after settings have loaded, i.e. after `.runLaunchAutomation`'s preconditions.
  - Only the age wall gates network; the analytics choice screen is shown before content (D-03) but the network may
    already start loading behind it. **Default recorded (section 9, A-2):** settings load starts at age
    confirmation, not after the analytics choice, so the tab content is ready when the second screen closes. This
    satisfies D-04 (the network rule is tied to the age wall) and D-06 (only the SDK waits for the choice).
- `RootView` renders the first-launch screens instead of `TabBarView` until `complete` (UI plan; needs the UI-SPEC).

### 3.2 Storage (DD-08, D-22)

- `Setting` is persisted whole under `AppStorageKey("setting")` (`AppModels/Persistence/AppSharedKeys.swift:53`), is
  already at `SchemaV2` (`Setting.swift:59`), and decodes through a hand-written `init(from:)` with `decodeIfPresent`
  for optional fields (`Setting.swift:92-127`). Adding optional fields needs **no schema bump and no migration**:
  absent keys decode as `nil`, which is exactly "never answered".
- Recommended fields on `Setting` (edited in place):
  - `ageDeclarationVersion: Int?` — the wording version the user confirmed; `nil` = never. The gate re-prompts when
    `ageDeclarationVersion != AgeDeclaration.currentVersion` (starts at 1).
  - `analyticsLevel: AnalyticsLevel?` — `nil` = not chosen yet. `AnalyticsLevel` is a `String`-raw `Codable` enum
    `minimal | basic | full` in AppModels (D-06a). No `none` case exists; nothing ever stored one, since the level
    is new in this phase.
- Retire `shareAnalyticsData` / `isSharingAnalyticsData` (`Setting.swift:227-241`): remove the property, the coding
  key and the decode line. Synthesised and hand-written decoding both ignore unknown keys, so a 2.x/pre-release blob
  that still carries `shareAnalyticsData` decodes with `analyticsLevel == nil`, which is what makes upgraders see the
  choice (D-03, DD-08). The precedent is `SettingRetiredTitlePreferenceTests` (a retired key neither resets settings
  nor is written again); `SettingAnalyticsOptOutTests` is rewritten into `SettingFirstLaunchFieldsTests`.
- Why on `Setting` rather than a dedicated key: the analytics client and its default-parameters closure already read
  `@Shared(.setting)` per signal, the Settings picker binds to `setting`, and a single model keeps one decode path.
  DD-08 allows either.

### 3.3 Automation and capture launches

Every UI test launch goes through `launchStubbed` (`EHPANDA_UITEST_STUB_NETWORK`), a capture launch through
`EHPANDA_CAPTURE_CONFIGURATION`, and the hosted visual tests through `EHPANDA_VISUAL_TEST_HOST`
(`UITestAutomation.swift`). Once the gate exists, all of them would stop at the age wall. So `UITestAutomation.prepare`
(DEBUG only) must, for any of these launches, write `ageDeclarationVersion = current` and `analyticsLevel = .minimal`
into the shared setting before the store is built (test hosts have no TelemetryDeck app ID, so even Minimal's install
signal is a no-op there), unless `EHPANDA_UITEST_FIRST_LAUNCH=show` asks for the real first
launch (used by the first-launch UI tests). The key starts with `EHPANDA_`, so `verify-release.py` already fails a
Release build that leaks it. Phase 19's capture scenes for the new screens will use the same key.

FeatureTests do not send `onLaunchFinish` (`AppInfo.isTesting`), but `AppReducer` tests that drive `.onLaunchFinish` or
the scene phase must state the gate (locked or unlocked) explicitly.

## 4. Analytics: SDK facts, the install signal and level gating

### 4.1 TelemetryDeck 2.14.2 (read from `AppPackage/.build/checkouts/SwiftSDK`, tag 2.14.2)

- `TelemetryDeck.signal` and `TelemetryDeck.internalSignal` both return early when
  `configuration.analyticsDisabled` is true (`TelemetryDeck.swift:46`, `:176`).
- `TelemetryManager.shared` asserts when accessed before `initialize`, so nothing may call the SDK before `start`
  (the existing `started` latch in `AnalyticsClient.live` protects `send`).
- Initialising starts a session: `Config.sessionID`'s `didSet` runs `SessionManager.startNewSession()` (when
  `sessionStatsEnabled`, default true) and sends `TelemetryDeck.Session.started` (when `sendNewSessionBeganSignal`,
  default true) (`TelemetryClient.swift:74-84`). `startNewSession` sends `TelemetryDeck.Acquisition.newInstallDetected`
  whenever its stored recent-session list is empty (`SessionManager.swift:170-185`); that list is pruned to 90 days at
  init, so a device idle for 90 days is "new" again. A new session starts on cold launch and after more than 5 minutes
  in the background; session-duration stats are written to the SDK's UserDefaults every second.
- **Every SDK signal carries `DefaultSignalPayload.parameters`** (`Signal.swift:43-135`), merged first in
  `SignalManager.processSignal` (`SignalManager.swift:152-190`): device model, OS and version, platform, app version
  and build, locale, language, region, time zone, screen metrics, colour scheme, layout direction, accessibility
  settings, calendar settings, SDK version, and the retention counters (first session date, total sessions, distinct
  days, average and previous session seconds). Metadata enrichers and parameters can override keys but cannot
  remove one. Hence D-06b: the SDK cannot send "only that EhPanda is installed".
- `TelemetryDeck.terminate()` sets the manager to nil; after it, `initialize` must be called again before any use.
  The `Config` is a reference type (`TelemetryManagerConfiguration`, a final class), so a held instance can be mutated.
- **Wire format** (what D-06b's own sender reproduces): `SignalManager.send` posts to
  `getServiceUrl(baseURL:namespace:)` = `https://nom.telemetrydeck.com/v2/` (no namespace configured), method `POST`,
  header `Content-Type: application/json`, body `JSONEncoder.telemetryEncoder.encode([SignalPostBody])`, a JSON
  array. `SignalPostBody` (`Signal.swift:15-40`) has `receivedAt` (date formatted `yyyy-MM-dd'T'HH:mm:ssZ`, UTC,
  `en_US` locale; `JSONFormatting.swift:49-57`), `appID`, `clientUser` (`CryptoHashing.sha256(string: id, salt:)`
  = SHA-256 hex of `id + salt`; salt `""` when none), `sessionID` (UUID string), `type`, `floatValue` (optional,
  omitted when nil by synthesized `Encodable`), `payload` (`[String: String]`), `isTestMode` (`"true"`/`"false"`;
  the SDK's default is `DEBUG`). Response disposition (`SignalManager.swift:430-455`): 2xx success; 400, 401, 403,
  404, 413, 422, 501, 505 dropped (not retried); anything else, or a transport error, retried with backoff.
- Cached but unsent signals are flushed on the SDK's own timer; neither `analyticsDisabled` nor `terminate` purges a
  request already in flight (Pitfall P-5).

### 4.2 Current client (`AnalyticsClient/AnalyticsClient.swift`)

`start` builds a `Config` (default parameters, orientation enricher), primes orientation, `initialize`s, sets
`started`. `send` returns unless started, then returns unless `setting.isSharingAnalyticsData`, then renders and
calls `TelemetryDeck.signal` or `errorOccurred`. `AnalyticsDefaultParameters.snapshot` returns `[:]` when opted out.
This is Phase 14's opt-out: `start` untouched so `Session.started`/`newInstallDetected` "still count the
installation" — with the full default payload, at every launch. It cannot be reused for Minimal (D-06b). The comment
at `:76-82` records Phase 14's reason for keeping the SDK alive when opted out; D-06b reverses that premise, so the
comment is rewritten, not kept (Pitfall P-4).

### 4.3 Level gating

| Level | SDK | SDK session/acquisition signals | App signals | Default parameters | Install signal (own sender) |
|-------|-----|----------------------------------|-------------|--------------------|-----------------------------|
| nil (not chosen) | never initialised | none | none | — | not sent |
| Minimal | **never initialised**; terminated if it was running in this process | none | none | — | once per install, payload = install source only |
| Basic | started | yes | screens and features ("which screens and features you use"): `tabOpened`, `homeSectionViewed`, `filterPanelOpened`, `quickSearchPanelOpened`, `savedSearchUsed`, `tagTapped`, `searchPerformed`; kinds of errors ("which kinds of errors occur"): `errorSurfaced`, `loginFailed`, `cloudflareChallengeEncountered` | `[:]` | once per install (same signal) |
| Full | started | yes | everything in Basic, plus reading and download activity: `galleryDetailOpened`, `readingSessionEnded`, `downloadStateChanged` (i.e. every `AnalyticsSignal` case) | the five `App.*` parameters ("your main settings") | once per install (same signal) |

Split per D-06f (owner msgs 1869, 1880; developer mapping msg 1878), replacing the earlier "Basic = errors only"
split. All 13 `AnalyticsSignal` cases are classified: 10 Basic, 3 Full.

- The gate is an exhaustive `switch` over `AnalyticsSignal` (no `default`), `AnalyticsSignal.minimumLevel`, so a case
  added later must be classified. **A-3 as amended by D-06f:** `cloudflareChallengeEncountered` is Basic, with the
  error kinds (developer decision, msg 1878; it was Full by default before, as an access event). OI-3 is closed.
- The install source rides only on the own install signal in this phase (D-06c); the Basic/Full SDK signals get it
  in ANALYTICS-02 (D-06, D-02 as amended). The SDK's `newInstallDetected` at Basic/Full
  duplicates the own install signal; ANALYTICS-02 reconciles it (carry to Phase 20, D-06b).

### 4.4 Lifecycle and the test seam (DD-09a)

- Replace the direct SDK calls with a `TelemetrySDK` struct of closures (`initialize(config)`, `terminate`, `signal`,
  `errorOccurred`) whose `.live` value is the only place importing `TelemetryDeck` (keeps the D-12 single-import
  rule). `AnalyticsClient.live(appID:salt:sdk:installSender:)` is then testable with recording fakes and a non-nil app
  ID; `AnalyticsClient.live` stays the nil-app-ID-to-noop resolution (Phase 14 D-13).
- Replace `start` with `apply: @Sendable (AnalyticsLevel?) -> Void`, idempotent:
  - `nil` → nothing at all (no SDK, no install signal).
  - `.minimal` → ensure the install signal (§4.5); if the SDK is running, `terminate()` it and clear the `started`
    latch; never `initialize`.
  - `.basic`/`.full` → ensure the install signal; `initialize` if not running (a terminated SDK may be initialised
    again in the same process).
- `send` reads the level live (as today it reads the toggle) and drops a signal whose `minimumLevel` exceeds it, and
  every signal while the SDK is not running.
- Callers: `AppReducer` once the age wall is confirmed (stored level at launch), `FirstLaunchReducer` on the choice,
  the General settings picker on change. Emission from reducers only (D-08).
- ~130 test sites override `analyticsClient` with `.noop`-derived spies (`AnalyticsClient.swift:15-18`); renaming
  `start` to `apply` touches only sites that set `start`. Grep before and after.

### 4.5 The own install sender (D-06b)

- `InstallSignalSender` in the AnalyticsClient module (no `TelemetryDeck` import needed: it builds the request
  itself), an `actor` so one request is in flight at a time. Dependencies injected for tests: `transport:
  @Sendable (URLRequest) async throws -> (Data, URLResponse)` (live: a `URLSession` with
  `URLSessionConfiguration.ephemeral`, `httpShouldSetCookies = false`, `httpCookieStorage = nil`, `urlCache = nil`),
  `now`, `uuid`, `sleep`, and the persisted state.
- Persisted state: a dedicated `@Shared(.installSignal)` `AppStorageKey` holding `{ settled: Bool, clientUser: String? }`
  (Codable, decodes absent as "not settled"). Not on `Setting`, so a settings reset cannot re-send it. `clientUser`
  is created on the first attempt and reused by every retry (a retry after a lost response then counts as the same
  user, not a second install), and cleared once settled.
- `ensureSent()`: return if settled or a send is in flight; build the request (§4.1 wire format, `type`
  `App.installed`, `payload` `{"App.installSource": <value>}`, §4.6); post; settle on 2xx or a drop status; on retry statuses or transport errors wait
  10 s, 20 s, 40 s and try again, then give up until the next `apply` (next launch, or the next level change).
- The request contains no device, OS, locale, region, time-zone, screen or app-version field. The IP address is
  visible to the ingest server at the transport layer, as for every request; nothing in the body adds to it.
- Tests (`InstallSignalSenderTests`, recording transport): exactly one request with the exact JSON keys
  (`appID`, `clientUser`, `isTestMode`, `payload`, `receivedAt`, `sessionID`, `type`), `payload` with exactly the
  one key `App.installSource` and a value from the enum, URL, method
  and header; a second `ensureSent` after success makes no request; a relaunch (a new sender over the same persisted
  state) makes no request; a 500 then 200 sends twice with the same `clientUser` and then never again; a 400 settles
  without a retry; two concurrent calls make one request; a nil app ID makes none.

### 4.6 The install source (D-06c)

- **API** (read from the iOS 27.2 SDK's `MarketplaceKit.swiftinterface`): `@available(iOS 17.4, *) public enum
  AppDistributor { static var current: AppDistributor { get async throws }; case appStore; case testFlight; case
  marketplace(String); @available(iOS 17.5, *) case web; case other }`. The package and the app target are on
  iOS 27 (`platforms: [.iOS(.v27)]`, `IPHONEOS_DEPLOYMENT_TARGET = 27.0`), so no `#available` guard is needed.
  MarketplaceKit is also in the simulator SDK, so the module builds for both.
- **Shape.** A new `InstallSourceClient` module (no TCA feature code; `ComposableArchitecture` for `@Dependency`
  only), so Phase 20's ANALYTICS-02 can reuse it without touching the sender. `public enum InstallSource: Equatable,
  Sendable { case appStore, testFlight, marketplace(String), web, other, unknown }` with `wireValue`
  (`appStore`, `testFlight`, `marketplace:<id>`, `web`, `other`, `unknown`); `InstallSourceClient { current:
  @Sendable () async -> InstallSource }` with `.live`, `.unknown` (test value) and a `static func
  map(_ distributor: AppDistributor) -> InstallSource` that is the only place reading MarketplaceKit cases.
- **Mapping.** `.appStore → appStore`, `.testFlight → testFlight`, `.marketplace(id) → marketplace(id)` when `id`
  matches `^[A-Za-z0-9.-]{1,155}$` (Apple's bundle-ID alphabet and length), else `unknown`; `.web → web`;
  `.other → other`; `@unknown default → unknown`; a thrown error → `unknown`. `#if targetEnvironment(simulator)`
  returns `unknown` and other `#if DEBUG` builds return `other` before MarketplaceKit is asked (D-06c), so the
  mapping on real distribution is verified in Phase 20.
- **Use.** `InstallSignalSender` takes `installSource: @Sendable () async -> InstallSource` and asks it once per
  `ensureSent()` call, before the first attempt; retries in the same call reuse the value. It is not persisted.
- **Tests** (`AnalyticsClientTests/InstallSourceTests`): every `AppDistributor` case maps as above (the enum's cases
  are public and constructible); invalid marketplace IDs (empty, 156 characters, `/`, space, non-ASCII) map to
  `unknown`; every `wireValue` matches `^(appStore|testFlight|web|other|unknown|marketplace:[A-Za-z0-9.-]{1,155})$`.
  `InstallSignalSenderTests` assert the payload's key set is exactly `{"App.installSource"}` with the injected value.
- **Privacy.** One low-cardinality value; a marketplace's bundle ID identifies the store, not the user. Threat
  T-18-21 (18-03) covers an unbounded or crafted string reaching the payload.

## 5. Comments: code map and moderation design

### 5.1 Where comments are rendered and posted

| Surface | File | Notes |
|---------|------|-------|
| Comments list | `DetailFeature/Comments/CommentsView.swift` | `List(comments)` of `CommentCell`; swipe actions vote down (leading), vote up and edit (trailing); toolbar "Post Comment" disabled when logged out; `PostCommentView` sheet for post and edit |
| Comments reducer | `DetailFeature/Comments/CommentsReducer.swift` | `Destination.postComment(String)` (empty = new); `.postComment(galleryURL:commentID:)` sends `EditGalleryCommentRequest` or `CommentGalleryRequest`; has `galleryURL`, `setting` |
| Detail preview | `DetailFeature/DetailView+CommentCells.swift`, `DetailView+Subviews.swift` `CommentsSection` | fixed-size cards (`cardWidth`/`cardHeight × scale`) in a horizontal strip composited as one drawing group (removed in this phase, §5.6 a); one combined accessibility element |
| Detail post | `DetailFeature/DetailReducer+Actions.swift:61`, `DetailReducer+Fetch.swift:167` | Detail's own post-comment path (`.postComment(URL)`), separate from the comments screen |
| Editor | `DetailFeature/Components/PostCommentView.swift` | toolbar confirm (`role: .confirm`) runs `postAction`, which today also dismisses |
| Model | `AppModels/Gallery/GalleryComment.swift` | `author`, `commentID`, `votable`, `editable`, `plainTextContent`; no report link |

So the posting warning must sit in **two** reducers (Detail's new-comment path and the comments screen's post/edit
path). Both must keep the sheet open and the text intact when the warning is shown, which changes today's
"post then dismiss in the view" order: the view sends a post intent and the reducer decides whether to dismiss.

### 5.2 Report target (D-10, OI-1)

- Both captured gallery pages (`EhPandaUITests/Fixtures/GalleryDetail.html`, `AppPackage/Sources/TestingSupport/
  Resources/Parser/Gallery/GalleryDetail.html`) contain exactly one report link: `<a href="https://e-hentai.org/g/
  3103480/0000000000/?report=select">Report Gallery</a>`. The per-comment chrome is `c4 nosel` with `Vote+`/`Vote-`
  (and Edit for one's own comments); no report link.
- Report URL = the gallery URL with query `report=select`, on the gallery's own host (e-hentai.org or exhentai.org).
  `{site}` = the gallery URL's host mapped to `GalleryHost.rawValue` ("E-Hentai" / "ExHentai"), falling back to the
  current `setting.galleryHost` when the host is unrecognised.
- **Route: an in-app sheet that carries the app's sign-in (decision A-5, revised; the designer's preference).** How
  the app holds its session today:
  - The session lives in `HTTPCookieStorage.shared`, owned by `CookieClient` (`CookieClient/CookieClient.swift`;
    `DidLoginKey.swift`: "`HTTPCookieStorage` stays the single source of truth"). Every app request reads it.
  - The only bridge to WebKit is one-way and one-time: the web-login sheet (`SettingFeature/Components/WebView.swift:34-36`)
    copies the `WKWebView` default store's cookies **into** `HTTPCookieStorage.shared` when the login page finishes.
    Nothing copies the app's cookies **into** WebKit, and `CookieClient.clearAll` (logout) does not touch WebKit.
  - The existing `WebView` sheet (EhSetting's uConfig, Account's My Tags) uses `WKWebView()` with the default
    persistent store, so it is signed in only if the user once signed in through the web-login sheet, and it stays
    signed in after the app logs out. Reusing it for Report would show a signed-out form to users who signed in with
    the native form or pasted cookies, and a signed-in form after logout. (Recorded as a finding for the existing
    sheets; not changed in this phase.)
  - `ChallengeWebView` (`SettingFeature/Components/ChallengeWebView.swift:92`) already uses
    `WKWebsiteDataStore.nonPersistent()`, the pattern to copy.
  - **Decision:** a new `SessionWebView` (AppComponents, so DetailFeature can present it) built on a
    `WKWebsiteDataStore.nonPersistent()` store. Before loading, it writes the app's current cookies for the report
    URL's host into that store's `httpCookieStore` (`await setCookie` for each; awaited before `load`), taken from a
    new `CookieClient.sessionCookies(for: URL) -> [HTTPCookie]` (reads `cookieStorage.cookies(for:)`). The sheet is
    presented from the comment's alert action (UI-SPEC C-4: large detent, `SheetCloseToolbar`, no title,
    `.privacyMask()` like the other web sheets). Nothing persists after the sheet closes, and the web view's sign-in
    always equals the app's: signed out in the app means signed out on the form. Cookies are scoped by WebKit to their
    domain, so navigation inside the sheet cannot carry them to another site.
  - Signed-out users can still open Report (UI-SPEC C-4); the site shows its own sign-in prompt in the sheet.

### 5.3 Posting filter (DD-04)

- Pure function `CommentFilter.matches(_ text: String, terms: CommentFilterTerms) -> Bool`, no I/O; the bundled list
  is a JSON resource in DetailFeature (`Resources/CommentFilterTerms.json`, six language groups), loaded once.
- Normalisation, applied identically to the list and the input: `folding(options: [.caseInsensitive,
  .widthInsensitive, .diacriticInsensitive], locale: nil)`, then collapse whitespace.
- Matching: Latin-script terms match on word boundaries (so a term inside a longer innocent word does not match);
  CJK and Hangul terms match as substrings (no word spaces; Korean particles attach to nouns).
- Tests inject a synthetic term list for the matching rules, and separately prove the bundled list loads, has every
  language group non-empty, contains no sexual-vocabulary group, and round-trips through normalisation.

### 5.4 Block store (DD-10, D-13, D-14)

- `@Shared(.blockedCommentAuthors)`: `AppStorageKey<[String]>` (ordered, de-duplicated on insert, so the Settings list
  has a stable order; a `Set` has none). Exact author strings; device-local.
- "Show" is per-session view state: a set of revealed comment IDs in the reducer, cleared when the screen goes away.
- The collapsed row never renders `author` (D-13). Unit test: the collapsed row's accessibility label and text do
  not contain the author.
- **Where the list lives (D-14a):** Account settings. `AccountSettingView` (`SettingFeature/AccountSetting/`) is a
  `Form` with the account section (website picker, log in/out, host settings, My Tags) and then `CookieSection`; the
  new section goes between them and is shown signed in or not (UI-SPEC C-10). The push follows the existing pattern:
  `AccountSettingReducer.Delegate` gains `.pushBlockedUsers` beside `.pushLogin`/`.pushEhSetting`, `SettingPath` gains a
  `.blockedUsers(BlockedUsersReducer)` case with its `pathID`, and `SettingReducer+Body.swift` maps the delegate to the
  push (as it does for `.pushEhSetting` at `:32`). The block store is read through `@Shared`, so the list and the
  comments screens stay in step without messages between features.

### 5.5 Accessibility and dialog constraints for the UI-SPEC

- Phase 16 (16-13, confirmed in `16-SWEEP.md` OQ2) recorded `CONTEXTMENU=not-exposed`: a SwiftUI context menu is not
  a VoiceOver rotor source in this app, so a context menu alone would make Report and Block unreachable. Every menu
  action must also be mirrored as an `accessibilityAction(named:)` (the project's established mirror pattern).
- AGENTS.md "Confirmation dialog / alert placement": attach each confirmation to the triggering row, not the list.
- The Detail preview card is fixed-size; the collapsed row must fit the same card budget at every Dynamic Type size
  (the card layout tests in `CommentCardLayoutTests` are the pattern).

### 5.6 The designer's three technical questions (UI-SPEC C-4, C-8; answered from the code)

- **(a) Buttons and context menus inside the Detail strip's `drawingGroup()`.** The strip is
  `ScrollView(.horizontal) { HStack { ForEach CommentCell }.drawingGroup() }` (`DetailView+Subviews.swift:614-622`).
  Today it holds only `Text` and SF Symbol images, so nothing in it has had to be interactive. `drawingGroup()`
  flattens the subtree into one offscreen Metal-rendered image: SwiftUI-drawn content renders, but anything backed by
  a platform view renders as a placeholder, and system effects that lift or highlight a single view (the context-menu
  preview, `.hoverEffect`) can only see the flattened group, not the card. SwiftUI still hit-tests the view tree, so
  plain taps may work, but per-card context menus and hover are not safe to assume. The modifier came in with
  `eb8e6fd0e` (2021, "Better DescScrollView approach", an iOS 14/15-era rendering workaround) and has no purpose for at
  most six fixed-size text cards today. **Decision (A-11):** remove `.drawingGroup()` from the strip in the comment
  UI plan, update the `CommentCell` doc comment that cites it, and prove the result with a UI test (long-press on a
  card shows Report and Block; the collapsed card's Show and Unblock work) plus the agent-run check on both
  simulators. The other two `drawingGroup()` uses (`LoginView`, `GalleryDetailCell`) are untouched.
- **(b) Detecting the user's own comments (no menu on them).** The parser sets `GalleryComment.editable` when the
  comment's `c4 nosel` bar has an `edit_comment` link (`ParserFeature/Parser+Comment.swift:31-41`); the site renders
  that link only on the signed-in user's own comments. The signed-in user's forum name is also persisted as
  `User.displayName` (`AppModels/Persistent/User.swift`, set in `SettingReducer.swift:75`), which is the name the
  site prints as a comment's author. **Decision (A-10):** `isOwn = comment.editable || (didLogin &&
  user.displayName == comment.author)`, a pure function with tests. `editable` alone is the designer's suggested proxy;
  the name check covers an own comment whose Edit link the site no longer shows. A false positive is not possible in
  practice (forum names are unique), and its only effect would be a missing menu on one comment.
- **(c) Report in an in-app sheet or the browser.** In an in-app sheet that carries the app's sign-in, by seeding a
  private web view from the app's cookie store (§5.2). The browser would not have the app's session at all.

## 6. Reader page tracking (D-18, D-19, DD-01..DD-03, DD-11)

### 6.1 Current anchors (confirmed against `17-READER-ROOT-CAUSE.md` §1)

- A `pageModel.index`: `Support/PageModel.swift:23`; written by `jump` (`ReadingView.swift:491-511`), the idle
  observer (`:351-356`), `correctPager` (`:532-550`), `seedPager` (`:559-566`), `setPageIndex` (`:568`).
- B `scrollPositionID`: `ReadingView.swift:39`, bound at `:334`; written by `scrollPager`, `tryScrollTo` (`:576`),
  `pagerRebuilt` (`:526-530`), `correctPager`, `seedPager`.
- C `shownPagerPosition`: `:42`, from `onScrollTargetVisibilityChange` (`:336`).
- D `pageHandler.sliderValue`: seeded at `:56`, drives the title (`:166`) and slider; mirrored from A at `:403-411`.
- E `readingProgress` / `pendingReadingProgress`: `ReadingReducer.swift:58-61`; `.syncReadingProgress`
  (`ReadingReducer+Session.swift:13-18`).
- F `AdvancedList.position`: `Support/AdvancedList.swift`.
- Control state: `PagerTurnGate` (`PageModel.swift:60-131`), `PagerSeed` (`:134-147`), `performingChanges` (`:43`,
  `PageModel.echoGuardDuration = 0.2`).
- Rebuild sites: `.id(store.forceRefreshID)` (`:219`) with `.onChange(of: forceRefreshID)` (`:221`), and the
  `readingDirection` observer (`:418-420`).

### 6.2 Target (DD-11)

`ReaderPosition` value in `ReadingReducer.State` (reading-page space, 1-based): `page`, `request: {target, generation,
tries}?`, `generation`. Pure transitions: `turn(to:)`, `pagerSettled(shown:generation:)`, `pagerRebuilt()`; the
derived pager position is `PageHandler.mapToPager(page, layout)`. The view keeps one actuator that writes B only on a
command and reports C at `.idle` with the generation it was built with. D is derived from `page`; the slider keeps a
display-only scrub value while dragging (DD-01). After the retry limit the shown page is committed (DD-02).
`readingProgress` persistence reads `page`. The rework deletes `PagerTurnGate`, `performingChanges` and the
A↔B/A↔D/A↔F `onChange` mirrors; `PagerSeed` shrinks to "area measured".

### 6.3 Tests to port and add

- Port: `PagerTurnGateTests` (16 cases → `ReaderPositionTests`; WR-01's four rebuild cases become "stale generation
  ignored"), `PagerSeedTests` (3), `PageHandlerTests`, `ContainerDataSourceTests`, `ReaderPagesAccessibilityTests`,
  `AutoPlayHandlerTests`, `ReadingOrientationTests`, ReadingFeature `AnalyticsEmissionTests`.
- Keep green unchanged: `ReaderPageSyncUITests` (8 tests), `ReadingOrientationUITests` (3), `DuoReadingPanelUITests` (2).
- Add (D-19): `ReaderRebuildUITests` with
  1. `testReloadAllImagesThenATurnKeepsTheIndicatorOnThePageShown` (G1, forced-refresh path);
  2. `testChangingDirectionDuringAutoPlayKeepsTheIndicatorOnThePageShown` (G1, direction path; R5-1's gap);
  3. `testSwitchingLeftToRightAndRightToLeftKeepsThePageInSync` (G2, RTL).
  Plus R5-1's suggested run: a DEBUG-only launch key that drops the new pager's first `idle` report
  (`EHPANDA_UITEST_DROP_INITIAL_IDLE`), run against test 1 so the "stale generation ignored" rule is what passes it.
- Mapping from the Phase 17 UAT harness (kept outside the repo): its T1 (Reload All Images while reading) → test 1;
  T2 (vertical → LTR) is covered by `ReaderPageSyncUITests.underEachDirection`; T3 (LTR → RTL, with Auto-Play) → tests
  2 and 3; T4/T4b (reopen, quick turns, rotation, fast tap bursts) stay covered by the existing suites. The harness's
  timing approach (one synthesized event: edge tap, then More, then Reload All Images at a measured lead) is reused;
  its video/NSLog evidence approach is not committed. The harness's code is not copied into the repo verbatim; the
  committed tests use `ReaderPageProbe` and the existing `XCUIApplication` helpers.

## 7. Carries and the release fix

### 7.1 IN-02 (`Scripts/visual/verify-release.py:19-35`)

Add `b'captureSystemOverlay'` to `FORBIDDEN_CONTENT`. Today every use is DEBUG-gated: the key itself
(`AppComponents/CaptureSystemOverlays.swift`, whole file in `#if DEBUG`), `ReadingView.swift:24-26,69-73`,
`FiltersView.swift:9-11,54-56`, `RootView.swift:33`. So a clean Release passes. Add a case to `test_release.py`
modelled on `test_seeded_bad_payload_fails_on_every_leak` (`:104-127`): a binary containing
`captureSystemOverlayVisibility` must produce a `content` finding with token `captureSystemOverlay`.

### 7.2 IN-03 (`AppFeature/RootView.swift:1`)

Move `import AppComponents` into a `#if DEBUG` block (line 4's block is `DEBUG && canImport(Appshot)`, so a separate
`#if DEBUG` import line is needed). If the gate UI later needs AppComponents in Release, the import moves back out
with that use, and plan 18-09 must say so (it is then no longer unused).

### 7.3 `MKSellsDigitalGoods` (`App/Info.plist`)

The key is absent today. Add `<key>MKSellsDigitalGoods</key><false/>`. Verify on the built product with
`plutil -extract MKSellsDigitalGoods raw <app>/Info.plist` → `false`.

## 8. Localisation

- Module catalogs: `<Module>/Resources/Localizable.xcstrings`; non-translatable constants in `Constant.xcstrings`.
  Symbols are generated (`STRING_CATALOG_GENERATE_SYMBOLS`); cross-module strings live in the `Resources` module and
  are re-exported through `Resources/ResourceStringSymbols.swift` as `.RLocalizable.…`.
- Placement (recommended):
  - First-launch and level strings (`ageWall*`, `consent*`) → `Resources` (used by AppFeature's first-launch screens
    and SettingFeature's picker), with forwarders.
  - Comment report/filter/block strings → `DetailFeature` catalog.
  - Blocked Users strings → `Resources` with forwarders: the list is in SettingFeature, but the collapsed row's
    Unblock pill (DetailFeature) reuses `blocked_users.unblock` (UI-SPEC copy table), so the key is shared.
  - The privacy page URL → `Resources/Resources/Constant.xcstrings` (`contact.privacy_policy`, untranslated,
    forwarded as `.RConstant.contactPrivacyPolicy`), because both AppFeature (analytics choice) and SettingFeature
    (General) open it; `contact.website` (`https://ehpanda.app`) in SettingFeature's catalog is the analog.
- Keys: the copy files' keys are suggestions (D-09). The catalogs already use dotted snake-case keys
  (`continued_session.title`, `download_store.download_busy`) beside older camelCase ones (`shareAnalyticsData`), so
  the copy files' keys are used as written; the generated symbols are camelCase (`age_wall.title` → `ageWallTitle`).
  The strings are copied verbatim (straight apostrophes, as in the copy files).
- Placeholders: `{site}` and `%@` both appear in `comment.report.confirm_body`; use positional `%1$@` (site) and
  `%2$@` (author) in every locale (the order is the same in all six). `comment.report` uses `%@` for the site.
- Every new key is filled for en, de, ja, ko, zh-Hans, zh-Hant (D-22). A catalog check script (python, reads the JSON)
  proves it and compares each value with the copy file's table cell byte for byte.
- **Minimal (D-06a, `18-COPY-MINIMAL.md`, owner msg 1805):** the catalog gets `consentLevelMinimal`,
  `consentLevelMinimalDescription` and `consentBody` with the Minimal file's text (the description from its
  Revision 2, owner msg 1818, D-06c; the first-table description is superseded; `consentBody` from its Revision 5,
  below); the first-launch file's
  `consent.level.none`, `consent.level.none.description` and old `consent.body` are never added.
- **Basic (D-06d, owner msgs 1830, 1839):** `consentLevelBasicDescription` takes Revision 3 of the Minimal file
  ("Everything in Minimal, plus how often the app is used, technical details such as device model and app version, and
  which kinds of errors occur." and its five translations); the first-launch file's Basic description is retired.
  The Basic name stays the first-launch file's. **Superseded by D-06f:** see the next bullet.
- **Basic, Full and Recommended (D-06f, owner msgs 1869, 1880, 1882):** `consentLevelBasicDescription` and
  `consentLevelFullDescription` take Revision 6 of the Minimal file (Basic: "Everything in Minimal, plus how often the
  app is used, which screens and features you use, technical details such as device model and app version, and which
  kinds of errors occur."; Full: "Everything in Basic, plus your reading and download activity and your main
  settings."); the Revision 3 Basic line and the first-launch Full line are retired. A new key
  `consent.level.recommended` ("Recommended" and its five translations, Revision 6) labels Basic on the first-launch
  screen only (UI-SPEC C-3).
- **Intro (D-06e, owner msgs 1844, 1854, 1864):** `consentBody` takes Revision 5 of the Minimal file ("Anonymous
  analytics. Your searches and the galleries you view are never sent." and its five translations); the msg-1805
  first-table `consent.body` is retired, like the original first-launch one. Revision 4 (msg 1847) was not approved.
- Copy precedence: the Minimal file's Revision 6 (Basic and Full descriptions, `consent.level.recommended`),
  Revision 5 (`consent.body`) and Revision 2 (Minimal description) > its first table > the first-launch file
  (Revision 3 is superseded by Revision 6). The copy check reads the Minimal file for those six keys and the
  first-launch file for the rest, and fails if any retired text (`None`/`Nothing is sent.` rows, both old
  `consent.body` texts, the superseded first-table Minimal description, the first-launch Basic description, the
  Revision 3 Basic description, the first-launch Full description) appears in a catalog.
- `shareAnalyticsDataFooter` (and the old toggle's use of `shareAnalyticsData` as a toggle label) is removed in the
  same plan that removes its last use (the Settings UI plan, 18-10), or the module stops compiling.
- READMEs: `README.md` "## Analytics" (`:34-43`) and the five files in `READMEs/` describe on-by-default and "your
  installation is still counted". Rewrite each for Minimal / Basic / Full, quoting the approved level descriptions in
  that language (DD-12); none may say analytics can be turned off completely (`18-COPY-MINIMAL.md`, knock-on note).

## 9. Defaults recorded in place of questions

| ID | Default | Why | Owner tag |
|----|---------|-----|-----------|
| A-1 | Run all GSD roles inline; no `/gsd-ui-phase`; UI gate honoured by task dependencies on the committed UI-SPEC | user instruction for this run | — |
| A-2 | Network may start at age confirmation, before the analytics choice is made | D-04 ties the network rule to the age wall; only the SDK waits for the choice (D-06) | technical |
| A-3 | *Amended by D-06f (owner msgs 1869, 1880; developer msg 1878):* Basic = SDK session/acquisition signals + `tabOpened`, `homeSectionViewed`, `filterPanelOpened`, `quickSearchPanelOpened`, `savedSearchUsed`, `tagTapped`, `searchPerformed` + `errorSurfaced`, `loginFailed`, `cloudflareChallengeEncountered`; Full = Basic + `galleryDetailOpened`, `readingSessionEnded`, `downloadStateChanged`; default parameters Full only; Minimal = the own install signal only, SDK never initialised (D-06b) | approved descriptions | technical; owner tagged |
| A-4 | Both new fields on `Setting`; retire `shareAnalyticsData` by removal | DD-08, D-22 | technical |
| A-5 | Report page opens in an in-app sheet (`SessionWebView`) whose non-persistent web view is seeded with the app's cookies for the gallery host (revised from "system browser" after reading the cookie code, §5.2) | the site's form needs the session, which only the app's cookie store holds; the designer's preference | technical |
| A-6 | Privacy URL `https://ehpanda.app/privacy` as a constant, confirmed by the website owner before Phase 20 | the page exists (copy file, "Knock-on for the website"); its exact path is not in the repo | open item OI-2 |
| A-7 | Block list stored as ordered `[String]` | stable list order | technical |
| A-8 | UI tests and capture launches preset the first-launch answers in DEBUG; `EHPANDA_UITEST_FIRST_LAUNCH=show` opts out | keeps every existing suite runnable | technical |
| A-9 | `{site}` = gallery host's display name | D-15 allows either form | — |
| A-10 | Own comment = `editable` or (signed in and `User.displayName == author`); no menu on it | §5.6 (b) | technical |
| A-11 | Remove `.drawingGroup()` from the Detail comment strip | §5.6 (a) | technical |
| A-12 | Install signal: own sender, `type` `App.installed`, payload exactly `App.installSource` (D-06c, §4.6), once per install at every level, dedicated persisted state, SDK-mirrored retry/drop rules; lowering to Minimal terminates the SDK | D-06b (lead's decision, recorded in CONTEXT) | technical |
| A-13 | UI tests and capture launches preset `analyticsLevel = .minimal` | test hosts have no app ID, so nothing is sent; Minimal is the lowest level | technical |

## 10. Pitfalls

- **P-1 Lazy download client.** Any `downloadClient` access while locked builds the live client and may resume
  queued transfers (L4/L5). Test: a locked `AppReducer` with an unimplemented `downloadClient` receives
  `.onLaunchFinish` and `.onScenePhaseChange(.active)` without a reported issue.
- **P-2 Existing AppReducer tests.** Tests that drive launch or scene phase assume the old ungated order; give each
  an explicit gate state instead of weakening the gate.
- **P-3 OS-owned background transfers.** A 3.0 pre-release user with transfers in flight may receive
  `handleEventsForBackgroundURLSession` before confirming. The app starts nothing new; the OS finishes its own
  transfer. Accepted and recorded; the gate does not touch it.
- **P-4 Phase 14 comment.** `AnalyticsClient.swift:76-82` argues for keeping the SDK alive when opted out "so
  installs are still counted"; rewrite it to D-06b's rule (Minimal never initialises the SDK; the own sender counts
  installs) or the next reader will "restore" Phase 14's behaviour.
- **P-5 Cached signals.** Lowering to Minimal stops new app signals at once and terminates the SDK (DD-09a), but a
  batch the SDK already handed to `URLSession` may still complete. Accepted: it was sent under the consent in force
  when emitted.
- **P-11 WebKit cookie store is not the app's.** `WKWebView()` uses its own persistent store, which the app never
  writes and logout never clears (§5.2). Never present the report page in the existing `WebView`.
- **P-12 Install signal and the vendor's validation.** The own sender reproduces the SDK's 2.14.2 wire format; a
  future vendor change could reject it (a drop status settles it silently). Mitigation: the request is pinned by
  `InstallSignalSenderTests` against the SDK's field list, and 18-12's agent-run check observes one accepted request
  when a credentialed build is available; an SDK upgrade must re-read `SignalPostBody`.
- **P-6 Diacritic folding in Japanese.** `.diacriticInsensitive` also strips dakuten (が → か). Fold list and input the
  same way; a few extra false positives only produce a warning that can be dismissed.
- **P-7 VoiceOver and context menus.** See §5.5.
- **P-8 Post-then-dismiss order.** `CommentsView`'s `postAction` sends `.postComment` then dismisses; with the
  warning, dismissal must follow the reducer's decision or the typed text is lost (D-12).
- **P-9 Release leak of the new DEBUG keys.** `EHPANDA_UITEST_FIRST_LAUNCH` and `EHPANDA_UITEST_DROP_INITIAL_IDLE`
  must sit in `#if DEBUG` code; `verify-release.py` fails Release otherwise (`EHPANDA_` token).
- **P-10 Upgrader re-prompt.** If the confirmed wording version is compared with `>=` instead of `==`, a downgrade
  test blob would skip the wall; compare for equality with the current version.

## 11. Open items

- **OI-1 Per-comment report link.** Not found in the two captured gallery pages (logged-in fixture HTML). The live
  site could not be checked from this environment (no network access to the site was used). The copy's second
  sentence stays. If an executor or the owner finds a per-comment report link on the live site, drop the second
  sentence of `comment.report.confirm_body` in all six locales (copy file note) and point the action at that link.
- **OI-2 Privacy page URL.** Default A-6; the website owner confirms the path before Phase 20's listing work.
- **OI-3 Basic vs Full classification of `cloudflareChallengeEncountered`.** CLOSED: Basic (developer decision msg
  1878, with D-06f).
- **OI-4 Install-count duplicate at Basic/Full.** The SDK's `newInstallDetected` and the own `App.installed` both
  arrive for Basic/Full installs. Carry to Phase 20's ANALYTICS-02 (D-06b); the dashboard should count `App.installed`.
- **OI-5 Existing web sheets' sign-in.** uConfig and My Tags use the default WebKit store (§5.2), so their sign-in can
  differ from the app's. A finding, not in this phase's scope; reported to the lead.

## 12. Security domain (ASVS L1)

| Area | Applies | Control |
|------|---------|---------|
| V1 Architecture (consent before processing) | yes | SDK, install signal and network behind the gate; unit proof of no SDK call and no request before consent; SDK never initialised under Minimal |
| V5 Input handling | yes | filter runs on user text locally; no text leaves the device for filtering; report URL built from the parsed gallery URL only, never from comment content |
| V6/V8 Data protection | yes | block list and answers stay in local app storage; analytics vocabulary stays type-closed; no author names in analytics; the one new signal (`App.installed`) carries only the install source (a fixed enum; marketplace IDs validated) and a random, per-install, salted-hash user ID that is discarded once sent |
| V3 Session management | yes | the report sheet's web view is non-persistent and seeded only with the gallery host's cookies; nothing is written back to the app's store; the sheet's sign-in always equals the app's |
| V14 Configuration | yes | DEBUG-only automation keys; Release scanner tokens (`EHPANDA_`, `captureSystemOverlay`) |

Threat IDs are unique across the phase: T-18-01 scanner (18-01); T-18-02..04 gate bypass, early deep link, DEBUG
preset leak (18-02); T-18-05..08 analytics before consent, Minimal payload or SDK start, repeated or linkable install
signal, credentials and endpoint (18-03); T-18-21 install-source value (18-03); T-18-09..11 report URL off-site, filter list failure, cookie scope
(18-04); T-18-12..13 author-name leak, post before the warning (18-05); T-18-14 copy drift (18-06); T-18-15 reader
progress integrity (18-07); T-18-16 DEBUG idle key leak (18-08); T-18-17 content rendered behind the gate (18-09);
T-18-18 Settings lowering not stopping the SDK (18-10); T-18-19..20 web sheet persistence, menu/collapsed-card leak
(18-11); T-18-22..23 README overclaim, DEBUG keys in the Release product (18-12). `T-18-SC` is reserved for package installs.

## Package Legitimacy Audit

No package-manager installs in this phase. TelemetryDeck stays at the resolved 2.14.2; no dependency is added or
upgraded. `T-18-SC` is carried in every plan as not applicable.

## Validation Architecture

### Test framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (255 test files) for FeatureTests; XCTest for `EhPandaUITests`; `unittest` for `Scripts/visual` |
| Config | `AppPackage/Tests/FeatureTests.xctestplan`, the `UITests` test plan, `.swiftlint.yml` |
| Quick run | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE" -only-testing:<Module>Tests` |
| Full run | FeatureTests on `$PHONE` then `$PAD`; UITests on `$PHONE` then `$PAD`; one invocation at a time |
| Lint | `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` |
| Python | `python3 -m unittest discover -s Scripts/visual -p 'test_release.py'` |
| Devices | the project simulators `EhPanda iPhone Air` (`$PHONE`) and `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), resolved by name with `xcrun simctl list devices` |

### Requirement → test map

| Req / item | Behaviour | Type | Command / file | Exists? |
|------------|-----------|------|----------------|---------|
| AGE-18-01 | locked launch starts no network-capable client and no SDK | unit | `AppFeatureTests/FirstLaunchGateTests` | ❌ W0 (18-02) |
| AGE-18-01 | unlock runs the deferred work once; queued deep link routes after load | unit | `AppFeatureTests/FirstLaunchGateTests` | ❌ W0 (18-02) |
| AGE-18-01 | answers persist; wording-version re-prompt; legacy blobs | unit | `AppModelsTests/SettingFirstLaunchFieldsTests` | ❌ W0 (18-02) |
| AGE-18-01 | Continue dimmed until ticked; nothing else reachable; no request before Continue | UI | `EhPandaUITests/FirstLaunchUITests` | ❌ (18-09) |
| CONSENT-18-01 | no SDK call and no request before the choice; SDK never initialised under Minimal; Basic/Full gating per §4.3 (D-06f: 10 Basic cases, 3 Full-only); lowering terminates | unit | `AnalyticsClientTests/AnalyticsLevelGateTests` | ❌ W0 (18-03) |
| CONSENT-18-01 | Minimal: exactly one request, payload exactly `App.installSource`, exact wire keys, never a second (relaunch, level change, concurrency); retry/drop rules | unit | `AnalyticsClientTests/InstallSignalSenderTests` | ❌ W0 (18-03) |
| CONSENT-18-01 | install-source mapping, ID validation, wire values | unit | `AnalyticsClientTests/InstallSourceTests` | ❌ W0 (18-03) |
| CONSENT-18-01 | Settings picker writes the level and calls `apply` | unit | `SettingFeatureTests/GeneralSettingReducerTests` | extend (18-10) |
| CONSENT-18-01 | first-launch choice screen has no default, three equal options, Recommended label on Basic only, Continue dimmed until picked | UI | `FirstLaunchUITests` | ❌ (18-09) |
| UGC-18-01 | filter normalisation and matching; bundled list | unit | `DetailFeatureTests/CommentFilterTests` | ❌ W0 (18-04) |
| UGC-18-01 | report URL and site name; own-comment rule; session cookies scoped to the host | unit | `DetailFeatureTests/CommentReportTargetTests`, `DetailFeatureTests/CommentOwnershipTests`, `CookieClientTests` | ❌ W0 (18-04) |
| UGC-18-01 | block store ordering and de-duplication | unit | `AppModelsTests/BlockedCommentAuthorsTests` | ❌ W0 (18-04) |
| UGC-18-01 | warning flow for post and edit keeps text; block/unblock/show-once; report confirm presents the report sheet | unit | `DetailFeatureTests/CommentModerationReducerTests` | ❌ (18-05) |
| UGC-18-01 | Account → Blocked Users push, list, unblock, empty state | unit + UI | `SettingFeatureTests/BlockedUsersReducerTests`, `EhPandaUITests/SettingsModerationUITests` | ❌ (18-10) |
| UGC-18-01 | `…` menu, long-press, a11y actions, alerts, collapsed rows and cards, Detail strip menu after `drawingGroup` removal | UI | `EhPandaUITests/CommentModerationUITests` | ❌ (18-11) |
| copy | every new key in six locales, verbatim (Minimal file for the superseded keys: its Revision 2 for the Minimal description, its Revision 3 for the Basic description, D-06d; its Revision 5 for `consent.body`, D-06e); retired text absent, incl. the first-launch Basic description and both old `consent.body` texts | script | `.planning/phases/18-…/18-copy-check.py` run by plan 18-06 | ❌ (18-06) |
| reader | one source of truth; ported rules | unit | `ReadingFeatureTests/ReaderPositionTests` + ported suites | ❌ W0 (18-07) |
| reader G1/G2 | rebuild then turn; direction change in Auto-Play; LTR/RTL | UI | `EhPandaUITests/ReaderRebuildUITests` | ❌ (18-08) |
| IN-02 | scanner catches `captureSystemOverlay` | python | `Scripts/visual/test_release.py` | extend (18-01) |
| IN-03 | no Release `import AppComponents` in RootView | grep | `grep -n` in 18-01 | — |
| DIST-18-01 | `MKSellsDigitalGoods` false in the built product | plutil | 18-01 | — |

### Sampling

After every task: the module's FeatureTests (`-only-testing:<Module>Tests`) and strict lint of touched paths. After
every plan: the module tests on `$PHONE` then `$PAD`. Phase gate (18-12): FeatureTests and UITests on `$PHONE` then
`$PAD`, 0 failures and 0 Repetition nodes, strict no-cache lint 0 violations.

### Wave 0 gaps

The ❌ W0 rows are written test-first inside their own plans (18-02, 18-03, 18-04, 18-07): each plan's first task
adds the failing tests. No framework install is needed.

## Sources

- Code at `43333aae0` (files cited inline); TelemetryDeck SwiftSDK 2.14.2 resolved checkout.
- `18-CONTEXT.md` (incl. amendments D-06a, D-06b, D-06c, D-06d, D-06e, D-06f, DD-09a, D-14a, D-17a), `18-COPY-FIRST-LAUNCH.md`,
  `18-COPY-MINIMAL.md` (with Revision 2, msg 1818, Revision 3, msg 1839, Revision 5, msg 1864, and Revision 6, msg 1880), `18-COPY-COMMENTS.md`, `18-UI-SPEC.md` (final, msg 1826; Basic line refreshed, msg 1843), `18-DISCUSSION-PREP.md`,
  `18-DISCUSSION-LOG.md`.
- iOS 27.2 SDK `MarketplaceKit.framework` Swift interface (`AppDistributor`).
- TelemetryDeck SwiftSDK 2.14.2 at `AppPackage/.build/checkouts/SwiftSDK`: `TelemetryDeck.swift`,
  `TelemetryClient.swift`, `Signals/SignalManager.swift`, `Signals/Signal.swift`, `Helpers/SessionManager.swift`,
  `Helpers/CryptoHashing.swift`, `Helpers/JSONFormatting.swift`.
- Phase 14: `14-18-SUMMARY.md`, `14-VERIFICATION.md` (truth 4), `COVERAGE.md` (`analyticsDisabled` row) for the old
  opt-out mechanism.
- `17-READER-ROOT-CAUSE.md`, `17-WR01-MIDTURN.md`, `17-VERIFICATION.md` (R5-1), `17-VALIDATION.md` (G1/G2),
  `17-REVIEW.md` (IN-02, IN-03), `17-REVIEW-DISPOSITION.md`.
- The Phase 17 UAT harness (kept outside the repo), read only.
- `AGENTS.md` (dialog placement, test parallelism, simulators, scroll-edge policy).
