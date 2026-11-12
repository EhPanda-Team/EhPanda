# 20-12: Analytics vocabulary for the 3.0 flows

**Status: SIGNED OFF (OQ-E), 2026-11-09.** The product lead approved the §2 list (product lead msg 2829). The owner
dropped the report reason (owner msg 2837, option 3-i) and chose the channel on every signal (owner msg 2842, §3
option 1). OI-4 (§5, answer A) and the SC8 wording (§6) were technical calls by the developer. The sign-off table
at the end has the details. 20-13 implements this version: §2 as amended by §4, with §3 option 1. Text kept from
the proposal is marked where a decision changed it.

Sources: Research §10, refined against the code at `feature/gsd-phase-20`. Rules: ANALYTICS-01 and Phase 14 D-06 to
D-14. Level contract: `18-COPY-MINIMAL.md` Revision 7 (Minimal) and Revision 6 (Basic, Full); the header rule in
`AnalyticsSignal+Level.swift`.

## 1. What the code does today

- `AnalyticsSignal` has 13 cases. Each is rendered once in `AnalyticsSignal+Rendering.swift`, with names in
  `Domain.eventName` form and keys in `Domain.name` form. Its level is set in `AnalyticsSignal+Level.swift`, whose
  switch is exhaustive, so a new case does not compile until both are decided.
- `AnalyticsClient.send` drops any signal whose minimum level the stored level does not reach. It sends nothing
  while `Setting.analyticsLevel` is `nil`, and nothing while the SDK is not running. Under Minimal the SDK is never
  started.
- The only signal sent at every level is `App.installed`, from `InstallSignalSender`, with one key:
  `App.distributionChannel`. It uses its own random per-install user hash, not the SDK's.
- Default parameters: the five `App.*` settings, at Full only (`AnalyticsDefaultParameters.snapshot`). Below Full,
  none.
