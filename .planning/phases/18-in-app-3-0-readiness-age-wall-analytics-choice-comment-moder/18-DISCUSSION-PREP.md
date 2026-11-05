# Phase 18: discussion prep (draft, not CONTEXT.md)

> **Status (2026-11-05):** kept as the phase record. The owner answered the gray areas in msgs 1753, 1765, 1767 and 1780 and split the phase into Phases 18, 19 and 20. Where an answer differs from this prep, [18-CONTEXT.md](18-CONTEXT.md) (and 19-CONTEXT.md, 20-CONTEXT.md) win. Only L10 below was edited, as the owner asked.

**Prepared:** 2026-11-05, at `aaa514d46` (branch `feature/gsd-phase-17`). Uncommitted draft.
**Workflow:** `discuss-phase` steps done through `analyze_phase`: init, anti-pattern check (no `.continue-here.md`),
spec check (no SPEC.md), existing check (no CONTEXT.md, no checkpoint, no plans), prior context, todo match
(0 matches), codebase scout, `discuss:pre` hooks (none). Discuss mode is `discuss`, no advisor profile. Stopped
before `present_gray_areas`.
**Phase:** 3.0 Release Readiness: Age Wall, Consent, Marketplace Distribution & Visual Regression.
**Domain:** make 3.0 shippable on the existing GitHub/AltStore Classic channel and on AltStore PAL (plus other
marketplaces through the same ADP path). Add the three compliance features to every build. Finish the visual
regression and marketing work moved from Phase 17. Rework reader page tracking. Run the device checks. End
with the analytics revision.

Note: `workflow.ui_phase` is `true`. The age wall, consent and moderation UI will likely need a UI-SPEC pass
before planning.

---

## 1. Decisions already locked (don't re-ask)

### Scope and ownership

| # | Decision | Source |
|---|---|---|
| L1 | Phase 18 is the last 3.0 phase. Snapshot tests (17-08 to 17-13, 17-14 T1/T3, 17-15, 17-20), the 384 export (17-07, 17-21) and the AltStore promotional images (17-22) move here. They are not deferred past 3.0. | Owner msg 1305; ROADMAP scope 1 |
| L2 | Phase 18 takes all the work needed for AltStore PAL and other potential marketplaces. | Owner msg 1287; ROADMAP scope 2 |
| L3 | Analytics also tracks the marketplace or install source. The analytics revision is the **last** plan. | Owner msg 1289; ANALYTICS-02; Step 12 |
| L4 | Comment report, block user, contact details and a posting filter ship to **all users in every build**, not just the marketplace build. | Owner msg 1294, research msg 1299; UGC-18-01 |
| L5 | The age wall and analytics consent are standard in **every build**. | STATE Deferred Items (2026-11-02); AGE-18-01, CONSENT-18-01 |
| L6 | Apple-service actions (App IDs, app record, certificates, API keys, marketplace registration, trader status) happen in the collaborator's App Store Connect account, by the collaborator or with the owner's explicit OK at the time. Agents never create them on their own. | ROADMAP scope 5; DIST-18-03 |
| L7 | The privacy policy and support pages are website work owned by another team member. This phase records the URLs it needs and waits for them. The website's adult-mode declaration uses the age-wall wording. | ROADMAP scope 6; DIST-18-02; team spec msg 1240 |
| L8 | No "Apple-approved" wording anywhere. | DIST-18-02 |

### Age wall (AGE-18-01)

