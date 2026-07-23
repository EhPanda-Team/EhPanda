# Phase 13: Deep Link Hardening - Context

**Gathered:** 2026-07-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Code-review the deep-link implementation and resolve its hacky/fragile spots at root, at
**unchanged destination-routing behavior** for currently-supported links; make malformed or
unresolvable links fail gracefully (no crash, no unrecoverable silent no-op); and back the
supported routes with end-to-end UI automation tests (launch/foreground via a deep link →
land on the correct destination screen).

Scope anchor is **ROADMAP.md §Phase 13's three success criteria**. Naming note: the
ROADMAP's `AppRouteReducer.swift` is today's
`AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` (Phase 9 rename).

**The deep-link surface** (verified by code scout, 2026-07-23):

- **Entries** — four paths converge on the same downstream:
  1. `ehpanda://` custom scheme (`Info.plist` `CFBundleURLSchemes`) → `onOpenURL` in
     `TabBarView` → `PresentationFeature.handleDeepLink`;
  2. ShareExtension — rewrites a shared gallery URL's scheme to `ehpanda` and opens the app;
  3. clipboard detection on cold launch / foreground (`detectClipboardURL`) → same handler;
  4. in-app gallery links tapped in the Comments view (`CommentsReducer.handleCommentLink`).
- **Routes** — plain gallery `/g/<gid>/<token>`, single-page `/s/<token>/<gid>-<page>`,
  comment fragment `#c<commentID>`, on `e-hentai.org` / `exhentai.org`.
- **Shared downstream** — every entry constructs
  `DetailReducer.State(gallery:, pendingDeepLink:)`; the route-specific landing is decided
  at the single consumption site `DetailReducer+Fetch.swift:58` once the detail loads.
- There are **no universal links** (no associated-domains entitlement) — adding them would
  be a new capability, out of scope.

**Locked routing contract (parity — criterion 1).** Confirmed with the owner during
discussion, applies to every deep-link entry with no exception:
- `/g/` gallery link → detail page only (comments entry pushes it; scheme/share/clipboard
  entries present it modally per the Phase 5 locked baseline).
- `/s/` page link → detail page, then the reader auto-presents at the linked page (reading
  progress pre-seeded to `@Shared(.galleryHistory)`).
- `#c` comment link → detail page, then Comments pushed scrolled to the linked comment.
- Deep links never skip the detail page and jump straight to the reader.
- Non-deep-link navigation (e.g. the Downloads gallery-cell tap) is untouched by this phase.

</domain>

<decisions>
## Implementation Decisions

### Malformed-link failure UX (criterion 3)
- **D-01:** An **explicit** open (`ehpanda://` scheme or ShareExtension hand-off) that
  cannot be recognized as a gallery link surfaces the Phase 9 error path: persistent
  tappable toast → `ErrorInfoView` with the URL and reason. The current silent no-op for
  explicit opens is the criterion-3 defect being fixed.
- **D-02:** **Clipboard** URLs that are not gallery links stay a **silent no-op** — the
  user never asked the app to open them; toasting would be noise. Only a recognized
  gallery link that then fails to resolve gets the error toast (as today).
- **D-03:** The unrecognized-link failure gets a **dedicated `AppError` case** (e.g.
  `unsupportedDeepLink`) with its own localized description and a recovery suggestion
  telling the user what links EhPanda can open — the Phase 12 D-10 precedent for genuinely
  new, user-actionable failure kinds. New `.xcstrings` keys follow the repo's localization
  conventions (labeled numeric arguments; non-translated keys filled for every locale).
- **D-04:** A well-formed gallery link whose fetch fails keeps the **existing error
  mapping** — `GalleryReverseRequest`'s `AppError` flows into the toast → `ErrorInfoView`
  with URL context. No deep-link-specific cause differentiation.

### UI test harness (criterion 2)
- **D-05:** A **new XCUITest UI-testing bundle target** in `EhPanda.xcodeproj` — the
  project's first UI automation infrastructure (all 18 existing test targets are SPM
  unit-test bundles). Deep links are delivered with the modern system-open API
  (`XCUIDevice.shared.system.open`) for both cold-launch and warm-foreground variants.
- **D-06:** Tests run **hermetically**: a launch-environment flag makes the app swap in
  stubbed gallery responses (fixture data) so tests are deterministic, offline, and need
  no credentials. The stub seam's exact shape is planner detail; the thing under test —
  routing — stays real.
- **D-07:** The UI test target joins a **second test plan (e.g. `UITests.xctestplan`) on
  the existing `EhPanda` scheme**. `FeatureTests.xctestplan` (all unit tests) stays the
  default plan, so everyday `xcodebuild test` stays unit-only; UI tests run on demand via
  `-testPlan`.
