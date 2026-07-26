---
phase: 14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir
verified: 2026-07-26T15:43:25Z
status: gaps_found
score: 7/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "All five gallery-detail entry paths emit an identical `galleryDetailOpened` payload"
    status: failed
    reason: >-
      Only four emission sites exist. `SearchRootReducer.pushGalleryDetail` — the Search tab's
      compact-width (iPhone) push of a gallery detail — returns navigation only and emits nothing.
      On iPad the same tap routes to `.delegate(.presentGalleryDetail)` and IS counted by the app-root
      modal site, so `Navigation.galleryDetailOpened` both undercounts overall and is skewed by device
      idiom: search-originated opens appear only from iPads. Plan 14-12 listed this exact case under
      `read_first` ("the gallery-detail push case near line 130") but its `<behavior>` and `<action>`
      blocks only ever instructed the Favorites push, so the site was read and never wired.
    artifacts:
      - path: "AppPackage/Sources/SearchFeature/SearchRootReducer.swift"
        issue: "Lines 132-138 — `case .pushGalleryDetail(let gallery)` returns only `GalleryNavigation.presentationEffect(...)`; no `analyticsClient.send(.galleryDetailOpened(...))`. Contrast HomeReducer+Body.swift:51-67, FavoritesReducer.swift:137-153, DownloadsReducer.swift:131-150, which all `.merge` the emission."
      - path: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift"
        issue: "10 tests, none covering `galleryDetailOpened`. The other three push hosts each have one (AppFeatureTests:74, FavoritesFeatureTests:34, HomeFeatureTests:78, DownloadsFeatureTests:244)."
      - path: "AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift"
        issue: "Line 149 comment asserts this modal is the 'fifth' path emitting 'an identical shape to the four push paths'. Only three push paths exist, so the comment (and its three siblings) is factually wrong today."
    missing:
      - "Merge a `galleryDetailOpened` emission into `SearchRootReducer.pushGalleryDetail`, using the same `Category` + `TagNamespaceCounts(tags:)` derivation the other four sites use."
      - "Add a SearchFeatureTests case asserting exactly one `galleryDetailOpened` with the expected payload on `.pushGalleryDetail`."
      - "Add the explanatory 'no analytics here, counted at the push/modal' comment to `SearchRootReducer` `.galleryTapped` (lines 124-130) to match HomeReducer+Body.swift:42-44."
      - "Once wired, the 'four push paths' / 'all five' comments in PresentationFeature.swift:149, HomeReducer+Body.swift:59, FavoritesReducer.swift:145 and DownloadsReducer.swift:135 become true; leave them as-is only if the gap is closed."
  - truth: "Planning artifacts describe the phase as shipped"
    status: partial
    reason: >-
      ROADMAP.md still carries the pre-reversal D-01 wording and an inconsistent plan checklist.
      Confirmed stale by the orchestrator brief and by REQUIREMENTS.md:82-83 (restated 2026-07-26).
    artifacts:
      - path: ".planning/ROADMAP.md"
        issue: "Line 37 (milestone checklist) and line 748 (Phase 14 Goal) both read 'on by default with no opt-out (D-01)'. D-01 was reversed 2026-07-26 (commit bc67b874); a runtime opt-out ships."
      - path: ".planning/ROADMAP.md"
        issue: "Line 751 says 'Plans: 18/18 plans executed' while line 794 still shows `- [ ] 14-18-PLAN.md` unchecked. 14-18-SUMMARY.md exists and the plan is complete."
    missing:
      - "Rewrite ROADMAP.md:37 and :748 to match ANALYTICS-01 (runtime opt-out in General Settings; SDK session signal preserved; credential-gated no-op)."
      - "Tick ROADMAP.md:794 to `- [x] 14-18-PLAN.md`."
deferred: []
---

# Phase 14: Analytics Instrumentation (TelemetryDeck) Verification Report

**Phase Goal (authoritative):** ANALYTICS-01 in `.planning/REQUIREMENTS.md:82-83`, restated 2026-07-26.
The `.planning/ROADMAP.md:748` goal line is stale and is itself reported as a finding below.

