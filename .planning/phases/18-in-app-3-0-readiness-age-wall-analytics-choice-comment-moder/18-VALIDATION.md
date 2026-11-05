---
phase: "18"
slug: "in-app-3-0-readiness-age-wall-analytics-choice-comment-moder"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: true
wave_0_complete: true
created: "2026-11-05"
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 18-RESEARCH.md "Validation
> Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (FeatureTests), XCTest (`EhPandaUITests`), Python `unittest` (`Scripts/visual`) |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan`, the `UITests` test plan, `.swiftlint.yml` |
| **Devices** | `EhPanda iPhone Air` (`$PHONE`) then `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), resolved by name: `PHONE=$(xcrun simctl list devices \| grep "EhPanda iPhone Air (" \| grep -Eo '[0-9A-F-]{36}' \| head -1)`; `PAD=$(xcrun simctl list devices \| grep "EhPanda iPad Pro 11-inch (M5) (" \| grep -Eo '[0-9A-F-]{36}' \| head -1)` |
| **Quick run command** | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE" -only-testing:<Module>Tests` |
| **Full suite command** | FeatureTests on `$PHONE`, then `$PAD`; UITests (`-testPlan UITests`) on `$PHONE`, then `$PAD`; one `xcodebuild` invocation at a time |
| **Lint** | `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` → `Found 0 violations` |
| **Estimated runtime** | module FeatureTests ~60–180 s; full FeatureTests ~15 min per device; full UITests ~60 min per device |

---

## Sampling Rate

- **After every task commit:** the touched module's FeatureTests on `$PHONE` (or the named UI test class) and strict
  lint of the touched paths.
- **After every plan:** the touched modules' FeatureTests on `$PHONE` then `$PAD`.
- **Before `/gsd-verify-work`:** plan 18-12's full gate: FeatureTests and UITests on both devices, 0 failures, 0
  Repetition nodes (`xcrun xcresulttool` summary), strict no-cache lint 0 violations. Passed by 18-12 on `f08a6a781` (see 18-12-SUMMARY).
