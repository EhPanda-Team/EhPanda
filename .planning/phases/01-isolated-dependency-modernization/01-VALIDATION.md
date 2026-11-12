---
phase: 01
slug: isolated-dependency-modernization
status: draft
nyquist_compliant: true
wave_0_complete: true
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
| **Quick run command** | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` |
| **Full suite command** | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` |
| **Confirmed simulator** | iPhone Air, iOS 26.5, id `ADE09605-A44E-4F00-BE12-235970217355` |
| **Destination syntax** | `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` |
| **Estimated runtime** | Wave 0 targeted run (SwiftyOpenCC + UIImageColors + FileClient): ~1s of test execution after a clean build |

> Re-confirmed 2026-07-10 via `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations`: the list includes `{ platform:iOS Simulator, arch:arm64, id:ADE09605-A44E-4F00-BE12-235970217355, OS:26.5, name:iPhone Air }`. All later plans use the id-based destination syntax above.
>
> **Command correction (2026-07-10, plan 01-01):** The `FeatureTests` test plan is associated with the app's `EhPanda` shared scheme (`EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme`), not the auto-generated SwiftPM `AppPackage-Package` scheme. Passing `-testPlan FeatureTests` to `-scheme AppPackage-Package` fails with "Scheme does not have an associated test plan named FeatureTests". The `AppPackage-Package` scheme already includes every package test target by default, so the `-testPlan FeatureTests` flag was removed from all commands here; `-only-testing:` filters select the specific targets. The `FeatureTests.xctestplan` file still drives the `EhPanda` scheme and is kept in sync with the new test targets.

---

## Sampling Rate

- **After every task commit:** Run the complete `Automated Command` from the corresponding `Per-Task Verification Map` row.
- **After every plan wave:** Run the `Full suite command` from `Test Infrastructure`.
- **Before `$gsd-verify-work`:** Run the `Full suite command` from `Test Infrastructure`; it must be green.
- **Max feedback latency:** ~10s wall for a targeted Wave 0 run (incremental build ~9s + <0.1s pure test execution); a clean rebuild is ~25-30s. Pure `xcodebuild` test execution for all Wave 0 targets is under 0.1s.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-W0-01 | 01-01 | 0 | DEP-01 | - | N/A | unit/integration | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:SwiftyOpenCCTests -only-testing:FileClientTests` | Yes | passed 2026-07-10 |
| 01-W0-02 | 01-01 | 0 | DEP-02 | - | N/A | unit | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:UIImageColorsTests` | Yes | passed 2026-07-10 |
| 01-W0-03 | 01-02 | 1 | DEP-03 | T-01-02-01 | Markdown image URL handling stays structured and fixture-locked | unit/integration | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:MarkdownExtTests -only-testing:TagTranslationFeatureTests` | Yes | passed 2026-07-10 |
| 01-W0-04 | 01-02 | 1 | DEP-06 | T-01-02-02 | Host header, cookies, body, redirects, and original-domain trust semantics are preserved | unit plus manual technical verification | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:NetworkingFeatureTests` | Yes | passed 2026-07-10 |
| 01-W0-05 | 01-07 | 6 | DEP-07 | T-01-07-03 | N/A | build plus manual visual UAT | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` | No stable automated UI visual test; manual verification required | pending |

---

## Wave 0 Requirements

- [x] `AppPackage/Tests/SwiftyOpenCCTests` - fixture-lock DEP-01 converter parity for default, HK/TW, and custom conversion cases.
- [x] Focused `FileClientTests` fixture - verify app-level `TagTranslation` conversion behavior remains unchanged.
- [x] `AppPackage/Tests/UIImageColorsTests` - deterministic image fixtures for DEP-02 background/primary/secondary/detail parity.
- [x] `AppPackage/Tests/MarkdownExtTests` - Wave 0 parity for `parseTexts`, `parseLinks`, and `parseImages` against the current `CommonMarkExt.MarkdownUtil` (later retargeted to `MarkdownExt`).
- [x] `AppPackage/Tests/TagTranslationFeatureTests` - app-level markdown-derived `TagTranslation` coverage (`displayValue`, `valueImageURL`, description text/images, `links`).
- [x] `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` - DEP-06 technical semantics for host replacement, header/cookie/body preservation, and original-domain recovery for redirects and trust-host selection.
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

- [x] All tasks have automated verify steps or explicit Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency is recorded after first targeted and full-suite runs.
- [x] `nyquist_compliant: true` set in frontmatter after Wave 0 and sampling map are complete.

**Approval:** Wave 0 complete (plans 01-01 and 01-02) — DEP-01, DEP-02, DEP-03, and DEP-06 baselines locked on 2026-07-10.
