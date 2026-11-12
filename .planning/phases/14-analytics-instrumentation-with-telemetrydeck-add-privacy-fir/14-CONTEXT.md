# Phase 14: Analytics Instrumentation (TelemetryDeck) - Context

**Gathered:** 2026-07-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Add usage analytics to EhPanda via the TelemetryDeck SDK, instrumenting the app's key user
flows. Scope anchor is **ROADMAP.md §Phase 14**.

This is **green-field** — verified by code scout 2026-07-24, the repository contains no
analytics, telemetry, crash-reporting, or third-party metrics code of any kind. Nothing is
being replaced or migrated; everything here is new surface.

**⚠ ROADMAP wording is now stale.** The Phase 14 goal line reads "privacy-first, **opt-in**
analytics". Per D-01 the owner chose default-on with no opt-out. The goal line must be
reworded during planning to say what is actually being built — "privacy-first" still holds
(see the redaction rules in D-07/D-08), "opt-in" does not.

**Milestone-theme note (for the record).** The v3.0.0 milestone's stated theme is
*dependency reduction*; this phase adds a third-party SDK. That tension was raised and the
owner proceeded — the phase is roadmapped and intentional. Planners should not treat the
new dependency as an error to be designed around.

**In scope:** the TelemetryDeck SPM dependency; a new `AnalyticsClient` module; signal
emission across the four instrumented flow families (D-06); global default parameters;
build-time app-ID configuration; a README disclosure section.

**Out of scope:** any in-app analytics UI (there is none by design — D-01); crash reporting;
performance tracing; the ShareExtension target (see Deferred).

</domain>

<decisions>
## Implementation Decisions

### Consent model & disclosure

- **D-01:** **Analytics is ON by default, with no opt-out.** No settings toggle, no
  first-run prompt, no consent dialog. Consequently there is **no** new `Setting` field, **no**
  new `@Shared` consent key, **no** `GeneralSettingView` row, and **no** new `.xcstrings`
  localization keys — this phase adds no user-facing UI whatsoever.

- **D-02:** The legal basis for D-01, researched during discussion:
  - TelemetryDeck's position is that it collects no data governed by GDPR/CCPA, stores **no
    IP addresses** anywhere (not in the database, logs, or elsewhere), and therefore requires
    neither consent nor an opt-out.
  - Apple's App Store Review Guideline 5.1.1(ii) *would* require consent "even if such data
    is considered to be anonymous" — **but it does not apply here.** EhPanda is distributed
    as an `.ipa` installed via AltStore (`README.md:20`); there is no App Review gate.
  - Caveats recorded honestly: the GDPR reading above is the *vendor's* legal position, not a
    regulator's ruling, and ePrivacy Art. 5(3) is read more strictly by some EU DPAs. This is
    not legal advice. If distribution ever moves to TestFlight or the App Store, **D-01 must
    be revisited** — 5.1.1(ii) would then bind.

- **D-03:** Collection is disclosed in a new **`README.md` "Analytics" section**: that
  anonymous usage data is sent to TelemetryDeck, what is collected, what is never collected,
  and a link to TelemetryDeck's privacy policy. This is the only disclosure surface.

- **D-04:** **No `PrivacyInfo.xcprivacy`** is added. None exists in the repository today and
  AltStore distribution does not require one. (Revisit alongside D-01 if distribution changes.)

### Event taxonomy

- **D-05:** **All four flow families are instrumented** — the owner's framing was "collect
  everything that's not privacy sensitive":
  1. **Lifecycle & navigation** — launch/foreground; Home section viewed (Frontpage, Popular,
     Watched, Toplists, History); Favorites and Downloads tab opens; gallery detail opened.
  2. **Search & discovery** — search performed; filter panel used; quick-search word used;
     tag tapped from a gallery.
  3. **Reading & downloads** — reader session start/end; pages read per session; reading
     direction and dual-page mode in use; download started / completed / failed.
  4. **Errors & feature adoption** — which `AppError` cases reach users (the Phase 9 typed
     error surface already classifies these); login failures; Cloudflare challenges hit;
     which settings are enabled in the field.

- **D-06: Never-send list (hard constraint, no exceptions).** These must be impossible to
  transmit: gallery IDs (`gid`), gallery tokens, gallery titles, any gallery or page URL,
  **search keyword strings**, tag *values*, usernames, cookies or any credential material,
  and file paths.

- **D-07: Allow-list of content-adjacent payloads.** Only these cross the line, and only in
  the stated shape:
  - **Gallery category** — the E-Hentai category enum (Doujinshi, Manga, Artist CG, Game CG,
    Western, Non-H, Cosplay, Asian Porn, Misc).
  - **Tag namespaces, counts only** — which namespaces are present on an opened gallery and
    how many of each, across the **full** E-Hentai namespace set **including `female` and
    `male`**. Tag *values* remain forbidden per D-06.
  - **Host & login state** — E-Hentai vs ExHentai, and whether the user is authenticated.
  - **Search shape** — word count, a "used tag syntax" boolean, bucketed result count, and
    **exact keyword length**. The keyword text itself is forbidden per D-06.

  *Recorded for auditability:* during discussion Claude recommended cutting the tag
  namespaces and the exact keyword length (fetish-namespace counts are weakly
  content-revealing; exact length plus a stable install ID plus timestamps is a usable
  fingerprint for narrowing candidate queries). The owner had already selected both and
  reinstated them in full. **The allow-list above is the decision — planners implement it as
  written.** No further narrowing.