- The 3.0 flows send nothing yet. Phase 18 D-02 and 18.1 D-11 left that to this revision, and these headers say so:
  `CommentModeration.swift` ("Nothing here sends an analytics signal (D-02)") and `ReportFormFeature.swift` ("no
  report action sends an analytics signal (D-08, D-11)"). 20-13 rewrites both headers to point at this record.

## 2. Proposed signals

Every case below needs **Basic**. The sentence that covers it is Basic's (Revision 6): "which screens and features
you use". None of them changes a level description; §4 flags the one borderline case. Every parameter value is the
raw value of a closed enum declared in `AnalyticsVocabulary.swift`; the spelling equals the case name, as that
file's rule 1 requires.

| # | Flow | `AnalyticsSignal` case | Name | Parameters (key: every value) | Sent from (file, action) |
|---|------|------------------------|------|-------------------------------|--------------------------|
| 1 | First launch (age wall + analytics choice) | `firstLaunchCompleted(level: AnalyticsLevel)` | `FirstLaunch.completed` | `Analytics.level`: `basic` / `full` | `AppFeature/DataFlow/AppReducer.swift`, `.firstLaunch(.delegate(.levelChosen(level)))`, after `analyticsClient.apply(level)` in the same effect (see note a) |
| 2 | Analytics choice in Settings | `analyticsLevelChanged(from: AnalyticsLevel, to: AnalyticsLevel)` | `Analytics.levelChanged` | `Analytics.from`: `minimal` / `basic` / `full`; `Analytics.to`: `basic` / `full` | `SettingFeature/GeneralSetting/GeneralSettingReducer.swift`, `.analyticsLevelPicked(level)`, after `apply(level)` in the existing `.run` |
| 3 | Report form | `commentReportOutcome(ReportOutcome)` *(signed off without the reason, §4 (3-i); proposed as `commentReportOutcome(reason: ReportReason, outcome: ReportOutcome)`)* | `Moderation.reportOutcome` | `Moderation.reportOutcome`: `sent` / `failed` / `unavailable` / `reportPageOpened`. *(`Moderation.reportReason`, `child` / `illegal` / `none`, is dropped, owner msg 2837.)* | `DetailFeature/Moderation/ReportFormFeature.swift`: `.sendResponse` (`sent`, or `failed` per failed attempt), `.loaded(nil)` (`unavailable`), `.primaryTapped` when `primaryKind == .openReportPage` and `.alert(.presented(.openReportPage))` (`reportPageOpened`) |
| 4a | Block | `commentPosterBlocked` | `Moderation.posterBlocked` | none | `DetailFeature/Moderation/CommentModeration.swift`, `.alert(.presented(.confirmBlock))` |
| 4b | Block (unblock) | `commentPosterUnblocked(from: UnblockSurface)` | `Moderation.posterUnblocked` | `Moderation.unblockSurface`: `comment` / `blockedUsers` | `CommentModeration.swift` `.unblock` (`comment`); `SettingFeature/BlockedUsers/BlockedUsersReducer.swift` `.unblockTapped`, after its guard (`blockedUsers`) |
| 4c | Block (show a collapsed comment) | `blockedCommentShown` | `Moderation.blockedCommentShown` | none | `CommentModeration.swift`, `.show(commentID:)` |
| 5 | Posting filter | `commentPostingWarningAnswered(PostingWarningChoice)` | `Moderation.postingWarningAnswered` | `Moderation.postingChoice`: `edit` / `postAnyway` | `CommentModeration.swift`, `.alert(.presented(.edit))` and `.alert(.presented(.postAnyway))`. This covers both the Comments list and the Detail strip, which scope the same feature. |
| 6 | Marketplace build | none new | — | Already covered: `App.installed` carries `App.distributionChannel` (`altstorePAL` for the PAL build). The open choice is §3. | — |

Notes:

- **a. First launch, exactly once.** If the level is chosen before the deferred launch has run, `AppReducer` does not
  call `apply` on `levelChosen`; the deferred launch applies the stored level instead. 20-13 has to send
  `firstLaunchCompleted` on whichever path calls `apply` first after the choice: for example, a pending flag in
  `AppReducer.State` that is set on `levelChosen` and cleared when the signal is sent. A test should cover both
  orders.
- **b. The age wall sends nothing of its own.** Nothing may be sent before a level is chosen, and the wall comes
  first. `FirstLaunch.completed` implies the wall was confirmed. Declining or leaving the wall is never observable,
  by design.
- **c. Research's `FirstLaunch.kind` (`newInstall` / `upgrade`) is dropped.** 2.8.1 kept its settings in the Core
  Data `AppEnv` store (`DatabaseClient.updateAppEnv(key: "setting")` on `main`), while 3.0 reads
  `appStorage("setting")`. So 3.0 has no stored fact that tells an upgrader from a new install. Adding one would
  mean a launch-time probe of the 2.x store: new code with its own risks, for one dashboard column. If the product
  lead wants it anyway, it comes back as a separate item.
- **d. Level changes are seen only when the new level is Basic or Full.** A move to Minimal sends nothing: the SDK
  stops and Minimal promises only the install signal. So `Analytics.to` never reads `minimal`, and the dashboard
  shows downgrades to Minimal only as a missing session.
- **e. Report outcomes are the ones the reducer sees.** A swipe-down dismissal is not an action, so "closed without
  sending" is not counted. Counting it with an `onDisappear` hook would undercount in other ways. *(The proposal's
  reason values, `none` for a form that ended before a reason was picked and `illegal` for the site's `other`, are
  gone with the reason, owner msg 2837.)*
- **f. The unblock surface** comes from which reducer handles it, so no moderation state has to learn where it is
  scoped. A comparable surface on Block or Show would need such a field. Not proposed.

### README lines (English; 20-13 adds the five translations in `READMEs/`, checked by `18-copy-check.py --readmes`)

In "At Basic, … adds:", the bullet "which screens and features you use: …" gains, after "searches as a shape (…)
rather than as text":

