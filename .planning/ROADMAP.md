# Roadmap: EhPanda — Dependency Reduction & Modernization (v3.0.0)

## Overview

A foundation milestone that shrinks EhPanda's third-party surface and modernizes its
concurrency, UI architecture, and lint bar ahead of the unreleased v3.0.0 — every task held to
behavior/appearance parity. The journey runs from low-risk isolated dependency swaps, through the
two parity-risk native swaps that are spike-gated first (WaterfallGrid→Layout, SwiftUIPager→TabView),
into the big framework migration (Combine→async/await, TCA traits), then the UI-architecture and
hygiene refactors (adaptive layout, GenericList decomposition, root privacy mask, auto-lock removal,
de-globalized clients) with their folded-in security/test/correctness concerns, and finishing with a
structured error surface and a lint capstone. Refactor-gated lint rules land with the refactors that
enable them; the mechanical rules sweep last.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Isolated Dependency Modernization** - Fork/modernize/replace the third-party deps that don't couple to other work, at parity (completed 2026-07-10)
- [x] **Phase 2: Native Masonry Grid Swap (spike-gated)** - Validate then replace WaterfallGrid with a custom SwiftUI Layout (completed 2026-07-11)
- [x] **Phase 3: Native Reader Paging Swap (spike-gated)** - Validate then replace SwiftUIPager with a native horizontal paging ScrollView (completed 2026-07-12)
- [x] **Phase 4: Concurrency & Framework Migration** - Move requests to async/await and pin TCA with deprecation traits (completed 2026-07-12)
- [ ] **Phase 5: Adaptive Layout & Universal Orientation** - Let size classes and the OS govern layout and rotation; retire screen-metric math and TouchHandler
- [ ] **Phase 6: GenericList Decomposition** - Replace the super-list with per-page lists built from shared atoms
- [ ] **Phase 7: Root Privacy Mask & Auto-Lock Removal** - One shared-state mask per root surface; remove the custom auto-lock for iOS's built-in per-app lock
- [ ] **Phase 8: Architecture Hygiene & Client Seams** - De-globalize Utils into injected clients, move cookies to Keychain, cover reworked seams with tests
- [ ] **Phase 9: Correctness & Structured Error Handling** - Kill the private-category crash and replace silent try? with a user-facing error surface
- [ ] **Phase 10: UI Polish** - Monospaced digits and numeric-text transitions; reduce ZStack in favor of overlay/background
- [ ] **Phase 11: Lint Capstone** - Ratchet SwiftLint to the stricter ruleset at error; mechanical sweep last, refactor-gated rules flipped on

## Phase Details

### Phase 1: Isolated Dependency Modernization

**Goal**: Shrink and modernize the isolated third-party surface — the swaps that don't couple to other work — with behavior parity.
**Depends on**: Nothing (first phase)
**Requirements**: DEP-01, DEP-02, DEP-03, DEP-06, DEP-07
**Success Criteria** (what must be TRUE):

  1. Simplified/Traditional tag conversion (`ChineseConverter`) produces identical output on the forked, modernized SwiftyOpenCC, and the project builds clean on the pinned toolchain.
  2. Dominant-color extraction (`getColors` → primary/secondary/detail/background) is unchanged on the forked, modernized UIImageColors.
  3. Markdown parsing (`MarkdownUtil.parseTexts/parseLinks/parseImages`) yields identical `TagTranslation` output on swift-markdown fixtures, `DetailView` markdown is preserved, and SwiftCommonMark is removed from `Package.swift`.
  4. DeprecatedAPI is gone — the `getCFReadStream` path is inlined warning-free or replaced by a non-deprecated API, with DF networking behavior unchanged.
  5. `GalleryCardCell`'s animated gradient renders as before on the latest Colorful, with the version pin updated.

