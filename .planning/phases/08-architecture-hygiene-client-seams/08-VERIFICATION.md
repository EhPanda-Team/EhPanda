---
phase: 08-architecture-hygiene-client-seams
verified: 2026-07-14T11:10:43Z
status: gaps_found
score: 10/16 must-haves verified
behavior_unverified: 2
overrides_applied: 0
gaps:
  - truth: "Normal-image refetch keeps the request's originating gallery host through response cookie handling."
    status: failed
    reason: "The request snapshots GalleryHost, but refetchNormalImageURLsDone drops it and setSkipServer re-reads mutable shared settings. A host switch while the request is in flight can write skipserver to the wrong domain."
    artifacts:
      - path: "AppPackage/Sources/ReadingFeature/ReadingReducer.swift"
        issue: "refetchNormalImageURLsDone carries only index and result, not the originating host."
      - path: "AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift"
        issue: "The completion reducer uses state.setting.galleryHost for the response cookie write."
    missing:
      - "Carry GalleryHost in refetchNormalImageURLsDone and use it for setSkipServer."
      - "Add a reducer test that changes shared host while the request is suspended and proves the cookie write stays on the originating host."
  - truth: "Profile verification keeps the request's originating gallery host through profile-cookie and default-profile side effects."
    status: failed
    reason: "fetchEhProfileIndex snapshots a host for the request, but its completion drops that value. Completion then re-reads shared settings for selectedProfile and may start default-profile creation against a different host."
    artifacts:
      - path: "AppPackage/Sources/SettingFeature/SettingReducer.swift"
        issue: "fetchEhProfileIndexDone and createDefaultEhProfile do not carry an originating host."
      - path: "AppPackage/Sources/SettingFeature/SettingReducer+Body.swift"
        issue: "The request host is not included in the completion action."
      - path: "AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift"
        issue: "Completion side effects resolve host from current state rather than the completed request."
    missing:
      - "Carry GalleryHost through fetchEhProfileIndexDone and createDefaultEhProfile."
      - "Add a suspended-request host-switch reducer test for selectedProfile and profile creation."
  - truth: "UserDefaults access is fully substitutable through the injected UserDefaultsClient."
    status: failed
    reason: "Only writes are stored in the dependency value. getValue is an instance method that always reads UserDefaults.standard, so .noop, .unimplemented, and test overrides cannot control reads."
    artifacts:
      - path: "AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift"
        issue: "getValue bypasses the injected dependency value and reads process-global storage directly."
      - path: "AppPackage/Sources/AppFeature/DataFlow/AppRouteReducer.swift"
        issue: "detectClipboardURL depends on the non-substitutable read."
    missing:
      - "Model the remaining clipboardChangeCount read as a Sendable dependency endpoint with deterministic noop/test values."
      - "Add a reducer/client test proving an override controls both read and write behavior."
  - truth: "The cookie-logging gate rejects cookie values routed through ordinary aliases or differently named Logger instances."
    status: failed
    reason: "The scanner matches fixed cookie-like identifier spellings only inside calls on a receiver literally named logger. A temporary source fixture that assigned cookie.value to diagnosticValue and logged it through alternateLog at .public privacy passed the gate."
    artifacts:
      - path: "Scripts/check-cookie-logging.sh"
        issue: "Token/receiver-name matching is not a data-flow check and does not enforce the stated logging invariant."
    missing:
      - "Replace the naming-convention scan with syntax/data-flow-aware enforcement, or conservatively reject flows from cookie sources regardless of alias and Logger variable name."
      - "Add executable negative fixtures for aliased values and alternate Logger receiver names."