- **D-08:** **iPhone is the primary simulator matrix.** iPad gets targeted coverage only
  for iPad-exclusive code paths (e.g. the `presentGalleryDetail` tab-modal entry).

### Test route coverage
- **D-09:** Matrix density is **full on scheme, smoke elsewhere** (~8 UI tests): all three
  routes (`/g/` → detail; `/s/` → detail + reader at page; `#c` → detail + Comments at
  comment) plus the malformed-link error-toast test run via `ehpanda://` scheme opens,
  each in cold-launch and warm-foreground variants; clipboard, share sheet, and
  comments-view entries each get **one representative happy-path test**. Rationale: all
  entries converge on the shared consumption site (`DetailReducer+Fetch.swift:58`), so
  per-entry coverage only needs to prove the arrival leg.
- **D-10:** The ShareExtension entry is tested **true E2E through the real share sheet**
  (XCUITest drives Safari, opens the share sheet, taps the EhPanda extension, asserts the
  app lands on detail). Owner chose this over split coverage knowing share-sheet
  automation is the flakiest XCUITest kind — the planner budgets retries/waits for it.

### Parsing hardening
- **D-11:** **Full `URLComponents` rebuild** of URL recognition/analysis: exact host
  matching, path-component route parsing, fragment-based `#c` extraction,
  optional-returning gallery-ID parsing (no more empty-string-on-failure). Closes the
  spoofable `absoluteString.contains(...)` host check
  (`https://evil.com/g/123/token?ref=https://e-hentai.org/` passes today).
- **D-12:** Recognized hosts are **`e-hentai.org`, `exhentai.org`, plus their `www.`
  variants**. `www.` links are real-world share targets that today fail silently;
  accepting them is a durability fix in the phase's spirit, and the exact-match check is
  still stricter overall than today's substring check.
- **D-13:** The `URLClient` **injected dependency is replaced by a pure parser type**
  (URL in → route/gid/token/page/commentID out), per the Phase 8 D-06 precedent that pure
  deterministic helpers are namespaces/values, not clients. Kills the `noop`/
  `unimplemented` ceremony; tests exercise real parsing. Call sites in
  `PresentationFeature`, `CommentsReducer`, `DetailReducer`, and `ReadingFeature`
  (`checkIfMPVURL`) migrate.
- **D-14:** **Both magic-number sleeps are root-fixed** with deterministic coordination:
  the 1000ms modal-dismissal wait in `handleDeepLink` (gates navigation correctness — a
  slow dismissal can race the re-present) and the 500ms loading-toast → error-toast gap
  (in both `PresentationFeature` and `CommentsReducer`). No timing-based sequencing
  remains in the routing path.

### Claude's Discretion
- The stub seam's mechanism for D-06 (how the launch-environment flag swaps dependencies
  inside the app process) and the fixture gallery content.
- The deterministic-coordination mechanism replacing each sleep (D-14) — e.g. driving the
  re-present from the dismissal completion seam, and whether the toast library exposes a
  dismissal hook or the gap is re-expressed as an explicit animation hand-off.
- The pure parser type's name and module home (D-13), within repo conventions.
- Accessibility identifiers or other assertion hooks the UI tests need on destination
  screens.
- `ErrorInfo` context rows carried by the new `AppError` case (Phase 9 D-06 precedent:
  planning detail).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authoritative scope
- `.planning/ROADMAP.md` §"Phase 13: Deep Link Hardening" — the 3 success criteria (the
  scope contract). Note the `AppRouteReducer.swift` → `PresentationFeature.swift` rename.

### The deep-link implementation (the code under review)
- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` — the modal
  deep-link/clipboard entry: `handleDeepLink` (1000ms sleep, D-14), `detectClipboardURL`,
  `handleGalleryLink`, `fetchGallery/-Done` (500ms sleep, D-14), `presentGalleryDetail`
  (the iPad-exclusive tab-modal entry, D-08).
- `AppPackage/Sources/DetailFeature/GalleryDeepLink.swift` — the deferred-intent enum
  (`.reading(page:)` / `.comments(commentID:)`) and its precedence initializer.
- `AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift` (≈line 58) — the single
  shared `pendingDeepLink` consumption site that decides the route landing; the locked
  routing contract in `<domain>` describes exactly this code.
- `AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift` —
  `handleCommentLink` (non-handleable → opens in browser via `applicationClient`),
  `handleGalleryLink`, its own 500ms toast sleep (D-14).
- `AppPackage/Sources/DetailFeature/GalleryNavigation.swift` — turns the
  `.pushDetail(gallery:deepLink:)` delegate into the pushed detail carrying
  `pendingDeepLink`.
- `AppPackage/Sources/URLClient/URLClient.swift` — the parsing being rebuilt (D-11/D-13):
  `checkIfHandleable` (substring host check), `analyzeURL` (manual string ranges),
  `parseGalleryID` (empty-string failure), `resolveAppSchemeURL`, `checkIfMPVURL`.
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` — the `onOpenURL` entry
  (line ≈104).