**Verified:** 2026-07-26T15:43:25Z
**Status:** gaps_found
**Re-verification:** No — initial verification (no prior `14-VERIFICATION.md`)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The public signal API accepts no bare `String` apart from `SearchShape(keyword:)`, whose reduction is proven by sentinel reflection tests | ✓ VERIFIED | `grep 'public' AppPackage/Sources/AnalyticsClient/*.swift \| grep String` returns exactly one parameter position: `SearchShape.swift:32 public init(keyword: String)`. Every other hit is a `: String` raw-value enum declaration (`Buckets.swift:11,46`; `AnalyticsVocabulary.swift:25,34,67,78,100`; `AppErrorKind.swift:17,93`). `AnalyticsSignal.swift:25-50` — all 13 cases carry closed enums, `Bool`, buckets or `TagNamespaceCounts`; not one `String`. Sentinel proof: `SearchShapeTests.swift:84-95` reflects the constructed value through `Mirror.leafRenderings` (`ContentLeakProbe.swift:17-22`) and asserts the sentinel `zqxsentinelkeyword4718` appears in none of them, with a `renderings.count > 1` guard against a vacuous pass; `SearchShapeTests.swift:100-105` pins the stored-property set to exactly `[wordCount, usedTagSyntax, keywordLength]`. `TagNamespaceCountsTests` applies the same probe to the second reduction (which takes `[GalleryTag]`, not `String`). Suites confirmed executed: `Suite SearchShapeTests passed` / `AnalyticsSignalRenderingTests passed` in the regression log. |
| 2 | Counters and durations ship as buckets, with exactly two documented exceptions: exact search-keyword length, exact per-namespace tag counts | ✓ VERIFIED | `Buckets.swift:11-44` (`CountBucket`, total by construction, negatives clamp) and `:46-82` (`DurationBucket`, NaN-safe). Every numeric-bearing signal case takes a bucket: `AnalyticsSignal.swift:34` (`resultCount: CountBucket`), `:42` (`pagesRead: CountBucket, duration: DurationBucket`). The only two exact `Int`s that reach the wire are `SearchShape.keywordLength` → `AnalyticsSignal+Rendering.swift:157` and `TagNamespaceCounts.countsByNamespace` values → `:143`, both carrying the D-08/D-16 rationale in-file (`Buckets.swift:5-9`, `TagNamespaceCounts.swift:12-13`). The SDK's exact-value paths are structurally unreachable: `signal(_:floatValue:)` and the `startDurationSignal`/`stopAndSendDurationSignal` pair are OPT-OUT with reasons (`COVERAGE.md:56,63-64`) and appear nowhere in `AnalyticsClient.swift`, whose only emission calls are `TelemetryDeck.signal(name:parameters:)` (`:60`) and `errorOccurred(id:category:parameters:)` (`:63`). Default parameters are non-numeric by test: `AnalyticsDefaultParametersTests.swift:49-61` asserts no snapshot value parses as a bare integer. |
| 3 | The client no-ops when the build carries no ingestion credential; both deploy workflows inject credentials from repository secrets | ✓ VERIFIED | Single gate: `AnalyticsClient.swift:31` — `guard let appID = AppInfo.telemetryDeckAppID else { return .noop }` inside the `static let live` closure, so a credential-less build resolves the whole client (both `start` and `send`) to `.noop` and never references the SDK. `AppInfo.swift:18-38` collapses missing key / non-string / empty `$(VAR)` substitution onto one `nil`. `Config/Analytics.xcconfig:24,29` ship empty with an optional `#include? "Analytics.local.xcconfig"` (gitignored, `.gitignore:8`). `App/Info.plist:149-152` substitutes both keys. Both deploy workflows inject and then verify: `deploy.yml:50-51,64-65` and `deploy-pre-release.yml:51-52,65-66` pass `TELEMETRYDECK_APP_ID`/`TELEMETRYDECK_SALT` from `secrets.*` as command-line build settings to `xcodebuild archive`, and each has a `Verify analytics credentials` step reading them back out of the **archived** `Info.plist` with `plutil -extract` and `exit 1` on empty (`deploy.yml:66-72`). `test.yml` injects nothing. Behavioral proof: `AnalyticsClientGateTests.swift:17-24` drives `AnalyticsClient.live.start()` plus every rendering fixture through `live.send` under the test host, where the SDK's uninitialized-manager assertion would fire if the gate were wrong — `Suite AnalyticsClientGateTests passed`. A second in-depth guard exists at `AnalyticsClient.swift:36,46` (`started` mutex) so a pre-init signal is dropped rather than asserting. |
| 4 | The runtime opt-out stops every app-authored signal and empties the per-signal settings snapshot, leaving only the SDK's own session signal | ✓ VERIFIED | Gate on `send` only: `AnalyticsClient.swift:55-56` reads `@Shared(.setting)` **inside** the closure (never captured) and returns early when `isSharingAnalyticsData` is false; `start` (`:39-44`) is deliberately untouched so `sendNewSessionBeganSignal` keeps counting installs, and `Config.analyticsDisabled` — which would silence the session signal too — is OPT-OUT with that exact reason at `COVERAGE.md:50`. Snapshot emptied: `AnalyticsDefaultParameters.swift:29` — `guard setting.isSharingAnalyticsData else { return [:] }`, so no app-authored parameter rides the session signal. Storage: `Setting.swift:137` `shareAnalyticsData: Bool?` (optional so a pre-toggle blob still decodes) read through `isSharingAnalyticsData` (`:143-146`, default `true`). UI: `GeneralSettingView.swift:134-143` — an `AppToggle` in its own `Analytics` section with a footer. Tests: `AnalyticsDefaultParametersTests.swift:158-162` (empty when opted out), `:169-184` (empty under every other setting permutation), `:193-195` (default is opted in); `AppModelsTests/SettingAnalyticsOptOutTests.swift:58,64-80` (decode tolerance + round-trip). Both suites green in the regression log. Owner-confirmed at runtime in `14-UAT.md` tests 1 and 2 (both `pass`). |
| 5 | Every signal carries a per-signal snapshot of the feature-adoption settings rather than a value frozen at launch | ✓ VERIFIED | `AnalyticsClient.swift:41` assigns `config.defaultParameters = AnalyticsDefaultParameters.live` — a `@Sendable () -> [String: String]` closure the SDK evaluates per signal (`COVERAGE.md:33`). `AnalyticsDefaultParameters.swift:46-50`: both `@Shared(.setting)` and `@SharedReader(.didLogin)` are declared *inside* the closure body, never at file or type scope, so each invocation re-reads live state. Six keys, all dot-namespaced and collision-free (`:32-37`). Proven, not asserted: `AnalyticsDefaultParametersTests.swift:208-223` mutates the shared setting between two `live()` calls and asserts the second reflects `exhentai` where the first read `ehentai`; `:37-41` pins the key set at exactly six. |
| 6 | The single-SDK-import boundary is enforced by a lint rule (added in 14-17) | ✓ VERIFIED | `.swiftlint.yml:58-69` — custom rule `analytics_sdk_import_boundary`, regex `\bimport\s+TelemetryDeck\b`, `severity: error`, `excluded: [".*/Sources/AnalyticsClient/.*"]` (path regex, so the one owning module is exempt), with `excluded_match_kinds` for comment/doccomment/string so prose mentions don't trip it. Provenance confirmed: `git log -S analytics_sdk_import_boundary -- .swiftlint.yml` → `c5b35da1 feat(14-17): enforce the single-SDK-import boundary with a lint rule`. Boundary currently holds: repo-wide `grep -rn "import TelemetryDeck" --include=*.swift` returns exactly one hit, `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift:5`. `AppPackage/Package.swift:414` documents the same restriction on the target, and `AnalyticsSignal+Rendering.swift:19` records that the rendering layer must not import the SDK. |
| 7 | The four flow families are instrumented: lifecycle & navigation, search & discovery, reading & downloads, errors & feature adoption | ✓ VERIFIED | All 13 `AnalyticsSignal` cases have at least one live emission site (table below). Lifecycle: `AppDelegateReducer.swift:50` (`start`, from the launch-finish reducer action, not a view lifecycle callback). Navigation: `AppReducer.swift:242`, `HomeReducer+Body.swift:75,98`, four `galleryDetailOpened` sites. Search & discovery: `SearchReducer.swift:176`, seven panel sites, `QuickSearchReducer.swift:95`, `DetailReducer+Actions.swift:90`. Reading & downloads: `ReadingReducer+Body.swift:95` plus nine `downloadStateChanged` sites. Errors & feature adoption: `PresentationFeature.swift:179`, `LoginReducer.swift:179,258`, and feature adoption via the six per-signal default parameters. 70 emission tests across eight `AnalyticsEmissionTests.swift` suites, all reported passed. |
| 8 | All five gallery-detail entry paths emit an identical `galleryDetailOpened` payload (plan must-have, 14-10/14-11/14-12/14-15) | ✗ FAILED | Only four sites exist: `PresentationFeature.swift:164` (modal), `HomeReducer+Body.swift:63`, `FavoritesReducer.swift:149`, `DownloadsReducer.swift:140`. The Search tab's push — `SearchRootReducer.swift:132-138` — emits nothing. See Gaps Summary. |