**Plans**: 7/7 plans executed
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Wave 0 conversion/color fixture lock and simulator validation
- [x] 01-02-PLAN.md — Wave 0 markdown/domain-fronting fixture lock

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-03-PLAN.md — Local SwiftyOpenCC module and FileClient adoption

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-04-PLAN.md — Local UIImageColors module and LibraryClient adoption

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 01-05-PLAN.md — SwiftCommonMark to swift-markdown via MarkdownExt

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 01-06-PLAN.md — DEP-06 domain-fronting evidence checkpoint and conditional DeprecatedAPI handling

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 01-07-PLAN.md — Colorful update and GalleryCardCell gradient parity

### Phase 2: Native Masonry Grid Swap (spike-gated)

**Goal**: Replace WaterfallGrid with a custom SwiftUI `Layout` — validated by a feasibility spike first — with column-balancing and scrolling parity.
**Depends on**: Nothing (independent; may run alongside Phase 1)
**Requirements**: DEP-04
**Success Criteria** (what must be TRUE):

  1. A feasibility spike confirms a custom `Layout` can reproduce masonry column balancing before implementation is committed, or surfaces the blocker.
  2. All cells share one identical flexible width and tile any container width with fixed 15pt spacing; the column count is a pure function of container width (adaptive rule, min cell width 185pt, min 2 columns) — stable against cell-content changes, image loading, and type size. *(Exact 2/4/5 count parity with WaterfallGrid intentionally dropped — owner decision 2026-07-11.)*
  3. Scrolling performance is not regressed.
  4. WaterfallGrid is removed from the dependency set.

**Plans**: 4/4 plans executed
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Test target + pure masonry core (columnCount/cellWidth/masonryPlan) with Swift Testing suite

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Feasibility spike: live candidate wiring, width sign-off table, freeze `m` (SR-1 gate)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-03-PLAN.md — Production swap: finalize MasonryLayout, swap GenericList call site, delete legacy column reads

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 02-04-PLAN.md — Remove WaterfallGrid dependency, regenerate Package.resolved, AboutView acknowledgement decision

**UI hint**: yes

### Phase 3: Native Reader Paging Swap (spike-gated)

**Goal**: Replace SwiftUIPager with a native horizontal paging `ScrollView` for reading — validated by a spike first — preserving all paging UX. *(Construct decided by D-04: a paging `ScrollView`, not a page-style `TabView`, because only `ScrollView` can freeze its own swipe while an image is zoomed.)*
**Depends on**: Nothing (independent; may run alongside Phases 1–2)
**Requirements**: DEP-05
**Success Criteria** (what must be TRUE):

  1. A feasibility spike confirms a native horizontal paging `ScrollView` reaches reading-paging parity (horizontal/RTL/dual-page, page-index mapping, gesture coexistence) before commit, or surfaces the gap.
  2. Reading paging behaves identically: horizontal and RTL direction, dual-page mode, and correct page-index mapping.
  3. Reader gestures (zoom/pan/tap) continue to coexist with paging.
  4. SwiftUIPager is removed from the dependency set.

**Plans**: 5/5 plans executed
Plans:
**Wave 1**

- [x] 03-01-PLAN.md — New ReadingFeatureTests target + PageHandler/containerDataSource pure-mapping suites (Wave 0 guard)
- [x] 03-02-PLAN.md — Home carousel native swap: viewAligned peek/fade/spacing + tripled-buffer infinite loop (D-08)

**Wave 2** *(blocked on 03-01)*

- [x] 03-03-PLAN.md — Reader core: shared @Observable PageModel + horizontal paging ScrollView + vertical AdvancedList re-seam + resume-seed + reducer fan-out

**Wave 3** *(blocked on 03-03)*

- [x] 03-04-PLAN.md — Reader writers: guarded/clamped autoplay + slider + tap-to-turn jumps + zoom/pan/tap coexistence (D-09)

**Wave 4** *(blocked on 03-02 + 03-04)*

- [x] 03-05-PLAN.md — Go/No-Go parity checklist + owner sign-off (D-02 gate) + SwiftUIPager removal & acknowledgement cleanup (D-13)

**UI hint**: yes

### Phase 4: Concurrency & Framework Migration