- `ShareExtension/ShareViewController.swift` — the scheme-rewrite hand-off the D-10 E2E
  test drives.
- `AppPackage/Sources/AppTools/Defaults.swift` §URL — `ehentai`/`exhentai` host constants
  (D-12's parity anchor).
- `App/Info.plist` — the `ehpanda` `CFBundleURLSchemes` registration.

### Test infrastructure
- `AppPackage/Tests/FeatureTests.xctestplan` — the single existing test plan (all 18 SPM
  unit targets); stays the default plan beside the new D-07 UI plan.
- `EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme` — the single shared scheme
  whose `<TestPlans>` block gains the second plan.

### Error machinery (extended, conventions unchanged)
- `AppPackage/Sources/AppModels/Support/AppError.swift` — the enum gaining the D-03 case;
  description/`recoverySuggestion`/`ErrorInfo` conventions from Phase 9.
- `.planning/phases/09-correctness-structured-error-handling/09-CONTEXT.md` — the
  error-surface conventions (toast → `ErrorInfoView`, per-site presentation at the owning
  reducer) that D-01/D-03 build on.

### Project rules that constrain this phase
- `CLAUDE.md` (repo root) — `Feature`-suffix reducer naming, SwiftLint-read-first +
  no-suppression rule, labeled localized-format arguments, non-translated keys filled for
  every locale.
- `.swiftlint.yml` (repo root) — all Phase 11 rules live at error; new code (UI test
  target included, via its module `.swiftlint.yml` per AGENTS.md) must be clean from the
  start.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 9 error machinery** — `AppError` description/solution structure,
  `ErrorInfoView`, persistent tappable failure toast: D-01/D-03 extend it exactly the way
  Phase 12's `cloudflareChallengeFailed` did.
- **`GalleryDeepLink` + `pendingDeepLink`** — the deferred-intent mechanism itself is
  sound and already centralized; hardening targets its feeding (URL parsing) and its
  hosts' timing hacks, not the enum.
- **Phase 12's stub/fixture patterns** — synthetic fixtures and per-test isolation
  precedents for the D-06 hermetic stubs.

### Established Patterns
- **Presentation-driven lifecycle (Phase 11, `lifecycle_modifiers` at error)** — the
  deep-link path already sends `.onPresented` from reducers; any new coordination (D-14)
  must stay reducer-driven, no view `onAppear`.
- **Pure helpers as namespaces, not clients (Phase 8 D-06)** — the D-13 parser reshape
  applies this locked decision to `URLClient`.
- **Modal deep-link baseline (Phase 5)** — deep-link/URL/clipboard gallery entries
  present modally, device-independent; the phase preserves this.
- **Typed `throws(AppError)` request layer (Phase 4)** — the new failure case rides the
  existing shape.

### Integration Points
- **`DetailReducer+Fetch.swift:58`** — the single shared consumption site; the D-09 test
  matrix's density argument rests on it staying single.
- **`state.detail(.dismiss)` → `path.removeAll()`** — the modal-replacement flow the
  1000ms sleep papers over; the deterministic re-present (D-14) coordinates here.
- **New XCUITest target ↔ app process** — the D-06 launch-environment stub seam is the
  only test-only surface added to the app target; it must not leak into release behavior.
- **Privacy-mask roots (Phase 7)** — if any new presentation root appears during fixes,
  the 39-root reconciliation must be updated (none is expected).

</code_context>

<specifics>
## Specific Ideas

- **"No exception in deep links"** — the owner's routing rule: every deep-link entry
  lands on the detail page first; the reader may only appear after it (page links), and
  non-deep-link navigation (Downloads cell tap) keeps its own behavior untouched.
- **Share sheet tested for real** — the owner explicitly wants the ShareExtension leg
  driven through the actual share sheet, accepting the flake cost (D-10).
- **Recovery suggestion names what works** — the D-03 error should tell the user what
  kinds of links EhPanda can open, mirroring Phase 12's "fail toward the alternatives"
  approach.

</specifics>

<deferred>
## Deferred Ideas

- **Universal links (associated domains)** — opening `https://e-hentai.org/...` links
  directly from other apps without the `ehpanda://` scheme would be a new capability for
  a future phase; this phase covers only the existing scheme/share/clipboard entries.
- **MPV route support** — `/mpv/` URLs are recognized by `checkIfMPVURL` for the reader's
  internal use but are not an openable deep-link route today; adding them as one would be
  new capability, not hardening.

</deferred>

---

*Phase: 13-Deep Link Hardening*
*Context gathered: 2026-07-23*
