---
phase: 14
slug: analytics-instrumentation-with-telemetrydeck-add-privacy-fir
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-24
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `14-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Suite` / `@Test`) + TCA `TestStore` |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` |
| **Quick run command** | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:AnalyticsClientTests` |
| **Full suite command** | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` |
| **Estimated runtime** | ~{N} seconds (measure at Wave 0) |

> ⚠ **Registration hazard.** A new test target must be registered in
> `AppPackage/Tests/FeatureTests.xctestplan` — an unregistered target runs zero tests and looks green.
> There is no `AppPackage-Package` scheme; the `EhPanda` scheme is what runs the whole
> `AppPackage` graph.
>
> *Correction to `14-RESEARCH.md`:* research states a new target must **also** be registered in the
> `EhPanda` scheme. Verified false — `EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme`
> contains **zero** `TestableReference` entries; its `<TestAction>` holds only two
> `<TestPlanReference>`s, and `CookieClientTests` is registered in the xctestplan today
> (`FeatureTests.xctestplan:130`). The xctestplan is the **sole** registration surface; there is no
> separate scheme edit to make.

---

## Sampling Rate

- **After every task commit:** `xcodebuild test … -only-testing:<target touched by the task>`
- **After every plan wave:** full `EhPanda` scheme test run
- **Before `/gsd-verify-work`:** full suite green through the `EhPanda` scheme
- **Max feedback latency:** {N} seconds (set at Wave 0)

---

## Per-Task Verification Map

*Populated by `/gsd-validate-phase` once PLAN.md task IDs exist. Behaviors below come from
`14-RESEARCH.md` §Validation Architecture and are the rows this map must cover.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | D-09 | — | `AnalyticsSignal` renders stable names + parameter keys for every case | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsSignalRenderingTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-06 / D-09 | T-14-01 | No rendered parameter value can be a free-form `String` (exhaustive over all cases) | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsSignalRenderingTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-08 | T-14-02 | Bucket boundaries map correctly at every edge | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/BucketTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-13 | T-14-03 | `liveValue` resolves to `.noop` when the app ID is absent | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsClientGateTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-11 | — | Default-parameter closure reflects a *changed* setting, not an init-time snapshot | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsDefaultParametersTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-14 | — | Each instrumented reducer action emits exactly the expected signal | unit (`TestStore` + `LockIsolated` spy) | per existing feature test target | ❌ per-target | ⬜ pending |
| TBD | TBD | TBD | D-14 | — | No signal emitted on non-instrumented actions | structural | covered by `testValue = .unimplemented` | ✅ free | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/AnalyticsClientTests/` — new test target (declare in `Package.swift` `Module` enum + `targets`, with `plugins: swiftLintPlugins`)
- [ ] Register the new target in `AppPackage/Tests/FeatureTests.xctestplan` **and** the `EhPanda` scheme
- [ ] `AppPackage/Sources/AnalyticsClient/.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`
- [ ] Decide and implement the `.noop` override strategy for existing suites — `testValue = .unimplemented` (locked by D-12) means instrumenting a reducer breaks its existing tests; research counted **127 `TestStore(` sites across 6 targets**, `DownloadsFeatureTests` alone carrying 75
- [ ] Make `AnalyticsSignal: Equatable` so `TestStore` spies can assert on associated values

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Signals actually arrive in the TelemetryDeck dashboard | D-10 | Requires a real app ID and the vendor's ingestion endpoint; not reachable from a test target | Build with `Analytics.local.xcconfig` present, exercise one instrumented flow, confirm the signal appears in the TelemetryDeck web console |
| A build with **no** app ID ships zero network traffic | D-13 | Negative network assertion is not expressible in the unit suite | Clean-clone build (no `Analytics.local.xcconfig`), run under Charles/Proxyman, confirm no requests to `nom.telemetrydeck.com` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < {N}s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