**Score:** 7/8 truths verified (0 present, behavior-unverified)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift` | Credential gate, opt-out gate, single SDK call site | ✓ VERIFIED | 102 lines; gate `:31`, mutex `:36,46`, opt-out `:55-56`, two SDK calls `:60,63`; `liveValue`/`previewValue = .noop`/`testValue = .unimplemented` at `:76-78` |
| `AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift` | Closed 13-case vocabulary, no `String` payloads | ✓ VERIFIED | 51 lines; three deliberate omissions documented `:14-23` |
| `AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift` | Sole name/key minting site, exhaustive switch, no catch-all | ✓ VERIFIED | 219 lines; 12 signal names `:178-191`, 13 parameter keys `:195-217`, all dot-namespaced |
| `AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift` | Per-signal closure, opted-out returns `[:]` | ✓ VERIFIED | 52 lines; pure `snapshot` `:24-39` + 3-line `live` adapter `:46-50` |
| `AppPackage/Sources/AnalyticsClient/SearchShape.swift` | The one audited `String` entry point | ✓ VERIFIED | 63 lines; stores only bucket + flag + length |
| `AppPackage/Sources/AnalyticsClient/TagNamespaceCounts.swift` | Domain-typed reduction, no tag text stored | ✓ VERIFIED | 63 lines; `TagNamespaceKey.unrecognized` prevents a scraped namespace naming its own key `:17-25` |
| `AppPackage/Sources/AnalyticsClient/Buckets.swift` | Total, gap-free bucket vocabulary | ✓ VERIFIED | 83 lines; `BucketTests.swift` exercises both sides of every boundary |
| `AppPackage/Sources/AnalyticsClient/AppErrorKind.swift` | Payload-free `AppError` mirror, no catch-all arm | ✓ VERIFIED | 15 cases `:17-33`; exhaustive `init(_:)` binds nothing, so a new `AppError` case is a compile error `:11-15` |
| `Config/Analytics.xcconfig` | Committed, credential-free, optional local include | ✓ VERIFIED | Empty defaults `:24,29`; `#include?` last so a later assignment wins; header corrected by commit 2c7e0d0f |
| `App/Info.plist` | Build-variable substitution for both keys | ✓ VERIFIED | `:149-152` |
| `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` | Single-`nil` accessor for both credentials | ✓ VERIFIED | `:18-38` |
| `AppPackage/Sources/AppModels/Persistent/Setting.swift` | Opt-out storage tolerant of pre-toggle blobs | ✓ VERIFIED | `:137,143-146` |
| `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift` | Opt-out toggle in General Settings | ✓ VERIFIED | `:134-143`, own section + footer |
| `.swiftlint.yml` | `analytics_sdk_import_boundary` at error | ✓ VERIFIED | `:58-69` |
| `README.md` + `READMEs/README.{chs,cht,de,jpn,ko}.md` | D-03 disclosure in all six locales | ✓ VERIFIED | `README.md:30-41`; each localized file carries 3 TelemetryDeck references and the Settings opt-out sentence |
| `.github/workflows/deploy.yml`, `deploy-pre-release.yml` | Secret injection + archived-plist verification | ✓ VERIFIED | `deploy.yml:50-51,64-72`; `deploy-pre-release.yml:51-52,65-66` |
| `AppPackage/Sources/SearchFeature/SearchRootReducer.swift` | `galleryDetailOpened` on the Search push path | ✗ MISSING | `:132-138` — no emission. See gap. |
| 18 × `14-NN-SUMMARY.md` | One per plan | ✓ VERIFIED | 14-01 … 14-18 all present in the phase directory |
| `14-UAT.md` | Owner UAT | ✓ VERIFIED | `status: complete`, 55 passed / 2 issues, both reconciled (G-14-6 → 3fcce0f0, G-14-7 → 2c7e0d0f) |
| `14-VALIDATION.md` | Nyquist validation | ✓ VERIFIED | `status: validated`, `nyquist_compliant: true`, `wave_0_complete: true` |
| `COVERAGE.md` | SDK surface matrix | ✓ VERIFIED | 59 capabilities, 14 INTEGRATE / 45 OPT-OUT, 0 OPT-OUT without a reason; records the D-01 reversal at `:50` |
| `.planning/ROADMAP.md` | Current phase description | ⚠️ STALE | Lines 37, 748 pre-reversal wording; line 794 unchecked box vs line 751 "18/18 executed" |

