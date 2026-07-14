---
phase: 08-architecture-hygiene-client-seams
verified: 2026-07-14T13:20:00Z
status: human_needed
score: 14/16 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 10/16
  gaps_closed:
    - "Normal-image refetch keeps the request's originating gallery host through response cookie handling."
    - "Profile verification keeps the request's originating gallery host through profile-cookie and default-profile side effects."
    - "UserDefaults access is fully substitutable through the injected UserDefaultsClient."
    - "The cookie-logging gate rejects cookie values routed through ordinary aliases or differently named Logger instances."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "The 12 migrated login-gated controls remain visually present/hidden and enabled/disabled exactly as before."
    test: "Exercise logged-in and logged-out states on download, archive, comment, rating/tag-vote, favorite, watched, and account controls."
    expected: "Each control has the same visibility and enabled state as before CookieUtil was removed."
    why_human: "The didLogin matrix proves predicate semantics and source inspection proves wiring, but it does not exercise rendered control state on a device."
  - truth: "The four migrated haptic interactions produce identical physical feedback."
    test: "On a physical device, trigger excluded-language, category-filter, reload, and archive-selection feedback."
    expected: "Each interaction fires the same feedback at the same time as the former utility path."
    why_human: "Source parity and build coverage cannot observe physical haptic output."
human_verification:
  - test: "Exercise the 12 migrated login-gated controls in logged-in and logged-out states on a device."
    expected: "Download, archive, comment, rating/tag-vote, favorite, watched, and account controls keep their prior visibility and enabled state."
    why_human: "Client tests prove the didLogin predicate; they do not render these controls."
  - test: "Trigger the four migrated haptic interactions on physical hardware."
    expected: "Feedback type and timing match the previous utility path."
    why_human: "Simulator/build evidence cannot observe physical feedback."
---

# Phase 8: Architecture Hygiene & Client Seams Verification Report

**Phase Goal:** De-globalize side-effecting Utils into injected clients, retain pure helper namespaces (URLUtil/FileUtil), remove singletons (AppUtil, TouchHandler.shared, DataCache.shared), audit cookie logging so no cookie value is ever emitted at .public privacy, and cover the reworked client seams (async NetworkingFeature, CookieClient, ImageClient) with deterministic tests.
**Verified:** 2026-07-14T13:20:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (plans 08-15..08-18)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Planning scope is logging-audit-only, and the current source tree contains no cookie-value log sink. | ✓ VERIFIED | Clean-tree gate exits 0; CookieClient has no logger; `getCookiesDescription` has one clipboard consumer. |
| 2 | The cookie-logging gate catches cookie data flow after aliasing and Logger renaming. | ✓ VERIFIED (gap closed) | `check-cookie-logging.sh` now does file-scoped alias taint tracking + arbitrary-receiver matching. The aliased-value fixture (`diagnosticValue = cookie.value` via `auditLog`) and alternate-logger fixture (`securityEvents`) are both rejected (exit 1); the `.private` fixture passes; the clean tree passes. |
| 3 | Host-dependent Defaults/URLUtil construction requires an explicit GalleryHost. | ✓ VERIFIED | Host-taking builders only; no transitional default/global remains. |
| 4 | Gallery-list requests receive shared-setting host snapshots explicitly. | ✓ VERIFIED | Request structs store GalleryHost; reducers pass `setting.galleryHost`. |
| 5 | Setting profile flows retain the originating host through asynchronous completion. | ✓ VERIFIED (gap closed) | `fetchEhProfileIndexDone(GalleryHost, Result…)` and `createDefaultEhProfile(GalleryHost)` carry the origin; `handleFetchEhProfileIndexDone` uses the carried `host` for both the selectedProfile cookie write and default-profile creation. Two deterministic SettingReducer regressions cover a mid-flight host switch. |
| 6 | Detail account requests and CookieClient apiuid access are host-explicit. | ✓ VERIFIED | Detail requests require GalleryHost; apiuid call sites pass the selected host. |
| 7 | Remaining image/parser/cookie operations retain the originating host through asynchronous completion. | ✓ VERIFIED (gap closed) | `refetchNormalImageURLsDone(Int, GalleryHost, Result…)` carries the construction-time host; the completion writes `setSkipServer(response:host:)` with the carried host, not `state.setting.galleryHost`. A ReadingReducer regression proves the cookie stays on the origin after a shared-host switch. |
| 8 | View/reducer host reads and host-derived settings URLs use shared Setting state. | ✓ VERIFIED | Former AppUtil view sites use store/shared setting. |
| 9 | Gallery-host globals, transitional defaults, and the UserDefaults mirror are removed. | ✓ VERIFIED | Static sweeps find no `AppUtil`, mirror restore/write, or transitional global. |
| 10 | DataCache is an injected actor with one coherent live identity and no public singleton. | ✓ VERIFIED | `DataCache.shared` absent; consumers resolve `\.dataCache`. |
| 11 | ImageClient has deterministic, isolated client-layer coverage. | ✓ VERIFIED | Dedicated target with `parent_config`; cache/failure/placeholder/cancellation tests. |
| 12 | CookieClient has deterministic client-layer coverage. | ✓ VERIFIED | Dedicated target; login matrix/expiry/response/host-sync/backfill/automation tests. |
| 13 | CookieUtil is removed and all 12 login-gated controls preserve rendered behavior. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `CookieUtil` absent; 21 `didLogin` view/reducer uses wired through injected CookieClient; device-level rendered-state check not automatable. |
| 14 | HapticsUtil is folded into HapticsClient and all four migrated interactions preserve physical output. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `HapticsUtil` absent; `hapticsClient` wired at call sites; physical haptic output has no automated observer. |
| 15 | UserDefaultsUtil is folded into a fully substitutable injected client. | ✓ VERIFIED (gap closed) | `getValue` is now a stored `@Sendable (AppUserDefaults) -> Int?` endpoint (live/noop/unimplemented); the generic `getValue<T>` instance method is gone; `UserDefaults.standard` appears only inside `live`'s closures; `detectClipboardURL` reads via the injected endpoint. A reducer test proves one override controls read and write despite a conflicting process-global. |
| 16 | AppUtil/dead dispatch helper are removed and app metadata is preserved in AppInfo. | ✓ VERIFIED | AppUtil/dispatchMainSync absent; AboutView/AppDelegateReducer use AppInfo. |

