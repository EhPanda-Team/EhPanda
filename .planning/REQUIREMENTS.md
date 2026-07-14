# Requirements: EhPanda — Dependency Reduction & Modernization (v3.0.0)

**Defined:** 2026-07-09
**Core Value:** The load-bearing paths — fetch, parse, read, download — keep working; every task is a foundation change held to **behavior/appearance parity**.

> These are a modernization milestone's requirements: technical and refactor-oriented rather than user-stories. Each carries acceptance criteria that define "done"; unless stated otherwise, **no user-facing regression** is an implicit criterion for all of them.

## v1 Requirements

### DEP — Dependency reduction

- [x] **DEP-01**: Fork SwiftyOpenCC and modernize it — update its OpenCC dependency, package requirement, and Swift version to the latest, rebuilt on the current stack.
  - App depends on the fork; Simplified/Traditional tag conversion (`ChineseConverter`) is unchanged in behavior; builds clean on the pinned toolchain.
- [x] **DEP-02**: Fork UIImageColors and modernize it the same way.
  - App depends on the fork; dominant-color extraction (`getColors` → primary/secondary/detail/background) unchanged; builds clean.
- [x] **DEP-03**: Migrate Markdown from SwiftCommonMark to Apple swift-markdown.
  - `MarkdownUtil.parseTexts/parseLinks/parseImages` reproduced on swift-markdown's `Document`/walker; `TagTranslation` output identical on fixtures; `DetailView` markdown confirmed (render vs parse) and preserved; SwiftCommonMark removed from `Package.swift`.
- [x] **DEP-04**: Replace WaterfallGrid with a custom SwiftUI `Layout`. *(Spike-gated: validate feasibility before committing tasks.)*
  - Grid tiles any container width: all cells share one identical flexible width with fixed 15pt spacing; column count is a pure function of the layout's own container width (adaptive rule `max(2, floor((w + 15) / (185 + 15)))`) and never varies with cell content, image loading, or type size; masonry shortest-column balancing preserved; no `UIScreen`/`DeviceUtil` reads; WaterfallGrid removed; scrolling performance not regressed. *(Exact 2/4/5 count parity with WaterfallGrid intentionally dropped — owner decision 2026-07-11.)*
- [x] **DEP-05**: Replace SwiftUIPager with a native horizontal paging `ScrollView`. *(Spike-gated. Construct decided by D-04: a paging `ScrollView`, not a page-style `TabView`, so it can freeze its own swipe while zoomed.)*
  - Reading paging parity: horizontal/RTL/dual-page, page-index mapping, gesture coexistence; SwiftUIPager removed; if native can't reach parity, spike surfaces it before commit. *(Spike reached parity across all 16 D-11 rows, owner-signed-off 2026-07-12 → spike KEEP, SwiftUIPager removed.)*
- [x] **DEP-06**: Investigate inlining DeprecatedAPI (`getCFReadStream`) into the project without deprecation warnings; adopt a non-deprecated API if actionable.
  - Either the shim is inlined warning-free or a non-deprecated replacement is used; DeprecatedAPI dependency removed; DF networking behavior unchanged.
- [x] **DEP-07**: Migrate to the latest Colorful.
  - `GalleryCardCell` animated gradient renders as before on the current API; version pin updated.

### CONC — Concurrency & framework modernization

- [x] **CONC-01**: Migrate Combine-based requests to async/await.
  - `NetworkingFeature` request layer returns async results (no `AnyPublisher`); `ApplicationClient`/`AuthorizationClient`/`ImageClient`/`LibraryClient` and all consuming reducer effects migrated off Combine; request behavior/error paths preserved.
- [x] **CONC-02**: Pin TCA `from: 1.25.3` with traits `ComposableArchitecture2Deprecations` + `ComposableArchitecture2DeprecationOverloads` and resolve all surfaced deprecations.
  - `Package.swift` updated with traits; zero TCA deprecation warnings remain; reducers/stores behave identically.

### UIARCH — UI architecture

