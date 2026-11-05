# Phase 18: In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework - Context

**Gathered:** 2026-11-05
**Status:** Ready for planning. UI execution waits for the UI-SPEC (D-17).
**Amended:** 2026-11-05, during planning: D-06a, D-06b, DD-09a (owner msgs 1795, 1796, 1805; analytics "Minimal"),
D-06c (owner msgs 1812, 1818; the install signal carries the install source), D-06d (owner msgs 1830, 1839; Basic's
description builds on Minimal), D-06e (owner msgs 1844, 1854, 1864; the short analytics intro), D-06f (owner msgs 1869, 1880, 1882; screens and
features move to Basic, Basic marked Recommended), D-14a (owner msg 1795; Blocked Users in Account settings), D-17a (UI-SPEC delivered, msgs 1791, 1803, 1807, 1820, 1826, 1843, 1866, 1886). The
original decisions are kept as written; where an amendment differs, the amendment wins.
**Sources:** the discussion prep [18-DISCUSSION-PREP.md](18-DISCUSSION-PREP.md) (locked decisions L1 to L46, gray areas GA-1 to GA-8, developer defaults, outside blockers, split proposal); the owner's answers to card msg 1748 (owner msg 1753) and card msg 1759 (owner msg 1765); the owner's copy approvals (msgs 1767, 1780). Where the owner answered, the answer overrides the prep. All dates are UTC.

<domain>
## Phase Boundary

Phase 18 is the in-app part of the original Phase 18, which the owner split into three phases (msg 1753). It
delivers, in every build and for every user:

- **First launch:** the age wall, then the analytics choice (Minimal / Basic / Full; D-06a). Both are shown once to everyone,
  upgraders included. No content, network request or analytics SDK start happens before them.
- **Analytics in Settings:** a picker with the three levels replaces today's "Share Analytics Data" toggle.
- **Comment moderation (Guideline 1.2):** an E-Hentai report action on every comment, a posting warning that still
  allows posting, blocking that collapses a blocked user's comments, and a Blocked Users list in Account settings
  (D-14a).
- **Reader page tracking:** one source of truth for the page shown and the number displayed, with committed UI tests
  for Phase 17's gaps G1/G2.
- **In-app carries and release fix:** IN-02, IN-03 and `MKSellsDigitalGoods = NO`.

**Not in this phase:**

- **Phase 19:** snapshot scenarios, the baseline, the CI gate, preview review, the 384 export and the
  `Scripts/visual/README.md` rewrite. Phase 19 must cover this phase's new screens.
- **Phase 20:** the marketplace build flavor and bundle ID, the PAL source and listing, store screenshots and
  decorations, notarization, the website pages and the published contact link, the release workflows and build
  number, the real-device checks, the final Release isolation scan and the analytics revision (ANALYTICS-02), which
  reuses this phase's `InstallSourceClient`, verifies and if needed extends its mapping on the real marketplace build
  and on a device, and adds the install source to the Basic/Full signals (D-06c).
- **No phase:** tag creation and release order (owner msg 1753: "Tagging is not your business").

</domain>

<decisions>
## Implementation Decisions

Owner decisions are binding. "Prep L*n*" and "GA-*n*" refer to [18-DISCUSSION-PREP.md](18-DISCUSSION-PREP.md).

### Phase organisation

- **D-01:** Three phases, not one phase with stages (owner msg 1753, card msg 1748). The order is in-app work (18),
  then visual regression and the marketing export (19), then distribution (20). All waiting on outside parties
  (the App Store Connect collaborator, the website, Apple) is in Phase 20, so this phase closes on its own evidence.
  The Phase 19 baseline is approved once, after every UI change here has landed.
- **D-02:** The final analytics revision (ANALYTICS-02: install source, plus the signals for the 3.0 flows under the
  consent levels) is the **last plan of Phase 20**, not of this phase. The owner said to decide by where its inputs
  exist (msg 1753). **Why:** the install source needs the marketplace build, which first exists in Phase 20. This phase
  still gates the existing ANALYTICS-01 vocabulary by level (D-06), because the approved level descriptions promise it.
  It adds no new signals for the age wall, the analytics choice or moderation; those come with ANALYTICS-02.
  This updates prep L3 ("last plan" now means the last plan of Phase 20) and prep L1 (Phase 20, not 18, is the last
  3.0 phase).
  **Amended by D-06c (owner msg 1812):** the install source client is created in this phase, for the one install
  signal only; Phase 20's ANALYTICS-02 extends and verifies it (real marketplace build, device) and adds the source
  to the Basic/Full signals.

### First launch: age wall (AGE-18-01)

- **D-03:** There are two screens, in sequence: the age wall, then the analytics choice. Everyone sees both once on
  their first 3.0 launch, including upgraders from 2.x and from the 3.0.0 pre-release (owner msg 1753; prep GA-1 Q1/Q2
  option A). Neither screen may be skipped by a stored 2.x answer: there is none.
