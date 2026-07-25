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
| **Measured runtime** | ~76 seconds, full app scheme, 765 tests (measured 2026-07-25 at 14-18) |

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

- **After every task commit:** `xcodebuild test … -only-testing:<target touched by the task>`, narrowed to `-only-testing:<Target>/<Suite>` where the task owns a single suite. Tasks that instrument an existing reducer stay at target granularity on purpose: the point of that run is to prove the target's *pre-existing* suites survived the instrumentation, which a suite-scoped filter would not show.
- **After every plan wave:** full `EhPanda` scheme test run
- **Before `/gsd-verify-work`:** full suite green through the `EhPanda` scheme
- **Max feedback latency:** 76 seconds (full suite; a single-target filter returns in ~25-50s)

---

## Per-Task Verification Map

*Populated by `/gsd-validate-phase` once PLAN.md task IDs exist. Behaviors below come from
`14-RESEARCH.md` §Validation Architecture and are the rows this map must cover.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-05 T2 | 14-05 | 3 | D-09 | — | `AnalyticsSignal` renders stable names + parameter keys for every case | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsSignalRenderingTests` | ✅ | ✅ green |
| 14-05 T3 | 14-05 | 3 | D-06 / D-09 | T-14-01 | No rendered parameter value can be a free-form `String`; reserved-key collision sweep over all 13 cases | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsSignalRenderingTests` | ✅ | ✅ green |
| 14-01 T3 | 14-01 | 1 | D-08 | T-14-02 | Bucket boundaries map correctly at every edge | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/BucketTests` | ✅ | ✅ green |
| 14-06 T3 | 14-06 | 4 | D-13 | T-14-03 | `liveValue` resolves to `.noop` when the app ID is absent | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsClientGateTests` | ✅ | ✅ green |
| 14-06 T1 | 14-06 | 4 | D-11 | — | Default-parameter closure reflects a *changed* setting, not an init-time snapshot | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AnalyticsDefaultParametersTests` | ✅ | ✅ green |
| 14-03 T2 | 14-03 | 2 | D-06 / D-16 / D-19 | T-14-01 | `TagNamespaceCounts` / `SearchShape` retain no content; sentinel survives nowhere in the reflected graph | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/TagNamespaceCountsTests -only-testing:AnalyticsClientTests/SearchShapeTests` | ✅ | ✅ green |
| 14-03 T3 | 14-03 | 2 | D-09 | T-14-01 | `AppErrorKind` mirrors all 15 `AppError` cases with no catch-all and stores no `String` | unit | `xcodebuild test … -only-testing:AnalyticsClientTests/AppErrorKindTests` | ✅ | ✅ green |
| 14-04 T3 | 14-04 | 2 | D-13 / D-17 | T-14-03 | Absent app ID and salt resolve to nil under the test host; substitution proven against the **built** Info.plist | unit | `xcodebuild test … -only-testing:AppModelsTests/AppInfoAnalyticsTests` | ✅ | ✅ green |
| 14-07/08/09 | 14-07…09 | 5 | D-12 | T-14-03 / T-14-12 | All 107 pre-existing `TestStore` sites resolve analytics to `.noop`; proven per target by a temporary real emission | unit | `xcodebuild test … -only-testing:<each hardened target>` | ✅ | ✅ green |
| 14-10 T3 | 14-10 | 6 | D-14 / D-05 | T-14-01 / T-14-13 | Tab open, modal gallery detail, user-visible error emit once; re-tap, caption-only toast and error drill-down emit nothing | unit (`TestStore` + `LockIsolated` spy) | `xcodebuild test … -only-testing:AppFeatureTests/AnalyticsEmissionTests` | ✅ | ✅ green |
| 14-11 T3 | 14-11 | 6 | D-14 / D-05 | T-14-01 / T-14-14 | All five Home sections sweep `allCases`; gallery-detail push emits the shared payload | unit | `xcodebuild test … -only-testing:HomeFeatureTests/AnalyticsEmissionTests` | ✅ | ✅ green |
| 14-12 T3 | 14-12 | 6 | D-06 / D-07 | T-14-01 / T-14-15 | Performed search emits a `SearchShape`; the sentinel keyword survives nowhere; the raw-keyword history action emits nothing | unit | `xcodebuild test … -only-testing:SearchFeatureTests -only-testing:FavoritesFeatureTests` | ✅ | ✅ green |
| 14-13 T3 | 14-13 | 6 | D-06 / D-07 | T-14-01 / T-14-16 | Tag tap emits the namespace and forwards the keyword in one assertion; download failure arms emit nothing | unit | `xcodebuild test … -only-testing:DetailFeatureTests/AnalyticsEmissionTests` | ✅ | ✅ green |
| 14-14 T2 | 14-14 | 6 | D-08 / D-11 | T-14-01 / T-14-02 | One bucketed session signal at dismissal; scrubbing does not inflate pages; four duration boundaries | unit (frozen clock) | `xcodebuild test … -only-testing:ReadingFeatureTests/AnalyticsEmissionTests` | ✅ | ✅ green |
| 14-15 T3 | 14-15 | 6 | D-05 | T-14-13 | Edge-triggered outcomes; a cold start emits nothing; repeated identical snapshots emit once | unit (pure + store) | `xcodebuild test … -only-testing:DownloadsFeatureTests/AnalyticsEmissionTests` | ✅ | ✅ green |
| 14-16 T2 | 14-16 | 6 | D-05 | T-14-01 / T-14-13 | Login failures classify by kind; sentinel credentials survive nowhere; the generic error signal never accompanies them | unit | `xcodebuild test … -only-testing:SettingFeatureTests/AnalyticsEmissionTests` | ✅ | ✅ green |
| 14-17 T3 | 14-17 | 7 | D-12 / D-18 | T-14-01 | Only `AnalyticsClient` may import the SDK — enforced by lint at error severity, proven to fire | static (lint) | `swiftlint lint --config .swiftlint.yml` (build-plugin enforced) | ✅ | ✅ green |
| — | — | 6 | D-14 | — | No signal emitted on non-instrumented actions | structural | covered by `testValue = .unimplemented` | ✅ free | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `AppPackage/Tests/AnalyticsClientTests/` — new test target (declared in `Package.swift` `Module` enum + `targets`, with `plugins: swiftLintPlugins`) — plan 14-01
- [x] Register the new targets in `AppPackage/Tests/FeatureTests.xctestplan` — the **sole** registration surface. The scheme holds no testable references, so no `EhPanda.xcscheme` edit is required or possible; the earlier claim that one was needed came from research and is false (corrected at 14-18).
- [x] `AppPackage/Sources/AnalyticsClient/.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml` — plan 14-01
- [x] `.noop` override strategy implemented for existing suites — `testValue = .unimplemented` (D-12) meant instrumenting a reducer would break its existing tests. Wave 5 (plans 14-07/08/09) hardened **107 real `TestStore` sites across 6 targets** ahead of instrumentation, each target proven by a temporary real emission. (Research's 127 was a raw substring count; 55 of the 75 attributed to `DownloadsFeatureTests` were real initializers and 20 were factory calls routing through them.)
- [x] `AnalyticsSignal: Equatable` so `TestStore` spies can assert on associated values — plan 14-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Behavior | Requirement | Why Manual | Status |
|----------|-------------|------------|--------|
| Signals actually arrive in the TelemetryDeck dashboard | D-10 | Requires a real app ID and the vendor's ingestion endpoint; not reachable from a test target | ⬜ **pending owner** — Check B in plan 14-18 Task 2; blocked on the owner creating `Config/Analytics.local.xcconfig` per `14-USER-SETUP.md` |
| A build with **no** app ID ships zero network traffic | D-13 | Negative network assertion is not expressible in the unit suite | ⬜ **pending owner** — Check A in plan 14-18 Task 2; requires a network inspection proxy |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 76s (full suite; single-target filters ~25-50s)
- [ ] `nyquist_compliant: true` set in frontmatter — **held pending the two owner checks below**

## Whole-Phase Static Verification (14-18 Task 1, 2026-07-25)

| Check | Result |
|-------|--------|
| Full app-scheme run | ✅ **TEST SUCCEEDED** — 765 tests, 0 failures, ~76s |
| `AnalyticsClientTests` executed | ✅ all 8 suites ran; `AnalyticsClientGateTests` passed *with 2 known issues*, which are the deliberate `withKnownIssue` assertions proving the unimplemented client reports rather than crashes |
| `SearchFeatureTests` executed | ✅ 10 tests (its `AnalyticsEmissionTests` suite ran by name) |
| `FavoritesFeatureTests` executed | ✅ 3 tests (its `AnalyticsEmissionTests` suite ran by name) |
| Exactly one SDK import | ✅ `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift`, and nowhere else |
| No deprecated `TelemetryManager` spelling | ✅ 0 occurrences |
| No suppression directive added during the phase | ✅ `git diff 26425c1b..HEAD -- '*.swift'` adds 0 `swiftlint:disable` lines (the 27 elsewhere in the repo predate the phase and were not touched) |
| Clean build warnings | ✅ 0 code warnings; the single log line is `appintentsmetadataprocessor` noting no AppIntents dependency, which is not a code warning |
| SDK pin is a 2.x stable tag | ✅ TelemetryDeck/SwiftSDK **2.14.1**, no pre-release suffix |

**Approval:** ⬜ **pending owner** — every automated and static check passes. The two manual-only rows above (Checks A and B of plan 14-18 Task 2) are the remaining gate; the phase is not verified until the owner runs them.
