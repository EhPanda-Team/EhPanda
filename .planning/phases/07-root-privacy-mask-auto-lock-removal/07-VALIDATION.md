---
phase: 7
slug: root-privacy-mask-auto-lock-removal
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-14
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 07-RESEARCH.md § Validation Architecture. This phase is **mostly deletion/rename at parity** — it deletes more test surface than it adds. Only one behavior (the D-05/D-06 scenePhase→shared-blur fold) is non-mechanical; everything else is manual parity/UAT.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (not XCTest) |
| **Config file** | `AppPackage/Package.swift` test targets; `AppPackage/Tests/FeatureTests.xctestplan` (bound to the app scheme, not the package scheme) |
| **Quick run command** | `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` (also runs the SwiftLint build plugin) |
| **Full suite command** | `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` |
| **Estimated runtime** | build ~1–3 min; full suite ~431 tests / 88 suites (do not pass `-testPlan FeatureTests` to the package scheme; `-only-testing` does not filter — run the whole action) |

---

## Sampling Rate

- **After every task commit:** Build the affected module scheme (`AppFeature` builds the whole graph and runs SwiftLint). A warning-free build ⇒ lint clean.
- **After every plan wave:** Run the full `AppPackage-Package` suite — it must stay green (regression guard; this phase must not break the existing ~431 tests).
- **Before `/gsd-verify-work`:** Full suite green + the manual parity checks below completed.
- **Max feedback latency:** ~3 min (module build); full suite as a wave gate.

---

## Per-Task Verification Map

> Task IDs (`7-NN-MM`) are assigned by the planner. This phase's automated surface is small — most tasks are verified by **build-green + grep-absence** assertions (dead code / dead l10n removed) plus the full-suite regression guard, not new unit tests. Populate concrete task rows after PLAN.md files exist.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 7-NN-MM (scenePhase fold) | TBD | TBD | UIARCH-04 | — | `.inactive` → `@Shared(.privacyMaskBlur)` = `privacyMaskIntensity`; `.active` → `0`; re-homed `fetchGreeting`/`detectClipboardURL` fire exactly-once | unit (TestStore) | `xcodebuild test -scheme AppPackage-Package …` | ❌ W0 (no AppFeatureTests target) | ⬜ pending |
| 7-NN-MM (dead-code/l10n removal) | TBD | TBD | UIARCH-05 | — | AuthorizationClient / AutoLockPolicy / auto-lock l10n keys absent from tree | grep-absence + build-green | `grep -r AuthorizationClient AppPackage/Sources \| wc -l` = 0; build succeeds | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

The single recommended unit test (the scenePhase→shared-blur fold, protecting Pitfall 1's launch greeting/clipboard exactly-once concern) has **no home target today**:

- [ ] **Decision (planner):** There is **no `AppFeatureTests` target** (verified — 13 test targets exist: AppModels, Detail, Downloads, FileClient, GalleryListComponents, ImageColors, MarkdownExt, Networking, Parser, Reading, Setting, SwiftyOpenCC, TagTranslation). Adding the scenePhase `TestStore` test requires standing up a new `AppFeatureTests` target in `Package.swift` (raises cost). Weigh this against the manual scenePhase check. The feature-test pattern already exists (e.g. `SettingFeatureTests`) to copy.
- [ ] If the planner elects the test: add `AppPackage/Tests/AppFeatureTests/` + the `Package.swift` `.testTarget` + register it so `AppPackage-Package` picks it up.
- [ ] No other test-infrastructure gaps — this phase deletes more than it adds.

*If the planner declines the new target: "The scenePhase fold is verified manually (see Manual-Only) — no Wave 0 test infrastructure required."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No content leak in App Switcher / when backgrounded, across **all 40 mask sites** | UIARCH-04 (D-16) | Visual, per-surface; not cheaply automatable | Background the app from each of the 40 root/modal surfaces (app root + 39 sheet/cover roots incl. the newly-masked AppActivityLogs run-picker) → confirm the App Switcher snapshot is blurred |
| NavigationBar does not collapse at blur `0` | UIARCH-04 (D-03) | Visual regression of a removed workaround | On a large-title NavigationBar screen, background→foreground the app; confirm the bar returns intact when blur → `0` (no `max(0.00001, …)` floor) |
| Auto-lock control gone from General; Privacy Mask control present under tint-color in Appearance with label + footer | UIARCH-05 (D-09/D-10) | Visual/UX placement check | General settings has no Security section / auto-lock Picker; Appearance settings shows a "Privacy Mask" slider under the tint-color row with an explanatory footer |
| Info.plist has no orphaned `NSFaceIDUsageDescription` | UIARCH-05 (D-15) | One-time hygiene grep during execution | Grep the app target Info.plist; remove the key if it existed solely for the removed biometric flow |
| Launch greeting fires once; clipboard detection fires exactly once at cold launch | UIARCH-04 (D-06, Pitfall 1) | Cross-path ordering; best traced live | On cold launch confirm the greeting appears and the clipboard-URL prompt does not double-fire (the `.unlockApp` cascade + `loadUserSettingsDone` both touched `detectClipboardURL`) |

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` verify (build-green / grep-absence / regression suite) or an explicit Manual-Only entry
- [ ] Sampling continuity: no 3 consecutive tasks without an automated verify (build-green counts)
- [ ] Wave 0 covers the AppFeatureTests-target decision (create, or accept manual verification)
- [ ] No watch-mode flags
- [ ] Feedback latency < ~180s (module build)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