behavior_unverified_items:
  - truth: "The 12 migrated login-gated controls remain visually present/hidden and enabled/disabled exactly as before."
    test: "Exercise logged-in and logged-out states on download, archive, comment, rating/tag-vote, favorite, watched, and account controls."
    expected: "Each control has the same visibility and enabled state as before CookieUtil was removed."
    why_human: "The didLogin matrix proves predicate semantics and source inspection proves wiring, but it does not exercise rendered control state on a device."
  - truth: "The four migrated haptic interactions produce identical physical feedback."
    test: "On a physical device, trigger excluded-language, category-filter, reload, and archive-selection feedback."
    expected: "Each interaction fires the same feedback at the same time as the former utility path."
    why_human: "Source parity and build coverage cannot observe physical haptic output."
---

# Phase 8: Architecture Hygiene & Client Seams Verification Report

**Phase Goal:** De-globalize side-effecting Utils into injected clients, retain pure helper namespaces, remove singletons, audit cookie logging, and cover the reworked client seams with tests.
**Verified:** 2026-07-14T11:10:43Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Planning scope is logging-audit-only, and the current source tree contains no cookie-value log sink. | ✓ VERIFIED | ROADMAP/REQUIREMENTS match D-01; CookieClient contains no logger, `getCookiesDescription` has one clipboard consumer, and the clean-tree gate exits 0. |
| 2 | The cookie-logging gate catches cookie data flow after aliasing and Logger renaming. | ✗ FAILED | A temporary `diagnosticValue = cookie.value` fixture logged through `alternateLog` at `.public`; the gate still printed `Cookie logging audit passed.` |
| 3 | Host-dependent Defaults/URLUtil construction requires an explicit GalleryHost. | ✓ VERIFIED | `Defaults+Runtime.swift` exposes host-taking functions only; all host-dependent URLUtil builders require `host:` and no transitional default/global remains. |
| 4 | Gallery-list requests receive shared-setting host snapshots explicitly. | ✓ VERIFIED | Twelve request structs store GalleryHost; reducers pass `setting.galleryHost`; networking baselines cover deterministic request URLs. |
| 5 | Setting profile flows retain the originating host through asynchronous completion. | ✗ FAILED | `fetchEhProfileIndexDone` omits host and completion/profile creation re-read mutable shared settings. |
| 6 | Detail account requests and CookieClient apiuid access are host-explicit. | ✓ VERIFIED | Five Detail requests require GalleryHost; all apiuid call sites pass the selected host. |
| 7 | Remaining image/parser/cookie operations retain the originating host through asynchronous completion. | ✗ FAILED | Request construction is explicit, but normal-image refetch drops the host before `setSkipServer`. |
| 8 | View/reducer host reads and host-derived settings URLs use shared Setting state. | ✓ VERIFIED | Former AppUtil view sites use store/shared setting; myTags/uConfig use host-taking helpers. |
| 9 | Gallery-host globals, transitional defaults, and the UserDefaults mirror are removed. | ✓ VERIFIED | Static sweeps find no `Defaults.URL.host`, `AppUtil.galleryHost`, `galleryHostChanged`, or mirror restore/write. |
| 10 | DataCache is an injected actor with one coherent live identity and no public singleton. | ✓ VERIFIED | `DataCacheKey.liveValue` and the purge observer share `canonicalDataCache`; all consumers resolve `\.dataCache`; `DataCache.shared` is absent. |
| 11 | ImageClient has deterministic, isolated client-layer coverage. | ✓ VERIFIED | Dedicated target exists with parent SwiftLint config; tests cover cache hit/miss, failure, placeholder/invalid data, and cancellation using per-test cache roots and CGImage dimensions. |
| 12 | CookieClient has deterministic client-layer coverage. | ✓ VERIFIED | Dedicated target exists with parent SwiftLint config; tests cover login matrix/expiry, response parsing, host-exact sync, backfill, and automation import using isolated stores. |
| 13 | CookieUtil is removed and all 12 login-gated controls preserve rendered behavior. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The type is absent and all 12 view sites use injected CookieClient, but the planned device-level rendered-state check has not been performed. |
| 14 | HapticsUtil is folded into HapticsClient and all four migrated interactions preserve physical output. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Client implementation and four view call sites are wired; physical haptic behavior has no automated observer. |
| 15 | UserDefaultsUtil is folded into a fully substitutable injected client. | ✗ FAILED | The utility file is gone, but `getValue` always reads `UserDefaults.standard` outside the dependency's stored endpoints. |
| 16 | AppUtil/dead dispatch helper are removed and app metadata is preserved in AppInfo. | ✓ VERIFIED | AppUtil/dispatchMainSync are absent; AboutView and AppDelegateReducer use AppInfo; the stale AuthorizationClient directory/reference is absent. |