- **D-04:** Before the age wall is confirmed, no content is shown, no network request is made and the analytics SDK is
  not started. Nothing else in the app works. There is no skip and no "No" button: Continue stays dimmed until the
  checkbox is ticked, as on the website's adult-mode box. The footnote ("If this isn't true for you, please close
  EhPanda.") is always visible. Nothing on the screen may say or suggest that the age was checked. The answer is
  stored on the device. Sources: prep L9, L11, L12; owner msgs 1231, 1235, 1239; copy file, Screen 1.
- **D-05:** The checkbox sentence is the owner-approved website sentence (msgs 1454, 1457), word for word and
  unchanged. The approved text has **no list of examples** (owner msg 1753). Prep L10 is updated accordingly. The
  examples in L10 and AGE-18-01 (where they are, where they live, their citizenship) explain the intent; they are not
  on-screen text. "Under every law that applies to me" carries that intent. — **Reversibility:** costly — the
  same sentence is the website's adult-mode declaration and is owner-approved in six languages; changing it means a
  new owner approval, a new wording version (re-prompting every user) and a website change.

### First launch: analytics choice (CONSENT-18-01)

- **D-06:** There are three levels, **None / Basic / Full**, all equally prominent, with **none pre-selected** (owner
  msg 1753). The SDK does not start before the choice and never starts under None (prep L14). What each level sends
  is fixed by its owner-approved description (prep GA-2 option A, as written into the approved copy):
  - **None** sends nothing.
  - **Basic** sends how often the app is used (the SDK's session signal), technical details (device model, app
    version), the install source and error kinds.
  - **Full** sends Basic plus the screens and features used, reading and download activity, and the main settings.
  - **Amended by D-06f (owner msgs 1869, 1880):** the screens and features used move from Full to Basic; Full adds
    reading and download activity and the main settings. "None pre-selected" stays; Basic is marked Recommended.

  Basic's install source is added by ANALYTICS-02 in Phase 20. Until then Basic just doesn't send it; no build ships
  in between. If what a level sends changes, its description must change too, which needs a new owner approval.