**Goal**: Move the request layer to async/await and pin TCA with deprecation traits — with request and reducer behavior preserved.
**Depends on**: Phase 2, Phase 3 (migrations sequenced after the native swaps to minimize churn)
**Requirements**: CONC-01, CONC-02
**Success Criteria** (what must be TRUE):

  1. The `NetworkingFeature` request layer returns async results with no `AnyPublisher`, and request behavior and error paths are preserved.
  2. `ApplicationClient`/`AuthorizationClient`/`ImageClient`/`LibraryClient` and all consuming reducer effects are migrated off Combine.
  3. `Package.swift` pins TCA `from: 1.25.3` with the `ComposableArchitecture2Deprecations` + `ComposableArchitecture2DeprecationOverloads` traits.
  4. Zero TCA deprecation warnings remain, and reducers/stores behave identically.

**Plans**: 14/14 plans executed
Plans (sequential waves — xcodebuild invocations must never overlap on this machine):

- [x] 04-01-PLAN.md — Free the `response()` name (facade → `legacyResponse()`) + injectable urlSession seam (D-07)
- [x] 04-02-PLAN.md — Offline harness: counting URLProtocol stub + typed-throws `capture` adapter
- [x] 04-03-PLAN.md — Wave-0 baselines: routine + account families (retry counts, mapAppError table, TagTranslator chain)
- [x] 04-04-PLAN.md — Wave-0 baselines: gallery-list family + gdata plumbing
- [x] 04-05-PLAN.md — Wave-0 baselines: detail + image families (fan-out contract)
- [x] 04-06-PLAN.md — Async engine: typed-throws fetch/retry helper + routine bodies + parity flip
- [x] 04-07-PLAN.md — Account bodies + parity flip
- [x] 04-08-PLAN.md — gdataResponse plumbing + gallery/metadata bodies + parity flips
- [x] 04-09-PLAN.md — Detail + image bodies (task-group fan-out) + parity flips
- [x] 04-10-PLAN.md — Call sites: Home/Search/Favorites → `do throws(AppError)` (D-03)
- [x] 04-11-PLAN.md — Call sites: Detail/Reading/AppFeature
- [x] 04-12-PLAN.md — Call sites: Setting + DownloadClient (final facade consumers)
- [x] 04-13-PLAN.md — Combine teardown: protocol flip, bridge/publisher deletion (D-04), client imports (D-13)
- [x] 04-14-PLAN.md — CONC-02: TCA traits + recon positive control (D-10) + 66-site compiler-inventory migration

### Phase 5: Adaptive Layout & Universal Orientation

**Goal**: Let size classes and the OS govern layout and orientation — retiring screen-metric math, the custom touch handler, and the custom orientation lock — with reading and rotation parity.
**Depends on**: Phase 2, Phase 3, Phase 4 (refines the swapped grid/reader surfaces on top of the migrated code)
**Requirements**: UIARCH-01, UIARCH-03
**Success Criteria** (what must be TRUE):

  1. No view reads `DeviceUtil.window*/screen*/absWindow*` for layout; discrete `isPadWidth`/`isSEWidth` breakpoints are replaced by size-class / container-relative decisions; `GeometryReader` is avoided in favor of `containerRelativeFrame`/`onGeometryChange`/`ViewThatFits`.
  2. `TouchHandler` is retired via `SpatialTapGesture.location` + `MagnifyGesture.startAnchor`, and reading zoom/pan/tap parity is preserved.
  3. `Defaults.FrameSize`/`ImageSize` no longer derive size from a global.
  4. All pages rotate with the device; `AppOrientationMask` masking, `AppDelegateClient.setOrientation*`, the reading `setOrientationPortrait` flow, and `Setting.enablesLandscape` are removed, with the OS orientation lock governing.

**Plans**: 9/10 plans executed
Plans (sequential waves — xcodebuild invocations must never overlap on this machine):

