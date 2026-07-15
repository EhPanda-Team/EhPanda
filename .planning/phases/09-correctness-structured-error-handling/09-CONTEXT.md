# Phase 9: Correctness & Structured Error Handling - Context

**Gathered:** 2026-07-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Kill the `Category.private.filterValue` `fatalError` landmine, and replace silent `try?`
with structured `AppError`-based handling surfaced through a user-facing failure toast that
opens a dismissable `ErrorInfoView` detail surface — so the `optional_try` lint rule can later
(Phase 11) be enabled at **error** with (near-)zero violations.

Requirements: **QUAL-03** (fix the `Category.private.filterValue` trap) and **QUAL-04**
(structured `AppError` + user-facing error surface + `try?` → `do/catch`).

This phase clarifies HOW to implement that error surface. It does not add new capabilities:
no new error-reporting/telemetry backend, no crash-reporting SDK, no offline error queue.
</domain>

<decisions>
## Implementation Decisions

### `optional_try` escape hatch (the crux — QUAL-04)
- **D-01:** Default posture — **every `try?` becomes `do/catch` that throws a proper `AppError`**.
  The error is propagated (never swallowed). Where the failure warrants the user's attention it
  is surfaced via a toast → `ErrorInfoView` (see D-08..D-12).
- **D-02:** A `try?` may **survive only** where `do/catch` genuinely cannot express the intent —
  specifically a decode/parse that **intentionally falls back to a default value**. Every survivor
  must carry an **inline comment stating the just cause** to keep it. There is no silent
  best-effort `try?` bucket; "best-effort" is expressed as `do/catch` with the fallback in the
  `catch`, unless it truly resists that shape.
- **D-03:** Surviving just-cause `try?` sites are **owner-blessed exceptions**. When Phase 11
  enables `optional_try` at **error**, those specific reviewed lines may carry a
  `// swiftlint:disable` (e.g. `:this optional_try`) — the one sanctioned suppression, because the
  owner personally reviewed each. **Downstream flag:** Phase 11 / LINT-01's absolute wording
  ("No rule is suppressed, disabled, or bypassed with `// swiftlint:disable`") needs a
  reconciliation to carve out these owner-blessed `optional_try` suppressions. (Not edited here —
  raised for the Phase 11 discuss/plan step.)
- **D-04:** `optional_try` stays commented in `.swiftlint.yml` during this phase; the at-**error**
  flip and zero-violation verification happen in the Phase 11 capstone (per ROADMAP). Phase 9's job
  is to drive the `try?` count to (near-)zero and leave every survivor a justified, commented
  exception.

### `AppError` structure (QUAL-04)
- **D-05:** **Merge, don't replace.** Keep EhPanda's existing `AppError` case set
  (`copyrightClaim`, `ipBanned`, `expunged`, `networkingFailed`, `parseFailed`, `quotaExceeded`,
  `authenticationRequired`, `fileOperationFailed`, `notFound`, `unknown`, …) and its existing
  `isRetryable` / `alertText` behavior — those encode real E-Hentai response semantics and back the
  ~10 existing `ErrorView` call sites. Layer the structured-error machinery on top.
- **D-06:** Add per-incident **typed context**: `context: Context?` where
  `Context = [ContextKey: AnyHashableBox]`. `ContextKey` is a `String` enum with human-readable
  raw values (used directly as row labels in `ErrorInfoView`). `AnyHashableBox` is a small
  `Hashable & Sendable` type-erasing box with `ExpressibleBy*Literal` conformances so a throw site
  reads naturally, e.g. `[.action: "…", .reason: "…"]`. Which cases carry `context` (the throw
  sites with real diagnostic value) is a research/planning detail.
- **D-07:** Add a **suggested solution**: a `solution: String?` computed property (per-kind,
  localized), plus conform `AppError` to `LocalizedError` (`errorDescription` → description,
  `recoverySuggestion` → solution). Keep `alertText`/`isRetryable` intact.

### Failure surface & routing (QUAL-04 SC-3)
- **D-08:** Reuse and extend EhPanda's existing Liquid Glass toast infra (`AppAlertState` +
  `.toast()` + `ToastMessageView`). Do **not** rebuild a custom notification renderer.
- **D-09:** The detail surface is **`ErrorInfoView`** — a `Form` with **Description / Suggested
  Solution / Context / Environment** sections and a close toolbar button. **iOS/iPadOS only**: drop
  every `#if os(macOS)` / mac-layout branch from the reference; drop the reference's Firebase
  `.analyticsScreen`. Environment info sources from EhPanda's current homes — app version/build from
  `AppInfo`, device from `DeviceClient`, OS from `ProcessInfo` — **not** `AppUtil.*` (removed in
  Phase 8) and **not** `DeviceUtil.*` (deleted in Phase 5). New `.xcstrings` keys authored to the
  project's labeled-format-argument + non-translated-key conventions.