| # | Decision | Source |
|---|---|---|
| L9 | Shown on first launch, before any content is shown or any network request is made. | Owner msgs 1231, 1235, 1239; AGE-18-01 |
| L10 | The user confirms that they are an adult **and** that they may legally view explicit content under every law that applies to them. Not just "18 or older". *Updated 2026-11-05 (owner msg 1753):* the on-screen text is the owner-approved website sentence (msgs 1454, 1457), unchanged, with **no list of examples**; the earlier examples (where they are, where they live, their citizenship) describe the intent only. | Owner msgs 1235, 1239, 1753; team spec msgs 1232, 1236, 1240 |
| L11 | No skip. Answering no keeps the user on that screen. Nothing else in the app works until they confirm. | Same |
| L12 | The answer is stored on the device. | Same |
| L13 | Reference: the reference app's onboarding named in STATE.md Deferred Items, and the notarization rule on an honest age rating and declared age. | Team msg 1211; STATE Deferred Items |

### Analytics consent (CONSENT-18-01)

| # | Decision | Source |
|---|---|---|
| L14 | No analytics are collected until the user chooses. The SDK is **not started** before consent. | Owner msg 1231; CONSENT-18-01; criterion 3 |
| L15 | A first-launch screen offers a few levels of sharing. One of them is **none**. The choice can be changed in Settings. | Same |
| L16 | This replaces Phase 14's "on by default, switch off in Settings" (ANALYTICS-01 D-01 reversal). Guideline 5.1.1 applies even to anonymous data. | CONSENT-18-01; team msg 1211 |
| L17 | ANALYTICS-01's rules stay: type-closed vocabulary, no bare `String`, buckets, never-send list, credential-less builds no-op, reducer-only emission. | ANALYTICS-02; 14-CONTEXT D-06 to D-14 |

### Comment moderation (UGC-18-01)

| # | Decision | Source |
|---|---|---|
| L18 | Every comment has a report action. It links to E-Hentai's own report option where one exists, otherwise to the support contact. | UGC-18-01; criterion 4 |
| L19 | Blocking a user hides their comments locally, on this device. | Same |
| L20 | Contact details appear on the support page (website) and in Settings. | Same |
| L21 | Posting a comment passes a filter for objectionable content. | Same |

### Release mechanics and marketplace (REL-18-01, DIST-18-01..03)

| # | Decision | Source |
|---|---|---|
| L22 | Both release workflows use one tag style for the GitHub release and the AltStore `downloadURL`. | REL-18-01 |
| L23 | The existing `3.0.0` tag is removed or renamed only with the owner's OK **at that time** (Step 1 checkpoint). | REL-18-01; Step 1 |
| L24 | Build number above 158. `AltStore.json` keeps version history and shows new non-explicit screenshots. | REL-18-01; criterion 1 |
| L25 | `MKSellsDigitalGoods = NO` in `App/Info.plist`. | DIST-18-01 |
| L26 | The marketplace flavor gets its own bundle ID through the existing `BUNDLE_ID_SUFFIX` setting, for both the app and the share extension, without changing the unsigned IPA build or private local signing. | DIST-18-01 |
| L27 | A separate PAL source JSON (`marketplaceID`, `nsfw: true`, ADP download URLs, version history). The Classic `AltStore.json` stays for unsigned IPAs. | DIST-18-02 |
| L28 | All-ages (4+) icon and listing screenshots. Privacy policy reachable in the app and on the listing, plus a support URL. | DIST-18-02 |
| L29 | A CI job submits for notarization, waits for the ADP and publishes it to the PAL source. Test and record whether an App Manager API key can create the version and submit. | DIST-18-03 |

### Visual regression and marketing (VIS-18-01, MKT-18-01; Phase 17 decisions carried)