- **D-06a (amends D-06; owner msgs 1795, 1796, 1805):** the lowest level is **Minimal**, not None. The levels are
  **Minimal / Basic / Full**, in that order, all equally prominent, **none pre-selected**. Minimal sends only the
  installation: an install count and nothing else (D-06c adds where it was installed from). No level sends nothing any more, so every statement that a level
  "sends nothing" or that "None means no SDK" is withdrawn (D-06's first bullet, prep L14's "never starts under
  None", DD-09's "above None"). Before the choice nothing starts and nothing is sent, as before (D-04). The approved
  strings are in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md) (owner msg 1805): `consent.level.minimal`,
  `consent.level.minimal.description` and a new `consent.body` (itself superseded by D-06e); `consent.level.none` and
  `consent.level.none.description` are retired, and `shareAnalyticsDataFooter` stays retired (D-07). The Settings
  footer keeps its rule (the selected level's description). This also amends D-02 for one signal: the install signal
  of D-06b is new in this phase; every other new signal still waits for ANALYTICS-02.
- **D-06b (developer's technical decision for D-06a, relayed by the lead; confirmed to Camo in msg 1798):** what
  "Minimal" sends, exactly.
  - **Why not the SDK.** Phase 14's "your installation is still counted" came from the SDK's own signals:
    `TelemetryDeck.Session.started` on every cold launch and every foreground after 5 minutes, and
    `TelemetryDeck.Acquisition.newInstallDetected` once, with session-duration tracking running. Every SDK signal
    carries the full `DefaultSignalPayload` (device model, OS, locale, region, time zone, screen, app version,
    accessibility and calendar settings, retention counters). Starting the SDK under Minimal would make "Sends only a
    signal that EhPanda is installed" false.
  - **Under Minimal the TelemetryDeck SDK is never initialised.**
  - **One install signal, once per install, at every level.** After a level is chosen (any level), the app sends one
    install signal through a small sender of its own, unless the persisted "install signal settled" flag is set.
    Upgraders from 2.x and the 3.0 pre-release send it once, on their first 3.0 launch, after choosing. The same signal
    is sent at Basic and Full, so install counts are comparable across levels.
  - **The request** (format verified against SwiftSDK 2.14.2, `SignalManager.swift` `send`/`getServiceUrl` and
    `Signal.swift` `SignalPostBody`): `POST https://nom.telemetrydeck.com/v2/`, `Content-Type: application/json`,
    body a one-element JSON array of `{receivedAt, appID, clientUser, sessionID, type, payload, isTestMode}`:
    `receivedAt` formatted `yyyy-MM-dd'T'HH:mm:ssZ` in UTC; `appID` the build's TelemetryDeck app ID; `clientUser`
    the SHA-256 hex of a random UUID plus the salt (the SDK's hashing), generated once and kept only until the signal
    settles; `sessionID` a fresh random UUID; `type` `App.installed`; `payload` **`{}`**; `isTestMode` `"true"` in
    DEBUG, `"false"` in Release (the SDK's default); no `floatValue`. No device, OS, locale, region, time-zone,
    screen or app-version field exists anywhere in the request. The session is ephemeral (no cookies, no cache).
  - **Retries.** The response disposition mirrors the SDK's: 2xx settles; 400, 401, 403, 404, 413, 422, 501, 505 also
    settle (the server rejected it; retrying cannot help; logged); anything else, or a transport error, is retried
    with backoff in the process (10 s, 20 s, 40 s) and again at the next launch. Once settled it is never sent again.
    One request in flight at a time. A build without a TelemetryDeck app ID sends nothing (Phase 14's D-13 gate).
  - **Basic and Full** start the SDK after the choice, as planned. The SDK's own `newInstallDetected` duplicates the
    install signal there; that is a carry for Phase 20's ANALYTICS-02 to reconcile, not a defect here.
  - **Level changes.** Minimal → Basic/Full starts the SDK at that moment. Basic/Full → Minimal stops every app signal
    at once and calls `TelemetryDeck.terminate()`; nothing re-initialises it in this process or at any later launch
    while the level is Minimal. Chosen over "flip `analyticsDisabled` and keep the SDK alive" because a terminated
    SDK has no session timer and no lifecycle observers left that could emit anything; signals already cached by the
    SDK under the earlier level may still flush (Pitfall P-5).
  - **Tests must prove:** nothing is sent before the choice; Minimal makes exactly one request, with an empty
    payload, and never a second one (also across a relaunch and after a level change); the SDK is never initialised
    under Minimal.
  - **Amended by D-06c:** the payload is no longer `{}`; it holds exactly one key, the install source.
- **D-06c (amends D-06b; owner msg 1812, developer decision relayed by the lead; copy approved in owner msg 1818):**
  the Minimal install signal also carries where the app was installed from, and nothing else.
  - **One parameter.** The one-time `App.installed` signal (at every level, as in D-06b) has exactly one payload key,
    `App.installSource`, whose value is one of a small fixed enum, `InstallSource`: `appStore`, `testFlight`,
    `marketplace(<the marketplace bundle ID as reported>)`, `web`, `other`, `unknown`. On the wire the values are the
    strings `appStore`, `testFlight`, `marketplace:<id>`, `web`, `other`, `unknown`. No other field is added; every
    other part of D-06b's request is unchanged.
  - **`InstallSourceClient` (`@Dependency`)** produces it from MarketplaceKit's `AppDistributor.current` (`async
    throws`). The deployment target is iOS 27, above the API's iOS 17.4 (and `.web`'s 17.5), so no availability guard
    is needed. A thrown error, a case added in a later SDK (`@unknown default`) and a marketplace ID that is not a
    plausible bundle ID (empty, longer than 155 characters, or outside `A-Z a-z 0-9 . -`) all map to `unknown`.
    Simulator builds return `unknown` and other DEBUG builds return `other` without asking MarketplaceKit, so a
    development install can never be counted as a store install.
  - **Tests** assert the payload has exactly the one key and that its value comes from the enum, and cover the
    mapping of every `AppDistributor` case.
  - **Phase 20 (ANALYTICS-02)** reuses the same client: it verifies, and if needed extends, the mapping on the real
    marketplace build and on a device, and adds the source to the Basic/Full signals (D-02 as amended).
  - **Copy:** the Minimal description is now "Sends only a signal that EhPanda is installed, and where you installed
    the app from." (Revision 2 in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md), owner msg 1818). `consent.body` and the
    level name are unchanged. Copy precedence: Revision 3 of the same file (owner msg 1839, D-06d) supersedes the
    first-launch Basic description; Revision 5 (owner msg 1864, D-06e) supersedes `consent.body`; Revision 6 (owner
    msg 1880, D-06f) supersedes Revision 3's Basic description and the first-launch Full description.
- **D-06d (amends the Basic copy only; owner msgs 1830, 1839; its Basic line is superseded by D-06f):** the owner noted that Basic's description repeated
  Minimal's install line (msg 1830). Basic's description now builds on Minimal the way Full builds on Basic:
  "Everything in Minimal, plus how often the app is used, technical details such as device model and app version, and
  which kinds of errors occur." (Revision 3 in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md), drafted in msg 1832,
  approved in owner msg 1839, six languages). It supersedes `consent.level.basic.description` in
  [18-COPY-FIRST-LAUNCH.md](18-COPY-FIRST-LAUNCH.md); that file's Basic line is retired and must not appear in any
  catalog or README. **What Basic sends does not change** (D-06's Basic bullet, D-06b, D-06c; D-06f changes it later): the install signal
  and its source come through "Everything in Minimal". Minimal (Revision 2), Full, `consent.title` and
  `consent.body` are unchanged (`consent.body` later changes under D-06e). The Settings footer rule is unchanged, so
  at Basic it now starts "Everything in Minimal".
- **D-06e (amends the analytics intro only; owner msgs 1844, 1854, 1864):** the owner found the intro under the
  analytics title too verbose (msg 1844) and asked for something like "what you have searched or viewed are never
  sent" (msg 1854). `consent.body` is now one short line: "Anonymous analytics. Your searches and the galleries you
  view are never sent." (Revision 5, version B, in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md), approved in owner msg
  1864, six languages). It supersedes the msg-1805 `consent.body` in that file's first table and, with it, the
  original first-launch `consent.body`; both are retired and must not appear in any catalog. Revision 4 (msg 1847)
  was not approved and is not used.
  - **Why it is true (developer check, msg 1858):** at no level does any gallery ID, title, link, tag name or search
    text go out. Full sends a gallery's category and per-namespace tag counts when one is opened; a search sends only
    word count, length, a tag-syntax flag and a result-count bucket. If a later signal sends a search's text or which
    gallery was viewed, this line must change first, with a new owner approval.
  - **Purpose and TelemetryDeck's name move to the Privacy Policy**, which the same screen links
    (`consent.privacy_link`). The intro no longer says why analytics are collected or who receives them, so the
    website's privacy page must say both when it is rewritten for 3.0 (website, Phase 20; see the knock-on note
    under Specifics).
  - **Layout:** about 77 characters in en, two lines on iPhone at default size (designer msgs 1846, 1850); German may
    wrap to three lines on the smallest iPhones, which is acceptable. `consent.title`, the level names and
    descriptions, `consent.footer` and the Settings footer rule are unchanged.
- **D-06f (amends D-06, D-06d and Research A-3; owner msgs 1869, 1880, 1882; developer mapping msg 1878):** the
  owner moved the screens and features from Full to Basic (msg 1869, "move screen + features to basic") and chose to
  mark Basic as recommended (msg 1882).
  - **Copy (Revision 6 in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md), approved in owner msg 1880, six languages):**
    Basic: "Everything in Minimal, plus how often the app is used, which screens and features you use, technical
    details such as device model and app version, and which kinds of errors occur." Full: "Everything in Basic, plus
    your reading and download activity and your main settings." It supersedes the Revision 3 Basic line (msg 1839)
    and the first-launch Full line ("Everything in Basic, plus which screens and features you use, your reading and
    download activity, and your main settings."); both are retired in all six languages and must not appear in any
    catalog or README. Minimal (Revision 2), `consent.title`, `consent.body` (Revision 5) and the names are unchanged.
  - **What each level sends** (replaces D-06's Basic/Full bullets and Research A-3; the developer's mapping, msg
    1878, matches the copywriter's lines):
    - **Minimal:** unchanged (D-06b, D-06c): the one install signal; the SDK is never initialised.
    - **Basic:** the SDK's session and acquisition signals; the screens and features: `tabOpened`,
      `homeSectionViewed`, `filterPanelOpened`, `quickSearchPanelOpened`, `savedSearchUsed`, `tagTapped`,
      `searchPerformed`; the kinds of errors: `errorSurfaced`, `loginFailed`, `cloudflareChallengeEncountered`.
      Default parameters stay `[:]`.
    - **Full:** everything in Basic, plus reading and download activity: `galleryDetailOpened`,
      `readingSessionEnded`, `downloadStateChanged`; plus the main settings: the five `App.*` default parameters.
    - Research OI-3 is closed: `cloudflareChallengeEncountered` is Basic (developer decision, msg 1878).
  - **Recommended, not pre-selected (owner msg 1882, card 1873; options in msgs 1872 and 1874):** Basic shows a
    "Recommended" label (`consent.level.recommended`, six languages in Revision 6). Nothing is pre-selected (D-06,
    D-06a stay true) and Continue stays disabled until a level is tapped. The pre-selected variant (msg 1871) was not
    chosen. The order stays Minimal, Basic, Full (designer's call, msg 1886): the descriptions are a ladder that reads
    top-down. The label follows UI-SPEC C-3: a neutral grey capsule in Basic's name row, never accent (accent means
    selected) and the same whether Basic is selected or not; it drops under the name at accessibility sizes; VoiceOver
    reads it as part of the card ("Basic, Recommended, ..."). The Settings picker is unchanged (UI-SPEC C-9: the three
    names only, no label); its footer shows the Revision 6 descriptions.
- **D-07:** Settings follows the copy file's "Settings (replaces today's toggle)" section:
  - The row label `shareAnalyticsData` stays, now as a picker with the three level labels.
  - The footer shows the selected level's description.
  - A "Privacy Policy" row (`consent.privacy_link`) opens the website's privacy page.
  - `shareAnalyticsDataFooter` ("your installation is still counted") is retired.

  The choice can be changed at any time (prep L15).
- **D-08:** This replaces Phase 14's "on by default, switch off in Settings" (prep L16; ANALYTICS-01 D-01 reversal).
  ANALYTICS-01's rules stay: type-closed vocabulary, no bare `String`, buckets, the never-send list, no-op in builds
  without credentials, and emission only from reducers (prep L17; 14-CONTEXT D-06 to D-14).
- **D-09:** All first-launch and analytics-Settings strings come **verbatim** from
  [18-COPY-FIRST-LAUNCH.md](18-COPY-FIRST-LAUNCH.md) (owner msg 1767), in all six languages. The keys there are
  suggestions and may be renamed to fit the string catalogs; the strings may not change. Its "one term per concept"
  table applies to any other string this phase adds.

### Comment moderation (UGC-18-01)

- **D-10:** **Reporting goes to E-Hentai only** (owner msg 1753). Each comment's menu has "Report on {site}". It shows
  a confirmation, then opens the gallery's report page on E-Hentai or ExHentai. There is no email, no "Report to
  EhPanda" and no support-contact fallback. This replaces prep L18's fallback and GA-3 Q1 option A. If research finds a
  per-comment report link on the site, drop the second sentence of `comment.report.confirm_body` (copy file note).
- **D-11:** **No in-app contact option now.** The owner asked Ampo (msg 1760), and Ampo answered "not now" (msg 1774).
  Prep L20's "contact details in Settings" and GA-3 Q2 (a support mailbox) are not done in this phase. Before the
  AltStore build goes to Apple, a published contact link is needed: GitHub Issues on the website, owned by Leto. That
  is Phase 20 work. The existing About contact list in Settings (website, GitHub, Discord, Telegram) is unchanged.
- **D-12:** **The posting filter warns and still allows posting** (owner msg 1765, card msg 1759). This replaces GA-4
  Q1 option A (block posting). Ampo flagged the Guideline 1.2 risk (msg 1751); the owner made the call. The warning:
  - appears after the user taps Post, before anything is sent;
  - offers Edit (the default, which keeps the typed text) and Post Anyway;
  - never names the matched word;
  - also applies when the user edits an existing comment.
- **D-13:** **Blocking collapses the comment instead of hiding it** (owner msg 1765). This replaces GA-4 Q3 option A
  (hide fully). A blocked user's comment becomes the row "Comment from a user you've blocked", with Show and Unblock,
  in both the comments list and the Detail comment preview.
  - The row never shows the blocked user's name.
  - Show reveals that one comment once; the user stays blocked.
  - Blocking is local to this device (prep L19).
- **D-14:** **The Blocked Users list in Settings is included** (owner msg 1780). It has a footer, an empty state ("You
  haven't blocked anyone.") and a swipe action to unblock.
- **D-14a (amends D-14's location; owner msg 1795):** the Blocked Users row and list live in **Account** settings
  (`AccountSettingView`), not General: a section between the account section and the cookie section, shown whether
  or not the user is signed in (UI-SPEC C-10).
- **D-15:** All comment-moderation strings come **verbatim** from [18-COPY-COMMENTS.md](18-COPY-COMMENTS.md) (owner msg
  1780). `{site}` may be the gallery's site name or a fixed form, whichever the developer finds simpler; the copy file
  allows either. Cancel reuses the existing `cancel` key.
- **D-16:** Moderation ships to all users in every build, not only the marketplace build (prep L4; owner msg 1294).

### Design dependency (UI-SPEC before UI execution)

- **D-17:** Colo, the designer, owns the layout spec and mockups for the age wall, the analytics choice, the comment
  report and block UI (menu items, confirmations, the posting warning, the collapsed row) and the Blocked Users list
  (msg 1757). The project has `workflow.ui_phase: true`. Requirements for plan-phase:
  - A UI-SPEC (`18-UI-SPEC.md`) must exist before any UI execution task: either run `/gsd-ui-phase 18` to produce the
    design contract Colo fills or reviews, or take a UI-SPEC Colo supplies.
  - Plans must leave that spec input for him (screens, states, approved strings, constraints such as "no default
    selection" and "Continue dimmed until ticked") and make every UI task depend on it.
  - Non-UI tasks may run first: the launch gate, the SDK lifecycle, level gating, the filter function, the block
    store, the reader rework, IN-02/IN-03 and `MKSellsDigitalGoods`.
  - Layout choices left open by the copy, such as whether the analytics choice uses a separate Continue button or
    saves on tap, are Colo's.
- **D-17a (amends D-17's status):** the UI-SPEC exists. Colo delivered it in msg 1791, revised it for D-06a/D-14a in
  msg 1803, finalised it in msg 1807 and refreshed the Minimal line and mockups 03, 04, 13 and 21 for D-06c
  in msg 1820, added the title line-break rule (owner msg 1822; C-3: a title's last line is never a single
  word, or for zh/ja/ko never a single character, in any locale or text size) in msg 1826, and took the Revision 3
  Basic line (D-06d, owner msg 1839) into the spec and refreshed mockups 03, 04, 12 and 21 in msg 1843, and took
  the short intro (D-06e, owner msg 1864) into the spec and refreshed mockups 03, 04 and 21 in msg 1866, and added Basic's Recommended label and the Revision 6
  lines (D-06f, owner msgs 1880, 1882; order stays Minimal, Basic, Full) and refreshed mockups 03, 04, 12, 18 and 21
  in msg 1886: [18-UI-SPEC.md](18-UI-SPEC.md) with 24 mockups in `mockups/`. It is the
  design contract for every UI task; `/gsd-ui-phase` is not run. His layout calls: a separate Continue on the
  analytics choice, dimmed until a level is picked; a `…` menu on each comment in the list with the same items on
  long-press and as VoiceOver actions, long-press only on the Detail strip; Report, Block and the posting warning are
  alerts, with Edit as the cancel-role default; the collapsed row uses the plain "Unblock".

### Reader page tracking (carried from Phase 17)

- **D-18:** Replace the reader's separate copies of "the current page" with one source of truth for the page shown and
  the number displayed, as one task, not more patches (prep L38; owner msg 1630, product lead msg 1631). The copies are
  the page-model index, the pager scroll position, the shown pager position, the displayed slider value, the saved
  reading progress and the vertical list's position.
- **D-19:** Add committed UI tests for Phase 17's gaps G1/G2 (prep L39):
  - Reload All Images, then a page turn.
  - A reading-direction change during Auto-Play.
  - A left-to-right/right-to-left switch.

  These are the WR-01 rebuild paths and RTL page sync; see 17-VERIFICATION.md R5-1 for the suggested scope.

### In-app carries and the app-code release fix

- **D-20:** Close IN-02 and IN-03 in this phase, before Phase 20's final Release isolation scan (prep L40, L41;
  owner msg 1627):
  - IN-02: add a `captureSystemOverlay` token to `Scripts/visual/verify-release.py` `FORBIDDEN_CONTENT`, with a
    `Scripts/visual/test_release.py` case.
  - IN-03: move RootView's `import AppComponents` into its `#if DEBUG` import block.
- **D-21:** Set `MKSellsDigitalGoods = NO` in `App/Info.plist`, for every build (prep L25; DIST-18-01). It sits here,
  not in Phase 20, because it is the one release fix that is app code. The rest of DIST-18-01, the marketplace build
  flavor, is Phase 20.

### Standing project rules (carried)

- **D-22:** These project rules apply (prep L44 to L46):
  - Persisted `@Shared` models stay at v1 and are edited in place; no migration before 3.0 ships.
  - SwiftLint runs as error, with no suppressions without permission.
  - Every `.xcstrings` key is filled for all six locales.
  - Agent-run UAT is allowed where no hardware or owner judgment is needed.
  - Closing gates need 0 failures and 0 Repetition nodes.

### Developer defaults (changeable)

**These were not put to the owner.** The planner may follow them; the owner may change any of them at any time.
They come from the prep's GA-4/GA-5 recommendations and its section 3.

- **DD-01, slider scrub (GA-5 Q1 A):** the reader title shows the scrub preview while dragging and snaps to the
  settled page on release (parity).
- **DD-02, turn that can't land (GA-5 Q2 A):** keep follow-the-screen: after the retry limit, the shown page is
  committed, so the number always matches what is shown.
- **DD-03, iPad two-page spread (GA-5 Q3 A):** stays a known limit; add a spread probe only if it's cheap. The rework
  stays one task.
- **DD-04, filter targets (GA-4 Q2 A):** slurs, hate speech, threats and harassment phrases in all six app languages.
  Sexual vocabulary is excluded, since EhPanda is an adult-content client. The filter is a pure, unit-tested function
  with normalization (case, width, diacritics) and a bundled list. It applies to new comments and edits.
- **DD-05, marketplace bundle suffix:** `.marketplace` (channel-neutral; GA-6 Q2). Phase 20 uses it. It is recorded
  here because the owner's decision record lists it among the developer defaults. — **Reversibility:** one-way — it becomes a permanent
  App ID in the collaborator's App Store Connect account.
- **DD-06, launch gate:** a root gate in `RootView`/`AppReducer`. `AppDelegateReducer.onLaunchFinish` keeps only local
  work (cookie prep, history prune, image-cache init). Everything else runs only after confirmation:
  `loadUserSettings`' network effects, the greeting fetch, tab fetches, clipboard detection, launch automation and the
  SDK start.
- **DD-07, deep links and the share extension before confirmation:** queue the incoming URL and route it after
  confirmation. Never open content first.
- **DD-08, storage:** the v1 `Setting` edited in place, or a dedicated `@Shared` key. It holds the age answer plus a
  wording version; re-prompt only if the wording version changes. The analytics level is stored the same way. The old
  `isSharingAnalyticsData` is ignored, not migrated, which also makes upgraders see both screens (D-03).
- **DD-09, SDK lifecycle:** `AnalyticsClient.start` runs only at a level above None. Raising the level at runtime
  starts the SDK. Lowering it stops app signals immediately and disables the SDK (`analyticsDisabled`). Unit tests
  prove no SDK call before consent.
- **DD-09a (amends DD-09; owner msgs 1795, 1796; developer decision D-06b):** nothing starts before the choice. After
  it, every level sends the one install signal (D-06b); the SDK starts at Basic and Full only. Raising to Basic/Full
  starts the SDK; lowering to Minimal stops app signals at once and terminates the SDK, which then stays down. Unit
  tests prove no request and no SDK call before the choice and no SDK initialisation under Minimal. Ato's msg 1796
  ("the SDK starts at every level") is met in substance by the own sender: what the owner asked for is that Minimal
  sends the install signal, and the SDK cannot send it without device details.
- **DD-10, moderation storage:** the block list is an `@Shared` set of author names. The report and block actions go
  in the comment cell's menu.
- **DD-11, reader structure:** a `ReaderPosition` in reducer state with a generation counter (17-READER-ROOT-CAUSE.md
  section 3). The existing gate and seed tests port to it. The three new UI tests run, plus the run R5-1 suggests with
  the initial idle report suppressed.
- **DD-12, docs:** rewrite the README "Analytics" section and its five translations (`READMEs/`) for the three levels.

### Claude's Discretion

Anything not fixed above, within these decisions, the approved copy and the UI-SPEC: reducer and state shape, file
layout, test structure and the bundled filter list's contents.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Approved copy (canonical; never paraphrase)

- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-FIRST-LAUNCH.md`: age
  wall, analytics choice and Settings strings in six languages (owner msg 1767). The `age_wall.declaration` row is the
  owner-approved website sentence (msgs 1454, 1457).
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-MINIMAL.md` (**D-06a**):
  the approved Minimal level name and description and the new `consent.body`, six languages (owner msg 1805). It
  supersedes the None strings and `consent.body` in the first-launch copy file. Its Revision 2 (owner msg 1818,
  **D-06c**) supersedes the Minimal description in its own first table. Its Revision 3 (owner msg 1839, **D-06d**)
  supersedes the Basic description in the first-launch copy file. Its Revision 5 (owner msg 1864, **D-06e**)
  supersedes `consent.body` in its own first table (msg 1805) and in the first-launch copy file. Precedence: Revision
  5 (`consent.body`), Revision 3 (Basic description), Revision 2 (Minimal description) > its first table > the
  first-launch copy file. Revision 4 (msg 1847) was not approved. Its Revision 6 (owner msg 1880, **D-06f**)
  supersedes Revision 3's Basic description and the first-launch Full description, and adds
  `consent.level.recommended`. Precedence now: Revision 6 (Basic and Full descriptions, `consent.level.recommended`),
  Revision 5 (`consent.body`), Revision 2 (Minimal description) > its first table > the first-launch copy file.
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-COMMENTS.md`: report,
  posting warning, blocking and Blocked Users strings in six languages (owner msg 1780).
- Age-wall sentence source: owner msgs 1454 and 1457 (the website's adult-mode sentence). Its text is
  `age_wall.declaration` in the first-launch copy file; use it unchanged.

### Phase records

- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-DISCUSSION-PREP.md`: the locked
  decisions L1 to L46, the gray areas with their options, the developer defaults, outside blockers and the split
  proposal. Where this CONTEXT records an owner answer, this CONTEXT wins.
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-DISCUSSION-LOG.md`: the options
  and the owner's choices (audit trail only).
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-UI-SPEC.md` and `mockups/`:
  Colo's final design contract (msg 1826, revising msgs 1807 and 1820; D-17a).
- `.planning/ROADMAP.md`, Phase 18 (and the split map at the end of that section); Phases 19 and 20 for the work that
  is not here.
- `.planning/REQUIREMENTS.md`: AGE-18-01, CONSENT-18-01, UGC-18-01, DIST-18-01 and their 2026-11-05 amendments.
- `.planning/STATE.md`: Deferred Items (the age wall and consent standards, 2026-11-02) and Blockers (G1/G2).
- `.planning/phases/19-visual-regression-marketing-export/19-CONTEXT.md` and
  `.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md`: the owner
  decisions for the later phases.

### Reader rework and carries

- `.planning/phases/17-localized-screenshot-capture-harness/17-READER-ROOT-CAUSE.md`: what holds "the page" today, the
  mirror graph, the single-source sketch (section 3) and the guarding tests (section 4).
- `.planning/phases/17-localized-screenshot-capture-harness/17-VERIFICATION.md`: R5-1, the suggested UI-test scope.
- `.planning/phases/17-localized-screenshot-capture-harness/17-VALIDATION.md`: gaps G1 and G2.
- `.planning/phases/17-localized-screenshot-capture-harness/17-WR01-MIDTURN.md`: the throwaway mid-turn check the new
  tests replace.
- `.planning/phases/17-localized-screenshot-capture-harness/17-FINAL-VALIDATION.md` section 9.
- `.planning/phases/17-localized-screenshot-capture-harness/17-REVIEW.md` and `17-REVIEW-DISPOSITION.md`: IN-02 and
  IN-03.

### Analytics rules

- `.planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-CONTEXT.md`: D-01 (reversed
  here), D-04 (privacy manifest; revisited in Phase 20) and D-06 to D-14 (the vocabulary rules that stay).

### Comments

- `.planning/quick/261102-comment-parser/SUMMARY.md`: the comment parser and the edit form's plain-text pre-fill
  (a deferred item, unchanged here).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift` and `AnalyticsDefaultParameters.swift`: both guard on
  `setting.isSharingAnalyticsData` today. These guards become the level gate.
- `AppPackage/Sources/AppModels/Persistent/Setting.swift`: `isSharingAnalyticsData` (v1 model, edited in place).
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift`: today's analytics toggle and footer;
  the picker and Privacy Policy row go here, unless the UI-SPEC says otherwise.
- `AppPackage/Sources/AppModels/Gallery/GalleryComment.swift`: the parsed comment model (vote and edit state; no
  per-comment report link found).
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift`, `DetailView+CommentCells.swift` and
  `Components/PostCommentView.swift`: the comment list, the Detail preview cells and posting/editing.
- The gallery page's Report Gallery link (`?report=select`, seen in the UI-test fixture): the report target.

### Established Patterns

- TCA reducers with `@Shared` persisted settings at v1; analytics are emitted only from reducers.
- Strings live in per-module `Resources/Localizable.xcstrings` catalogs, six locales, every key filled.
- UI tests run on phone then tablet, one invocation at a time; project-prefixed simulators (AGENTS.md).

### Integration Points

- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` (`onLaunchFinish` starts the SDK today) and
  `AppReducer.swift` (the `loadUserSettings` chain fires the greeting fetch, the Home fetch and clipboard detection).
  All of these move behind the gate.
- `AppPackage/Sources/AppFeature/RootView.swift`: the root gate (DD-06) and IN-03's import.
- `AppPackage/Sources/ReadingFeature/` (`ReadingReducer*.swift`, `ReadingView.swift`): the reader rework.
- `App/Info.plist`: `MKSellsDigitalGoods`.
- `Scripts/visual/verify-release.py` and `Scripts/visual/test_release.py`: IN-02.

</code_context>

<specifics>
## Specific Ideas

These notes come from the approved copy files and keep their intent:

- **Age-wall title:** it says what the app is ("EhPanda is for adults"), not what the user is. The screen stays a
  statement by the user, never a check by us.
- **Continue:** the button is "Continue", not "I agree"; the agreement is the checkbox.
- **Analytics title:** it is neutral on purpose ("Choose what EhPanda shares"), because a choice with no default
  shouldn't nudge. (The owner chose to mark Basic "Recommended", msg 1882, D-06f; the title stays neutral and
  nothing is pre-selected.)
- **"None" in ko, ja and zh:** it reads as "Don't share", since a bare 없음 / なし / 无 is unclear as a button.
  (Withdrawn with None itself: D-06a, 18-COPY-MINIMAL.md.)
- **Blocking terms:** zh-Hans uses 屏蔽 for blocking, matching "Excluded Uploaders"; zh-Hant uses 封鎖.
- **The website's privacy page:** it says sharing is on by default and that a switch turns it off. It must be
  rewritten for the three levels when 3.0 ships, not before (website, Phase 20). Knock-on of D-06e (owner msg
  1864): the in-app intro no longer names TelemetryDeck or says why analytics are collected, so the rewritten page,
  linked from the analytics screen, must name TelemetryDeck as the recipient and state the purpose (seeing which
  features matter).

</specifics>

<deferred>
## Deferred Ideas

- **Contact option:** no in-app contact option or support mailbox for now (Ampo msg 1774). Phase 20 needs a published
  contact link (GitHub Issues on the website, Leto) before the AltStore build goes to Apple.
- **New analytics signals and the install source on Basic/Full:** signals for the age wall, the analytics choice and
  moderation, and the install source on the Basic/Full signals, come with ANALYTICS-02, the last plan of Phase 20
  (D-02). The install source client itself and its use in the one install signal are in this phase (D-06c).
- **iPad two-page spread test:** a known limit (DD-03).
- **Comment styles on edit:** keeping a comment's styles and links when editing is still an open STATE Deferred Item.
  The posting warning applies to edits, but this phase does not change the edit form's plain-text pre-fill.
- **Not adopted from the prep:** GA-3's "Report to EhPanda" email and support mailbox (owner msg 1753); GA-4's "block
  posting" and "hide fully" (owner msg 1765).
- **Out of every phase:** GA-7's tag style, the `3.0.0` retag and release sequencing (owner msg 1753: "Tagging is not
  your business").
- **Later phases:** GA-6 (the marketplace build) and GA-8 (listing content, the 384 selection) belong to Phases 20 and
  19 and are recorded in their CONTEXT files.

</deferred>

---

*Phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder*
*Context gathered: 2026-11-05*
