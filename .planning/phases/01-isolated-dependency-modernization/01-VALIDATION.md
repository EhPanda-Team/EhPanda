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
| **Quick run command** | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` |
| **Full suite command** | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` |
| **Confirmed simulator** | iPhone Air, iOS 26.5, id `ADE09605-A44E-4F00-BE12-235970217355` |
| **Estimated runtime** | TBD after first clean run on the confirmed simulator |

---

## Sampling Rate

- **After every task commit:** Run the complete `Automated Command` from the corresponding `Per-Task Verification Map` row.
- **After every plan wave:** Run the `Full suite command` from `Test Infrastructure`.
- **Before `$gsd-verify-work`:** Run the `Full suite command` from `Test Infrastructure`; it must be green.
- **Max feedback latency:** TBD after Wave 0 establishes targeted test runtimes.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-W0-01 | 01-01 | 0 | DEP-01 | - | N/A | unit/integration | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:SwiftyOpenCCTests -only-testing:FileClientTests` | No - 01-01 creates `AppPackage/Tests/SwiftyOpenCCTests` and a focused FileClient fixture | pending |
| 01-W0-02 | 01-01 | 0 | DEP-02 | - | N/A | unit | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:UIImageColorsTests` | No - 01-01 creates `AppPackage/Tests/UIImageColorsTests` | pending |
| 01-W0-03 | 01-02 | 1 | DEP-03 | T-01-02-01 | Markdown image URL handling stays structured and fixture-locked | unit/integration | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:MarkdownExtTests -only-testing:TagTranslationFeatureTests` | No - 01-02 creates `MarkdownExtTests` and `TagTranslationFeatureTests` with real source files before registration | pending |
| 01-W0-04 | 01-02 | 1 | DEP-06 | T-01-02-02 | Host header, cookies, body, redirects, and original-domain trust semantics are preserved | unit plus manual technical verification | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:NetworkingFeatureTests` | Partial - existing target lacks `DFRequestSemanticsTests.swift` until 01-02 | pending |
| 01-W0-05 | 01-07 | 6 | DEP-07 | T-01-07-03 | N/A | build plus manual visual UAT | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` | No stable automated UI visual test; manual verification required | pending |

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/SwiftyOpenCCTests` - fixture-lock DEP-01 converter parity for default, HK/TW, and custom conversion cases.
- [ ] Focused `FileClientTests` fixture - verify app-level `TagTranslation` conversion behavior remains unchanged.
- [ ] `AppPackage/Tests/UIImageColorsTests` - deterministic image fixtures for DEP-02 background/primary/secondary/detail parity.
- [ ] `AppPackage/Tests/MarkdownExtTests` - swift-markdown adapter parity for `parseTexts`, `parseLinks`, and `parseImages`.
- [ ] `AppPackage/Tests/TagTranslationFeatureTests` - app-level markdown-derived `TagTranslation` coverage if `MarkdownExtTests` alone does not prove the feature boundary.
- [ ] `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` - DEP-06 technical semantics for host replacement, headers/cookies/body preservation, redirects, and trust-host selection.
- [x] Confirmed simulator destination: `platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355` (iPhone Air, iOS 26.5), verified with `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| UIImageColors visual parity | DEP-02 | Automated tests can compare deterministic color tuples, but subjective visual quality belongs to user verification. | Compare representative gallery cards before and after the local module swap and confirm dominant colors still support readable, expected cards. |
| Colorful animated gradient parity | DEP-07 | Animated gradient appearance is visual and may be affected by latest Colorful API adoption. | Open Home gallery cards after the latest Colorful update; confirm animated gradient concept and fallback colors match the pre-phase behavior closely enough. |
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
