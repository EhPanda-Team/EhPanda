---
phase: 8
slug: architecture-hygiene-client-seams
status: partial
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-14
audited: 2026-07-14
requirements:
  HYG-01: partial
  QUAL-01: partial
  QUAL-02: covered
---

# Phase 8 — Validation Strategy

> Retrospective Nyquist audit of all 14 plans, their summaries, the resulting source,
> the executable cookie gate, and the actual test files. This phase is a
> behavior/appearance-parity refactor: a green build proves compile completeness, but
> reducer completion races and dependency substitution require behavioral tests.

## Audit Result

**PARTIAL.** The phase build and all executed suites are green, and the dedicated
`CookieClientTests` and `ImageClientTests` contain substantive deterministic coverage.
Six validation gaps remain. Three expose confirmed implementation defects, two are
missing adversarial or identity coverage, and one is canonical test-plan wiring.

| Classification | Count |
|----------------|------:|
| Task rows audited | 28 |
| Covered task rows | 22 |
| Partial task rows | 6 |
| Confirmed implementation defects | 3 |
| Missing regression/enforcement coverage | 3 |

No test or implementation file was changed by this audit. The gap plan must be approved
before a Nyquist auditor writes tests; implementation defects must be fixed by the phase
executor, not hidden by weakening assertions.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) + TCA `TestStore` / `withDependencies` |
| **Canonical config** | `AppPackage/Tests/FeatureTests.xctestplan`, driven by the shared `EhPanda` scheme |
| **Build gate** | `xcodebuild -quiet -project EhPanda.xcodeproj -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build` |
| **Canonical feature suite** | `xcodebuild -quiet -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' test` |
| **Focused target (once listed in the plan)** | Append `-only-testing:<TargetName>` to the canonical feature-suite command |
| **Static privacy gate** | `./Scripts/check-cookie-logging.sh` |
| **Lint gate** | SwiftLint build-tool plugins run as part of the build; no suppressions permitted |

> **Machine constraint:** never overlap `xcodebuild` invocations. The fresh post-Wave-14
> evidence already records a warning-free app build, green canonical FeatureTests, green
> full AppPackage suite, green SwiftLint, and a passing cookie gate. This audit did not
> start another build or test run.

### Canonical Plan Caveat

`CookieClientTests` and `ImageClientTests` both pass in the separately executed full
AppPackage suite, but neither target is listed in `FeatureTests.xctestplan`. Therefore the
canonical `EhPanda`/`FeatureTests` command does not run the two Phase-8 seam suites. This is
a wiring gap, not a claim that either suite currently fails.

## Requirement Coverage

| Req ID | Status | Verified evidence | Remaining gap |
|--------|--------|-------------------|---------------|
| HYG-01 | **PARTIAL** | Targeted utility/global-host absence sweeps pass; the app builds; full suites pass; all intended utility deletions and explicit-host request APIs exist. | Two host-snapshot completion defects, a non-injectable UserDefaults read, and missing DataCache prefetch/purge identity coverage. |
| QUAL-01 | **PARTIAL** | Planning scope is reconciled; `Scripts/check-cookie-logging.sh` passes on the current source and constrains `getCookiesDescription` to its clipboard consumer. | The scanner follows fixed identifier and receiver names, so an aliased cookie value or renamed `Logger` receiver can evade it. |
| QUAL-02 | **COVERED** | Networking tests exercise async requests, retries, parsing, and explicit-host URLs; CookieClient and ImageClient suites are deterministic and green in the full AppPackage suite. | Canonical FeatureTests wiring remains GAP-06 hardening, but does not negate the requirement's current green full-suite evidence. |

## Phase Requirements → Test Map

