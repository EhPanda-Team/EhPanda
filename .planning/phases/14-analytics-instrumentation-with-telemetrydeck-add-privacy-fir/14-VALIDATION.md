---
phase: 14
slug: analytics-instrumentation-with-telemetrydeck-add-privacy-fir
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
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
| Signals actually arrive in the TelemetryDeck dashboard | D-10 | Requires a real app ID and the vendor's ingestion endpoint; not reachable from a test target | ✅ **verified 2026-07-26** — Check B below. Delivery confirmed at the ingestion endpoint (8/8 `POST /v2/` → `200 OK`) with decrypted payload inspection. Visual confirmation in the vendor's web console was not separately performed. |
| A build with **no** app ID ships zero network traffic | D-13 | Negative network assertion is not expressible in the unit suite | ✅ **verified by owner 2026-07-26** — Check A in plan 14-18 Task 2. See the Check A record below. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 76s (full suite; single-target filters ~25-50s)
- [x] `nyquist_compliant: true` set in frontmatter — released 2026-07-26 on Checks A and B; this flag tracks test-sampling adequacy, which is unaffected by the Check C disclosure gap recorded under Approval

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

## Check A — Silence Without a Credential (14-18 Task 2, 2026-07-26)

D-13's terminal check: a build carrying no app ID must reach the ingestion host zero times.

**Preconditions confirmed before the run**

| Precondition | Evidence |
|--------------|----------|
| Working tree credential-free | `git status --porcelain Config/` empty; `Config/` holds only the tracked `Analytics.xcconfig` |
| Built bundle carries no credential | `TelemetryDeckAppID` and `TelemetryDeckSalt` both read back empty (length 0) from the **built** `EhPanda.app/Info.plist`, not the source plist |
| Bundle is not a stale artifact | Freshly built at 10:22 on the day of the check |

**Method** — Proxyman capturing the simulator via the macOS system proxy, no certificate installed (undecrypted HTTPS still exposes the CONNECT host, which is all a presence/absence check needs). Positive control taken first: with the filter cleared, the app's ordinary `e-hentai.org` and image-CDN traffic appeared, proving capture was live. Filter then set to `Host` `Contains` `telemetrydeck`. Flows run, then a 25 s wait to cover the SDK's 10 s `transmitInterval` so an unflushed batch could not masquerade as silence.

**Flows exercised** — two Home sections (Frontpage, Toplists–Yesterday), a gallery detail open, a reader session opened and closed, a tab switch, and a tag-syntax search (`Language:chinese big breasts`). Six emissions across five of the thirteen signal cases, plus the SDK's own `sendNewSessionBeganSignal` at init.

**Result: ✅ PASS — zero requests.** 79 domains captured overall; zero rows matching `telemetrydeck`.

The absent session-start signal is the load-bearing part: that signal is emitted by the SDK itself rather than by app instrumentation, so its absence shows the D-13 gate resolves *before* the SDK is initialized, rather than merely suppressing app-level call sites.

---

## Check B, Live Delivery and Payload Inspection (14-18 Task 2, 2026-07-26)

A build carrying the real app ID and salt, run against the same instrumented flows as Check A, captured through a decrypting proxy so the inspection reads the bytes that left the device rather than the vendor's post-parse view.

**Delivery:** 8 requests, all `POST https://nom.telemetrydeck.com/v2/` returning `200 OK`. Every emitted signal is accounted for: `TelemetryDeck.Session.started`, `Navigation.homeSectionViewed` (2), `Navigation.galleryDetailOpened`, `Reading.sessionEnded`, `Navigation.tabOpened` (4), `Search.performed`. Nothing unexpected was sent.

**Forbidden-value sweep** over every request body, with a positive control (`App.readingDirection` matched 8/8) proving the body search was live rather than silently matching nothing:

| Probe | Meaning | Matches |
|-------|---------|---------|
| `big breasts`, `chinese` | search keyword text | 0 |
| `女王` | gallery title | 0 |
| `lgtx486` | uploader name | 0 |
| `4073049` | gallery identifier | 0 |
| `3899c10fdd` | gallery token | 0 |
| `http` | any URL | 0 |

No `Cookie` header on any request.

**Payload shape confirmed on the three highest-risk signals**

| Signal | Observed payload |
|--------|------------------|
| `Search.performed` | `keywordLength: 28`, `wordCount: 2-5`, `usedTagSyntax: true`, `resultCount: 21-50`. A 28-character, 4-word tag-syntax query rendered as numbers and a flag. |
| `Navigation.galleryDetailOpened` | `category: manga`, `tagNamespace.language: 1`, `tagNamespace.female: 11`. About 30 tags reduced to two namespace counts, no values. |
| `Reading.sessionEnded` | `pagesRead: 1`, `duration: 10-60s`, with no reference to which gallery was read. |