**Score:** 10/16 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `Scripts/check-cookie-logging.sh` | Deterministic enforcement of cookie-log privacy | ✗ PARTIAL | Passes the clean tree but misses alias and alternate-receiver flows. |
| `AppPackage/Sources/AppModels/Utilities/URLUtil.swift` | Pure, host-explicit URL namespace | ✓ VERIFIED | Substantive and used by request types; no global host read/default. |
| `AppPackage/Sources/AppTools/DataCache.swift` | Actor dependency with coherent live identity | ✓ VERIFIED | DependencyKey, accessor, canonical actor, and purge observer are wired. |
| `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift` | Host-explicit image request and cookie response handling | ✗ PARTIAL | Request side is explicit; response-cookie side uses the current host. |
| `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift` / `SettingReducer+Helpers.swift` | Host-explicit profile lifecycle | ✗ PARTIAL | Request side is explicit; completion side loses origin. |
| `AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift` | Fully substitutable defaults seam | ✗ PARTIAL | Write is injected; read bypasses the dependency value. |
| `AppPackage/Tests/ImageClientTests` | Dedicated lint-covered deterministic suite | ✓ VERIFIED | Target, Swift files, and `parent_config` exist and are wired in Package.swift. |
| `AppPackage/Tests/CookieClientTests` | Dedicated lint-covered deterministic suite | ✓ VERIFIED | Target, Swift file, and `parent_config` exist and are wired in Package.swift. |
| `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` | Pure relocated app metadata namespace | ✓ VERIFIED | Consumers use the relocated version/build/isTesting facts. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Shared Setting GalleryHost | Gallery request URL | `Request(host:)` → `URLUtil(...host:)` | ✓ WIRED | Construction sites and request baselines are explicit. |
| Originating image request host | Skip-server cookie write | refetch completion action | ✗ NOT WIRED | Completion action omits host and re-reads mutable state. |
| Originating profile request host | selectedProfile/default-profile side effects | profile completion action | ✗ NOT WIRED | Completion and follow-up action omit host. |
| `DataCacheKey.liveValue` | Image/Library/Download/Reading/purge paths | `DependencyValues.dataCache` / canonical actor | ✓ WIRED | All live paths resolve or reference the same actor. |
| CookieClient.didLogin | 12 login-gated view sites | `@Dependency(\.cookieClient)` | ✓ WIRED | Twelve former CookieUtil view uses are migrated. |
| UserDefaultsClient override | clipboard change-count read | `getValue` | ✗ NOT WIRED | Override has no read endpoint; process-global storage is always used. |
| AppInfo | About/AppDelegate | static pure metadata facts | ✓ WIRED | Both consumers use the new namespace. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| Normal-image refetch | `HTTPURLResponse` skipserver cookie | Request host snapshot + response | Response is real, but origin host is discarded | ✗ DISCONNECTED ORIGIN |
| Profile verification | profile id / selectedProfile cookie | VerifyEhProfile response | Response is real, but origin host is discarded | ✗ DISCONNECTED ORIGIN |
| DataCache consumers | image bytes | injected canonical actor / per-test actor | Yes | ✓ FLOWING |
| Login-gated views | `cookieClient.didLogin` | injected CookieClient | Yes; matrix-covered | ✓ FLOWING |
| Clipboard change count | stored integer | `UserDefaults.standard` | Yes, but not from injected override | ⚠️ GLOBAL BYPASS |

### Behavioral Spot-Checks