| Req ID | Behavior | Type | Automated evidence | Status |
|--------|----------|------|--------------------|--------|
| HYG-01 | Targeted side-effecting Utils/globals deleted; retained URL/File/Markdown helpers are pure namespaces | build + static | App build; targeted `rg` absence audit | **COVERED** |
| HYG-01 | Host-taking request builders preserve E-Hentai and ExHentai URLs and async semantics | integration | `NetworkingFeatureTests` request baselines | **COVERED** |
| HYG-01 | An in-flight reader refetch applies `skipserver` to its originating host | reducer | proposed `ReadingFeatureTests` suspended-response test | **MISSING — implementation defect** |
| HYG-01 | An in-flight profile verification applies profile state to its originating host | reducer | proposed `SettingFeatureTests` suspended-response test | **MISSING — implementation defect** |
| HYG-01 | Login-gating parity after `CookieUtil` deletion | unit | `CookieClientTests` didLogin matrix | **COVERED** |
| HYG-01 | DataCache direct fetches use isolated injected actors | unit | `ImageClientTests` cache hit/miss/failure/placeholder cases | **COVERED** |
| HYG-01 | `prefetchImages`, direct reads, and the purge observer share the injected live DataCache | unit + integration | proposed cache-identity/purge test | **MISSING** |
| HYG-01 | UserDefaults reads and writes are fully substitutable through `UserDefaultsClient` | unit | proposed dependency-override/AppRoute test | **MISSING — implementation defect** |
| QUAL-01 | No direct known cookie identifier is logged non-private; cookie description stays clipboard-only | static | `./Scripts/check-cookie-logging.sh` | **PARTIAL** |
| QUAL-01 | Aliased cookie values and alternate logger receiver names cannot reach public logs | static fixture | proposed gate fixture suite | **MISSING** |
| QUAL-02 | Networking async request, retry, parse, and host URL behavior | integration | `NetworkingFeatureTests` | **COVERED** |
| QUAL-02 | CookieClient didLogin/header parsing/sync/backfill/import behavior | unit | `CookieClientTests.swift` | **COVERED** |
| QUAL-02 | ImageClient cache/failure/placeholder/cancellation behavior with per-test caches and decoded pixel dimensions | unit | `ImageClientTests.swift` | **COVERED** |
| QUAL-02 | Client seam suites run from the canonical EhPanda FeatureTests plan | integration hardening | `FeatureTests.xctestplan` target inventory | **MISSING — requirement remains covered by full AppPackage suite** |

## Per-Task Validation Map

| Task ID | Requirement | Behavioral evidence inspected | Status |
|---------|-------------|-------------------------------|--------|
| 08-01-01 | QUAL-01 | Scoped ROADMAP/REQUIREMENTS audit | COVERED |
| 08-01-02 | QUAL-01 | Current-tree gate passes; verifier's alias/receiver fixture incorrectly passed | **PARTIAL — GAP-04** |
| 08-02-01 | HYG-01 | Host-taking `Defaults.URL` helpers + build evidence | COVERED |
| 08-02-02 | HYG-01 | URLUtil host parameters + Networking URL baselines | COVERED |
| 08-03-01 | HYG-01 | Twelve gallery-list requests store/forward explicit host | COVERED |
| 08-03-02 | HYG-01 | Reducer construction inventory + Networking baselines | COVERED |
| 08-04-01 | HYG-01 | Five Setting requests store/forward explicit host | COVERED |
| 08-04-02 | HYG-01 | Construction path covered; completion drops origin host | **PARTIAL — GAP-02** |
| 08-05-01 | HYG-01 | Detail requests and `apiuid(host:)` source + baselines | COVERED |
| 08-05-02 | HYG-01 | Detail host construction sites + focused suite evidence | COVERED |
| 08-06-01 | HYG-01 | Request/parser/cookie signatures require host | COVERED |
| 08-06-02 | HYG-01 | Callers pass snapshots; reader completion re-reads mutable host | **PARTIAL — GAP-01** |
| 08-07-01 | HYG-01 | Leaf view host sources + build evidence | COVERED |
| 08-07-02 | HYG-01 | Setting/detail host sources + full-suite evidence | COVERED |
| 08-08-01 | HYG-01 | Global/default absence sweeps + build evidence | COVERED |
| 08-08-02 | HYG-01 | Mirror action/write/restore/onChange absence sweeps | COVERED |
| 08-09-01 | HYG-01 | Canonical live actor and observer source identity inspected | **PARTIAL — GAP-05** |
| 08-09-02 | HYG-01 | Direct consumers use dependency; prefetch/purge unproved behaviorally | **PARTIAL — GAP-05** |
| 08-10-01 | QUAL-02 | Target, parent SwiftLint config, and green full-package evidence | COVERED |
| 08-10-02 | QUAL-02 | Nine actual ImageClient behavioral tests inspected | COVERED |
| 08-11-01 | QUAL-02 | Target, parent SwiftLint config, and green full-package evidence | COVERED |
| 08-11-02 | QUAL-02 / HYG-01 | Ten actual CookieClient behavior tests inspected | COVERED |
| 08-12-01 | HYG-01 | Twelve injected login reads + didLogin matrix | COVERED |
| 08-12-02 | HYG-01 | CookieUtil file/type absence + full-suite evidence | COVERED |
| 08-13-01 | HYG-01 | Folded implementation and four injected call sites inspected | COVERED |
| 08-13-02 | HYG-01 | Utility deleted, but `getValue` bypasses dependency storage | **PARTIAL — GAP-03** |
| 08-14-01 | HYG-01 | AppInfo consumers + AppUtil/dispatch helper absence | COVERED |
| 08-14-02 | HYG-01 | Orphan directory/package absence + final gates | COVERED |