- **Max feedback latency:** 300 s for a module run.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | IN-02 | T-18-01 | Release scan fails on `captureSystemOverlay` | python | `python3 -m unittest discover -s Scripts/visual -p test_release.py` | ✅ extend | ✅ green |
| 18-01-02 | 01 | 1 | IN-03, DIST-18-01 | — | no Release-only unused import; `MKSellsDigitalGoods` false | build + plutil | see plan | ✅ | ✅ green |
| 18-02-01 | 02 | 1 | AGE-18-01, CONSENT-18-01 | — | answers persist; legacy blobs decode to "not answered"; toggle retired | unit | `-only-testing:AppModelsTests` | ❌ W0 | ✅ green |
| 18-02-02 | 02 | 1 | AGE-18-01 | T-18-02, T-18-03 | locked launch touches no download client, no settings load, no SDK; queued deep link | unit | `-only-testing:AppFeatureTests/FirstLaunchGateTests` | ❌ W0 | ✅ green |
| 18-02-03 | 02 | 1 | AGE-18-01 | T-18-04 | DEBUG preset only; existing UI suites still pass | unit + UI smoke | `-only-testing:AppFeatureTests/UITestStubTests`, `-only-testing:EhPandaUITests/DeepLinkEntryUITests` | ✅ extend | ✅ green |
| 18-03-01 | 03 | 2 | CONSENT-18-01 | T-18-21 | install source is a fixed enum; IDs validated | unit | `-only-testing:AnalyticsClientTests/InstallSourceTests` | ❌ W0 | ✅ green |
| 18-03-02 | 03 | 2 | CONSENT-18-01 | T-18-06..08 | one install signal per install, exact payload | unit | `-only-testing:AnalyticsClientTests/InstallSignalSenderTests` | ❌ W0 | ✅ green |
| 18-03-03 | 03 | 2 | CONSENT-18-01 | T-18-05, T-18-06 | no SDK call before choice; never started under Minimal; level gating per D-06f (Basic: the seven screen/feature and three error cases, `[:]` parameters; Full: plus `galleryDetailOpened`, `readingSessionEnded`, `downloadStateChanged` and the five `App.*` parameters); lowering terminates | unit | `-only-testing:AnalyticsClientTests` | ❌ W0 | ✅ green |
| 18-03-04 | 03 | 2 | CONSENT-18-01 | T-18-05 | `apply` wired from reducers only | unit | `-only-testing:AppFeatureTests` | ✅ extend | ✅ green |
| 18-04-01 | 04 | 1 | UGC-18-01 | T-18-10 | filter rules; bundled list loads | unit | `-only-testing:DetailFeatureTests/CommentFilterTests` | ❌ W0 | ✅ green |
| 18-04-02 | 04 | 1 | UGC-18-01 | T-18-09, T-18-11 | report URL on the gallery's host; own-comment rule; block store; host-scoped session cookies | unit | `-only-testing:DetailFeatureTests -only-testing:AppModelsTests/BlockedCommentUserTests -only-testing:CookieClientTests` | ❌ W0 | ✅ green |
| 18-05-01 | 05 | 2 | UGC-18-01 | T-18-13 | warning before send, text kept, edits and Detail too | unit | `-only-testing:DetailFeatureTests/CommentModerationReducerTests` | ❌ | ✅ green |
| 18-05-02 | 05 | 2 | UGC-18-01 | T-18-12 | report confirm presents the report sheet; block/unblock/show-once; no analytics | unit | same | ❌ | ✅ green |
| 18-06-01 | 06 | 1 | AGE-18-01, CONSENT-18-01, UGC-18-01 | T-18-14 | copy check self-test | script | `python3 .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py --self-test` | ❌ | ✅ green |
| 18-06-02 | 06 | 1 | AGE-18-01, CONSENT-18-01, UGC-18-01 | T-18-14 | every key six locales, verbatim (Basic and Full descriptions and `consent.level.recommended` from Revision 6, D-06f; `consent.body` from Revision 5, D-06e); retired text absent, incl. the first-launch Basic and Full descriptions, the Revision 3 Basic description and both old `consent.body` texts | script | `python3 .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py` | ❌ | ✅ green |
| 18-07-01 | 07 | 1 | reader | T-18-15 | `ReaderPosition` rules; ported suites | unit | `-only-testing:ReadingFeatureTests` | ❌ W0 | ✅ green |
| 18-07-02 | 07 | 1 | reader | T-18-15 | view wired to one source; existing UI suites green | UI | `-only-testing:EhPandaUITests/ReaderPageSyncUITests -only-testing:EhPandaUITests/ReadingOrientationUITests` | ✅ | ✅ green |
| 18-08-01 | 08 | 2 | AGE-18-01, UGC-18-01 | T-18-16 | DEBUG launch keys, request log | unit | `-only-testing:AppFeatureTests/UITestStubTests` | ✅ extend | ✅ green |
| 18-08-02 | 08 | 2 | reader G1/G2 | — | rebuild then turn; Auto-Play direction change; LTR/RTL | UI | `-only-testing:EhPandaUITests/ReaderRebuildUITests` | ❌ | ✅ green |
| 18-09-01 | 09 | 3 | AGE-18-01, CONSENT-18-01 | — | shared components per UI-SPEC | unit + build | see plan | ❌ | ✅ green |
| 18-09-02 | 09 | 3 | AGE-18-01, CONSENT-18-01 | T-18-17 | root gate; nothing rendered behind it; no request before Continue; analytics choice starts with nothing selected and the Recommended label on Basic only (D-06f) | UI | `-only-testing:EhPandaUITests/FirstLaunchUITests` | ❌ | ✅ green |
| 18-09-03 | 09 | 3 | AGE-18-01, CONSENT-18-01 | — | C-3 title rule, 6 locales × default/AX5, both devices | UI + screenshot review | `-only-testing:EhPandaUITests/FirstLaunchTitleLayoutUITests` | ❌ | ✅ green |
| 18-10-01 | 10 | 3 | CONSENT-18-01 | T-18-18 | picker writes the level and calls `apply` from the reducer | unit | `-only-testing:SettingFeatureTests` | ✅ extend | ✅ green |
| 18-10-02 | 10 | 3 | UGC-18-01 | — | Blocked Users push, list, unblock, empty state | unit + UI | `-only-testing:SettingFeatureTests`, `-only-testing:EhPandaUITests/SettingsModerationUITests` | ❌ | ✅ green |
| 18-10-03 | 10 | 3 | UGC-18-01 | — | C-3 title rule on the empty-state title | UI + screenshot review | `-only-testing:EhPandaUITests/BlockedUsersTitleLayoutUITests` | ❌ | ✅ green |
| 18-11-01 | 11 | 3 | UGC-18-01 | T-18-19 | report sheet non-persistent, cookies before load, host only; post intent | unit | `-only-testing:DetailFeatureTests` | ❌ | ✅ green |
| 18-11-02 | 11 | 3 | UGC-18-01 | T-18-20 | menu items; collapsed row carries no author | unit | `-only-testing:DetailFeatureTests/BlockedCommentPresentationTests` | ❌ | ✅ green |
| 18-11-03 | 11 | 3 | UGC-18-01 | — | strip without drawing group; collapsed card size | unit | `-only-testing:DetailFeatureTests/CommentCardLayoutTests` | ✅ extend | ✅ green |
| 18-11-04 | 11 | 3 | UGC-18-01 | T-18-20 | menus, a11y actions, alerts, collapsed rows and cards, warning | UI | `-only-testing:EhPandaUITests/CommentModerationUITests` | ❌ | ✅ green |
| 18-12-01 | 12 | 4 | CONSENT-18-01 | T-18-22 | READMEs quote the three levels verbatim (Revision 6 Basic/Full); no off-completely claim | script | `python3 .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py --readmes` | ❌ | ✅ green |
| 18-12-02 | 12 | 4 | all | T-18-23 | full gate on both devices; Release scan | all | see plan | ✅ | ✅ green |
| 18-12-03 | 12 | 4 | UGC-18-01 | — | live report page loads signed in; after Log Out the site's guest page (verified by an agent per owner rule msg 1652, 2026-11-05 17:51Z) | manual | checkpoint | — | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Test-first tasks inside their plans (no separate Wave 0 plan; no framework install):