- [x] **UIARCH-01**: Modernize adaptive layout — remove screen-dependent logic across `DeviceUtil` and `DeviceClient`.
  - No view reads `DeviceUtil.window*/screen*/absWindow*` for layout; discrete `isPadWidth`/`isSEWidth` breakpoints replaced by size-class / container-relative decisions; `TouchHandler` retired via `SpatialTapGesture.location` + `MagnifyGesture.startAnchor`; **`GeometryReader` avoided** in favor of `containerRelativeFrame`/`onGeometryChange`/`ViewThatFits`; `Defaults.FrameSize`/`ImageSize` no longer derive size from a global; reading zoom/pan/tap parity preserved.
- [x] **UIARCH-02** *(rescoped — decomposition rejected, owner 2026-07-13)*: Rename the shared gallery list `GenericList` → `GalleryList`; keep the super-list.
  - **Why the decomposition was rejected:** the 8 consuming pages call the list near-identically — 5 are byte-identical; Popular passes no pagination, History adds a synthetic `PageNumber` + a notice, Favorites navigates modally — so splitting the super-list into per-page lists would relocate the shared glue (display-mode switch + loading/error overlay + refresh) into ~8 copies rather than remove duplication. The cells / footer / notice / loading-error overlay / grid atoms already exist as standalone components. **Delivered instead:** keep the single shared list and rename `GenericList` → `GalleryList` (type + file) for clarity, plus the now-stale private `WaterfallList` → `ThumbnailList` (renders via `MasonryLayout` since DEP-04). Behavior/appearance parity; the 8 call sites updated; build + full suite green.
- [x] **UIARCH-03**: Support device orientation on every page and remove EhPanda's custom orientation lock.
  - All pages rotate with the device; `AppOrientationMask` masking, `AppDelegateClient.setOrientation*`, the reading `setOrientationPortrait` flow, and the `Setting.enablesLandscape` field are removed (v1 in-place edit); OS orientation lock governs.
- [x] **UIARCH-04**: Replace `blurRadius` parameter-drilling with a root-level privacy mask.
  - No view initializer takes `blurRadius`; `.autoBlur` applied only at root surfaces — app root + every one of the ~41 modal roots; transient blur state sourced from shared in-memory state; **no lock-time/background content leak** in any modal; per D-03, there is no NavigationBar-collapse blur floor, the shared value is a true `0` when off (no `max(0.00001, radius)`), and a light visual check confirms no collapse at blur `0`.
- [x] **UIARCH-05**: Remove the auto-lock feature and defer re-authentication to iOS's built-in per-app lock.
  - `Setting.autoLockPolicy`, the biometric re-auth path (`authorize`/`lockApp`/`isAppLocked`/threshold), and `AuthorizationClient` are removed; per D-08, the security-section auto-lock control is removed outright with no in-app replacement description, deferring to iOS's built-in per-app lock, which has no Settings URL or API to point to; background blur is retained (see UIARCH-04).

### HYG — Architecture hygiene

- [ ] **HYG-01**: De-globalize `*Util` into injected clients and remove singletons.
  - The AppTools Utils (Device/Haptics/UserDefaults/File/Cookie) plus `URLUtil` and `AppUtil` are converted to / folded into injected clients; `TouchHandler.shared` and `DataCache.shared` globals removed; pure value types and constants retained; no remaining static global helper with side effects.

### QUAL — Correctness, security & tests

- [ ] **QUAL-01**: Audit cookie logging.
  - No cookie value is ever emitted to logs at `.public` privacy; the former at-rest migration was dropped per D-01 as out of milestone rather than deferred.
  - D-06 tightens HYG-01: retain `URLUtil` and `AppUtil` as pure namespaces rather than converting them to clients, in keeping with the anti-wrapper rule.
- [ ] **QUAL-02**: Add client-layer test coverage for the reworked seams.
  - `NetworkingFeature` covered (during CONC-01); `CookieClient` and `ImageClient` covered (during HYG-01); tests are deterministic and green.
- [ ] **QUAL-03**: Fix the `Category.private.filterValue` `fatalError` landmine.
  - `filterValue` no longer crashes for `.private`; no callsite iterating all categories can trap; covered by a test.
