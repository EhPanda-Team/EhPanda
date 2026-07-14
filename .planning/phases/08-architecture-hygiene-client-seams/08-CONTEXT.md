# Phase 8: Architecture Hygiene & Client Seams - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

De-globalize the **remaining** `*Util` statics into injected clients or pure value
namespaces, remove the `DataCache.shared` singleton, **rescope the cookie work to a
logging audit** (the Keychain migration is dropped — see D-01), and cover the reworked
client seams (`CookieClient`, `ImageClient`) with deterministic tests — all at **behavior
parity**. Delivers **HYG-01** (de-globalize the AppTools/AppModels Utils + kill the
singletons; retain pure value types & constants), a **rescoped QUAL-01** (cookie-logging
audit only), and **QUAL-02** (client-layer test coverage for the reworked seams).

**Already done upstream (do NOT re-do):**
- Phase 5 already deleted `DeviceUtil` and `TouchHandler.shared`, and reshaped
  `DeviceClient` to `deviceType()` (the Device slice of HYG-01). Those globals are gone.
- The injected clients **already exist** for Cookie / Haptics / UserDefaults / File / URL /
  Image. This phase **folds the redundant Utils into them and migrates direct callers** — it
  does not build clients from scratch.
- Phase 4 already wrote full async-layer baselines for `NetworkingFeature` and the
  `CookieClient.testing` in-memory double.

**What this phase is NOT:**
- Not a Keychain/cookie-storage migration — QUAL-01 is rescoped to the logging audit (D-01).
  The dropped Keychain work is **not deferred** to a later phase; it is out of scope for the
  milestone (owner decision, rationale in D-01).
- Not the `Category.private.filterValue` fix or the structured error surface (QUAL-03/04 — **Phase 9**).
- Not a `try?` sweep or lint ratchet (Phase 9 / Phase 11).
- Not a visual change — mechanism swaps at behavior/appearance parity.

**Scouted scope reality (grounds the plan):**
- Remaining AppTools Utils: `CookieUtil` (didLogin/verify), `HapticsUtil`, `UserDefaultsUtil`,
  `FileUtil`. AppModels Utils: `URLUtil` (pure URL builders, 22 refs), `AppUtil`
  (version/build/isTesting/galleryHost/dispatchMainSync).
- `CookieUtil.didLogin` is called from **12 view sites**; it is fully redundant with the
  existing `CookieClient.didLogin` accessor.
- `HapticsUtil.generateFeedback` is called directly from **4 view sites**
  (EhSettingView+Sections3, CategoryView, SubSection, ArchivesView); `HapticsClient.live`
  already delegates to it.
- `AppUtil.galleryHost` is read from **~12 sites** (views + `Defaults.URL.host` + a
  DetailReducer). It is backed by a manual `UserDefaults` mirror (`AccountSettingReducer`
  writes it; `SettingReducer+Helpers` restores it at launch) that shadows `@Shared(.setting).galleryHost`.
- `AppUtil.dispatchMainSync` has **zero callers** (dead code).
- `DataCache.shared` is used from **5 sites**: `ReadingView` (a SwiftUI View, cannot take
  `@Dependency`), `LibraryClient` (×2), `DownloadClient+Cache` (×2). `ImageClient` already
  carries an injectable `dataCache` property defaulting to `.shared`.
- The empty `AppPackage/Sources/AuthorizationClient/` directory is a stale leftover from
  Phase 7's client deletion (cleanup opportunity).

</domain>

<decisions>
## Implementation Decisions