## Gap Plan

### GAP-01 — Reader response cookie loses its originating host

- **Requirement:** HYG-01
- **Classification:** confirmed implementation defect; regression coverage missing
- **Observed behavior:** `refetchNormalImageURLs` snapshots `GalleryHost`, but
  `refetchNormalImageURLsDone` carries only index/result and later reads the mutable current
  setting before `setSkipServer`.
- **Required test:** suspend the request, switch the shared host, resume with a response carrying
  `skipserver`, then assert only the request-origin host receives the cookie.
- **Suggested path:** `AppPackage/Tests/ReadingFeatureTests/ReadingReducerImageFetchTests.swift`
- **Resolution:** make the completion action carry the originating host, fix the reducer, then run
  the focused ReadingFeature target and the canonical FeatureTests suite.

### GAP-02 — Profile verification loses its originating host

- **Requirement:** HYG-01
- **Classification:** confirmed implementation defect; regression coverage missing
- **Observed behavior:** `fetchEhProfileIndex` snapshots the host, but
  `fetchEhProfileIndexDone` does not carry it. Cookie/profile and default-profile side effects
  re-read mutable shared state.
- **Required test:** suspend profile verification, switch host, resume, and assert selected-profile
  writes/default-profile creation stay on the request-origin host.
- **Suggested path:** `AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift`
- **Resolution:** carry the originating host through completion and follow-up actions, then run the
  focused SettingFeature target and canonical FeatureTests suite.

### GAP-03 — UserDefaults read bypasses its injected client

- **Requirement:** HYG-01
- **Classification:** confirmed implementation defect; deterministic substitution test missing
- **Observed behavior:** `UserDefaultsClient` stores only `setValue`; generic `getValue` directly
  reads `UserDefaults.standard`. `.noop`, `.unimplemented`, and dependency overrides cannot control
  reads, while AppRoute tests install `.noop`.
- **Required test:** override the client with deterministic read/write endpoints, seed a conflicting
  process-global value, and prove AppRoute uses only the injected read.
- **Suggested path:** `AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift`
- **Resolution:** make the remaining typed read an endpoint of `UserDefaultsClient`, then add the
  reducer/client test and run canonical FeatureTests.

### GAP-04 — Cookie logging gate is identifier-sensitive

- **Requirement:** QUAL-01
- **Classification:** enforcement coverage missing
- **Observed behavior:** the AWK scanner recognizes only a receiver named `logger` and a fixed token
  inventory inside interpolation text. Phase verification added a temporary aliased-cookie fixture
  logged through an alternate `Logger` variable at `.public`; the gate incorrectly passed, and the
  fixture was removed afterward.