| Behavior | Command / evidence | Result | Status |
|---|---|---|---|
| Clean source passes cookie audit | `./Scripts/check-cookie-logging.sh` | `Cookie logging audit passed.` | ✓ PASS |
| Aliased cookie value at public privacy is rejected | Temporary Swift fixture using `diagnosticValue` and `alternateLog`, then the same script | Gate incorrectly passed; fixture was removed and worktree restored clean | ✗ FAIL |
| Regression gate | Final Wave 14 app build, FeatureTests, full AppPackage suite, SwiftLint, and cookie gate supplied by execute-phase | All exited successfully; no additional xcodebuild was started | ✓ PASS |
| Static deletion/inventory checks | `rg`/filesystem checks for removed globals/utils, 12 login sites, test target configs, and AppInfo consumers | Expected inventories found | ✓ PASS |

### Probe Execution

No probe scripts were declared by the Phase 8 plans, and no conventional `probe-*.sh` applies to this phase.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| HYG-01 | 08-02 through 08-09, 08-11 through 08-14 | De-globalize Utils and remove singletons | ✗ BLOCKED | Targeted globals/utils are removed, but two async host paths lose request origin and UserDefaults reads bypass the injected seam. |
| QUAL-01 | 08-01 | Audit cookie logging | ✗ BLOCKED | Current source is clean, but the committed gate accepts an aliased cookie value logged publicly through a differently named Logger. |
| QUAL-02 | 08-10, 08-11 plus Phase 4 coverage | Deterministic Networking/Cookie/Image client tests | ✓ SATISFIED | Dedicated CookieClient/ImageClient suites exist and the fresh complete regression gate is green; NetworkingFeature baselines remain extensive and green. |

No Phase 8 requirement is orphaned: HYG-01, QUAL-01, and QUAL-02 all appear in plan frontmatter. None of the four gaps is explicitly assigned to Phases 9–11, so no gap is deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `ReadingReducer+ImageFetch.swift` | 250–258 | Async completion re-reads mutable host | 🛑 Blocker | Cross-host response cookie write. |
| `SettingReducer+Body.swift` / `SettingReducer+Helpers.swift` | 187–200 / 117–140 | Async completion re-reads mutable host | 🛑 Blocker | Cross-host profile cookie/default-profile side effects. |
| `UserDefaultsClient.swift` | 16–18 | Dependency method reaches process-global state | 🛑 Blocker | Test overrides cannot control reads. |
| `check-cookie-logging.sh` | 5–6, 43–49, 77–88 | Security rule keyed to identifier names | 🛑 Blocker | Ordinary aliasing bypasses privacy enforcement. |

No new `TBD`, `FIXME`, or `XXX` debt marker was found in the phase file set. The existing ParserFeature SwiftLint suppression predates Phase 8 and was not introduced or expanded by this phase. The Package.swift dependencies questioned in the code review were not promoted to a verification gap: the test source directly imports AppModels/AppTools, so those direct target dependencies are consistent with SwiftPM module boundaries.

### Human Verification Required

#### 1. Login-gated control parity

**Test:** Exercise the migrated controls in logged-in and logged-out states on a device.
**Expected:** Download, archive, comment, rating/tag-vote, favorite, watched, and account controls keep their prior visibility and enabled state.
**Why human:** Client tests prove the predicate, but do not render these controls.

#### 2. Haptic parity

**Test:** Trigger the four migrated feedback interactions on physical hardware.
**Expected:** Feedback type and timing match the previous utility path.
**Why human:** Simulator/build evidence cannot observe physical feedback.

### Gaps Summary

The phase delivered most structural deletions and all requested client test targets, but it is not goal-complete. Two asynchronous flows violate the new caller-owned-host invariant, UserDefaults reads remain process-global despite dependency overrides, and the cookie privacy gate can be bypassed by routine local renaming. These four gaps are not covered by later roadmap phases and require gap-closure plans. Two additional parity checks remain human-observable after automated gaps close.

---

_Verified: 2026-07-14T11:10:43Z_
_Verifier: the agent (gsd-verifier; generic-agent workaround)_