| # | Decision | Source |
|---|---|---|
| L30 | Snapshot coverage: every screen/state × six locales × all 12 Dynamic Type sizes × portrait/landscape × iPhone/iPad × light/dark (576 coordinates per scenario). Each one is captured, failed or justified not applicable. No representative sampling. Now includes the age wall, consent and comment-moderation UI. | 17-CONTEXT D-07; CAP-17-02; VIS-18-01 |
| L31 | Strict never-record comparison. Explicit candidates get a full agent review, then **one** owner baseline approval. 17-20's separate re-approval is folded in. | 17-CONTEXT D-12; VIS-18-01; Step 6 |
| L32 | **Full matrix on every PR** and on releases. Longer runtime accepted. | 17-CONTEXT D-13; VIS-18-01 |
| L33 | Filterable, screen-grouped baseline/actual/diff report. A controlled regression proves detection. | 17-CONTEXT D-14; CAP-17-03 |
| L34 | Toplists fixtures carry at least six galleries per period (full 2×3 grid). | Step 5; 17-VERIFICATION deferred row 7 |
| L35 | AltStore promotional images are App Store-style designs made by a **separate designer agent**, who picks screens, matrix, copy and dimensions. The capture agent doesn't design and doesn't use `impeccable` for this. | 17-CONTEXT D-23, D-24; CAP-17-05 |
| L36 | Marketing gallery content is real. No duplicate gallery on one screen. Final owner identifiers, then regeneration. | 17-CONTEXT D-02, D-04, D-05 |
| L37 | The 384 tooling, handoff validator and 384 regeneration are in 3.0 scope, even though the website now consumes only the 192 iPhone coordinates. | Owner msg 1305; CAP-17-04 amendment; MKT-18-01 |

### Reader rework (Step 4b) and Phase 17 carry-overs