- [ ] **QUAL-04**: Replace silent `try?` with structured error handling and a user-facing error surface (gates the `optional_try` rule).
  - A structured `AppError` (description / suggested solution / typed context) exists; user-relevant failures surface via a non-blocking failure toast that opens a detailed, dismissable error surface (Description / Solution / Context / environment info); network/file/decode `try?` sites become proper `do/catch`; genuinely best-effort parsing stays explicitly optional (not every one prompts); `optional_try` can be enabled at error with zero violations.

### POLISH — UI polish

- [ ] **POLISH-01**: Apply `.monospacedDigit()` + `.contentTransition(.numericText())` to most number-bearing text.
  - Counts, page numbers, sizes, ratings, and similar numeric text use monospaced digits and animate as numeric transitions where it makes sense; no layout jitter on value change.
- [ ] **POLISH-02**: Reduce `ZStack` usage in favor of `.overlay`/`.background`.
  - `ZStack`s that express an overlay/background relationship (a child layered over or under primary content) become `.overlay`/`.background`, sized to the primary content, at layout/appearance parity; genuine union-sized multi-child stacks stay `ZStack`; no visual or layout regressions.

### LINT — Lint hardening

- [ ] **LINT-01**: Enable the stricter SwiftLint ruleset at error level.
  - The 5 commented custom rules (`binding_initializer`, `lifecycle_modifiers`, `optional_try`, `single_line_trailing_closure`, `unchecked_subscript_index_access`), opt-in `multiline_function_chains` & `sorted_imports`, and a new labeled-tuple-elements rule are all enabled at **error**; every violation resolved at its root (no suppressions); mechanical rules land as a capstone sweep, refactor-gated rules (`optional_try`→QUAL-04, plus binding/lifecycle/unchecked-subscript) land with their refactors.

## v2 Requirements

None. Deferred work is captured under Out of Scope (future milestone), not staged as v2 here.

## Out of Scope

| Feature | Reason |
|---------|--------|
| ParserFeature complexity refactor (per-field sub-parsers) | Real value but rides on nothing else this milestone; deferred to a future milestone |
| DownloadClient decomposition | Large standalone refactor; deferred |
| Client-layer tests beyond networking/cookie/image (Reading/Home/Search/Favorites) | Deferred; this milestone covers only seams already being reworked |
| Post-release v2 schema migrations + migration-mock cleanup | Models stay at v1 until v3.0.0 ships; first real v2 is post-release |
| Any visual redesign | UI-architecture tasks are mechanism swaps, not re-skins; parity required |
| Re-enabling `function_body_length` / `cyclomatic_complexity` / `type_body_length` | Kept disabled; `ParserFeature` relies on it; not requested |

## Traceability

<!-- Populated during roadmap creation. -->

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEP-01 | Phase 1 | Complete |
| DEP-02 | Phase 1 | Complete |
| DEP-03 | Phase 1 | Complete |
| DEP-04 | Phase 2 | Complete |
| DEP-05 | Phase 3 | Complete |
| DEP-06 | Phase 1 | Complete |
| DEP-07 | Phase 1 | Complete |
| CONC-01 | Phase 4 | Complete |
| CONC-02 | Phase 4 | Complete |
| UIARCH-01 | Phase 5 | Complete |
| UIARCH-02 | Phase 6 | Complete (rescoped — decomposition rejected) |
| UIARCH-03 | Phase 5 | Complete |
| UIARCH-04 | Phase 7 | Complete |
| UIARCH-05 | Phase 7 | Complete |
| HYG-01 | Phase 8 | Pending |
| QUAL-01 | Phase 8 | Pending |
| QUAL-02 | Phase 8 | Pending |
| QUAL-03 | Phase 9 | Pending |
| QUAL-04 | Phase 9 | Pending |
| POLISH-01 | Phase 10 | Pending |
| POLISH-02 | Phase 10 | Pending |
| LINT-01 | Phase 11 | Pending |

**Coverage:**

- v1 requirements: 22 total
- Mapped to phases: 22 ✓
- Unmapped: 0

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-07-13 — UIARCH-02 rescoped: `GenericList` decomposition rejected (owner); delivered as a `GenericList`→`GalleryList` rename instead (22/22 mapped)*