---

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `AnalyticsClient.swift` | TelemetryDeck SDK | `import TelemetryDeck` + two emission calls | ✓ WIRED | Only importer repo-wide; `:60,63` |
| `AnalyticsClient.swift:41` | `AnalyticsDefaultParameters.live` | `config.defaultParameters =` | ✓ WIRED | Closure, re-evaluated per signal |
| `AnalyticsClient.swift:31` | `AppInfo.telemetryDeckAppID` | `guard let … else { return .noop }` | ✓ WIRED | Reads the plist key injected by the xcconfig/CI |
| `App/Info.plist:149-152` | `Config/Analytics.xcconfig:24,29` | `$(TELEMETRYDECK_*)` substitution | ✓ WIRED | Workflows read the value back out of the built archive |
| `AnalyticsClient.swift:55-56` | `Setting.isSharingAnalyticsData` | `@Shared(.setting)` inside the closure | ✓ WIRED | Not captured — takes effect on the next signal |
| `GeneralSettingView.swift:137` | `Setting.isSharingAnalyticsData` | `Binding($setting.…)` | ✓ WIRED | Setter pins the underlying optional |
| `AnalyticsSignal` | `AnalyticsSignal.rendered` | exhaustive `switch`, no catch-all | ✓ WIRED | A new case is a compile error at the rendering site |
| `AppError` | `AppErrorKind` | exhaustive `init(_:)` | ✓ WIRED | A new `AppError` case is a compile error |
| `AppDelegateReducer.swift:50` | `AnalyticsClient.start` | launch-finish reducer action | ✓ WIRED | D-14 satisfied: not a view lifecycle callback |
| `SearchRootReducer.swift:132` | `AnalyticsClient.send` | — | ✗ NOT_WIRED | The Search push path never reaches the client |

