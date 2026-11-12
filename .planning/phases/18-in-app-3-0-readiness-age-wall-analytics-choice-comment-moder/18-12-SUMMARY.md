---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "12"
subsystem: docs-gate-moderation
tags: [readme, analytics, phase-gate, release-scan, comments, moderation, member-id]

requires: ["18-01", "18-02", "18-03", "18-04", "18-05", "18-06", "18-07", "18-08", "18-09", "18-10", "18-11"]
provides:
  - "The Analytics section of `README.md` and the five `READMEs/` translations: the three levels (Minimal, Basic, Full) verbatim from the copy files, the choice on first launch and in Settings → General → Analytics, and what each level sends as built"
  - "`18-copy-check.py --readmes`, with ten self-test cases"
  - "Comment blocking by the poster's E-Hentai member ID (owner msg 1918): `GalleryComment.authorMemberID` from the comment's forum contact link, `[BlockedCommentUser]` under `@Shared(.blockedCommentUsers)`, and the name a blocked poster was last seen under kept for the Blocked Users list"
  - "The Phase 18 gate record: four green test runs, lint, both copy checks, the Release scan and the no-network-before-Continue observation"
affects: [18-verify, 19]

actuals:
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "A block list is keyed by a stable ID, never a display name; the display name is stored only to label the list, and is refreshed when the ID shows up under a new name"
    - "A view that animates on block-list changes watches the list's IDs (`blockedMemberIDs`), not the list itself, so a name refresh neither animates nor moves VoiceOver focus"

key-files:
  created:
    - AppPackage/Sources/AppModels/Moderation/BlockedCommentUser.swift
    - AppPackage/Tests/AppModelsTests/BlockedCommentUserTests.swift
  modified:
    - README.md
    - READMEs/README.chs.md
    - READMEs/README.cht.md
    - READMEs/README.de.md
    - READMEs/README.jpn.md
    - READMEs/README.ko.md
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-VALIDATION.md
    - AppPackage/Sources/AppModels/Gallery/GalleryComment.swift
    - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
    - AppPackage/Sources/ParserFeature/Parser+Comment.swift
    - AppPackage/Sources/DetailFeature/Moderation/CommentModeration.swift
    - AppPackage/Sources/DetailFeature/Moderation/CommentModerationMenu.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersReducer.swift
    - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersView.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
    - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
    - AppPackage/Tests/DetailFeatureTests/BlockedCommentPresentationTests.swift
    - AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift
    - AppPackage/Tests/ParserFeatureTests/Gallery/GalleryCommentParserTests.swift
    - AppPackage/Tests/SettingFeatureTests/BlockedUsersReducerTests.swift
    - EhPandaUITests/CommentModerationUITests.swift
    - EhPandaUITests/SettingsModerationUITests.swift
    - EhPandaUITests/BlockedUsersTitleLayoutUITests.swift
    - EhPandaUITests/Support/UITestConstants.swift

key-decisions:
  - "Lead decision (owner msg 1918): comment blocking matches the poster's E-Hentai member ID, the digits after `showuser=` in the forum contact link that the site prints after every comment author's name. It never matches the display name, which can change"
  - "Lead decision (owner msg 1918): the block list moved to a new key, `blockedCommentUsers`, holding `[BlockedCommentUser]` (member ID plus the name last seen). There is no migration from `blockedCommentAuthors`: that key was added in 18-04 (`fb26b0e3c`), and `git tag --contains` shows no release tag holds it"
  - "Lead decision (owner msg 1918): a comment without a member ID offers no Block and is never collapsed, because there is nothing stable to match. Report stays"
  - "Lead decision (owner msg 1918): when a blocked ID appears under a new name, the block stays and the Detail fetch stores the new name, so the Blocked Users list shows the name the site shows now. The write happens only when a name changed"
  - "`BlockedCommentUser` decodes strictly, like `GalleryHistoryEntry`: an entry whose member ID is empty or not all digits, or whose schema is newer, fails the whole list's decode, so Sharing resets the list to `[]`. `block(memberID:name:)` refuses the same IDs, so the app never writes a list it cannot read back"
  - "`CommentModerationMenu.items` takes a `CommentBlockStatus` (`.blocked`, `.notBlocked`, `.noMemberID`) instead of `isBlocked` plus a sixth `hasMemberID` flag. The flag broke SwiftLint's five-parameter limit, and the enum rules out the impossible blocked-without-ID state"
  - "The Blocked Users list sorts by name with `localizedStandardCompare`, then by member ID, so two posters under one name keep a stable order"
  - "The README Analytics sections say Full sends the five settings the code sends (18-03 as built), not the six the plan names"