### Area 1 — Cookie work (QUAL-01, rescoped) — owner-decided 2026-07-14
- **D-01:** **QUAL-01 is rescoped to a logging audit only; the Keychain migration is dropped.**
  Rationale: (1) owner reports **years of zero observed cookie loss** in EhPanda's
  single-process usage, and Apple DTS's durability warning (forum thread 709838) targets
  **app-group cross-process** cookie stores, not the single-process case; (2) EhPanda is
  **sideload-distributed**, which makes Keychain *less* reliable here — a Team-ID re-sign
  (AltStore Apple-ID swap, move to TrollStore) **orphans Keychain items**, and some signing
  setups hit `errSecMissingEntitlement (-34018)`; the hard-to-obtain ExHentai `igneous` would
  vanish on a re-sign; (3) the app **deliberately** shows cookie values in the Settings cookie
  UI and copies them to the clipboard for cross-device portability, so the credential is
  intentionally user-portable and the at-rest security delta is small; (4) the cost (new
  Keychain wrapper + first-launch seed + tests + permanent maintenance surface, on a store
  that's *less* dependable in this distribution model) exceeds the payout for a never-observed
  failure mode. This is a **requirement change**: `REQUIREMENTS.md` (QUAL-01) and `ROADMAP.md`
  (Phase 8 goal + success criterion 2) MUST be reconciled to the logging-audit-only scope as a
  docs task **in this phase** (same "honest rescope" pattern as Phase 6's rejected decomposition).
- **D-02:** **The audit:** no cookie value is ever emitted to logs at `.public` privacy. Sweep
  `logger`/OSLog sites; where a cookie value must appear in diagnostics, use `.private`
  interpolation (or omit it). The user-initiated cookie UI and clipboard export
  (`getCookiesDescription`) are **not logs** and stay as-is — they are out of the audit's scope.

### Area 2 — Util de-globalization (HYG-01) — owner-decided 2026-07-14
- **D-03:** **`galleryHost` is parameterized all the way.** Delete the global read
  (`Defaults.URL.host` deriving host from a global), `AppUtil.galleryHost`, **and** the manual
  `UserDefaults` mirror (both the `AccountSettingReducer.galleryHostChanged` write and the
  `SettingReducer+Helpers` launch restore). Host then lives **only** in `@Shared(.setting)`.
  Views take host from store state / parent parameters; the ~44 `NetworkingFeature` requests
  take host **explicitly** as a parameter. **Accepted behavior change:** if the setting blob is
  lost, host resets to `.ehentai` (a minor, tolerable regression of a redundant durability
  path). `AppUserDefaults` shrinks to `clipboardChangeCount` only.
- **D-04:** **View-layer global reads become `@Dependency`.** The 12 `CookieUtil.didLogin` and 4
  `HapticsUtil.generateFeedback` view call sites become `@Dependency(\.cookieClient)` /
  `@Dependency(\.hapticsClient)` reads. Direct `.live` / `.shared` / static usage is **forbidden
  in consumers** (extends Phase 5 D-01's `@Dependency`-only rule). Read timing stays identical to
  today (views re-read each render; login-state changes reflect automatically), so parity holds;
  the in-body `@Dependency` read is accepted over the larger reducer-state-promotion rework.
- **D-05:** **`CookieUtil` is deleted** (its `didLogin`/`verify` logic is already covered by
  `CookieClient.didLogin`). **`HapticsUtil`'s implementation is folded into `HapticsClient.live`**
  and the standalone `HapticsUtil` is deleted. `UserDefaultsUtil` similarly folds into
  `UserDefaultsClient` (already its only real consumer once `AppUtil.galleryHost` is gone).
- **D-06:** **`URLUtil` and `FileUtil` are retained as pure constant/helper namespaces — NOT
  wrapped in clients.** A client wrapping a pure, deterministic function adds no
  testability/substitutability value (the project's anti-wrapper principle), and the HYG-01
  requirement itself says "pure value types and constants are retained." They may be
  relocated/renamed to shed the `*Util` label (e.g. `URLUtil`'s builders folded into
  `NetworkingFeature`-internal helpers). `URLUtil`'s only hidden impurity (its internal
  `Defaults.URL.host` read) is resolved by D-03. This **tightens** the requirement's "convert
  URLUtil/AppUtil to clients" wording — the docs reconciliation (D-01) notes it.
- **D-07:** **`AppUtil.dispatchMainSync` is deleted** (zero callers). The `AppUtil` type is
  **eliminated**; placement of the surviving `version`/`build` (Bundle constants) and `isTesting`
  (env read) facts is **Claude's discretion** (candidates: a small pure constants namespace, or
  inlining where consumed).

### Area 3 — DataCache de-globalization (HYG-01) — owner-decided 2026-07-14
- **D-08:** **`DataCache.shared` becomes a standalone `@Dependency(\.dataCache)`; `DataCache`
  stays an `actor` (type unchanged).** Add a `DataCache` `DependencyKey` whose `liveValue` is the
  single shared instance (the dependency system supplies the singleton semantics that the four
  consumers require). `ImageClient` / `LibraryClient` / `DownloadClient` resolve `\.dataCache`
  inside their live values instead of referencing `DataCache.shared`; `ReadingView` uses
  `@Dependency` (consistent with D-04). Delete `DataCache.shared` and `ImageClient`'s hardcoded
  `.shared` defaults. Chosen over folding into `ImageClient` because that would create
  client→client dependencies (LibraryClient/DownloadClient → ImageClient) and contradicts
  `DataCache`'s documented scope (reader pipeline + its exports, not an image-client concern).

### Area 4 — QUAL-02 test bar — owner-decided 2026-07-14
- **D-09:** **`NetworkingFeature`'s QUAL-02 share is satisfied by the Phase 4 baselines** — no new
  networking tests this phase. Phase 4 wrote full coverage against the migrated async request
  layer, which clears the `STATE.md` Phase-8 blocker ("verify NetworkingFeature parity tests
  target the async layer"). New test work targets **only** `CookieClient` + `ImageClient`.
- **D-10:** **Coverage is reworked-seam-first with a behavior matrix — deep, not padded.**
  `CookieClient`: `didLogin` full matrix (eh vs ex hosts, `igneous` present/mystery/absent,
  expiry), `setCredentials` + `setSkipServer` `Set-Cookie` header parsing, `syncExCookies`,
  `fulfillAnotherHostField`, `importAutomationCookies`. `ImageClient`: cache hit/miss + failure
  retry, using a **per-test `DataCache` instance** (never a process-global) and comparing
  **decoded pixel dimensions** (per the known DataCache.shared test-pollution rule). Do **not**
  pad coverage for client paths this phase doesn't touch (e.g. `editCookie`/`removeYay`/
  `loadCookiesState`). New test targets carry a `parent_config` `.swiftlint.yml` per the project
  convention.

### Claude's Discretion
- `AppUtil.version`/`build` and `isTesting` placement after `AppUtil` is eliminated (D-07).
- `URLUtil`/`FileUtil` final relocation and naming (D-06).
- `DataCache` `testValue` strategy (`unimplemented` vs a fresh per-test instance) — but tests
  MUST use a per-test instance (D-08/D-10).
- Removing the stale empty `AppPackage/Sources/AuthorizationClient/` directory if confirmed
  orphaned.
- Plan/wave decomposition. Natural seams (relatively independent): (a) `galleryHost`
  parameterization + mirror removal (touches NetworkingFeature + Setting + several views —
  largest blast radius); (b) `CookieUtil`/`HapticsUtil`/`UserDefaultsUtil` fold + view
  `@Dependency` swaps; (c) `URLUtil`/`FileUtil`/`AppUtil` residue; (d) `DataCache` dependency
  reshape; (e) cookie-logging audit; (f) CookieClient + ImageClient test suites; (g) docs
  reconciliation for the QUAL-01 rescope. Planner sequences (xcodebuild invocations must never
  overlap on this machine).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope (the locked contract — reconcile QUAL-01 per D-01)
- `.planning/REQUIREMENTS.md` §HYG (**HYG-01**) and §QUAL (**QUAL-01** — to be rescoped to
  logging-audit-only; **QUAL-02**). Acceptance criteria; the QUAL-01 Keychain clause is dropped.
- `.planning/ROADMAP.md` §"Phase 8: Architecture Hygiene & Client Seams" — goal + 3 success
  criteria; **criterion 2 (Keychain) is reconciled to the logging audit** in this phase.
- `.planning/PROJECT.md` §Constraints / §Key Decisions — parity bar; "De-`Util` package-wide
  (incl. URLUtil, AppUtil)"; "Injected clients over singletons/global helpers"; v1-schema freeze;
  lint-as-error / no suppressions. Note the AGENTS.md "avoid unnecessary wrappers" rule grounds D-06.

### Cross-phase carry-forward
- `.planning/phases/05-adaptive-layout-universal-orientation/05-CONTEXT.md` — D-01's
  `@Dependency`-only consumer rule (extended by D-04); the Device slice of HYG-01 + `TouchHandler.shared`
  are already removed, so they are **out** of this phase.
- `.planning/STATE.md` §Blockers/Concerns — the Phase-8 QUAL-02 NetworkingFeature note (cleared by D-09).

### Codebase maps (already-analyzed context)
- `.planning/codebase/STRUCTURE.md` — module layout (AppTools / AppModels / the *Client modules /
  test targets), where to add code.
- `.planning/codebase/CONVENTIONS.md` — lint rules, reducer/`@Dependency`/logger conventions,
  `parent_config` `.swiftlint.yml` requirement for new modules/targets.
- `.planning/codebase/TESTING.md` — Swift Testing patterns, xcodebuild-only build/test, no
  overlapping invocations.

### Key source files to modify
- `AppPackage/Sources/AppTools/CookieUtil.swift` (**delete**), `HapticsUtil.swift` (**fold into
  HapticsClient.live, delete**), `UserDefaultsUtil.swift` (**fold into UserDefaultsClient**),
  `FileUtil.swift` (**retain as pure namespace**), `DataCache.swift` (**+ DependencyKey, drop
  `.shared`**).
- `AppPackage/Sources/AppModels/Utilities/AppUtil.swift` (**eliminate type**), `URLUtil.swift`
  (**retain as pure namespace**), `Defaults+Runtime.swift` (`URL.host` global read — parameterize/delete).
- `AppPackage/Sources/CookieClient/CookieClient.swift` (absorb `didLogin`/`verify`; logging audit;
  new tests), `ImageClient/ImageClient.swift` (resolve `\.dataCache`; new tests).
- `LibraryClient/LibraryClient.swift`, `DownloadClient/DownloadClient+Cache.swift`,
  `ReadingFeature/ReadingView.swift` (`DataCache.shared` → `\.dataCache`).
- `SettingFeature/AccountSetting/AccountSettingReducer.swift` + `SettingFeature/SettingReducer+Helpers.swift`
  (remove the `galleryHost` UserDefaults mirror write + launch restore).
- `NetworkingFeature/Request+*.swift` (host becomes an explicit request parameter).
- The 12 `CookieUtil.didLogin` + 4 `HapticsUtil` view call sites (→ `@Dependency`).

No external ADRs/specs — the contract is fully captured in the requirements/roadmap above plus
the decisions in this document.

</canonical_refs>

<code_context>
## Existing Code Insights (verified 2026-07-14)

### Reusable Assets
- **`CookieClient`** — already a full `@Dependency` client with a `didLogin` accessor and a
  `CookieClient.testing(memberID:passHash:igneous:)` in-memory double (Phase 4). `CookieUtil` is
  redundant with it; the new tests hang off `.testing`.
- **`ImageClient.dataCache`** — already an injectable property (defaults to `.shared`); D-08
  makes the injection the norm. The DataCache test-pollution rule (per-test instance, compare
  pixel dims) is a known constraint.
- **`HapticsClient` / `UserDefaultsClient`** — already wrap `HapticsUtil` / `UserDefaultsUtil`;
  folding just makes the Util internal and migrates the direct view callers.
- **Phase 5 D-01 precedent** — the `@Dependency`-only consumer rule + the Device-slice removal
  are the template for this phase's fold-and-migrate.

### Established Patterns
- **`@Dependency` injection over globals** — the whole phase converts static `*Util.*` and
  `DataCache.shared` reads into `@Dependency` (views included) or explicit parameters (host).
- **`@Shared(.setting)` as single source of truth** — the redundant `galleryHost` UserDefaults
  mirror is removed in favor of the shared setting (D-03).
- **`.testing`/`noop`/`unimplemented` client factories + Swift Testing** — the QUAL-02 suites
  follow the existing client-test shape.
- **In-place v1 schema edits** — no `VersionedSchema` v2 (milestone schema freeze); the
  `AppUserDefaults` enum shrink is an in-place edit.

### Integration Points
- **`NetworkingFeature` host threading** — the ~44 requests currently resolve host from the
  global; D-03 makes host an explicit parameter. This is the largest-blast-radius change and
  touches the Phase-4-baselined request layer — parity is guarded by those baselines.
- **`DataCache` consumers** — `ImageClient`, `LibraryClient`, `DownloadClient`, and the
  `ReadingView` Live-Text path must all resolve the **same** injected instance (actor identity
  matters for cache coherence).
- **View → client reads** — TCA views taking `@Dependency` directly is the accepted seam (D-04),
  not reducer-state promotion.

### Parity constraints (do not regress)
- **Login-gated UI** — the 12 `didLogin` sites gate real controls (download/archive/comment
  buttons); the `@Dependency` swap must preserve identical enable/disable behavior.
- **Haptic feedback timing** — the 4 `HapticsUtil` sites fire on the same interactions.
- **Cookie behavior** — `CookieUtil` deletion must not change `didLogin` semantics (the client's
  accessor already matches; verify against the eh/ex + igneous/mystery/expiry matrix in tests).

</code_context>

<specifics>
## Specific Ideas

- **Cookie rescope rationale (D-01)** grounded in research: Apple DTS forum thread 709838 (the
  `HTTPCookieStorage` durability warning is app-group/cross-process, not single-process), the
  swift-security-expert skill (Keychain accessibility + Team-ID orphaning), and the
  sideload-distribution reality (Team-ID re-sign orphans Keychain items; `-34018`). The owner's
  lived experience (years, zero cookie loss) is the deciding evidence.
- **Anti-wrapper stance (D-06)** — the owner's standing rule "avoid unnecessary wrappers" (a
  wrapper must add value beyond renaming) directly governs `URLUtil`/`FileUtil`: a client over a
  pure deterministic builder adds none.
- **"Deep but not padded" test bar (D-10)** — the perfection-bar review posture applies to the
  *reworked seams*; coverage is not padded across untouched client paths.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (The dropped Keychain cookie migration is **not**
deferred to a later phase; it is out of the milestone by owner decision D-01, with the
requirement reconciled in this phase.)

</deferred>

---

*Phase: 8-Architecture Hygiene & Client Seams*
*Context gathered: 2026-07-14*