---

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| `AnalyticsDefaultParameters.live` | `setting`, `didLogin` | `@Shared(.setting)`, `@SharedReader(.didLogin)` read per call | Yes — mutation-between-calls test `AnalyticsDefaultParametersTests.swift:208-223` | ✓ FLOWING |
| `AnalyticsClient.live.send` | `signal.rendered` | 13-case exhaustive rendering, 12 distinct names + 13 keys | Yes — `AnalyticsSignalRenderingTests` pins every case's name and parameters | ✓ FLOWING |
| `AnalyticsClient.live` | `AppInfo.telemetryDeckAppID` | `Bundle.main` key substituted from xcconfig/CI build settings | Yes in CI (plist read-back gate); intentionally `nil` in clones/tests | ✓ FLOWING |
| `Navigation.galleryDetailOpened` | four call sites | Home / Favorites / Downloads pushes + app-root modal | Partially — Search-tab pushes contribute nothing | ⚠️ HOLLOW (one upstream branch disconnected) |
| `GeneralSettingView` toggle | `setting.isSharingAnalyticsData` | `@Shared(.setting)` persisted | Yes — UAT tests 1-2 pass, incl. relaunch survival | ✓ FLOWING |

---

### Behavioral Spot-Checks

Full-suite execution was performed by the orchestrator (**TEST SUCCEEDED**, 779 tests / 144 suites / 22 targets, 92.3 s); per the environment constraint no second `xcodebuild test` was launched. Evidence below is drawn from that run's log plus static enumeration.