patterns-established:
  - "Moderation UI tests preset the block list with `EHPANDA_UITEST_BLOCKED_USERS`, a JSON array of `{\"memberID\": …, \"name\": …}` objects; a malformed list, including the old array of names, starts the launch with no blocks"

requirements-completed: [AGE-18-01, CONSENT-18-01, UGC-18-01]

coverage:
  - id: T1
    description: "README Analytics sections in six languages"
    verification:
      - kind: script
        ref: "18-copy-check.py --self-test and --readmes exit 0 (6 sections, three levels verbatim, no retired text)"
        status: pass
    human_judgment: false
  - id: T2
    description: "Phase gate"
    verification:
      - kind: automated
        ref: "FeatureTests and UITests on the phone then the pad, lint, both copy checks, Release scan, plutil (table below)"
        status: pass
      - kind: manual_agent
        ref: "No network connection before Continue on a fresh install (below)"
        status: pass
    human_judgment: false
  - id: T3
    description: "Live report page (checkpoint, verified by an agent per owner rule msg 1652)"
    verification:
      - kind: manual_agent
        ref: "Debug build on the phone, signed in through the app's login: Report → Open Report Page loads the signed-in report form; after Log Out the same sheet loads the site's guest page (deviation 9). Nothing selected or submitted"
        status: pass
    human_judgment: false

duration: about 3h over several sessions (2026-11-05 14:40Z to 17:45Z), with the gate run twice, plus the live report-page check at 17:51Z
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 12: README Analytics, phase gate and member-ID blocking Summary

**The six README Analytics sections now describe the three analytics levels as the app offers and sends them. Comment
blocking now matches the poster's E-Hentai member ID instead of the display name (owner msg 1918). Phase 18 passes
its full gate on both devices and in Release. The live report-page check passed, verified by an agent per owner rule
msg 1652.**

## Accomplishments

- **README Analytics sections (Task 1, `cf18b952b`):**
  - Each of the six sections quotes the approved Minimal, Basic and Full names and descriptions in its language.
  - Each says the level is chosen on first launch and can be changed in Settings → General → Analytics.
  - Each describes what every level sends as built:
    - Minimal: one install signal, and the SDK is never started;
    - Basic: the SDK's session signals and technical details, plus the screen, feature and error signals;
    - Full: also gallery opens, reading sessions, download outcomes and the five settings.
  - The opt-out paragraph is gone. The never-included list, the TelemetryDeck links and the no-credentials paragraph
    stay.
  - `18-copy-check.py --readmes` checks the three levels verbatim and in order. It fails on retired descriptions,
    on None as a level and on the old opt-out sentences.
- **Member-ID blocking (owner msg 1918, `f08a6a781`):**
  - The parser reads the member ID from the comment's contact link,
    `https://forums.e-hentai.org/index.php?showuser=<digits>`. It accepts digits only, on an `e-hentai.org` host,
    from the author line only. A link inside the comment text never counts. With no such link the ID is `nil`.
  - `GalleryComment` gains `authorMemberID`; `author` is unchanged.
  - The block list is `[BlockedCommentUser]` under the new key `blockedCommentUsers`. Each member ID is held once,
    in block order, with the name it was last seen under.
  - Block, Unblock, collapse, the Detail strip, the comments list and the Blocked Users list all use the member ID.
  - A blocked poster seen under a new name stays blocked, and the stored name is updated from the Detail fetch.
  - Another poster who uses a blocked poster's name is not blocked.
  - A comment without a member ID has no Block item and is never collapsed.
- **Phase gate (Task 2):** the table below. It was run again from the start after the member-ID change.

## Gate

All runs are on the final code (`f08a6a781`), one `xcodebuild` at a time. The test plans run on clones of the two
simulators.