- [x] `AppPackage/Tests/AppModelsTests/SettingFirstLaunchFieldsTests.swift` — AGE-18-01, CONSENT-18-01 storage (18-02 T1)
- [x] `AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift` — AGE-18-01 gate (18-02 T2)
- [x] `AppPackage/Tests/AnalyticsClientTests/AnalyticsLevelGateTests.swift` — CONSENT-18-01 (18-03 T1)
- [x] `AppPackage/Tests/DetailFeatureTests/CommentFilterTests.swift`, `CommentReportTargetTests.swift`,
      `AppPackage/Tests/AppModelsTests/BlockedCommentUserTests.swift` — UGC-18-01 core (18-04 T1)
- [x] `AppPackage/Tests/ReadingFeatureTests/ReaderPositionTests.swift` — reader rework (18-07 T1)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The report page opens on the live site and its form accepts a report | UGC-18-01 | needs the live site and an account; the agent must not submit a real report | 18-12 Task 3 (owner checkpoint): open the report page from a comment on a simulator signed in by the owner, confirm the page loads signed in, do **not** submit; any screenshot stays local. **Result (18-12, verified by an agent per owner rule msg 1652, 2026-11-05 17:51Z, Debug build on `$PHONE`):** the sheet loaded the signed-in report form (no ad banner, "Multi-Page Viewer" link present); after Log Out it loaded the site's guest page (ad banner, no "Multi-Page Viewer", no session) rather than a sign-in prompt, which the site does not show there (18-12-SUMMARY deviation 9). Nothing selected or submitted |
| No network request before the age wall on a fresh install (end to end, beyond the stubbed sessions) | AGE-18-01 | `FirstLaunchUITests` (18-09) proves it for every request that reaches `UITestStubURLProtocol` (a DEBUG request log, `EHPANDA_UITEST_REQUEST_LOG`); sessions that do not route through the stub protocol are covered only by the reducer gate tests | 18-12 Task 2: agent-run once on `$PHONE` with a fresh install and the live network; observe with `log stream --predicate 'subsystem == "com.apple.network"'` for the app's process until Continue; record the result in 18-12's summary. **Result (18-12, Release build, fresh install on a clone of `$PHONE`):** 30 s at the age wall with Continue disabled: no socket (`lsof -i` each second), and `com.apple.network`/`com.apple.CFNetwork` logged only launch activities and cookie-store setup, with no connection, task or DNS lookup |
| iPad two-page spread page sync | reader | known limit (DD-03) | not tested; recorded |
| Title last line never a single word (UI-SPEC C-3, owner msg 1822) | AGE-18-01, CONSENT-18-01, UGC-18-01 | a line-break judgement on rendered text; the tests only capture | 18-09 Task 3 and 18-10 Task 3: review the exported screenshots (6 locales × default/AX5 × `$PHONE`/`$PAD`) and record a table in the summary |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 300 s for module runs
- [x] `nyquist_compliant: true` set in frontmatter (set by 18-12 after the gate)

**Approval:** pending