| # | Decision | Source |
|---|---|---|
| L38 | Replace the reader's separate copies of "the current page" with one source of truth for the page shown and the number displayed. One task, not more patches. | Owner msg 1630, product lead msg 1631; Step 4b |
| L39 | Add the missing UI tests: Reload All Images then a page turn; a reading-direction change during Auto-Play; an LTR/RTL switch (closes Phase 17 Nyquist gaps G1/G2). | Step 4b; 17-VALIDATION G1/G2; 17-VERIFICATION R5-1 |
| L40 | IN-02 (`captureSystemOverlay` token in `verify-release.py` `FORBIDDEN_CONTENT` plus a `test_release.py` case) and IN-03 (RootView's `import AppComponents` into its `#if DEBUG` block) close before the final Release scan. | Owner msg 1627; Step 7 |
| L41 | The release gate repeats the Release isolation scan on the final 3.0 build. | REL-18-01; Step 7 |
| L42 | Rewrite `Scripts/visual/README.md`: the index is now `website-capture-20261104.json` (11 fixture versions), and the runners are owned by Phase 18. | ROADMAP scope 8 |

### Device checks (DEV-18-01) and standing project rules

| # | Decision | Source |
|---|---|---|
| L43 | On owner hardware: the iPad Gallery Detail stall on a **Release** build, and continued background downloads on an **iPhone**. | DEV-18-01; Step 11 |
| L44 | Persisted `@Shared` models stay at v1 and are edited in place (no migration before 3.0 ships). SwiftLint-as-error, no suppressions without permission. Every `.xcstrings` key is filled for all six locales. | PROJECT Constraints; AGENTS.md |
| L45 | Agent-run UAT is allowed where no hardware or owner judgment is needed. | Owner rule msg 1652 (Phase 17 UAT) |
| L46 | Closing gates need zero failures and zero repetition nodes. | PROJECT Key Decisions (Phase 16) |

---

## 2. Gray areas for the owner (8)

### Age wall and consent

**GA-1. First-launch flow: order, upgrades and the final wording**

The behavior is locked. The flow around it isn't. Today `AppDelegateReducer.onLaunchFinish` starts the SDK, and
`AppReducer`'s `loadUserSettings` chain fires the greeting fetch, the Home tab fetch and clipboard detection.
All of these have to wait behind the gate.

- Q1 (shape): one screen or two?
  - **A. Two screens in sequence: age wall, then consent.** Each screen does one legal job, so each is easier
    to read and test. Costs one extra tap.
  - B. One combined screen with the age confirmation plus the consent choice. Fastest, but it mixes a
    blocking legal declaration with an optional choice, and reviewers may read that as bundled consent.
  - C. Age wall first, then ask for consent later (for example on first use of Settings). Shorter first run,
    but no analytics until the user finds Settings.
- Q2 (who sees it): users updating from 2.8.1 or the 3.0.0 pre-release?
  - **A. Everyone sees both screens once on their first 3.0 launch.** Nobody has a stored answer yet. Also
    the only honest consent for pre-release users who were opted in by default.
  - B. Only fresh installs. Fewer prompts, but upgraders are never asked, which fails L9/L14 for them.
- Q3 (copy): the requirement records what the wording must cover, not the final copy.
  - **A. The agent drafts the English copy and five translations. The owner approves all six before the
    snapshot baseline, and the website reuses the approved English.** One approval, consistent with L7.
  - B. The owner (or the website teammate) supplies the copy. Most control, but it blocks Step 2.
- **Recommended:** Q1 A, Q2 A, Q3 A. Two screens keep the declaration and the consent separate (5.1.1 asks for
  consent that is freely given), asking everyone is the only reading of "first launch" that covers upgraders,
  and the copy must be fixed before it gets a baseline.

**GA-2. Consent levels: how many, and what each sends**

Today's opt-out still sends the SDK's own session signal (installs, retention, SDK metadata) when switched off
(`AnalyticsClient.live`, README "Analytics"). Under L14 "none" must mean the SDK never starts.

- **A. Three levels: None / Basic / Full.** None: SDK never started. Basic: SDK session signal (install and
  retention counts, SDK technical metadata), install source and app error kinds. Full: today's complete
  ANALYTICS-01 vocabulary and settings snapshot. Clear choice, and Basic keeps install counts for users who
  want to share a little.
- B. Two levels: None / Full. Simplest UI and code, but "a few levels" (L15) reads as more than two, and
  privacy-minded users get no middle option.
- C. Three levels with Basic = install source and session only (no error kinds). Tighter Basic, but lose
  error visibility for most users.
- D. Four levels (split Full into usage vs. content-adjacent payloads such as category and tag-namespace
  counts). Finest control, but more UI and more analytics complexity to validate.
- Sub-question: does any button start out highlighted? **Recommend no default selection, all buttons equally
  prominent.** Avoids a dark pattern, and GDPR-style consent can't be pre-selected.
- **Recommended: A.** It meets "a few levels including none", gives the install-source tracking (L3) a home
  that most users will accept, and maps cleanly onto the existing vocabulary. ANALYTICS-02 then assigns each
  new Phase 18 signal to a level.

### Comment moderation

**GA-3. Where "report" goes, and which contact details are published**

The parsed comment model (`GalleryComment`) has vote and edit state only. The gallery page has E-Hentai's
**Report Gallery** link (`?report=select`, seen in the UI-test fixture). No per-comment report link was found.
The researcher must confirm what the site offers.

- Q1 (report target when E-Hentai has no per-comment report):
  - **A. A menu: "Report on E-Hentai" (opens the gallery's report page, if it lets users name a comment)
    plus "Report to EhPanda" (an email draft with the gallery ID, comment ID and author filled in).** Uses the
    site's own process where possible and always gives a fallback.
  - B. Email draft only. Simplest and consistent, but the team then handles every report itself.
  - C. A web form on the support page (website teammate). Nicer for users and spam-filterable, but blocked on
    the website.
  - D. GitHub issue link. No new infrastructure, but public, needs an account, and isn't suitable for reports
    about explicit content.
- Q2 (contact details in Settings and on the support page): which channels count?
  - **A. A dedicated support email address plus the support page URL, added to the existing About contact
    list (website, GitHub, Discord, Telegram).** Reviewers expect a direct, non-public channel.
  - B. Only the existing community channels. No new mailbox, but Discord/Telegram/GitHub may not count as a
    "timely" contact for 1.2.
- **Recommended:** Q1 A, Q2 A. Both need a team-owned address (see section 4).

**GA-4. Blocking and the posting filter: how strict, and how visible**

- Q1 (filter action when a comment matches):
  - **A. Block posting with a clear message naming the reason (not the matched word); the text is kept so the
    user can edit it.** Meets "passes a filter" with no surprise and no data loss.
  - B. Warn, but allow "Post anyway". Friendlier, but a reviewer may say the filter doesn't filter.
  - C. Silently mask the words. No friction, but it changes the user's text without asking.
- Q2 (what counts as objectionable): EhPanda is an adult-content client, so sexual vocabulary can't be the target.
  - **A. Slurs, hate speech, threats and harassment phrases in all six app languages; sexual terms excluded.
    Applies to new comments and edits.** Fits the app's purpose and the 1.2 intent.
  - B. English only. Quick, but doesn't cover most of the user base.
  - C. Also block links and contact info (spam). Fewer spam posts, but legitimate comments often link to
    sources.
- Q3 (blocking): show a placeholder or hide fully? Where to unblock?
  - **A. Hide fully, in both the comments list and the Detail comment preview, with a "Blocked users" list in
    Settings for unblocking.** Clean result, and a mistaken block can be undone.
  - B. Collapse into "Comment from a blocked user". Shows that something was hidden, but the content is one tap
    away, which is weaker for 1.2.
- **Recommended:** Q1 A, Q2 A, Q3 A.

### Reader page tracking (Step 4b)

**GA-5. Which behaviors must stay exactly as they are**

The root-cause sketch (17-READER-ROOT-CAUSE.md §3) makes the shown number a pure function of the settled page.
That changes two things users can see:

- Q1 (slider scrubbing): today the title `"n / total"` is the slider value, so it follows the finger while
  scrubbing.
  - **A. Keep it: the title shows the scrub preview while dragging and snaps to the settled page on
    release.** Parity, and what users are used to.
  - B. Title shows only the settled page; the preview appears only next to the slider. Purest invariant, but a
    visible change.
- Q2 (a turn that can't land): the sketch commits the shown page after the retry limit (today's
  "follow-the-screen").
  - **A. Keep follow-the-screen (the number always matches what's shown).**
  - B. Keep retrying the requested page. The page the user asked for wins, but it can loop.
- Q3 (iPad two-page spread): G2 records this as a known limit with no planned test.
  - **A. Leave it as a known limit; add a spread probe only if it's cheap.** Keeps 4b as one task.
  - B. Require a committed spread test in 4b. Fuller coverage, but needs new probe work for an iPad-only layout.
- **Recommended:** Q1 A, Q2 A, Q3 A. 4b should be a structural fix at visible parity, so the snapshot baseline
  (Step 6) reflects it without re-approving the reader screens.

### Marketplace build and PAL

**GA-6. What differs between the marketplace build and the GitHub IPA**

- Q1 (features):
  - **A. Same features; only bundle ID, signing, icon set and distribution differ.** One code path to test,
    and L4/L5 already make compliance universal.
  - B. Marketplace build also hides some features (for example Laboratory's network bypass, alternate icons
    with political themes, ExHentai). Lowers notarization risk, but splits behavior and doubles snapshot
    surface.
- Q2 (bundle ID suffix; owner/collaborator choice, since it becomes a permanent App ID): for example
  `app.ehpanda.marketplace`, `app.ehpanda.pal` or `app.ehpanda.eu`.
  - **Recommend a channel-neutral suffix (`.marketplace`), because the same ADP serves PAL and other
    marketplaces (L2).**
- Q3 (in-app icon): does the app's own primary icon have to be the all-ages icon in the marketplace build, or
  only the listing icon?
  - **A. Use the current primary icon everywhere if the owner judges it all-ages; listing assets only
    otherwise.** No extra asset if it already qualifies.
  - B. A designer-made all-ages icon for the marketplace build. Safest, but more work.
- Q4 ("other potential marketplaces"): is PAL the only listing for 3.0?
  - **A. PAL listing only; the ADP pipeline stays generic so other sources can be added later.** Bounded
    scope.
  - B. Also list on a second named marketplace now. More reach, more registration work.
- **Recommended:** Q1 A, Q2 `.marketplace`, Q3 A (owner checks the icon), Q4 A. Q1 B can come back only if
  notarization actually rejects a feature.

### Release mechanics

**GA-7. Tag scheme, the existing 3.0.0 pre-release, and whether the Classic release waits for PAL**

Facts: `deploy.yml` and `deploy-pre-release.yml` both tag `<version>` (no `v`), but `downloadURL` uses
`v<version>`. The published pre-release "v3.0.0 …" carries tag `3.0.0`. Older releases are `v2.x.y`, and two
historical tags use `v<version>_b<build>`. A pre-release and the final release of the same version would also
**collide** on one tag. The GSD config has `git.create_tag: true`, so milestone completion may create a `v3.0.0`
tag of its own.

- Q1 (tag style):
  - **A. Releases `v<version>`; pre-releases `v<version>-b<build>`.** Matches the 2.x history and the existing
    URL, and pre-releases can't collide.
  - B. Releases `<version>` (fix the URL instead); pre-releases `<version>-b<build>`. Matches the current
    workflows, but breaks with the release history.
- Q2 (the existing `3.0.0` tag and pre-release; acted on only at the Step 1 checkpoint):
  - **A. Retag the existing pre-release as `v3.0.0-b158` (its build) and delete tag `3.0.0`.** Keeps the
    pre-release and its download history.
  - B. Delete the pre-release and its tag. Cleanest, but pre-release users lose their link.
- Q3 (sequencing): can 3.0 ship on GitHub/Classic before the PAL/notarization path is done?
  - **A. Yes: ship Classic 3.0 when everything except Steps 9–10 is done, and ship PAL as soon as the
    collaborator's account is ready.** Users aren't held hostage by external steps.
  - B. No: one launch on both channels. One announcement, but the date depends on the collaborator, the website
    and Apple review.
- **Recommended:** Q1 A, Q2 A, Q3 A. Also tell GSD milestone completion not to create a `v3.0.0` tag (or
  give it a different prefix) so it can't race the release workflow.

### Listing content and marketing selection

**GA-8. What counts as "all-ages" and "non-explicit", and is the final gallery selection already made?**

The website already has two owner-approved content sets, `nonexplicit` (labelled 全年齡 / all-ages in Chinese)
and `explicit`, with owner-chosen centers and Frontpage versions (msg 1581).

- Q1 (PAL 4+ listing screenshots and the Classic "non-explicit" screenshots):
  - **A. Use the designer's promotional images built only from the approved `nonexplicit` set, after an owner
    check of every image.** Reuses approved content; the designer still makes the composition.
  - B. Also blur or replace every gallery cover, showing UI chrome only. Safest for a 4+ rating, but it hides
    what the app is for.
  - C. Use raw `nonexplicit` captures for Classic and designer images only for PAL. Less design work, but two
    different listings.
- Q2 (final gallery selection for the 384 regeneration, Step 8 checkpoint):
  - **A. Reuse the approved website selections (msg 1581) for the iPhone half, and have the owner pick only
    what the iPad half needs in addition.** Shortest checkpoint; the iPhone half is already approved.
  - B. A fresh full selection for all 384. More choice, and it redoes approved work.
- **Recommended:** Q1 A, Q2 A.

---

## 3. Technical choices left to the developer (defaults)

| Area | Default |
|---|---|
| Age-wall gate | A root gate in `RootView`/`AppReducer`. `onLaunchFinish` keeps only local work (cookie prep, history prune, image-cache init). `loadUserSettings`' network effects, the greeting fetch, tab fetches, clipboard detection, launch automation and the SDK start run only after confirmation. |
| Deep links / share extension before confirmation | Queue the incoming URL and route it after confirmation. Never open content first. |
| Storage | v1 `Setting` edited in place (or a dedicated `@Shared` key) holding the age answer plus a wording version. Re-prompt only if the wording version changes. Consent level stored the same way. The old `isSharingAnalyticsData` is ignored, not migrated. |
| SDK lifecycle | `AnalyticsClient.start` gated on level > none. Raising the level at runtime starts the SDK. Lowering it stops app signals immediately and disables the SDK (`analyticsDisabled`). Unit tests prove no SDK call before consent. |
| Install source | Closed enum, from MarketplaceKit `AppDistributor.current` at runtime, cross-checked with a build-flavor compile flag. No free-form marketplace strings (D-09). |
| Marketplace flavor | `Config/Marketplace.xcconfig` (or a build configuration) setting `BUNDLE_ID_SUFFIX` and a compilation condition. BGTask identifiers already derive from the bundle ID. `MKSellsDigitalGoods` in `App/Info.plist` for all builds. |
| Privacy manifest | Re-open Phase 14 D-04: research whether a `PrivacyInfo.xcprivacy` is required for notarization through App Store Connect, and add one if so. |
| Release workflows | One tag variable shared by `tag_name` and `downloadURL` in both workflows. `AltStore.json` gets the new version **prepended** to `versions`, older entries kept. `Scripts/bump-version.sh -v 3.0.0 -b 159` (or higher). |
| PAL source | Separate JSON in the repo, with the same version-history logic, written by the notarization job. Hosting URL agreed with the website teammate. |
| Notarization CI | Separate `workflow_dispatch` job, gated by a protected GitHub environment with a required reviewer. App Store Connect API (submit, poll, download ADP), then publish. Records the App Manager key test result. |
| Moderation | Block list as an `@Shared` set of author names. Filter is a pure, unit-tested function with normalization (case, width, diacritics), bundled list. Report actions in the comment cell's menu. |
| Reader 4b | `ReaderPosition` as reducer state with a generation counter (sketch §3). Existing gate/seed tests port to it. The three new UI tests plus R5-1's suggested run with the initial idle report suppressed. |
| Snapshot CI | Shard the 576-coordinate matrix across simulators on the self-hosted `xcode-27` runner. Report runtime per PR. The old manual "Visual capture" workflow that the README mentions was removed in quick task 261027-ci-cleanup, so the gate is a new workflow. |
| Docs | Rewrite the README "Analytics" section (and the five translated READMEs) for consent. Rewrite `Scripts/visual/README.md` (L42). |
| IN-02 / IN-03 | As specified in Step 7. |

---

## 4. Blocked on outside parties

| Party | What it needs | Blocks |
|---|---|---|
| **Collaborator (App Store Connect)** | App IDs for the marketplace app and share extension (suffix from GA-6 Q2). The app record, distribution certificate and profiles. Alternative-distribution / EU terms and marketplace (PAL) authorization. Trader-status declaration. Age-rating questionnaire. API keys (an Admin key, plus an App Manager key for the L29 test). The `marketplaceID`. Key and certificate material placed in GitHub environment secrets by the collaborator. The first submission. Each with the owner's explicit OK at that time (L6). | Steps 1 (bundle ID final), 9, 10; ANALYTICS-02's marketplace value |
| **Website teammate** | Privacy policy URL. Support page URL with the contact details (GA-3 Q2). The adult-mode declaration updated to the approved age-wall copy (GA-1 Q3). Hosting paths for the new Classic screenshots, promotional images and possibly the PAL source JSON. | Steps 4 (Settings contact links), 9; in-app privacy link |
| **Team / owner (mailbox)** | A team-owned support email address for reports and contact. | Steps 4, 9 |
| **Owner hardware** | An iPad running a signed **Release** build (Gallery Detail stall) and an iPhone for continued background downloads. Local signing is needed to install Release on devices. | Step 11 |
| **Owner approvals (checkpoints)** | Removing/retagging `3.0.0` (Step 1). Final copy for age wall and consent (GA-1). The one snapshot baseline (Step 6). The final gallery selection (Step 8). Promotional images and listing assets (Step 9). Whether to push the fixture repository commits `8ee4fc2`, `f71d108` (R4-3; needed if the 384 regeneration runs anywhere but this machine). | Steps 1, 2–3, 6, 8, 9 |
| **Designer agent** | Assigned by the owner (17-CONTEXT D-24: record only, don't dispatch from discussion). Needs the capture source set and the GA-8 content rule. | Step 9 |
| **Apple** | Notarization review time; possible rejection feedback on 1.2/5.1.1. | Step 10, PAL launch |

---

## 5. Splitting suggestion

**Assessment:** too big for one phase. 11 requirements plus five moved CAP parts. 12+ outline steps across four
unrelated domains (compliance UI, reader core UX, visual infrastructure, distribution). Six owner or
collaborator checkpoints and three outside dependencies. Phase 17's close took five verification rounds at
reduced scope. As one phase, nothing can be verified as done until the slowest outside party finishes, and the
snapshot baseline would be approved while compliance UI and the reader rework are still changing.

**Proposal:** three phases. Phase 18 is the last phase, so appending **integer** phases 19 and 20 renumbers nothing
(the owner chose integer over decimal for Phase 12; decimals 18.1/18.2 work too if preferred).

| Phase | Steps | Requirements | Outside dependency | Ends with |
|---|---|---|---|---|
| **18: In-app 3.0 readiness** | 1 (workflow fixes, build number, `MKSellsDigitalGoods`, marketplace flavor plumbing; tag checkpoint), 2, 3, 4, 4b, IN-02/IN-03 | REL-18-01 (mechanics part), DIST-18-01, AGE-18-01, CONSENT-18-01, UGC-18-01 | Contact email and URLs (placeholders allowed until the website lands) | All new UI stable, reader rework verified with G1/G2 tests |
| **19: Visual regression and marketing** | 5, 6, 7 (CI gate, preview docs, README rewrite), 8 | VIS-18-01, MKT-18-01 (export and selection), CAP-17-02/03 and the moved parts | Owner baseline and selection approvals only | Full PR gate live; 384 regenerated |
| **20: Distribution and 3.0 release** | 9, 10, 11, final Release scan and the 3.0 release run, 12 (last) | DIST-18-02, DIST-18-03, DEV-18-01, MKT-18-01 (promo part), ANALYTICS-02, REL-18-01 (release run) | Collaborator, website, designer, owner hardware, Apple | 3.0 on Classic (and PAL when ready); analytics revised last |

**Why this order:** the snapshot baseline (19) has to come after every UI change (18) to give "one owner-approved
baseline" any meaning. ANALYTICS-02 stays last (L3). All outside-party waiting goes into 20, so 18 and 19 can
close on their own evidence.

**Tradeoffs:**

- Pro: each phase verifies and closes on its own. The external waits don't stall the in-app work. The reader
  rework gets a focused verification. The collaborator and website teammate can start in parallel while 18 runs.
- Con: three discuss/plan/verify/UAT/secure/validate cycles instead of one, which is real overhead in this
  project. REL-18-01 and MKT-18-01 each span two phases, so traceability needs care. The ROADMAP, REQUIREMENTS
  traceability and STATE need an owner-approved edit (not done here).
- Lighter alternative: keep one Phase 18 but plan it in three waves with the same boundaries and a mid-phase
  verification after wave 1. Less overhead, but the phase stays open until the last outside party finishes.
- If GA-7 Q3 is "B" (one joint launch), the split still helps, but Phase 20 becomes the critical path for the
  whole release.