| Step | Result |
|------|--------|
| FeatureTests, phone (`FFE7E686`) | 1753 total: 1743 passed, 0 failed, 10 expected failures, 0 Repetition nodes |
| FeatureTests, pad (`B470DB46`) | run 1: 1742 passed, **1 failed** (`ReaderListPositionTests` `XCTUnwrap UIWindowScene`, deviation 7); run 2: 1744 passed, 0 failed, 9 expected failures, 0 Repetition nodes |
| UITests, phone | 120 total: 100 passed, 0 failed, 20 skipped, 0 Repetition nodes (983 s) |
| UITests, pad | 120 total: 103 passed, 0 failed, 17 skipped, 0 Repetition nodes (1062 s) |
| `CommentModerationUITests`, phone (after the change, before the full plans) | 16/16 |
| SwiftLint `--strict --no-cache` (plan's paths) | 0 violations in 805 files |
| `18-copy-check.py` / `--self-test` / `--readmes` | 38 keys × 6 locales verbatim, 48 retired texts absent / OK / 6 sections OK |
| `test_release.py` | 20 tests OK |
| Release build (`generic/platform=iOS Simulator`, `.capture/release/`) and Debug control | both `BUILD SUCCEEDED` |
| `verify-release.py` with 4 link maps (app and ShareExtension, arm64 and x86_64) and the launch probe on the phone | PASS, 0 findings, 378 payload files; 1 accepted inert shell (`UITestAutomation`); Release survived the probe launch, the Debug control did not |
| `plutil -extract MKSellsDigitalGoods` on the Release app | `false` |

The skipped UI tests are the Duo suites (`DuoHome` 8, `DuoReadingPanel` 2, `DuoToolbar` 1, `LandscapePane` 5), which run only with their opt-in environment, plus the iPad-only or phone-only cases on the other idiom (phone 4, pad 1). None is from Phase 18. The FeatureTests runs started
at 16:42:44Z, after the last edit to any file in `f08a6a781` (16:42:32Z), and the commit holds exactly what they ran.

### No network before Continue

Release build, installed fresh (the clone's copy uninstalled first) on a clone of the phone with the Mac's live
network. The app was launched and left at the age wall for 30 s. Continue was disabled and no box was ticked. Results:

- `lsof -nP -a -p <pid> -i` once a second found no socket at any point;
- `log stream` on the clone, for the `EhPanda` process and `com.apple.network*`, `com.apple.CFNetwork*` and
  `nsurlsessiond`, logged only the two `app_launch` activities, `networkd` settings reads, two context deallocations,
  cookie-storage setup and the ATS defaults. It logged no `nw_connection`, no URL task and no DNS lookup;
- the kept screenshot (local, not committed) shows "EhPanda is for adults" with Continue disabled.

**Result: no network connection before Continue.** The clone was deleted afterwards.

The credentialed check of `App.installed` at Minimal was not run. The Release build carries the real TelemetryDeck
app ID, so it would have posted a real, non-test install signal into the owner's analytics. That request is covered
by the `InstallSignalSender` unit tests (body, hash, disposition, retry).

### Earlier gate attempts (before owner msg 1918)

The gate first ran on `0062fa2e1`. That attempt is superseded, because the member-ID change touched the parser,
storage and the comment UI:

- lint 0 violations in 805 files;
- FeatureTests phone 1729 passed, 0 failed, 10 expected failures;
- FeatureTests pad: the first run had 2 failures, `XCTUnwrap UIWindowScene` in `ReaderListPositionTests` (see
  below); the rerun had 1730 passed, 9 expected failures;
- UITests phone 100 passed, 20 skipped;
- UITests pad: the first run had 1 `ReaderRebuildUITests` failure under parallel load. The second run reached 82
  cases with no failure, then a process restart stopped it.

It also found the stale Reduce Motion inventory (`3be402c1e`) and the strip-drag overshoot (`0062fa2e1`).

## Deviations from Plan

1. **[Owner change, msg 1918] Member-ID blocking.** This change came in the middle of the gate and is outside the
   plan's file list: the parser, models, moderation feature, settings screen, UI test support, and their tests
   (`f08a6a781`). The decisions are recorded above.
2. **[Rule 1] Reduce Motion inventory (`3be402c1e`).** 18-11 gated three comment moderation animations on Reduce
   Motion but did not update `ReduceMotionGatingSourceTests`' tables, so the full FeatureTests gate failed its three
   equalities. The tables now count 23 reads, 33 predicates and 70 mentions.
3. **[Rule 1] Strip-drag overshoot (`0062fa2e1`).** `CommentModerationUITests` repeated a case on the phone: a drag
   carried the strip past the collapsed card, which ended 26 pt outside the leading edge. The helper now drags back
   whichever way brings the card into view.
4. **[Rule 1] Two 18-11 polish fixes** were committed during this plan (`b4bd67dc0` the `…` button's muted gray,
   `1f83cb12b` no empty vote slot before a stacked comment's score). Both are labelled 18-11.
5. **README: five settings, not six.** The plan says Full sends "the six settings". The code sends five (18-03 as
   built), so the READMEs say five.
6. **`18-copy-check.py --readmes`** also fails each file's old opt-out sentences, beyond the plan's list. It has ten
   self-test cases.
7. **`XCTUnwrap UIWindowScene` on the pad.** `ReaderListPositionTests` sometimes finds no window scene in the pad
   clone's first moments. It failed once before msg 1918 and once after (`testAPageAcrossTheTopKeepsItsHeightUntilItsTopIsOnScreen`,
   0.27 s, in a run with 1742 passed). A rerun of the full plan was green each time. This is environmental; no code
   changed for it.
8. **Clones, not the devices themselves.** The test plans and the network observation ran on clones of `$PHONE`
   and `$PAD`, so the owner's simulators kept their state. The plan names `$PHONE` for the observation. Only
   `verify-release.py`'s probe ran on `$PHONE` itself: it installs over `app.ehpanda.personal`, which keeps that
   app's data container. Its preferences file was not modified.

9. **[Checkpoint, lead decision] Signed-out report page: the site's guest page, not a sign-in prompt.** The plan's
   Task 3 step 4 expected the sheet to show the site's sign-in prompt after Log Out. The site has no sign-in prompt
   at this point: signed out, the sheet loads the same report form in the site's guest version. Evidence:
   - an ad banner sits under the site menu, and the signed-in page had none;
   - the "Multi-Page Viewer" link is gone; the signed-in page showed it (the site shows it only to signed-in
     accounts with that perk);
   - the app had dropped its session: all four cookie fields in Account read "None", and Post Comment was disabled;
   - a cookie-free `curl` GET of another gallery's `?report=select` page returns the same form ("Report Type",
     "[Select a complaint type...]") with no "Multi-Page Viewer" link and no sign-in prompt; its only login reference
     is a script variable pointing at the site's login bounce page.

   What the check protects holds: the private report web view (18-11) does not keep the session after the app signs
   out. The lead accepted this result in place of the plan's expected text.

## Checkpoint: live report page (Task 3), PASSED

Verified by an agent per owner rule msg 1652 (agents test what they can themselves), 2026-11-05 17:51Z. No account
details are recorded here or in any screenshot.

Setup: a Debug build of `0c753baf8` (planning docs only since the gated `f08a6a781`), installed as
`app.ehpanda.personal` on the phone (`FFE7E686`). The app started signed out.

1. **Sign in: pass.** The agent signed in through the app's own Log In screen with the team test account (entered
   from the team's password store without printing it). No Cloudflare challenge. The iOS offer to save the password
   was declined.
2. **Report page signed in: pass.** Gallery → Comments → Show All → `…` on another poster's comment → Report on
   E-Hentai → "Report this comment?" → Open Report Page. The sheet loaded the gallery's report page with the site
   menu, the gallery header and the "Report Type" form ("[Select a complaint type...]"). The signed-in signs: no ad
   banner and the "Multi-Page Viewer" link present. Nothing was selected and nothing was submitted. The sheet closed
   with Close.
3. **Signed out: pass (deviation 9).** Account → Log Out → confirm; every cookie field read "None". The same steps
   loaded the site's guest version of the page: an ad banner, no "Multi-Page Viewer" link, no session. Nothing was
   selected or submitted. The sheet closed with Close.

The app was left signed out, no simulator setting was changed, and the phone was shut down afterwards. The two
screenshots (signed in, signed out) stay local and show no account name; they are not committed.

## Self-Check

- Commits on the branch: `cf18b952b`, `3be402c1e`, `0062fa2e1`, `f08a6a781` (this plan); `b4bd67dc0`, `1f83cb12b`
  (18-11 fixes). Each one is signed (`G`) and dated `+08:00`.
- Every file in `key-files` exists; `BlockedCommentAuthors.swift` and its tests are gone.
- `18-VALIDATION.md`: 33 rows green, including 18-12-03; `nyquist_compliant: true`, `wave_0_complete: true`.
- STATE, ROADMAP and REQUIREMENTS mark 18-12 complete; AGE-18-01, CONSENT-18-01 and UGC-18-01 are Complete. Phase
  18's verification (`/gsd-verify-work`) has not been run.