**D-11 per-signal freshness confirmed.** Within one `sessionID` and with no relaunch, `Search.performed` at 08:29:11 carried `App.readingDirection: leftToRight` and `Navigation.tabOpened` at 08:29:47 carried `vertical`. The parameters are re-read at emission, not snapshotted at launch. All six `App.*` parameters were present on every signal, and `clientUser` was a 64-character device hash (D-10), with `isTestMode: true` throughout.

**Result: ✅ PASS.** Visual confirmation in the vendor's web console was not separately performed; delivery is evidenced by the ingestion endpoint's `200` responses plus the decrypted bodies.

---

## Check C, Disclosure Against Observed Reality (14-18 Task 2, 2026-07-26)

**Finding: the README's never-collected list held, but the section understated the payload.** Nothing on the never-send list appeared, yet every signal also carried SDK-attached enrichment the disclosure did not mention: device model, architecture, screen metrics and orientation, OS version, locale, region and time zone, seven accessibility settings, appearance, retention and session counts, first-session date, and the date and time of day of the event. `Search.resultCount` was likewise absent from the section's description of a search.

This is the case threat **T-14-17** exists to catch, and it was reachable only by reading the disclosure against observed traffic rather than against intent. The accessibility flags carry the most weight, since reduce-motion, bold-text and text-size settings can imply disability status, and `region` plus `timeZone` are coarse location.

**Resolution:** the code was left unchanged, since the enrichment follows from the `sessionStatsEnabled: INTEGRATE` decision already recorded in `COVERAGE.md`. `README.md` was extended to disclose the enrichment and the search result count. The wording deliberately describes the SDK's date and time-of-day fields as "the date and time of day the event was sent" and never as calendar data, so a reader cannot mistake them for personal calendar events, and without an explicit denial that would plant the same idea.

**Second finding: the disclosure exists in English only.** `READMEs/README.chs.md`, `.cht.md`, `.de.md`, `.jpn.md` and `.ko.md` are structurally identical to `README.md` but carry no `## Analytics` section and no mention of the vendor at all. The section sits between Content & Copyright and Questions & Feedback in English and is simply absent from all five. A reader of any translated README receives no disclosure, which is a wider gap than the enrichment omission above.

**Result: ✅ PASS after the README corrections.** The English disclosure now matches observed traffic, and the section was added to all five translated READMEs (`chs`, `cht`, `de`, `jpn`, `ko`) once the wording had settled around the opt-out. All six sit at the same position, between Content & Copyright and Questions & Feedback, and each names the opt-out path using that locale's own UI strings, verified against the string catalogs rather than translated by feel (this caught two wrong paths: Simplified Chinese uses 一般 rather than 通用, and Traditional Chinese uses 一般設定 rather than 一般).

---

## Check D, The Runtime Opt-Out (added 2026-07-26, post-verification scope change)

The owner reversed D-01 after Checks A to C and asked for an in-app opt-out. `Setting.shareAnalyticsData` (optional, so pre-toggle blobs still decode) gates `AnalyticsClient.send` and empties `AnalyticsDefaultParameters.snapshot`. `start` is untouched, so the SDK still initializes and its session signal still counts installs.

**Automated:** full suite green, including new `SettingAnalyticsOptOutTests` (old-blob decode tolerance, opted-in resolution of `nil`, accessor round-trip) and new opt-out sweeps in `AnalyticsDefaultParametersTests` (empty snapshot under every other setting combination).

**On device, same proxy method as Check A.** With "Share Analytics Data" off, the instrumented flows were run again. Telemetry flow IDs stopped at 1924 and did not advance, while `e-hentai.org` traffic from the same session reached 2261, including the search request itself. About 340 captured flows of real app activity produced zero analytics requests.

Note for future verification: an injected instantaneous tap does not actuate a SwiftUI `Toggle`; a touch path with a short dwell does. Three taps appeared to be a binding failure until a known-good toggle in the same form reproduced it.

---

**Approval:** ✅ **owner-verified 2026-07-26.** Every automated and static check passes, and all four owner checks are complete:

- **A**: a build with no credential reaches the ingestion host zero times.
- **B**: a build with one delivers correct, leak-free payloads, confirmed against the decrypted bytes.
- **C**: the disclosure matches observed traffic, in English and in all five translations.
- **D**: the runtime opt-out added after the fact suppresses every app-authored signal while preserving install counts, confirmed on device.

The phase reverses **D-01** (no runtime opt-out) at the owner's direction; `COVERAGE.md` records the supersession on the `analyticsDisabled` row.

**Cleanup:** `Config/Analytics.local.xcconfig` was deleted after the checks, on the owner's confirmation that the write-once salt is backed up outside the repository. `Config/` holds only the tracked default and `git status --porcelain Config/` is empty, satisfying the plan's closing requirement that the working tree end credential-free.