| Behavior | Command | Result | Status |
|---|---|---|---|
| Exactly one file imports the SDK | `grep -rn "import TelemetryDeck" --include=*.swift .` | 1 hit — `AnalyticsClient.swift:5` | ✓ PASS |
| Only one bare-`String` public parameter | `grep 'public' Sources/AnalyticsClient/*.swift \| grep String` | 1 parameter (`SearchShape.init(keyword:)`); rest are raw-value declarations | ✓ PASS |
| Analytics suites executed (not zero-test targets) | `grep -o 'Suite …Analytics… passed' regression.log` | AnalyticsClientGateTests, AnalyticsDefaultParametersTests, AnalyticsEmissionTests, AnalyticsSignalRenderingTests, AnalyticsVocabularyTests, AppInfoAnalyticsTests, SettingAnalyticsOptOutTests — all passed | ✓ PASS |
| Unimplemented default is loud | `AnalyticsClientGateTests.swift:40-52` `withKnownIssue` ×2 | The 2 "known issues" in the run are exactly these, by design | ✓ PASS |
| SDK pinned to a 2.x stable tag (D-12) | `Package.swift:24` / `Package.resolved:250-254` | `.upToNextMajor(from: "2.14.1")`, resolved `2.14.1` @ `ad4a03ec` — no 3.0 pre-release | ✓ PASS |
| No app-side privacy manifest (D-04) | `find App ShareExtension -name PrivacyInfo.xcprivacy` | no results | ✓ PASS |
| No suppression directive added this phase | `git diff 2d3c885b~1..HEAD -- '*.swift' \| grep '^+.*swiftlint:disable'` | 0 added (the 27 elsewhere predate the phase) | ✓ PASS |
| `galleryDetailOpened` emitted from all five entry paths | `grep -rn "galleryDetailOpened" Sources` | 4 emission sites; SearchRoot absent | ✗ FAIL |
| Live delivery to the vendor dashboard | — | Owner-verified (14-18 Checks A-D, `14-VALIDATION.md`) | ? SKIP (already signed off) |

---

### Probe Execution

No `scripts/*/tests/probe-*.sh` exists in this repository and no PLAN or SUMMARY declares a probe path. Step 7c: **SKIPPED (no probes declared or discoverable)**.

---

### Requirements Coverage

All 18 plans declare `requirements: [ANALYTICS-01]`; no other ID is cited anywhere in the phase. `REQUIREMENTS.md:129` maps ANALYTICS-01 → Phase 14 and `grep -E "Phase 14" .planning/REQUIREMENTS.md` surfaces no additional ID for this phase, so there are **no orphaned requirements**.

| Requirement | Source plans | Description | Status | Evidence |
|---|---|---|---|---|
| ANALYTICS-01 | 14-01 … 14-18 (all) | Four flow families through a type-closed, privacy-redacted vocabulary on TelemetryDeck | ⚠️ SATISFIED WITH ONE GAP | Every clause of `REQUIREMENTS.md:83` verified independently (truths 1-6). The families clause (truth 7) is met, but the navigation family under-reports: one of the five declared gallery-detail entry paths never emits (truth 8). |

---

### Anti-Patterns Found

Scanned all 80 files touched between `2d3c885b~1` and `HEAD` (`.swift`, `.yml`, `.xcconfig`, `.plist`).

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | `TBD` / `FIXME` / `XXX` / `HACK` / `PLACEHOLDER` | — | **0 matches** across all phase-touched Swift files |
| — | — | `TODO` / "not yet implemented" / "coming soon" | — | **0 matches** |
| — | — | Added `swiftlint:disable` | — | **0 added** this phase |
| `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` | 148-149 | Comment asserts a fact the code does not deliver ("identical shape to the four push paths") | ⚠️ Warning | Same wording at `HomeReducer+Body.swift:59`, `FavoritesReducer.swift:145`, `DownloadsReducer.swift:135`. Currently false — three push paths, not four. Self-corrects once the gap closes. |
| `AppPackage/Sources/SearchFeature/SearchRootReducer.swift` | 124-130 | Missing the "no analytics here, counted at the push/modal" comment that every sibling `.galleryTapped` carries | ℹ️ Info | Its absence is consistent with the site simply having been overlooked rather than deliberately silenced. |

Nested gallery-detail pushes routed through `GalleryNavigation.nextScreen` — comments deep-link → detail, and detail-search result → detail (`DetailFeature/GalleryNavigation.swift:56-66`) — also emit nothing in any host (`HomeReducer+Body.swift:132-137`, `FavoritesReducer.swift:164-169`, `DownloadsReducer.swift:401-406`, `PresentationFeature.swift:97-103,116-121`). Unlike the gap above these were never enumerated in D-05 or in any plan, so they are recorded here as an **observation**, not a gap: the owner may want to decide explicitly whether an in-stack detail open counts, and document the answer either way.