> ; finishing the first-launch screens and the level you chose there; changing the level in Settings (the old and
> new level); and comment moderation: blocking, unblocking and showing a hidden comment, your answer to the posting
> warning, and how a report ended (sent, failed, unavailable or opened on the site)

*(Signed off without the proposal's closing words "with its reason", owner msg 2837.)*

§3 option 1 was chosen (owner msg 2842), so the Basic section also gains one line, its own bullet after the one
above:

> every event also carries where you got the app from

No other README line changes.

## 3. Decision: the distribution channel as a default parameter at Basic and Full

**Option 1: add `App.distributionChannel` to every SDK signal at Basic and Full** (`AnalyticsDefaultParameters`,
outside the Full-only guard).

- Pros:
  - Every signal can be split by channel: for example, errors on the PAL build against the AltStore build, or
    feature use by channel.
  - Today the dashboard cannot do this, because `App.installed` uses its own user hash and cannot be joined to SDK
    events.
  - Already covered by the approved copy: Basic's description begins "Everything in Minimal", and Minimal's says
    "where you got the app from". So no level description changes.
  - The value is the same closed six-value set (`DistributionChannel`), read through the same allow-list.
- Cons:
  - One more column on every event, including the SDK's own session and acquisition signals.
  - Small cohorts (`beta`, `altstorePAL` early on) combined with the SDK's device payload are a slightly finer
    partition of few users.
  - The README's Basic section needs one line: "every event also carries where you got the app from".

**Option 2: keep it on `App.installed` only (today).**

- Pros: no change; the smallest payload.
- Cons: no per-channel view of anything but installs.

**Decision: option 1** (owner msg 2842, "Yes, on every signal"), as recommended. It is the 18-03-SUMMARY carry
("add the install source to the Basic and Full signals"), and the approved copy already covers it. 20-13 adds a
`snapshot` case for Basic with exactly one key, and a test that Basic carries no `App.*` key other than
`App.distributionChannel`.

## 4. Rules check (ANALYTICS-01, Phase 14 D-06 to D-14; threat T-20-31)

For every signal in §2:

| Rule | 1 | 2 | 3 | 4a | 4b | 4c | 5 |
|------|---|---|---|----|----|----|---|
| Closed case sets only (no `String`, `URL`, `Data` or AppModels content type in the case) | yes | yes | yes | yes (no payload) | yes | yes (no payload) | yes |
| No gallery identifier, token, title or URL | yes | yes | yes: the form's `galleryURL` and `target` stay in its state | yes | yes | yes | yes |
| No keyword text or tag value | yes | yes | yes | yes | yes | yes | yes: the comment text and the matched term stay local |
| No username or member ID | yes | yes | yes: the comment's author is not passed | yes: `confirmBlock`'s `memberID` and `name` are not passed | yes: `memberID` not passed | yes: `commentID` not passed | yes |
| No comment text, report details or email | yes | yes | yes: `email`, `details` and the prefill are never read by the send site | yes | yes | yes | yes |
| Nothing before a level is chosen | yes: sent only after the level is stored and applied | yes | yes, by the `send` gate | yes | yes | yes | yes |
| Nothing under Minimal | yes: `isSent(at: .minimal)` is false for Basic signals, and the SDK is not running | yes | yes | yes | yes | yes | yes |
| Fits the approved Basic description without change | yes | yes | yes, without the reason (decided below; proposed: borderline) | yes | yes | yes | yes |

**Borderline: the report reason.** "Which screens and features you use" plainly covers that the Report form was
used and how it ended. Whether it also covers *why* (`child` or `illegal`) is a reading the approvers should make
explicitly. If they decide it does not, there are two ways to go:

- **(3-i)** drop `Moderation.reportReason`, so no copy changes; or
- **(3-ii)** keep it and send the Basic description back for a copy approval first (the `AnalyticsSignal+Level.swift`
  header rule).

**Recommendation: (3-i)** unless the reason split is needed for a decision. The outcome alone shows whether the
native form works.

**Decision: (3-i)** (owner msg 2837, "No, only how it ended"). `Moderation.reportReason` is dropped, so the report
signal carries its outcome only and no level description changes. The table above
records signal 3 as fitting.

## 5. OI-4 (carried from Phase 18): the install arrives twice at Basic and Full

At Basic and Full, one install can produce both:

- the SDK's `TelemetryDeck.Acquisition.newInstallDetected`, sent on the SDK's first session;
- EhPanda's `App.installed`.

They carry different user hashes, so the dashboard cannot de-duplicate them per install.

- **Option A (recommended): keep both, and document which one counts.** `COVERAGE.md` and the README would say
  that `App.installed` is the install count, because it is the only one sent at every level. `newInstallDetected`
  counts only Basic and Full installs. It also depends on the SDK's stored first-session state, which an upgrade
  from 2.x, where the SDK ran by default, may already have. No code change.
- **Option B: suppress the SDK's signal.** The SDK has no setting for this. It would need a filter in
  `TelemetrySDK.swift`, a test, and a re-read on every SDK upgrade (Pitfall P-12). It also drops a signal that the
  SDK's built-in acquisition insights rely on.

**Answer: A**, a technical call by the developer at sign-off (2026-11-09). Under §3 option 1, `newInstallDetected`
also carries the channel at Basic and Full. That does not change the answer: the install count stays
`App.installed`.

## 6. SC8 wording (ROADMAP Phase 20, success criterion 8)

Today: "As the last plan, analytics record the install source and every 3.0 flow under the consent levels, within
ANALYTICS-01's rules; nothing is sent under None."

There is no level called None any more (D-06a), and Minimal sends one signal. Proposed:

> 8. As the last plan, analytics record every 3.0 flow under the consent levels, within ANALYTICS-01's rules: the
> install signal carries the distribution channel at every level, Minimal sends nothing else, and nothing is sent
> before a level is chosen.

**Adopted** as a technical call by the developer at sign-off (2026-11-09), and applied to ROADMAP Phase 20 success
criterion 8. It holds under §3 option 1, which adds the channel to Basic and Full signals and sends nothing new
under Minimal.

## 7. For 20-13 once signed off

- 20-13 adds the cases, renderings, levels and enums (`ReportOutcome`, `UnblockSurface`, `PostingWarningChoice`;
  no `ReportReason`, §4), plus `AnalyticsVocabularyTests` spellings, rendering tests and reducer tests per send
  site. Both orders of note a get a test.
- It adds the Basic `snapshot` case with exactly one key, `App.distributionChannel`, and a test that Basic carries no
  other `App.*` key (§3 option 1).
- It rewrites the two "no analytics" headers (§1), and updates `COVERAGE.md` (OI-4 answer) and the README in all
  six languages.
- No level description changes: the approvers chose (3-i).

## Sign-off

| Item | Decision | Approved by |
|------|----------|-------------|
| §2 signals | the list as proposed: 1, 2, 3, 4a, 4b, 4c, 5 (6: nothing new) | product lead msg 2829 |
| §4 report reason | (3-i): drop `Moderation.reportReason`; the report signal carries the outcome only, and the README line loses "with its reason" | owner msg 2837 ("No, only how it ended") |
| §3 channel default parameter | option 1: `App.distributionChannel` on every signal at Basic and Full; one README line in the Basic section | owner msg 2842 ("Yes, on every signal") |
| §5 OI-4 | answer A: keep both install signals; `App.installed` is the install count | technical call by the developer at sign-off |
| §6 SC8 wording | as proposed, applied to ROADMAP Phase 20 SC8 | technical call by the developer at sign-off |

No level description changes, so no copy approval is needed (`AnalyticsSignal+Level.swift` header rule). Nothing was
implemented before these approvals. 20-13 implements this record.