**Score:** 14/16 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `Scripts/check-cookie-logging.sh` | Deterministic enforcement of cookie-log privacy | ✓ VERIFIED | File-scoped taint tracking + arbitrary-receiver matching; alias and alternate-receiver evasions rejected. |
| `AppPackage/Sources/AppModels/Utilities/URLUtil.swift` | Pure, host-explicit URL namespace | ✓ VERIFIED | Present; host-explicit; no global host read. |
| `AppPackage/Sources/AppTools/FileUtil.swift` | Pure file namespace retained | ✓ VERIFIED | Present as a pure namespace. |
| `AppPackage/Sources/AppTools/DataCache.swift` | Actor dependency with coherent live identity | ✓ VERIFIED | DependencyKey + canonical actor + purge observer wired. |
| `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift` | Host-explicit image request and cookie response handling | ✓ VERIFIED | Completion consumes carried host for `setSkipServer`. |
| `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift` | Host-explicit profile lifecycle | ✓ VERIFIED | `handleFetchEhProfileIndexDone` routes cookie write + default-profile creation through the carried host. |
| `AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift` | Fully substitutable defaults seam | ✓ VERIFIED | Read and write are both injected stored endpoints. |
| `AppPackage/Tests/ReadingFeatureTests/ReadingReducerImageFetchTests.swift` | Refetch host-preservation regression | ✓ VERIFIED | `refetchResponseWritesSkipServerToOriginatingHost` asserts cookie lands on `.ehentai` after a switch to `.exhentai`. |
| `AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift` | Profile host-preservation regressions | ✓ VERIFIED | Selected-profile and default-profile origin-stability tests. |
| `AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift` | UserDefaults read/write substitutability regression | ✓ VERIFIED | Override controls read and write despite conflicting process-global. |
| `AppPackage/Tests/ImageClientTests` | Dedicated lint-covered deterministic suite | ✓ VERIFIED | Target + `parent_config` wired in Package.swift. |
| `AppPackage/Tests/CookieClientTests` | Dedicated lint-covered deterministic suite | ✓ VERIFIED | Target + `parent_config` wired in Package.swift. |
| `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` | Pure relocated app metadata namespace | ✓ VERIFIED | Consumers use relocated version/build/isTesting facts. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Shared Setting GalleryHost | Gallery request URL | `Request(host:)` → `URLUtil(...host:)` | ✓ WIRED | Construction sites explicit. |
| Originating image request host | Skip-server cookie write | `refetchNormalImageURLsDone(_, host, _)` | ✓ WIRED | Carried host reaches `setSkipServer(response:host:)`. |
| Originating profile request host | selectedProfile/default-profile side effects | `fetchEhProfileIndexDone(host,_)` → helper → `createDefaultEhProfile(host)` | ✓ WIRED | Carried host used for both side effects. |
| `DataCacheKey.liveValue` | Image/Library/Download/Reading/purge paths | canonical actor / `\.dataCache` | ✓ WIRED | All live paths reference one actor. |
| CookieClient.didLogin | 12 login-gated view sites | `@Dependency(\.cookieClient)` | ✓ WIRED | Migrated view uses in place. |
| UserDefaultsClient override | clipboard change-count read | `getValue(.clipboardChangeCount)` | ✓ WIRED | Read is a substitutable stored endpoint. |
| AppInfo | About/AppDelegate | static pure metadata facts | ✓ WIRED | Both consumers use the namespace. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| Normal-image refetch | skipserver cookie host | carried request-origin host | Yes; origin preserved | ✓ FLOWING |
| Profile verification | selectedProfile cookie / default-profile host | carried request-origin host | Yes; origin preserved | ✓ FLOWING |
| Clipboard change count | stored integer | injected `getValue` endpoint | Yes; override honored | ✓ FLOWING |
| DataCache consumers | image bytes | injected canonical actor | Yes | ✓ FLOWING |
| Login-gated views | `cookieClient.didLogin` | injected CookieClient | Yes; matrix-covered | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command / evidence | Result | Status |
|---|---|---|---|
| Clean source passes cookie audit | `./Scripts/check-cookie-logging.sh` | `Cookie logging audit passed.` (exit 0) | ✓ PASS |
| Fixture harness (2 negatives + 1 positive + clean tree) | `./Scripts/Tests/check-cookie-logging-tests.sh` | `Cookie logging gate fixtures passed.` (exit 0) | ✓ PASS |
| Aliased cookie value at public privacy is rejected | `COOKIE_LOGGING_SCAN_ROOT=Scripts/Tests/fixtures/aliased-value ./Scripts/check-cookie-logging.sh` | audit failed (exit 1), correct line flagged | ✓ PASS |
| Renamed Logger receiver at public privacy is rejected | `COOKIE_LOGGING_SCAN_ROOT=Scripts/Tests/fixtures/alternate-logger ./Scripts/check-cookie-logging.sh` | audit failed (exit 1), correct line flagged | ✓ PASS |
| Full regression gate (app build + full AppPackage suite + SwiftLint) | Executor's Wave/gap-closure run (31.8s full suite green) — not re-run per instruction | Green | ✓ PASS (executor) |

