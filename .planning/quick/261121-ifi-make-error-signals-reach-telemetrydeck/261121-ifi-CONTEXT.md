# Quick Task 261121-ifi: Make error signals reach TelemetryDeck - Context

**Gathered:** 2026-11-21
**Status:** Ready for planning

<domain>
## Task Boundary

Make the app's user-visible errors reach TelemetryDeck, as Phase 14 D-05 family 4 intended ("which `AppError`
cases reach users"). Two defects, one task:

1. **The error signal is never sent.** `AnalyticsSignal.errorSurfaced` is emitted only from
   `PresentationFeature`'s `.setToast` case (`AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift`), and
   nothing in the app sends `.setToast`. Commit `04b198b26` (13-06, 2026-07-23) replaced the last
   `send(.setToast(.error(errorInfo)))` with a direct `state.toast = .error(errorInfo)`, one day before Phase 14
   research chose `.setToast` as the single emission site. The two error toasts that exist today (an unsupported deep
   link, and a gallery that failed to load from a deep link) set `state.toast` directly and emit nothing.
   `AnalyticsEmissionTests` sends `.setToast` itself, so it passes while the app never does. TelemetryDeck shows
   0 error events in the last 30 days against 1,442 users.
2. **Errors shown inside a screen were never covered.** About 70 sites in about 20 reducers set
   `LoadingState.failed(AppError)`, which renders `ErrorView` (list fetches on Front Page, Popular, Watched, Toplists,
   History, Favorites and Search; footer "load more"; detail and its sub-screens such as archives, torrents, previews
   and detail search; settings; the reader's per-page image and preview states). None of them emits a signal. Phase
   14 research assumed Phase 9 had routed every user-visible error through the toast; no decision excluded inline
   errors.

Out of scope: login failures. `LoginReducer` deliberately sends only `Account.loginFailed`, never the generic
`errorSurfaced`; that exclusion stays. Caption-only toasts (no `AppError`) also stay silent, as before.

</domain>

<decisions>
## Implementation Decisions

### Approach (agreed before the discussion)
- Emit when the state changes, not when an action arrives: observe the toast state and each `LoadingState` (for
  example with TCA's `Reducer.onChange(of:_:)`) so a later direct assignment cannot bypass the signal again, which is
  exactly how `04b198b26` broke it.
- If `PresentationFeature.Action.setToast` is left with no sender, delete it and its call sites rather than keep a
  dead action (project rule: remove emptied actions).
- Test through the real paths: an unsupported deep link produces the error toast and exactly one signal; a failed list
  fetch produces exactly one signal; the existing tests that send `.setToast` directly are replaced, not kept beside
  the new ones.

### Screen parameter (owner decision, 2026-11-21)
- The error signal carries the screen it happened on, as a closed enum (for example frontPage, popular, watched,
  toplists, history, favorites, search, detail, reading; exact case set at Claude's discretion, but every emission
  site maps to exactly one case and no case is unused).
- The owner approved this addition under the 20-12 sign-off rule. It stays at Basic: the approved Basic description
  already covers "which screens and features you use" and "which kinds of errors occur", so no level description
  changes.
- The value is a closed enum spelling only, rendered through the single literal site in
  `AnalyticsSignal+Rendering.swift`, with a dot-namespaced parameter key (no collision with the SDK's flat reserved
  keys) and its spelling pinned in tests like every other key.

### Reader page-image failures (owner decision, 2026-11-21)
- Count once per reading session: within one reader presentation, a given error kind on the reader screen is sent at
  most once, however many pages fail with it.

### Empty results, `.notFound` (owner decision, 2026-11-21)
- Count it as its own kind, everywhere it is shown, including local screens such as History. The screen parameter is
  what lets a dashboard look only at screens loaded from the site. Reason: list parsers return an empty list rather
  than throwing when the page markup changes (`Parser.parseGalleries` only throws when the page carries an explicit
  error banner), so a site break can appear only as `.notFound`.

### Claude's Discretion
- Footer "load more" failures and repeated failures after Retry are counted like any other transition into
  `.failed`; one transition into `.failed` is one signal (a failed state re-assigned with the same error while still
  failed is not a new transition).
- The exact screen case names, the parameter key name, and how the per-session reader de-duplication is held in
  state.
- Whether the two `PresentationFeature` error toasts carry a screen case of their own (for example deepLink) or map
  to an existing one.

</decisions>

<specifics>
## Specific Ideas

- Evidence gathered on 2026-11-21: TelemetryDeck event types for the last 30 days list no `TelemetryDeck.Error.*`
  event and no `TelemetryDeck.Error.*` parameter; `Account.loginFailed` (412 events) and
  `Account.cloudflareChallengeEncountered` (408) do arrive, so delivery itself works.
- `errorSurfaced` renders through the vendor error preset (`.error(id:category:parameters:)` in
  `AnalyticsSignal+Rendering.swift`), which already accepts parameters; the screen parameter rides there.
- `AnalyticsSignal+Level.swift` keeps `errorSurfaced` at Basic.
- The project's analytics privacy rules stay binding: no `String`, URL or content value may enter a payload (D-06,
  D-09); the screen value is a closed enum.
- After this lands, the insights collector's signal catalogue (kept outside this repository) must be re-derived,
  because `AnalyticsClient` changes; that is a follow-up there, not part of this task.

</specifics>

<canonical_refs>
## Canonical References

- `.planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-CONTEXT.md` (D-05, D-06, D-09)
- `.planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-RESEARCH.md` (Family 4 table)
- `.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-12-VOCABULARY.md` (sign-off rule
  for vocabulary changes)
- `AppPackage/Sources/AnalyticsClient/` (vocabulary, rendering, level mapping)
- `AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift`

</canonical_refs>