---

### Human Verification Required

None. Human sign-off is already complete and is not re-requested:

- `14-UAT.md` — `status: complete`, 55 passed, 2 issues, both reconciled to `resolved` in commit `c64b9994` with code fixes at `3fcce0f0` (login-refusal toast copy) and `2c7e0d0f` (release-disclosure wording).
- `14-VALIDATION.md` — `status: validated`, `nyquist_compliant: true`.
- Owner Checks A-D (plans 14-02 and 14-18), including live dashboard payload inspection and the no-credential no-traffic check, cleared and recorded in `14-18-SUMMARY.md`.

The one gap below is statically provable and needs no human testing.

---

### Gaps Summary

**One functional gap and one bookkeeping gap.**

**1. The Search tab's gallery-detail push is uninstrumented (functional, blocking).**

`SearchRootReducer.swift:132-138`:

```swift
case .pushGalleryDetail(let gallery):
    let screen = GalleryPath.State.detail(.init(gallery: gallery))
    return GalleryNavigation.presentationEffect(
        id: state.path.appendGuardingDuplicate(.gallery(screen)),
        screen: screen,
        embed: { .path(.element(id: $0, action: .gallery($1))) }
    )
```

Its three siblings all `.merge` an emission into this exact return (`HomeReducer+Body.swift:51-67`, `FavoritesReducer.swift:137-153`, `DownloadsReducer.swift:131-150`). The consequence is not merely a missing count: `SearchRootReducer.swift:124-130` routes by device idiom, so an iPad tap becomes `.delegate(.presentGalleryDetail)` → `AppReducer.swift:276` → `PresentationFeature.swift:164` and **is** counted, while the same tap on iPhone is silent. `Navigation.galleryDetailOpened` therefore under-reports and is systematically skewed toward iPad for the app's primary discovery surface — a shape of error that is invisible in the dashboard and would be read as a genuine behavioral signal.

This was not an executor improvisation: plan `14-12-PLAN.md:75` lists "the gallery-detail push case near line 130" among the file's regions to read, but the task's `<behavior>` block (`14-12-PLAN.md:87`) and `<acceptance_criteria>` only ever require the *Favorites* push. The plan asked the executor to read the site and never told it to wire it, and the criteria (`FavoritesReducer.swift contains .galleryDetailOpened( exactly once`) passed regardless. Every downstream artifact then inherited the "five entry paths" claim without it being true: `14-10-SUMMARY.md:117,137,158`, `14-11-SUMMARY.md:115`, `14-12-SUMMARY.md:20,133,160`, `14-15-SUMMARY.md:29`, and four source comments.

Closure is one merged effect plus one test, reusing the `Category` + `TagNamespaceCounts(tags:)` derivation verbatim so all five payloads stay identical.

**2. ROADMAP.md has not caught up with the D-01 reversal (documentation).**

`ROADMAP.md:37` and `:748` still read "on by default with no opt-out (D-01)". That was overtaken on 2026-07-26 by the owner's reversal (commit `bc67b874`), which is correctly reflected in `REQUIREMENTS.md:82-83`, `COVERAGE.md:50`, `14-18-SUMMARY.md` and all six READMEs. Separately, `ROADMAP.md:751` claims "18/18 plans executed" while `:794` still shows `- [ ] 14-18-PLAN.md`; `14-18-SUMMARY.md` exists, so the box should be ticked. Neither affects shipped behavior, but the goal line is the text a future reader verifies against — leaving it stale is how the next verification gets anchored on a superseded contract.

**What is genuinely solid.** The privacy architecture — the load-bearing half of this phase — holds up under adversarial reading. The type wall is real (13 signal cases, zero `String` payloads, one audited entry point with a sentinel reflection test that guards against vacuous passes), the bucketing guarantee is total with its two exceptions minted in exactly the two documented places, the credential gate collapses the whole client rather than each call site, the opt-out is read per signal rather than captured, and the SDK's exact-value and free-form-message APIs are structurally unreachable rather than merely unused. The single-import boundary is now enforced by a lint rule at `error` rather than by convention. None of that is contradicted by the gap above, which is a coverage hole in one navigation branch, not a leak.

---

_Verified: 2026-07-26T15:43:25Z_
_Verifier: Claude (gsd-verifier)_