- **D-08: Bucket numeric values.** Pages read, result counts, session lengths and similar
  counters are transmitted as buckets (e.g. `1 / 2-5 / 6-20 / 21+`), never as exact values —
  exact counters against a stable per-install identifier erode anonymity in aggregate.
  **One documented exception: search keyword length ships exact** (per D-07).

- **D-09: No free-form strings, enforced by type.** Every payload value originates from a
  closed Swift enum or a bucketed number. `AnalyticsClient`'s public API must not accept a
  bare `String` anywhere, so a future contributor **cannot** leak a title, keyword, or URL
  even by accident. This is a compile-time constraint, not a review-time convention, and it
  is the primary mechanism protecting D-06.

### Payload & identity

- **D-10:** Signals carry **TelemetryDeck's built-in anonymized identifier** — constant for
  the lifetime of one app install, salted and hashed server-side, with no IP retention. This
  preserves retention, DAU/MAU and per-user session analysis. No custom identifier, no
  rotation.

- **D-11:** The feature-adoption settings (host, login state, reading direction, dual-page
  mode, tag translation, list display mode) are registered as **TelemetryDeck global default
  parameters**, so every signal carries the current snapshot and any metric is segmentable by
  any setting without a query-time join. TelemetryDeck bills per signal rather than per byte,
  so the added payload is free.

### Integration seam

- **D-12:** A new **`AppPackage/Sources/AnalyticsClient`** module holding a `@Dependency`
  client, following the shape of the 15 existing clients (`HapticsClient`, `DeviceClient`, …).
  **Only this module imports the TelemetryDeck SDK.** Its API takes a closed `AnalyticsSignal`
  enum, satisfying D-09 structurally. Follow the established client idiom exactly:
  `liveValue` / `previewValue` = `.noop` / `testValue` = `.unimplemented`
  (see `AppPackage/Sources/HapticsClient/HapticsClient.swift` for the canonical template).

- **D-13:** The **TelemetryDeck app ID is not committed.** It comes from a gitignored
  `xcconfig` (or an `Info.plist` key fed by one); when absent, `AnalyticsClient` **no-ops
  entirely**. Rationale: the repository is public, so the ID is not secret in any case (it is
  a write-only ingestion key, extractable from any released `.ipa`) — the goal is **dataset
  cleanliness**, keeping contributor builds, forks and CI runs out of the owner's data. The
  same nil check covers DEBUG builds, tests, previews and CI with one guard. The release
  machine carries the file; a missing file silently ships zero analytics, which planners
  should surface in the README/build docs.

- **D-14:** **Signals are emitted from reducer actions only** — including screen views, which
  derive from the navigation actions the app already centralizes
  (`AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift`, `SettingPath`,
  `StackState`). No `.onAppear`/`.task` emission: it double-counts on re-appear and tab
  switches and is not unit-testable. Reducer-sourced signals are covered by `TestStore`.

### Claude's Discretion

