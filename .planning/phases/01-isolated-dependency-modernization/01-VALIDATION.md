---
phase: 01
slug: isolated-dependency-modernization
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 01 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing on Swift 6.3.3 |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` |
| **Quick run command** | `xcodebuild -project EhPanda.xcodeproj -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' test` |
| **Full suite command** | `xcodebuild -project EhPanda.xcodeproj -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' test` |
| **Estimated runtime** | TBD after `xcodebuild -showdestinations` and first clean run |

---

## Sampling Rate

- **After every task commit:** Run the targeted `xcodebuild ... -only-testing:<target>` command for the touched seam when available.
- **After every plan wave:** Run the full `FeatureTests` test plan.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** TBD after Wave 0 establishes targeted test runtimes.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-W0-01 | TBD | 0 | DEP-01 | - | N/A | unit/integration | `xcodebuild ... -only-testing:SwiftyOpenCCTests test` and targeted `FileClientTests` | No - W0 creates `AppPackage/Tests/SwiftyOpenCCTests` and a focused FileClient fixture | pending |
| 01-W0-02 | TBD | 0 | DEP-02 | - | N/A | unit | `xcodebuild ... -only-testing:UIImageColorsTests test` | No - W0 creates `AppPackage/Tests/UIImageColorsTests` | pending |
| 01-W0-03 | TBD | 0 | DEP-03 | T-01 | Markdown image URL handling stays structured and fixture-locked | unit/integration | `xcodebuild ... -only-testing:MarkdownExtTests test -only-testing:TagTranslationFeatureTests test` | No - W0 creates `MarkdownExtTests`; TagTranslation coverage may need a new target | pending |
| 01-W0-04 | TBD | 0 | DEP-06 | T-02 | Host header, cookies, body, redirects, and original-domain trust semantics are preserved | unit plus manual technical verification | `xcodebuild ... -only-testing:NetworkingFeatureTests test` | Partial - existing target lacks `DFRequestSemanticsTests.swift` | pending |
| 01-W0-05 | TBD | 0 | DEP-07 | - | N/A | build plus manual visual UAT | Full `FeatureTests` command after package resolution | No stable automated UI visual test; manual verification required | pending |

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/SwiftyOpenCCTests` - fixture-lock DEP-01 converter parity for default, HK/TW, and custom conversion cases.
- [ ] Focused `FileClientTests` fixture - verify app-level `TagTranslation` conversion behavior remains unchanged.
- [ ] `AppPackage/Tests/UIImageColorsTests` - deterministic image fixtures for DEP-02 background/primary/secondary/detail parity.
- [ ] `AppPackage/Tests/MarkdownExtTests` - swift-markdown adapter parity for `parseTexts`, `parseLinks`, and `parseImages`.
- [ ] `AppPackage/Tests/TagTranslationFeatureTests` - app-level markdown-derived `TagTranslation` coverage if `MarkdownExtTests` alone does not prove the feature boundary.
- [ ] `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` - DEP-06 technical semantics for host replacement, headers/cookies/body preservation, redirects, and trust-host selection.
- [ ] Confirm simulator destination with `xcodebuild -showdestinations` before hard-coding final execution commands.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| UIImageColors visual parity | DEP-02 | Automated tests can compare deterministic color tuples, but subjective visual quality belongs to user verification. | Compare representative gallery cards before and after the local module swap and confirm dominant colors still support readable, expected cards. |
| Colorful animated gradient parity | DEP-07 | Animated gradient appearance is visual and may be affected by upstream deprecation or fallback implementation. | Open Home gallery cards after the Colorful update or fallback implementation; confirm animated gradient concept and fallback colors match the pre-phase behavior closely enough. |
| Domain-fronting real-world behavior | DEP-06 | Local E2E proof is not possible without the relevant China/SNI filtering conditions. | If a non-deprecated replacement is implemented, collect user-arranged tester confirmation from China; if not viable, retain the current path and document D-12/D-13 skip evidence. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify steps or explicit Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency is recorded after first targeted and full-suite runs.
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 and sampling map are complete.

**Approval:** pending