- **D-10:** **Rename `AppRouteReducer` → `PresentationReducer`.** Add an `.errorInfo(AppError)`
  case to its `Destination`; `ErrorInfoView` is presented from there. This reuses the reducer that
  already owns the app-root toast and already does `fetchGalleryDone → failure → .setToast(.error())`.
- **D-11:** The failure toast **keeps the existing 3s auto-hide**; tapping it within that window
  opens `ErrorInfoView`. (An `AppError`-bearing error toast must carry the error so the tap can
  route to `.errorInfo`.)
- **D-12:** **Routing rule** — every `AppError` throw site must ensure the error is **carried up to
  the nearest surface (most likely the owning reducer)**, never swallowed. Whether that error is
  *presented* (tappable failure toast → `ErrorInfoView`, full-screen `ErrorView` for primary-content
  load failures, or handled silently with justification) is decided **per site** at the reducer.
  Not a blanket "every throw toasts" rule.

### `Category.private` fix (QUAL-03)
- **D-13:** `Category.private.filterValue` returns **0** in production (`.private` is a display-only
  category, not a search-filter category, so it contributes **no filter bit**), with a **doc comment**
  explaining why. Replace the `fatalError` with a **dev-time issue report** that flags misuse during
  development but is inert in release, plus a **test**. Likely mechanism: PointFree `IssueReporting`
  `reportIssue(...)` (raises a runtime warning/breakpoint in dev, records a test failure that the
  test asserts via `withExpectedIssue`/`withKnownIssue` — a raw `assertionFailure` would trip under
  the debug-config test run and collide with QUAL-03's "covered by a test"). Research to confirm the
  exact API.

### Claude's Discretion
- Exact set of `AppError` cases that gain `context`, and the concrete `ContextKey` members needed
  for EhPanda's throw sites (D-06).
- Module placement of `AnyHashableBox` (own tiny module vs folded into an existing low-level module)
  and of `ErrorInfoView` / the `AppError` context machinery across `AppModels` / `AppComponents`.
- The precise `try?` → `do/catch` conversion per site and which reducers present a toast vs handle
  silently (D-12), within the routing rule.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external ADR/spec docs govern this phase — decisions are captured above. The relevant
references are the existing in-repo files this phase modifies or extends:

### Correctness landmine (QUAL-03)
- `AppPackage/Sources/AppModels/Gallery/Category.swift` — the `filterValue` `fatalError` on
  `.private` (D-13); `value` already handles `.private`.
- `AppPackage/Sources/AppModels/Utilities/URLUtil.swift` §`categoryValue` builder (~lines 200-210) —
  the live `filterValue` consumers (all explicit non-private cases).

### Structured error type (QUAL-04)
- `AppPackage/Sources/AppModels/Support/AppError.swift` — the existing flat enum + `isRetryable` +
  `localizedDescription` + `alertText` to preserve and extend (D-05..D-07).

### Failure surface & routing (QUAL-04 SC-3)
- `AppPackage/Sources/AppComponents/AppAlertState.swift` — the unified presentation state + toast
  factories to extend (D-08, D-11).
- `AppPackage/Sources/SystemNotificationExt/ToastMessageView.swift` and
  `AppPackage/Sources/SystemNotificationExt/View+Toast.swift` — the Liquid Glass toast renderer +
  `.toast()` modifier (D-08, D-11).
- `AppPackage/Sources/AppComponents/AlertView.swift` — the existing `ErrorView`/`AlertView`
  full-screen error surface (D-12 primary-load path; `error.symbol` consumer).
- `AppPackage/Sources/AppFeature/DataFlow/AppRouteReducer.swift` — the reducer to rename
  `PresentationReducer` and extend with `.errorInfo` (D-10); already owns the app-root toast and the
  `fetchGalleryDone` failure-toast precedent.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` and
  `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` — the app-root `appRouteState`/toast
  wiring that the rename touches.

### Lint rule (verified in Phase 11)
- `.swiftlint.yml` §`optional_try` (currently commented, ~lines 144-151) — the rule this phase
  drives toward zero and Phase 11 flips to error (D-03, D-04).

### Design source (name-free)
- The `AppError` + `Context`/`ContextKey`/`AnyHashableBox` + `ErrorInfoView` + presentation-reducer
  pattern is adapted from an established error-handling design in a reference project on the
  contributor's machine, reproduced here name-free and re-homed to EhPanda's iOS-only,
  post-`AppUtil`/`DeviceUtil`, `LocalizedStringResource`, existing-Liquid-Glass-toast world.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`AppAlertState` + `.toast()` + `ToastMessageView`** (Liquid Glass) — the failure toast is an
  extension of this, not a new renderer. `AppAlertState<Never>.error(caption:)` factories already
  exist; the tap-to-detail affordance and AppError payload are the additions.
- **`ErrorView` / `AlertView`** (`AppComponents/AlertView.swift`) — stays as the full-screen
  primary-content error surface; `AppError.symbol`/`alertText` already feed it.
- **`AppRouteReducer`** — already centralizes the app-root toast + `@Presents var destination`
  (`.setting`/`.newDawn`) + `detail`/`path`; the rename to `PresentationReducer` + `.errorInfo`
  case slots straight in.
- **`IssueReporting`** — already a project dependency (used via `IssueReporting.unimplemented` in
  clients); the natural home for the D-13 dev-time report.
- **`AppInfo`** (version/build/isTesting, relocated in Phase 8) + **`DeviceClient`** (Phase 5) —
  the environment-info sources for `ErrorInfoView`.

### Established Patterns
- **`do throws(AppError) { … } catch { … }`** — already used in `AppRouteReducer.fetchGallery`
  and across the Phase-4 async request layer; the `try?` sweep converts to this same typed-throws
  shape.
- **`@Presents` + `@ReducerCaseIgnored` Destination cases** — the `.errorInfo` presentation follows
  the existing `.setting`/`.newDawn` idiom; `AppAlertState` is `_EphemeralState` for the toast.
- **`LocalizedStringResource` + `.xcstrings`** with labeled-format-argument / non-translated-key
  rules (AGENTS.md) — all new error description/solution/label/environment strings follow these.
- **Native presentation surfaces** (project memory) — render via native SwiftUI/system UI; unify
  the state type, don't rebuild native affordances as custom cards.

### Integration Points
- **Renaming `AppRouteReducer` → `PresentationReducer`** touches `AppReducer` and `TabBarView`
  (`appRouteState`/`appRoute` scoping) — a mechanical rename plus the new `.errorInfo` case.
- **`try?` blast radius** (~143 sites, non-test): ParserFeature 44, DownloadClient 36, AppTools 17,
  NetworkingFeature 9, FileClient 8, AppModels 6, SettingFeature 5, LogsClient 4, LibraryClient 4,
  ImageClient 4, plus scattered singles. Parser sites are the densest and most likely to hold
  legitimate decode-with-default survivors (D-02).
- **Per-feature toast owners** (~8: AccountSetting, Reading, Comments, Torrents, GalleryInfos,
  Archives, Downloads, + app-root) — each is a candidate reducer for the D-12 per-site presentation
  decision.

### Parity constraints (do not regress)
- **Existing `ErrorView` behavior** — the ~10 full-screen error sites keep their retry semantics
  and `alertText`/`isRetryable`/`symbol` outputs unchanged; the `AppError` merge must not alter them.
- **Existing toast behavior** — success/loading/info toasts and the 3s auto-hide are unchanged; only
  `AppError`-bearing failure toasts gain the tap-to-detail affordance.
</code_context>

<specifics>
## Specific Ideas

- **Adopt the reference error-handling design (adapted).** The owner pointed to an established
  `AppError` + `ErrorInfoView` + presentation-reducer pattern in a reference project and wants it
  adopted, re-homed to EhPanda: keep EhPanda's domain cases, add `context: [ContextKey:
  AnyHashableBox]` + `solution`, `LocalizedError` conformance, an `ErrorInfoView` with
  Description/Solution/Context/Environment sections, and route it through a renamed
  `PresentationReducer.Destination.errorInfo`. Strip the reference's macOS branches and Firebase
  analytics; source environment info from `AppInfo`/`DeviceClient`/`ProcessInfo`.
- **"Report the survivors."** The owner will personally review every surviving `try?`; each must be
  a deliberate, inline-commented exception by phase end (D-02), and Phase 11 grants those the only
  sanctioned `swiftlint:disable` (D-03).
- **Dev-time crash, production-safe.** For `.private.filterValue` the owner wants it to "crash the
  dev env" but return 0 in production (D-13) — a dev-only issue report, not a `fatalError`.
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (No error-telemetry/crash-reporting backend, offline
error queue, or new distribution surface was proposed; those would be their own phases.)
</deferred>

---

*Phase: 9-Correctness & Structured Error Handling*
*Context gathered: 2026-07-15*