The owner delegated these; planner/researcher decide:
- Signal naming convention (TelemetryDeck's `dot.separated` convention vs a flat scheme).
- Exact bucket boundaries for D-08.
- The precise app-ID plumbing mechanism (xcconfig → `Info.plist` key vs build setting).
- Which specific navigation actions map to which screen-view signals.
- Whether reader sessions emit start+end or a single end-of-session signal.

**Scope note on delegation:** "you decide" applies to open questions only. D-01 through D-14
are locked owner decisions and must not be reopened, narrowed, or re-litigated during
research, planning, or execution.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & project rules
- `.planning/ROADMAP.md` §Phase 14 — the phase goal (note the stale "opt-in" wording, D-01).
- `.planning/PROJECT.md` — milestone theme, core value, and the parity bar.
- `CLAUDE.md` (repo root, also `AGENTS.md`) — **mandatory.** Reducer `Feature` suffix naming;
  the per-module `.swiftlint.yml` rule (a new module **must** carry one — 43 of the existing
  modules do); the localized-format argument rules; the local-project-reference-privacy rule;
  the no-absolute-home-paths rule for generated docs.
- `.swiftlint.yml` (repo root) — **read before writing any Swift.** Custom regex rules and
  banned APIs; suppressions are forbidden without explicit owner permission.

### Code the phase touches or imitates
- `AppPackage/Sources/HapticsClient/HapticsClient.swift` — canonical `@Dependency` client
  template (live/noop/unimplemented + `DependencyKey` + `DependencyValues` extension).
- `AppPackage/Package.swift` — module enum, target declaration, `swiftLintPlugins`; all
  third-party dependencies are declared here, never in the Xcode project.
- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` — centralized navigation
  state; the source for screen-view signals per D-14.
- `AppPackage/Sources/AppModels/Support/AppError.swift` — the Phase 9 typed error surface
  feeding the error-family signals (D-05 family 4).
- `AppPackage/Sources/AppModels/Persistent/Setting.swift` — the settings read for D-11 global
  parameters. **Note: this phase adds no field to it** (D-01).
- `App/EhPandaApp.swift`, `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` —
  candidate SDK-initialization sites.
- `README.md` — receives the new Analytics disclosure section (D-03); line 20 documents the
  AltStore distribution that D-02 depends on.

### External (TelemetryDeck)
- `https://telemetrydeck.com/docs/guides/privacy-faq/` — the consent/opt-out and
  data-collection basis for D-02; also confirms no IP retention.
- `https://telemetrydeck.com/docs/articles/anonymization-how-it-works/` — how the default
  anonymized identifier in D-10 is derived.
- `https://developer.apple.com/app-store/review/guidelines/` §5.1.1(ii) — the rule that would
  bind if distribution ever changed (D-02 caveat).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The `@Dependency` client idiom** — 15 client modules already exist, all following an
  identical shape. `AnalyticsClient` is a drop-in addition, not a new pattern.
- **`Setting` on `@Shared(.appStorage("setting"))`** — already holds every value D-11 needs
  for global parameters; read-only for this phase.
- **Phase 9 typed `AppError`** — errors are already classified, so the error-family signals
  map onto an existing enum rather than needing new taxonomy.
- **Centralized navigation** (`PresentationFeature`, `SettingPath`, `StackState`) — screen
  views are derivable from existing actions, which is what makes D-14 viable.

### Established Patterns
- **Modules declare deps in `AppPackage/Package.swift` only** — the TelemetryDeck SPM
  dependency goes there, never into `EhPanda.xcodeproj`.
- **Every module carries a `.swiftlint.yml`** with `parent_config: ../../../.swiftlint.yml`
  (43 modules do today) — `AnalyticsClient` must too, per `CLAUDE.md`.
- **`liveValue` / `previewValue: .noop` / `testValue: .unimplemented`** — the unimplemented
  test value means any *unexpected* analytics call in a test fails loudly, which is the
  desired default.
- **Reducers carry the `Feature` suffix** — project convention overriding TCA's own.

### Integration Points
- `AppPackage/Package.swift` — new `.package(url:)` entry, new module case, new `.target`.
- SDK initialization at app start (`App/EhPandaApp.swift` or `AppDelegateReducer`), gated on
  the app ID being present per D-13.
- Signal emission sites across `HomeFeature`, `SearchFeature`, `FavoritesFeature`,
  `DetailFeature`, `ReadingFeature`, `DownloadsFeature`, `SettingFeature` reducers.
- `README.md` for the D-03 disclosure section.

### Notable non-impacts
- **No localization work** — D-01 removes all user-facing UI, so no `.xcstrings` keys are
  added and the labeled-format-argument rules never come into play.
- **No schema migration** — no persisted model changes, so the `SchemaVersion` machinery is
  untouched and all models stay at v1.

</code_context>

<specifics>
## Specific Ideas

- The owner's framing for the taxonomy was verbatim: *"basically i want to collect everything
  that's not privacy sensitive."* Read D-05/D-07 as maximal-within-the-rules, not minimal.
- The owner explicitly declined to set the redaction boundary themselves on the grounds that
  Claude's privacy bar is stricter than theirs — then reinstated both items Claude had cut.
  **Downstream agents: implement D-07 as written; do not re-narrow it on privacy grounds.**
- On the app ID, the owner's reasoning was that a public OSS repo argues *for* keeping the ID
  out of the tree, not against it (D-13).

</specifics>

<deferred>
## Deferred Ideas

- **`PrivacyInfo.xcprivacy` + revisiting D-01** — required only if distribution moves to
  TestFlight or the App Store, where Guideline 5.1.1(ii) would bind. Not now.
- **ShareExtension instrumentation** — the extension is a separate target with its own
  lifecycle; instrumenting it was not discussed and is out of this phase.
- **A `REQUIREMENTS.md` entry for analytics** — Phase 14 currently maps to **no requirement
  ID** (all 22 v1 requirements belong to Phases 1–11, and the ROADMAP lists Phase 14's
  Requirements as "TBD"). Worth adding an `ANALYTICS-01` entry with traceability during
  planning so coverage stays honest, but it is bookkeeping, not phase scope.
- **Crash reporting / performance tracing** — adjacent to analytics, separate capability,
  separate phase.

</deferred>

---

*Phase: 14-analytics-instrumentation-with-telemetrydeck*
*Context gathered: 2026-07-24*