- [x] 05-01-PLAN.md — `DeviceType` + `DeviceClient` reshape to `deviceType()` + reducer/nav idiom swap (D-01/D-03)
- [x] 05-02-PLAN.md — Orientation-lock removal: `AppOrientationMask`/`AppDelegateClient` module + `setOrientationPortrait` flow + `Setting.enablesLandscape` (D-08/D-09/D-10)
- [x] 05-03-PLAN.md — Idiom-view swaps (TabBar/TagSuggestion/SearchKeywords) + EhSetting width/height metrics
- [x] 05-04-PLAN.md — AppComponents metric conversion (AlertView/Placeholder/CategoryView/NewDawnView)
- [x] 05-05-PLAN.md — DetailFeature metric + preview-size `Defaults` dissolution
- [x] 05-06-PLAN.md — HomeFeature carousel `onGeometryChange` coupling + card/ranking widths + idiom (D-07)
- [x] 05-07-PLAN.md — GeometryReader conversions (LoginView/GalleryInfos easy; LiveTextView delicate) (D-06b)
- [x] 05-08-PLAN.md — Reader Wave-0 guard: `GestureHandler` purification + single `onGeometryChange` source + `GestureHandlerTests` + `PageHandler` default removal (D-05)
- [x] 05-09-PLAN.md — Reader source swap: `SpatialTapGesture`/`MagnifyGesture` + D-04 aspect landscape flag + `TouchHandler` deletion (D-04/D-05)
- [ ] 05-10-PLAN.md — Cleanup: `Defaults` dissolution + `ApplicationClient` window rehome + `DeviceUtil` deletion + phase gates

**UI hint**: yes

### Phase 6: GenericList Decomposition

**Goal**: Replace the `GenericList` super-list with per-page lists composed from shared atoms — preserving all list behavior.
**Depends on**: Phase 5 (per-page lists compose the new adaptive layout and custom grid atoms)
**Requirements**: UIARCH-02
**Success Criteria** (what must be TRUE):

  1. Reusable atoms (cells, footer, notice, loading/error overlays, grid) are extracted, and each of the 8 consuming pages composes its own list.
  2. The `GenericList` super-list is removed.
  3. List behavior is preserved: display modes, pagination, refresh, and badges.

**Plans**: TBD
**UI hint**: yes

### Phase 7: Root Privacy Mask & Auto-Lock Removal

**Goal**: Replace `blurRadius` parameter-drilling with one shared-state-driven mask per root surface, and remove the custom auto-lock in favor of iOS's built-in per-app lock — keeping background blur and leaking no content.
**Depends on**: Phase 4 (`AuthorizationClient` is removed after CONC-01 migrates it; the mask lands on migrated code)
**Requirements**: UIARCH-04, UIARCH-05
**Success Criteria** (what must be TRUE):

  1. No view initializer takes `blurRadius`; `.autoBlur` is applied only at root surfaces (app root + each of the ~41 modal roots), driven by shared in-memory state, with no lock-time/background content leak in any modal, and the NavigationBar-collapse workaround preserved.
  2. `Setting.autoLockPolicy`, the biometric re-auth path (`authorize`/`lockApp`/`isAppLocked`/threshold), and `AuthorizationClient` are removed.
  3. The security-section auto-lock control is replaced by a description pointing users to the iOS built-in per-app lock.
  4. Background / app-switcher blur is retained.

**Plans**: TBD
**UI hint**: yes

### Phase 8: Architecture Hygiene & Client Seams

**Goal**: De-globalize the Utils into injected clients and remove singletons, move session cookies to Keychain, and cover the reworked client seams with tests.
**Depends on**: Phase 4, Phase 5 (removes `TouchHandler.shared` after UIARCH-01 retires it; QUAL-02 tests the async `NetworkingFeature` from Phase 4)
**Requirements**: HYG-01, QUAL-01, QUAL-02
**Success Criteria** (what must be TRUE):

  1. The AppTools Utils (Device/Haptics/UserDefaults/File/Cookie) plus `URLUtil` and `AppUtil` are converted to / folded into injected clients; `TouchHandler.shared` and `DataCache.shared` globals are removed; pure value types and constants are retained; no static global helper with side effects remains.
  2. Durable auth cookies are stored via Keychain (within the CookieClient work), and no cookie value is ever emitted to logs at `.public` privacy.
  3. Client-layer tests cover the reworked seams — the async `NetworkingFeature` (from Phase 4), `CookieClient`, and `ImageClient` — and are deterministic and green.