- **Required test:** negative fixtures for direct identifiers, aliased values, multiline calls,
  alternate logger receivers, `.public`, omitted privacy, and accepted `.private` cases.
- **Suggested path:** `Scripts/Tests/check-cookie-logging-tests.sh`
- **Resolution:** strengthen the gate to pass the fixture suite; keep the live-tree gate in the
  phase and CI checks.

### GAP-05 — DataCache prefetch/purge identity is not behaviorally proven

- **Requirement:** HYG-01
- **Classification:** coverage missing; source currently appears correct
- **Observed behavior:** direct ImageClient fetch paths use isolated injected caches in tests, but
  no test exercises `prefetchImages` against the injected cache or proves system purge events clear
  the same actor. The observer is private, so current evidence is structural only.
- **Required test:** construct `ImageClient.live` under an isolated `dataCache` override, exercise
  prefetch into that cache, then post the supported purge notification and prove the same cache is
  cleared without touching another isolated actor.
- **Suggested path:** `AppPackage/Tests/ImageClientTests/ImageClientTests.swift`
- **Resolution:** add only the minimal test seam needed to observe prefetch/purge identity, without
  reintroducing a singleton or serializing cache state.

### GAP-06 — New client suites are absent from the canonical test plan

- **Requirement:** QUAL-02 (integration hardening; the requirement is currently covered)
- **Classification:** canonical test infrastructure wiring missing; suites themselves are green
- **Observed behavior:** `CookieClientTests` and `ImageClientTests` are registered SwiftPM targets
  and pass in the full AppPackage suite, but `FeatureTests.xctestplan` lists neither target.
- **Required change:** add both targets to the canonical plan and run the `EhPanda`/`FeatureTests`
  command above, including focused `-only-testing:` checks for both targets.
- **Suggested path:** `AppPackage/Tests/FeatureTests.xctestplan`

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|----------|-------------|------------|--------------|
| Physical haptic parity at the four migrated sites | HYG-01 | Simulator/build cannot prove actuator output | On a supported device, trigger excluded-language toggle, category toggle, subsection reload, and archive selection; confirm the same feedback timing and style. |
| Live host-switch end-to-end | HYG-01 | Requires authenticated live E-H/ExH sessions | Switch host in Settings and exercise frontpage/search/favorites/detail requests. This supplements, but does not replace, GAP-01/GAP-02 deterministic race tests. |
| Background/memory purge behavior | HYG-01 | OS lifecycle delivery is device-dependent | Populate reader cache, background the app or induce memory pressure, and confirm retained behavior. This supplements, but does not replace, GAP-05. |

## Fresh Evidence Preserved

- Warning-free `EhPanda` app build passed after Wave 14.
- Canonical `EhPanda` FeatureTests passed after Wave 14.
- Full AppPackage suite passed after Wave 14, including `CookieClientTests` and
  `ImageClientTests`.
- SwiftLint build-tool plugins completed cleanly with no suppressions.
- `Scripts/check-cookie-logging.sh` exits 0 on the current source tree.
- Current static sweeps find none of the targeted deleted utility/global-host symbols.

## Validation Audit 2026-07-14

| Metric | Count |
|--------|------:|
| Gaps found | 6 |
| Resolved during audit | 0 |
| Confirmed implementation defects escalated | 3 |
| Missing coverage/infrastructure escalated | 3 |

## Validation Sign-Off

- [x] All 14 plans and summaries audited against actual source/tests
- [x] Fresh full build/suite/lint/static-gate evidence preserved
- [x] No overlapping or redundant `xcodebuild` invocation started
- [x] No implementation or test file changed by this audit
- [ ] Confirmed host-snapshot defects fixed and regression-tested
- [ ] UserDefaults read made substitutable and tested
- [ ] Cookie gate passes adversarial alias/receiver fixtures
- [ ] DataCache prefetch/purge identity covered behaviorally
- [ ] CookieClientTests and ImageClientTests included in canonical FeatureTests
- [ ] `nyquist_compliant: true`

**Approval:** pending gap remediation