### Probe Execution

No probe scripts were declared by the Phase 8 plans, and no conventional `probe-*.sh` applies. The cookie-logging gate and its fixture harness are the phase's runnable checks and were executed here (all green).

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| HYG-01 | 08-02..08-09, 08-11..08-17 | De-globalize Utils and remove singletons | ✓ SATISFIED | Targeted globals/utils removed; both async host paths now carry request origin (08-15, 08-16); UserDefaults read/write both injected (08-17). |
| QUAL-01 | 08-01, 08-18 | Audit cookie logging | ✓ SATISFIED | Gate now catches aliased values and renamed Logger receivers; executable negative + positive fixtures committed. |
| QUAL-02 | 08-10, 08-11 plus Phase 4 coverage | Deterministic Networking/Cookie/Image client tests | ✓ SATISFIED | Dedicated CookieClient/ImageClient suites; NetworkingFeature baselines; regression suite green. |

No Phase 8 requirement is orphaned: HYG-01, QUAL-01, QUAL-02 all appear in plan frontmatter and are marked Complete in REQUIREMENTS.md. No gap is deferred to a later phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | — | — | None. The four prior blockers are resolved: no completion-time host re-read in ReadingReducer/SettingReducer, no process-global UserDefaults read outside `live`, and the cookie gate is data-flow aware. |

No new `TBD`, `FIXME`, or `XXX` debt marker was introduced. `UserDefaults.standard` appears only inside `UserDefaultsClient.live`'s endpoint closures (the single sanctioned sink).

### Human Verification Required

#### 1. Login-gated control parity

**Test:** Exercise the 12 migrated controls in logged-in and logged-out states on a device.
**Expected:** Download, archive, comment, rating/tag-vote, favorite, watched, and account controls keep their prior visibility and enabled state.
**Why human:** Client tests prove the `didLogin` predicate but do not render these controls.

#### 2. Haptic parity

**Test:** Trigger the four migrated feedback interactions on physical hardware.
**Expected:** Feedback type and timing match the previous utility path.
**Why human:** Simulator/build evidence cannot observe physical feedback.

### Gaps Summary

All four gap-closure plans landed and are verified against the actual source, not just the summaries:

- **GAP-01 (truth 7, 08-15):** `refetchNormalImageURLsDone` carries `GalleryHost`; `setSkipServer` uses the carried host; regression proves origin stability.
- **GAP-02 (truth 5, 08-16):** `fetchEhProfileIndexDone`/`createDefaultEhProfile` carry `GalleryHost`; helper routes both cookie write and default-profile creation through it; two regressions cover a mid-flight switch.
- **GAP-03 (truth 15, 08-17):** `getValue` is an injected `@Sendable` endpoint; the generic instance method is gone; a regression proves an override controls read and write.
- **GAP-04 (truth 2, 08-18):** the gate is now alias- and receiver-name-independent; committed negative fixtures for both evasion classes are rejected and the positive/private fixture passes.

No regression was found in the 10 previously-passing truths (all singletons/utils remain absent; URLUtil/FileUtil remain pure namespaces). Two device-observable parity checks (login-gated control rendering, physical haptics) remain and route to human verification — the migrated wiring and source are correct, but rendered/physical output cannot be verified programmatically.

---

_Verified: 2026-07-14T13:20:00Z_
_Verifier: the agent (gsd-verifier; generic-agent workaround)_