**Plans**: TBD

### Phase 9: Correctness & Structured Error Handling

**Goal**: Remove the private-category crash landmine and replace silent `try?` with structured error handling behind a user-facing error surface.
**Depends on**: Phase 8 (structured error handling applied to the settled client/architecture seams)
**Requirements**: QUAL-03, QUAL-04
**Success Criteria** (what must be TRUE):

  1. `Category.private.filterValue` no longer crashes, no callsite iterating all categories can trap, and a test covers it.
  2. A structured `AppError` (description / suggested solution / typed context) exists; network/file/decode `try?` sites become proper `do/catch`, while genuinely best-effort parsing stays explicitly optional.
  3. User-relevant failures surface via a non-blocking failure toast that opens a dismissable detail surface (Description / Suggested Solution / Context / environment info).
  4. `optional_try` can be enabled at error with zero violations (verified in the lint capstone).

**Plans**: TBD
**UI hint**: yes

### Phase 10: UI Polish

**Goal**: Apply monospaced digits and numeric-text transitions to number-bearing text, and reduce `ZStack` usage in favor of `.overlay`/`.background` where a child overlays/underlays primary content — both at appearance/layout parity.
**Depends on**: Phase 6, Phase 7 (applies to the settled UI surfaces after the Phase 5–7 refactors)
**Requirements**: POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):

  1. Counts, page numbers, sizes, ratings, and similar numeric text use `.monospacedDigit()` and `.contentTransition(.numericText())` where it makes sense.
  2. Numeric values animate as numeric transitions on change.
  3. No layout jitter occurs on value change.
  4. `ZStack`s that express an overlay/background relationship are converted to `.overlay`/`.background` (sized to the primary content) at layout/appearance parity; genuine union-sized multi-child stacks remain `ZStack`.

**Plans**: TBD
**UI hint**: yes

### Phase 11: Lint Capstone

**Goal**: Ratchet SwiftLint to the stricter ruleset at error — the mechanical rules as a final sweep, the refactor-gated rules flipped on now that their refactors have landed — with every violation resolved at its root.
**Depends on**: Phase 5, Phase 6, Phase 7, Phase 9 (refactor-gated rules land with their refactors; the mechanical sweep runs last)
**Requirements**: LINT-01
**Success Criteria** (what must be TRUE):

  1. The mechanical rules (`sorted_imports`, `multiline_function_chains`, `single_line_trailing_closure`, and the new labeled-tuple-elements rule) are enabled at **error** as a capstone sweep, with all violations resolved at root.
  2. The refactor-gated rules (`optional_try`, `binding_initializer`, `lifecycle_modifiers`, `unchecked_subscript_index_access`) — resolved at root during their coupled refactor phases (`optional_try` with Phase 9's structured-error work; the others with the Phase 5–7 UI/architecture refactors) — are switched to **error** with zero remaining violations.
  3. No rule is suppressed, disabled, or bypassed with `// swiftlint:disable`, and the project builds clean under SwiftLint-as-error.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Isolated Dependency Modernization | 9/9 | Complete    | 2026-07-10 |
| 2. Native Masonry Grid Swap | 4/4 | Complete    | 2026-07-11 |
| 3. Native Reader Paging Swap | 5/5 | Complete    | 2026-07-12 |
| 4. Concurrency & Framework Migration | 14/14 | Complete    | 2026-07-12 |
| 5. Adaptive Layout & Universal Orientation | 9/10 | In Progress|  |
| 6. GenericList Decomposition | 0/TBD | Not started | - |
| 7. Root Privacy Mask & Auto-Lock Removal | 0/TBD | Not started | - |
| 8. Architecture Hygiene & Client Seams | 0/TBD | Not started | - |
| 9. Correctness & Structured Error Handling | 0/TBD | Not started | - |
| 10. UI Polish | 0/TBD | Not started | - |
| 11. Lint Capstone | 0/TBD | Not started | - |
