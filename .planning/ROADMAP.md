# Roadmap: EhPanda — Dependency Reduction & Modernization (v3.0.0)

## Overview

A foundation milestone that shrinks EhPanda's third-party surface and modernizes its
concurrency, UI architecture, and lint bar ahead of the unreleased v3.0.0 — every task held to
behavior/appearance parity. The journey runs from low-risk isolated dependency swaps, through the
two parity-risk native swaps that are spike-gated first (WaterfallGrid→Layout, SwiftUIPager→TabView),
into the big framework migration (Combine→async/await, TCA traits), then the UI-architecture and
hygiene refactors (adaptive layout, GenericList→GalleryList rename, root privacy mask, auto-lock removal,
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
- [x] **Phase 5: Adaptive Layout & Universal Orientation** - Let size classes and the OS govern layout and rotation; retire screen-metric math and TouchHandler (completed 2026-07-13)
- [x] **Phase 6: GalleryList Rename** - Keep the shared gallery list (decomposition rejected) and rename `GenericList` → `GalleryList` (completed 2026-07-13)
- [x] **Phase 7: Root Privacy Mask & Auto-Lock Removal** - One shared-state mask per root surface; remove the custom auto-lock for iOS's built-in per-app lock (completed 2026-07-14)
- [x] **Phase 8: Architecture Hygiene & Client Seams** - De-globalize side-effecting Utils, audit cookie logging, and cover reworked seams with tests (completed 2026-07-14)
- [x] **Phase 9: Correctness & Structured Error Handling** - Kill the private-category crash and replace silent try? with a user-facing error surface (completed 2026-07-16)
- [x] **Phase 10: UI Polish** - Monospaced digits and numeric-text transitions; reduce ZStack in favor of overlay/background
- [x] **Phase 11: Infra Refactor & Lint Capstone** - Resolve infra-level refactors (incl. test-isolation cleanup), then ratchet SwiftLint to the stricter ruleset at error; mechanical sweep last, refactor-gated rules flipped on
- [x] **Phase 12: Cloudflare Login Restoration** - Restore username/password login broken by the Cloudflare wall: detect the challenge, clear it in an in-app browser, replay login with an in-memory cf_clearance (completed 2026-07-23)
- [x] **Phase 13: Deep Link Hardening** - Code-review the deep-link implementation and make it less hacky and more durable at navigating to the correct destination; add UI automation tests covering deep-link navigation (completed 2026-07-23)
- [x] **Phase 14: Analytics Instrumentation (TelemetryDeck)** - Add privacy-first analytics via the TelemetryDeck SDK — on by default with a runtime opt-out in General Settings (D-01 reversed) — instrumenting key user flows (completed 2026-07-27)
- [ ] **Phase 15: Continued Background Downloads** - Adopt `BGContinuedProcessingTask` so a user-started gallery download keeps running after backgrounding, with the system-provided progress UI
- [ ] **Phase 16: Dynamic Type Accessibility** - Complete full-range Dynamic Type readability/operability (AX1–AX5) on the Phase 10 font/reflow foundation — human-implemented, agent verify-only

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

**Plans**: 18/18 plans executed
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
- [x] 05-10-PLAN.md — Cleanup: `Defaults` dissolution + `ApplicationClient` window rehome + `DeviceUtil` deletion + phase gates

**Gap closure** (from UAT G-05-1 blocker + G-05-4 major — sequential waves 11–18):

- [x] 05-11-PLAN.md — G-05-1.1: About copyright/version → scrollable Form content (visible in landscape)
- [x] 05-12-PLAN.md — G-05-1.2: reader loading/failed placeholders sized against both container axes
- [x] 05-13-PLAN.md — G-05-1.3: Home carousel is the sole card-width owner (drop GalleryCardCell inner sizing)
- [x] 05-14-PLAN.md — G-05-1.4 + G-05-1.5 (locked): remove page-range visible prompt (a11y kept) + untitled `Button(role: .cancel)` on reusable sheets
- [x] 05-15-PLAN.md — G-05-1.6: Favorites toolbar regrouping + explicit date-seek availability
- [x] 05-16-PLAN.md — G-05-4.7: reader upper toolbar respects iPad window-control safe geometry
- [x] 05-17-PLAN.md — G-05-4.8 + G-05-4.9 (locked): distinct Home root surface + disable multi-scene support
- [x] 05-18-PLAN.md — G-05-4.10: investigate-then-fix iPhone detail push contract (human-surface fallback)

**UI hint**: yes

### Phase 6: GalleryList Rename

**Goal**: Keep the shared gallery list and rename it `GenericList` → `GalleryList` — at behavior/appearance parity. *(Decomposition rejected — owner 2026-07-13.)*
**Depends on**: Nothing (mechanical rename; independent of other phases)
**Requirements**: UIARCH-02 *(rescoped — decomposition rejected)*
**Success Criteria** (what must be TRUE):

  1. `GenericList` is renamed to `GalleryList` (type + file) and all 8 call sites are updated.
  2. The stale private `WaterfallList` is renamed to `ThumbnailList` (it renders via `MasonryLayout` since DEP-04).
  3. List behavior is unchanged — display modes, pagination, refresh, badges — and the build + full test suite pass.

**Why decomposition was rejected**: the 8 consuming pages call the list near-identically (5 byte-identical; Popular passes no pagination; History adds a synthetic page number + notice; Favorites navigates modally). Splitting the super-list into per-page lists would relocate the shared glue (display-mode switch + loading/error overlay + refresh) into ~8 copies rather than remove duplication, and the cell / footer / notice / overlay / grid atoms already exist as standalone components. The honest change is to keep one well-named shared list.

**Delivered**: 2026-07-13 — rename committed (`43da047d`); build + full suite green. No plan pipeline (mechanical). Formal phase close-out follows Phase 5 verification.
**Plans**: none (mechanical rename)
**UI hint**: no

### Phase 7: Root Privacy Mask & Auto-Lock Removal

**Goal**: Replace `blurRadius` parameter-drilling with one shared-state-driven mask per root surface, and remove the custom auto-lock in favor of iOS's built-in per-app lock — keeping background blur and leaking no content.
**Depends on**: Phase 4 (`AuthorizationClient` is removed after CONC-01 migrates it; the mask lands on migrated code)
**Requirements**: UIARCH-04, UIARCH-05
**Success Criteria** (what must be TRUE):

  1. No view initializer takes `blurRadius`; `.autoBlur` is applied only at root surfaces (app root + each of the ~41 modal roots), driven by shared in-memory state, with no lock-time/background content leak in any modal; per D-03, there is no `max(0.00001, radius)` blur floor, the shared value is a true `0` when off, and a light visual check confirms no NavigationBar collapse at blur `0` on the current iOS 26 stack.
  2. `Setting.autoLockPolicy`, the biometric re-auth path (`authorize`/`lockApp`/`isAppLocked`/threshold), and `AuthorizationClient` are removed.
  3. Per D-08, the security-section auto-lock control is removed outright with no in-app replacement description, deferring re-authentication to iOS's built-in per-app lock, which has no Settings URL or API to point to.
  4. Background / app-switcher blur is retained.

**Plans**: 12/12 plans executed
boundary via the mask-swap-first + vestigial-param technique; xcodebuild builds must not overlap on
this machine)
Plans:

**Wave 1**

- [x] 07-01-PLAN.md — Foundation: privacyMaskBlur shared key + self-sourcing .privacyMask() modifier + new Privacy Mask l10n keys

**Wave 2** *(blocked on 07-01)*

- [x] 07-02-PLAN.md — Part-B core: Setting rename + AutoLockPolicy removal + scenePhase fold (Pitfall 1) + General Security section removal + Appearance relocation

**Wave 3** *(blocked on 07-02)*

- [x] 07-03-PLAN.md — App-root teardown: TabBarView masks + lock-button removal + delete AppLockReducer/AuthorizationClient + Package.swift + Face ID Info.plist + dead l10n

**Wave 4** *(blocked on 07-03)*

- [x] 07-04-PLAN.md — HomeFeature + FavoritesFeature: blurRadius param removal + .privacyMask() swap

**Wave 5** *(blocked on 07-04)*

- [x] 07-05-PLAN.md — SearchFeature + DownloadsFeature: blurRadius param removal + .privacyMask() swap

**Wave 6** *(blocked on 07-05)*

- [x] 07-06-PLAN.md — DetailFeature: 13 mask sites + GalleryDestination drilling unwound

**Wave 7** *(blocked on 07-06)*

- [x] 07-07-PLAN.md — ReadingFeature + SettingFeature + new AppActivityLogs mask site (D-16); delete autoBlur (final Part-A)

**Wave 8** *(blocked on 07-07)*

- [x] 07-08-PLAN.md — Verification: AppFeatureTests scenePhase test + automated D-16 coverage/orphan audit + blocking human leak sweep

**Gap Closure** *(from 07-VERIFICATION.md — 6/11 must-haves; re-verify after execute)*

**Wave 9**

- [x] 07-09-PLAN.md — GAP-1 (BLOCKER): scene-phase mask writes + background latch independent of hasLoadedInitialSetting; pre-settings TestStore regression (threat T-07-20)
- [x] 07-11-PLAN.md — GAP-3 + WR-03: remove Download Inspector duplicate mask + one-to-one 39-root coverage inventory; Reduce-Motion-aware PrivacyMaskModifier
- [x] 07-12-PLAN.md — GAP-4 (docs-only): reconcile ROADMAP/REQUIREMENTS acceptance wording to locked D-03 (true-zero/no-floor) & D-08 (auto-lock removed, no pointer)

**Wave 10** *(blocked on 07-09)*

- [x] 07-10-PLAN.md — GAP-2 + WR-04: exhaustive exactly-once greeting/clipboard tests (drop withExhaustivity(.off)); drop AppFeatureTests direct ComposableArchitecture dep

**UI hint**: yes

### Phase 8: Architecture Hygiene & Client Seams

**Goal**: De-globalize side-effecting Utils into injected clients, retain pure helper namespaces, remove singletons, audit cookie logging, and cover the reworked client seams with tests.
**Depends on**: Phase 4, Phase 5 (removes `TouchHandler.shared` after UIARCH-01 retires it; QUAL-02 tests the async `NetworkingFeature` from Phase 4)
**Requirements**: HYG-01, QUAL-01, QUAL-02
**Success Criteria** (what must be TRUE):

  1. Side-effecting AppTools Utils are converted to / folded into injected clients; `URLUtil` and `FileUtil` retain only pure namespace responsibilities per D-06; `AppUtil`, `TouchHandler.shared`, and `DataCache.shared` are removed; no static global helper with side effects remains.
  2. No cookie value is ever emitted to logs at `.public` privacy; the former at-rest migration was dropped per D-01 as out of milestone rather than deferred.
  3. Client-layer tests cover the reworked seams — the async `NetworkingFeature` (from Phase 4), `CookieClient`, and `ImageClient` — and are deterministic and green.

**Plans**: 18/18 plans executed
Plans:
**Wave 1**

- [x] 08-01-PLAN.md — QUAL-01 rescope: reconcile ROADMAP/REQUIREMENTS to logging-audit-only (D-01) + cookie-logging static gate (D-02)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 08-02-PLAN.md — Seam A.1: URLUtil builders + Defaults.URL host-taking helpers (transitional bridge, D-03/D-06)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 08-03-PLAN.md — Seam A.2: Request+Gallery structs + list reducers thread explicit host (D-03)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 08-04-PLAN.md — Seam A.3: Setting-consumed account requests + Setting host reads thread host (D-03)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 08-05-PLAN.md — Seam A.4: Detail-consumed account requests + CookieClient.apiuid(host:) (D-03, Open-Q3)

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 08-06-PLAN.md — Seam A.5: Image/GData/Metadata/Torrents + setSkipServer + Parser host drain (D-03)

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 08-07-PLAN.md — Seam A.6: the 12 AppUtil.galleryHost view/reducer reads → setting.galleryHost (D-03/D-04)

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 08-08-PLAN.md — Seam A.7: teardown — delete host global + AppUtil.galleryHost + UserDefaults mirror (D-03)

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 08-09-PLAN.md — Seam D: DataCache DependencyKey + purge-observer rebind + consumers resolve \.dataCache (D-08)

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 08-10-PLAN.md — Seam F.image: ImageClientTests target (per-test cache, pixel dims) (QUAL-02, D-09/D-10)

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 08-11-PLAN.md — Seam F.cookie: CookieClientTests target (full didLogin/setCredentials/... matrix) (QUAL-02, D-10)

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 08-12-PLAN.md — Seam B.cookie: delete CookieUtil + migrate 12 login-gated view sites (D-04/D-05)

**Wave 13** *(blocked on Wave 12 completion)*

- [x] 08-13-PLAN.md — Seam B.haptics/ud: fold HapticsUtil + UserDefaultsUtil into their clients (D-05)

**Wave 14** *(blocked on Wave 13 completion)*

- [x] 08-14-PLAN.md — Seam C: eliminate AppUtil + relocate version/build/isTesting + AuthorizationClient cleanup (D-06/D-07)

**Gap Closure** *(from 08-VERIFICATION.md — 4 code gaps; the 3 xcodebuild plans run sequentially per the no-overlapping-xcodebuild rule; re-verify after execute)*

**Wave 15**

- [x] 08-15-PLAN.md — GAP-01 (HYG-01, blocker): carry originating GalleryHost through `refetchNormalImageURLsDone` → `setSkipServer`; host-switch-while-pending ReadingReducer regression
- [x] 08-18-PLAN.md — GAP-04 (QUAL-01, blocker): harden `check-cookie-logging.sh` against aliased-value/renamed-Logger evasions + executable negative-fixture harness (clean tree still exits 0); no xcodebuild — runs parallel

**Wave 16** *(sequenced after 08-15 to serialize xcodebuild)*

- [x] 08-16-PLAN.md — GAP-02 (HYG-01, blocker): carry originating GalleryHost through `fetchEhProfileIndexDone`/`createDefaultEhProfile`; suspended-request SettingReducer regression

**Wave 17** *(sequenced after 08-16 to serialize xcodebuild)*

- [x] 08-17-PLAN.md — GAP-03 (HYG-01, blocker): make `UserDefaultsClient` read a `@Sendable` endpoint (clipboardChangeCount); both-way substitutability AppRoute reducer test

### Phase 9: Correctness & Structured Error Handling

**Goal**: Remove the private-category crash landmine and replace silent `try?` with structured error handling behind a user-facing error surface.
**Depends on**: Phase 8 (structured error handling applied to the settled client/architecture seams)
**Requirements**: QUAL-03, QUAL-04
**Success Criteria** (what must be TRUE):

  1. `Category.private.filterValue` no longer crashes, no callsite iterating all categories can trap, and a test covers it.
  2. A structured `AppError` (description / suggested solution / typed context) exists; network/file/decode `try?` sites become proper `do/catch`, while genuinely best-effort parsing stays explicitly optional.
  3. User-relevant failures surface via a non-blocking failure toast that opens a dismissable detail surface (Description / Suggested Solution / Context / environment info).
  4. `optional_try` can be enabled at error with zero violations (verified in the lint capstone).

**Plans**: 13/13 plans executed
Plans:

**Wave 1**

- [x] 09-01-PLAN.md — AppError structured merge: AnyHashableBox + Context/ContextKey/ErrorInfo + solution + LocalizedError + Wave-0 tests (QUAL-04)

**Wave 2** *(sequenced to serialize xcodebuild)*

- [x] 09-02-PLAN.md — QUAL-03: Category.private.filterValue fatalError → reportIssue + return 0 + withExpectedIssue test

**Wave 3** *(sequenced to serialize xcodebuild)*

- [x] 09-03-PLAN.md — Failure surface: ErrorInfoView (native Form, redacted) + AppAlertState ErrorInfo-bearing toast + View+Toast onErrorTap (QUAL-04)

**Wave 4** *(sequenced to serialize xcodebuild)*

- [x] 09-04-PLAN.md — Routing: AppRouteReducer → PresentationFeature + .errorInfo(ErrorInfo) + tappable failure toast + TabBarView sheet + route test (QUAL-04)

**Wave 5** *(sequenced to serialize xcodebuild)*

- [x] 09-05-PLAN.md — try? sweep: FileClient (8) + NetworkingFeature (9) (QUAL-04)

**Wave 6** *(sequenced to serialize xcodebuild)*

- [x] 09-06-PLAN.md — try? sweep: DownloadClient part 1 (DownloadStore + Operations, 16) (QUAL-04)

**Wave 7** *(sequenced to serialize xcodebuild)*

- [x] 09-07-PLAN.md — try? sweep: DownloadClient part 2 (validation/networking/execution, ~20) (QUAL-04)

**Wave 8** *(sequenced to serialize xcodebuild)*

- [x] 09-08-PLAN.md — try? sweep: AppTools (DataCache fire-and-forget + Extensions/Defaults, 17) (QUAL-04)

**Wave 9** *(sequenced to serialize xcodebuild)*

- [x] 09-09-PLAN.md — try? sweep: ParserFeature (44, documented decode-with-default survivors) (QUAL-04)

**Wave 10** *(sequenced to serialize xcodebuild)*

- [x] 09-10-PLAN.md — try? sweep: LogsClient/LibraryClient/ImageClient + SettingFeature activity-logs (17) (QUAL-04)

**Wave 11** *(sequenced to serialize xcodebuild)*

- [x] 09-11-PLAN.md — try? sweep tail (JSONValue probes + view/markdown) + phase gate: residual audit + full suite + SwiftLint clean (QUAL-04)

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 09-12-PLAN.md — Privacy-safe gallery diagnostic context with route-aware `/g` and `/s` token redaction regressions (QUAL-04)

**Wave 13** *(blocked on Wave 12 completion)*

- [x] 09-13-PLAN.md — Persistent native accessible diagnostic toast with exactly-once lifecycle tests (QUAL-04)

**UI hint**: yes

### Phase 10: UI Polish

**Goal**: Apply monospaced digits and numeric-text transitions to number-bearing text, reduce `ZStack` usage in favor of `.overlay`/`.background` where a child overlays/underlays primary content, and land the accompanying UI-modernization sweeps (deprecated-API removal, custom corner-modifier removal, `\.inSheet` removal, Label conversions, `SystemNotificationExt` module rename, `#Preview` migration) — all at appearance/layout parity. **Comprehensive Dynamic Type support is deferred to Phase 16 (Dynamic Type Accessibility)**; a font-scaling + reflow foundation was delivered here in plans 10-10/10-11.
**Depends on**: Phase 6, Phase 7 (applies to the settled UI surfaces after the Phase 5–7 refactors)
**Requirements**: POLISH-01, POLISH-02, POLISH-03
**Success Criteria** (what must be TRUE):

  1. Counts, page numbers, sizes, ratings, and similar numeric text use `.monospacedDigit()` and `.contentTransition(.numericText())` where it makes sense.
  2. Numeric values animate as numeric transitions on change.
  3. No layout jitter occurs on value change.
  4. `ZStack`s that express an overlay/background relationship are converted to `.overlay`/`.background` (sized to the primary content) at layout/appearance parity; genuine union-sized multi-child stacks remain `ZStack`.
  5. *(Deferred to Phase 16 — Dynamic Type Accessibility.)* Every user-facing screen remains readable and operable throughout the complete Dynamic Type range, including accessibility sizes, without clipped essential text, overlapping content, or unreachable controls. **Foundation delivered** in 10-10 (7 fixed-pixel font sites scaled) and 10-11 (B1–B10 AX5 reflows, verified on-device); the remaining cosmetic AX5 edge cases, full accessibility-range readability/operability, and the owner-signed device UAT are deferred to Phase 16 for human implementation.
  6. The `\.inSheet` environment value is removed, with any presentation-context logic it drove reimplemented via a native/non-custom-environment mechanism.
  7. Deprecated SwiftUI APIs (e.g. `.foregroundColor` → `.foregroundStyle`) are swept and replaced with their current non-deprecated equivalents, at appearance parity, with no new SwiftLint or compiler deprecation warnings.
  8. The custom `cornerRadius(_:corners:)` view modifier in `ViewModifiers.swift` is removed, with its call site(s) replaced by the standard SwiftUI API (`.clipShape(.rect(cornerRadii:))`), at appearance parity.
  9. Call sites passing an empty string literal to a view (e.g. `Text("")`, `Label("", ...)`) are audited: each is replaced with a meaningful string, or the label is hidden where an empty string was standing in for "no label," at unchanged app behavior.
  10. All buttons using a plain text-plus-image combination in their label closure are audited and converted to `Label(_:systemImage:)`/`Label(_:image:)` where fitting, at appearance/layout parity. For toolbar buttons specifically, this audit also covers text-only and image-only labels, converting them to `Label` where fitting.
  11. The `SystemNotificationExt` module is renamed to `SystemNotification` (it contains the full implementation, not a thin extension), with every import/reference updated accordingly.
  12. Every legacy `_Previews: PreviewProvider` struct is migrated to the `#Preview` macro, and previews are enriched to exercise all realistic states as named `#Preview("…")` cases (empty / loading / loaded / error, boundary values such as min/max ratings, counts, page numbers, and long vs. short text), using modern preview features — `@Previewable` for interactive state, preview traits (e.g. `.sizeThatFitsLayout`), and environment/Dynamic Type/color-scheme variants where useful. No `PreviewProvider` remains in the codebase.

**Plans**: 12/12 plans executed
Plans:
**Wave 1**

- [x] 10-01-PLAN.md — SystemNotificationExt → SystemNotification parity rename (criterion 11)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 10-02-PLAN.md — Deprecated color-modifier sweep: foregroundStyle + tint (criterion 7)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 10-03-PLAN.md — Corner/autocorrection/status-bar sweep + custom cornerRadius(_:corners:) removal (criteria 7, 8)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 10-04-PLAN.md — \.inSheet removal via userInterfaceLevel trait, owner-gated delta checkpoint (criterion 6)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 10-05-PLAN.md — Label conversions + empty-string audit (criteria 9, 10)

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 10-06-PLAN.md — ZStack → overlay/background with per-site verdicts + D-11 spot-checks (POLISH-02)

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 10-07-PLAN.md — Paired numeric text on the D-05 changing-value set (POLISH-01)

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 10-08-PLAN.md — #Preview migration: stateful cells/components, full state matrix (POLISH-03)

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 10-09-PLAN.md — #Preview migration: remaining 34 screens, global zero-legacy gate (POLISH-03)

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 10-10-PLAN.md — Fixed-font remediation + whole-app Dynamic Type audit at XXL/AX3/AX5 (criterion 5)

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 10-11-PLAN.md — Dynamic Type reflow fixes (never cap) + default-size parity (criterion 5)

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 10-12-PLAN.md — Full suite + phase grep battery (criteria 1-4, 6-12) + ProgressView tint-regression fix; criterion-5 D-03 Dynamic Type device UAT deferred to Phase 16

**Cross-cutting constraints:**

- Previews stay at the default environment — no DT/color-scheme variants, no pinned size or scheme (D-09)

**UI hint**: yes

### Phase 11: Infra Refactor & Lint Capstone

**Goal**: Resolve the infra-level refactors gating the stricter SwiftLint ruleset — including test-isolation cleanup — then ratchet SwiftLint to error: the mechanical rules as a final sweep, the refactor-gated rules flipped on now that their refactors have landed, with every violation resolved at its root.
**Depends on**: Phase 5, Phase 6, Phase 7, Phase 9 (refactor-gated rules land with their refactors; the mechanical sweep runs last)
**Requirements**: LINT-01
**Success Criteria** (what must be TRUE):

  1. **MET.** The mechanical rules (`sorted_imports`, `multiline_function_chains`, `single_line_trailing_closure`, and the new `labeled_tuple_elements` rule) are enabled at **error** as a capstone sweep, with all violations resolved at root. The refactor-gated rules were not "already resolved" as the original goal assumed — see criterion 2.
  2. **MET, with a scope correction.** The refactor-gated rules (`optional_try`, `binding_initializer`, `lifecycle_modifiers`, `unchecked_subscript_index_access`) are at **error** with zero remaining violations. The premise that they had been "resolved at root during Phases 5–7/9" was **not true at HEAD** — ~127 `try?`, ~30 `Binding(` and ~46 lifecycle sites remained, plus 240 subscript matches — so resolving them was Phase 11 work, not a flip of already-clean code.
  3. **MET as amended (D-02).** No rule is suppressed, disabled, or bypassed with an **unapproved** `// swiftlint:disable` — every surviving disable carries an owner-reviewed `// reason:` comment — and the project builds clean under SwiftLint-as-error for both source and test targets. **8 exceptions total**, all inventoried in `11-EXCEPTIONS.md` for batch review: 6 `lifecycle_modifiers` and 2 `unchecked_subscript_index_access`. The other six rules shipped with **zero** exceptions.
  4. **MET structurally; the parallelism yield fell short of the framing.** `.serialized` is gone entirely (0 traits across 18 targets, all 41 removed by injection per D-12), and the full 565-test suite runs in parallel. `@MainActor` was swept across all 50 annotated files with every survivor compiler-required at member scope — but **157 of 186 cases (84%) remain main-actor-isolated**, a floor set by TCA's `TestStore`, not by annotation hygiene. D-13's yield is **17 cases and no measurable wall-clock change**; there is nothing left to sweep.

**Not achieved as originally written** (detail in `11-EXCEPTIONS.md` §7):

  - **11-02's must-have is inert.** "An unparseable gallery-list page throws instead of rendering as an empty list" cannot hold: D-04 Group A's `Parser.degrading` helper makes every row-level failure non-throwing, so the `try?`→`try` conversion changed nothing observable. Inventing an "empty means malformed" heuristic was correctly declined — it would throw on legitimately-empty search results. Needs an owner decision.
  - **D-09 is half-done.** `PreviewSupport` ships and five cell fixtures use it, but `AppModels`' shared fixtures (`Gallery.preview`, `previews(count:)`, `mockGalleries`) still mint random `UUID()`, and four of the five fixed files render `Gallery.preview` in their first preview. Giving `AppModels` a `PreviewSupport` dependency is an architectural call, deliberately deferred.
  - **There is no network seam.** `NetworkingFeature` request types take `urlSession: URLSession = .shared` as an init default (50 sites) and reducers never pass one, so a `TestStore` cannot stub a fetch. This limited coverage in plans 11-07 through 11-10 and 11-15. Structural, not an oversight.

**Plans**: 32/32 plans executed

Plans:
**Wave 1**

- [x] 11-01-PLAN.md — ParserFeature `try?` Groups A/B → do/catch + logger (D-04 A/B)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 11-02-PLAN.md — ParserFeature Group C propagation + thrown-error test updates (D-03/D-04 C)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 11-03-PLAN.md — DownloadClient `try?` part 1: store/persistence cluster

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 11-04-PLAN.md — DownloadClient `try?` part 2: validation/networking/execution

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 11-05-PLAN.md — AppTools + AppModels `try?` (JSONValue probe chain preserved)

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 11-06-PLAN.md — Remaining Sources `try?` (9 modules) + Sources-wide zero audit

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 11-07-PLAN.md — Lifecycle migration: Home/Search/Favorites (D-06/D-07)

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 11-08-PLAN.md — Lifecycle migration: DetailFeature (all entry paths)

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 11-09-PLAN.md — Lifecycle migration: ReadingFeature (parity-critical)

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 11-10-PLAN.md — Lifecycle migration: Setting/Filters/Downloads

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 11-11-PLAN.md — Component lifecycle + flip `lifecycle_modifiers` & narrowed `binding_initializer` (D-05)

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 11-12-PLAN.md — PreviewSupport module: stable UUID table + checked subscript (D-09)

**Wave 13** *(blocked on Wave 12 completion)*

- [x] 11-13-PLAN.md — Subscript safety: ReadingFeature (61) (D-08)

**Wave 14** *(blocked on Wave 13 completion)*

- [x] 11-14-PLAN.md — Subscript safety: ParserFeature (43)

**Wave 15** *(blocked on Wave 14 completion)*

- [x] 11-15-PLAN.md — Subscript safety: DownloadClient + NetworkingFeature (41)

**Wave 16** *(blocked on Wave 15 completion)*

- [x] 11-16-PLAN.md — Subscript safety: ImageColors checked idiom, fixtures unchanged (D-16)

**Wave 17** *(blocked on Wave 16 completion)*

- [x] 11-17-PLAN.md — Subscript safety: remaining modules + flip `unchecked_subscript_index_access`

**Wave 18** *(blocked on Wave 17 completion)*

- [x] 11-18-PLAN.md — Labeled tuple types + new `labeled_tuple_elements` rule + flip (D-10/D-11)

**Wave 19** *(blocked on Wave 18 completion)*

- [x] 11-19-PLAN.md — FileClient injectable-root seam + parallel FileClientTests (D-12)

**Wave 20** *(blocked on Wave 19 completion)*

- [x] 11-20-PLAN.md — Kingfisher cache seam + ImageClientTests trait + DidLoginKeyTests rationale (D-12/D-14)

**Wave 21** *(blocked on Wave 20 completion)*

- [x] 11-21-PLAN.md — DownloadsFeatureTests per-suite `.serialized` diagnosis + removal (D-12/D-14)

**Wave 22** *(blocked on Wave 21 completion)*

- [x] 11-22-PLAN.md — `@MainActor` sweep: DownloadsFeatureTests (27 files) (D-13)

**Wave 23** *(blocked on Wave 22 completion)*

- [x] 11-22.1-PLAN.md — `@MainActor` sweep: remaining targets + full-suite parallel gate (D-13)

**Wave 24** *(blocked on Wave 23 completion)*

- [x] 11-23-PLAN.md — Tests `try?`: DownloadsFeatureTests (D-15)

**Wave 25** *(blocked on Wave 24 completion)*

- [x] 11-24-PLAN.md — Tests `try?` tail + flip `optional_try` (no Tests exclusion, D-15)

**Wave 26** *(blocked on Wave 25 completion)*

- [x] 11-25-PLAN.md — `sorted_imports` autocorrect + flip + config hygiene

**Wave 27** *(blocked on Wave 26 completion)*

- [x] 11-26-PLAN.md — `single_line_trailing_closure`: Sources rewrap

**Wave 28** *(blocked on Wave 27 completion)*

- [x] 11-27-PLAN.md — `single_line_trailing_closure`: Tests rewrap + flip

**Wave 29** *(blocked on Wave 28 completion)*

- [x] 11-28-PLAN.md — `multiline_function_chains` reformat + flip

**Wave 30** *(blocked on Wave 29 completion)*

- [x] 11-29-PLAN.md — Capstone gate: seven-rule zero-check + parallel suite + 11-EXCEPTIONS.md owner-review inventory

**Wave 31** *(gap closure from 11-UAT.md — the two plans are independent and run in parallel)*

- [x] 11-30-PLAN.md — G-11-7 (blocker): restore DetailList's trailing-row fetch-more trigger; return the D-36 geometry heuristic to thumbnail-only scope
- [x] 11-31-PLAN.md — G-11-8 (cosmetic): reassert relative icon scale on the six `titleAndIcon` Labels that replaced icon+text stacks

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14 → 15

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Isolated Dependency Modernization | 9/9 | Complete    | 2026-07-10 |
| 2. Native Masonry Grid Swap | 4/4 | Complete    | 2026-07-11 |
| 3. Native Reader Paging Swap | 5/5 | Complete    | 2026-07-12 |
| 4. Concurrency & Framework Migration | 14/14 | Complete    | 2026-07-12 |
| 5. Adaptive Layout & Universal Orientation | 18/18 | In Progress|  |
| 6. GalleryList Rename | — | Delivered (rescoped) | 2026-07-13 |
| 7. Root Privacy Mask & Auto-Lock Removal | 12/12 | Complete    | 2026-07-14 |
| 8. Architecture Hygiene & Client Seams | 18/18 | Complete    | 2026-07-14 |
| 9. Correctness & Structured Error Handling | 13/13 | Complete    | 2026-07-16 |
| 10. UI Polish | 12/12 | In Progress|  |
| 11. Infra Refactor & Lint Capstone | 32/32 | Complete    | 2026-07-22 |
| 12. Cloudflare Login Restoration | 6/6 | Complete    | 2026-07-23 |
| 13. Deep Link Hardening | 10/10 | Complete    | 2026-07-23 |
| 14. Analytics Instrumentation (TelemetryDeck) | 18/18 | Complete    | 2026-07-27 |
| 15. Continued Background Downloads | 51/53 | In Progress|  |

### Phase 12: Cloudflare Login Restoration

**Goal**: Restore the broken username/password login: detect the Cloudflare challenge on the login POST, clear it through an in-app `WKWebView` the user can interact with, capture `cf_clearance` in memory only, and replay the login POST — leaving the other two login methods (in-app web login, manual cookie entry) unchanged.
**Requirements**: None mapped — the scope contract is this phase's five success criteria (C1–C5), referenced by plans as C-labels
**Depends on**: Phase 11
**Success Criteria** (what must be TRUE):

  1. Username/password login succeeds end-to-end against the live Cloudflare-fronted forums host.
  2. Challenge detection is dynamic per-response, not assumed per-host: an HTTP 403 with the `cf-mitigated: challenge` header routes into the clearance flow; any non-challenged response proceeds through the existing login path with no extra UI (the no-wall case).
  3. On challenge, an in-app `WKWebView` surface loads the challenged URL; the moment `cf_clearance` appears in the web view's cookie store it auto-dismisses and the login POST retries — covering both the interactive wall and a wall that auto-passes with zero user interaction (the surface closes itself).
  4. The retried login POST carries the captured `cf_clearance` and the challenge-solving web view's exact `User-Agent` (Cloudflare binds the clearance to the UA); with a valid clearance, the existing credential-cookie handling (`setCredentials`, `didLogin`) proceeds unchanged.
  5. `cf_clearance` lives in memory only and is never persisted across app launches. Expiration needs no timer: a retried POST that is challenged again re-presents the challenge surface (bounded retries), then fails through the structured `AppError` surface.

**Evidence (2026-07-20)**: GET and POST on `forums.e-hentai.org/index.php?act=Login` both return `403` + `cf-mitigated: challenge`; `e-hentai.org` / `exhentai.org` currently pass unchallenged (though `server: cloudflare`), so detection must stay response-driven.

**Plans**: 6/6 plans executed

Plans (sequential waves — xcodebuild invocations must never overlap on this machine):

- [x] 12-01-PLAN.md — AppModels foundation: `AppError.cloudflareChallengeFailed` + l10n keys, `CloudflareClearance` type + in-memory session key (D-06/D-10)
- [x] 12-02-PLAN.md — NetworkingFeature: generic `isCloudflareChallenge` classifier + clearance-carrying `LoginRequest` variant, with detection/header tests (D-04/D-05/D-07)
- [x] 12-03-PLAN.md — `ChallengeWebView` cookie-observing WKWebView wrapper (non-persistent store) + `LoginClient` dependency seam
- [x] 12-04-PLAN.md — LoginReducer challenge state machine (bounded rounds, cancel, toast) + LoginView challenge/error sheets (D-01/D-02/D-03/D-09/D-11)
- [x] 12-05-PLAN.md — `LoginChallengeFlowTests`: exhaustive TestStore coverage of pass-through, rounds, capture, session pair, cancel silence
- [x] 12-06-PLAN.md — Privacy-mask inventory reconciliation + static/full-suite gates + blocking owner live-login UAT (C1)

### Phase 13: Deep Link Hardening

**Goal**: Code-review the current deep-link implementation (`GalleryDeepLink.swift`, `AppRouteReducer.swift`) and make it less hacky and more durable at navigating the user to the correct destination screen, backed by UI automation tests.
**Depends on**: Phase 11
**Requirements**: None mapped — the scope contract is this phase's three success criteria, referenced by plans as SC-labels
**Success Criteria** (what must be TRUE):

  1. The deep-link implementation's hacky/fragile spots (identified by code review) are resolved at root, at unchanged destination-routing behavior for currently-supported links.
  2. UI automation tests exercise deep-link navigation end-to-end (launch/foreground via a deep link → land on the correct destination screen) for the app's supported deep-link routes.
  3. Malformed or unresolvable deep links fail gracefully (no crash, no silent no-op the user can't recover from).

**Plans**: 10/10 plans executed

Plans (sequential waves — xcodebuild invocations must never overlap on this machine):

- [x] 13-01-PLAN.md — Pure `GalleryURLParser` in AppTools + new AppToolsTests suite (D-11/D-12/D-13 core)
- [x] 13-02-PLAN.md — `AppError.unsupportedDeepLink` + 6-locale l10n + sanitized link context (D-03)
- [x] 13-03-PLAN.md — Migrate all URLClient call sites to the parser; delete the URLClient module (D-13, parity)
- [x] 13-04-PLAN.md — Entry-source policy: explicit-open failure toast, clipboard silence (D-01/D-02) + ShareExtension URLComponents rewrite (F8)
- [x] 13-05-PLAN.md — D-14a: dismissal-completion coordination replaces the 1000ms modal sleep
- [x] 13-06-PLAN.md — D-14b: identity-keyed toast replacement removes both 500ms loading→error sleeps
- [x] 13-07-PLAN.md — App-side test preparation: DEBUG URLProtocol stub seam + clipboard override + EhPandaApp arm point (D-06) + accessibility identifiers on destination screens
- [x] 13-08-PLAN.md — First XCUITest target + UITests.xctestplan + fixtures + cold-delivery probe + hermetic smoke (D-05/D-07)
- [x] 13-09-PLAN.md — Scheme matrix: /g/, /s/, #c + malformed × cold/warm — 8 UI tests (D-09)
- [x] 13-10-PLAN.md — Entry representatives: clipboard, comments link, real share sheet (D-10), iPad tab-modal (D-08) + phase test gate

### Phase 14: Analytics Instrumentation (TelemetryDeck)

**Goal:** Add privacy-first analytics via the TelemetryDeck SDK — on by default with a runtime opt-out in General Settings (D-01 reversed) — instrumenting key user flows behind a closed, type-enforced signal vocabulary
**Requirements**: ANALYTICS-01
**Depends on:** Phase 13
**Plans:** 18/18 plans complete

Plans:
**Wave 1**

- [x] 14-01-PLAN.md — SPM dependency, AnalyticsClient module, all three new test targets, D-08 bucket vocabulary, ANALYTICS-01
- [x] 14-02-PLAN.md — Owner decision checkpoint for the five open questions (D-15…D-19)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 14-03-PLAN.md — Closed vocabulary + the two audited content-reduction types + AppErrorKind
- [x] 14-04-PLAN.md — Build-time app-ID plumbing: xcconfig → Info.plist → AppInfo accessor

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 14-05-PLAN.md — AnalyticsSignal enum and its rendering layer (the single String-minting site)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 14-06-PLAN.md — AnalyticsClient with the D-13 gate and D-11 global default parameters

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 14-07-PLAN.md — Harden DownloadsFeatureTests against the unimplemented analytics default
- [x] 14-08-PLAN.md — Harden SettingFeatureTests
- [x] 14-09-PLAN.md — Harden AppFeatureTests, HomeFeatureTests, DetailFeatureTests, ReadingFeatureTests

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 14-10-PLAN.md — AppFeature: SDK init, tab opens, modal gallery detail, user-visible errors
- [x] 14-11-PLAN.md — HomeFeature: five sections, gallery-detail push, sub-screen panels
- [x] 14-12-PLAN.md — Search, QuickSearch and Favorites, plus the two search-family emission suites
- [x] 14-13-PLAN.md — DetailFeature: tag taps, download start/retry/delete, detail-search panels
- [x] 14-14-PLAN.md — ReadingFeature: one bucketed end-of-session signal
- [x] 14-15-PLAN.md — DownloadsFeature: edge-triggered completion/failure, delete, move
- [x] 14-16-PLAN.md — SettingFeature: classified login failures and Cloudflare encounters

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 14-17-PLAN.md — README disclosure, roadmap/requirements bookkeeping, conditional lint rule

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 14-18-PLAN.md — Phase verification: static sweeps plus the two manual-only checks

**Cross-cutting constraints:**

- The unimplemented default still applies to every target not touched here, so an unexpected analytics call outside the hardened targets still fails loudly

### Phase 15: Continued Background Downloads

**Goal**: Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps running when the app is backgrounded, surfaced by the system-provided progress UI, instead of being cut short by the short grace period that bounded the previous behavior.
**Depends on**: Phase 14
**Requirements**: None mapped — the scope contract is this phase's four success criteria, referenced by plans as SC-labels
**Success Criteria** (what must be TRUE):

  1. A download started in the foreground continues to completion after the app is backgrounded, for a queue large enough to outlast the `beginBackgroundTask` grace period that bounds today's behavior.
  2. The system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving download state consistent with an in-app cancel.
  3. Submission is treated as best-effort and there is **no fallback tier**: when the system refuses the request, queues it indefinitely, or expires it, downloads suspend with the process and resume on the next foreground, with no lost or duplicated work and no user-visible error. The discretionary processing-task path and the UIKit execution assertion are deleted outright rather than fallen back to.
  4. The new capability is reached through a testable client seam in the `BackgroundProcessingClient` module exposing a continued-processing **session** API — start, update-progress, complete, with events on a self-finishing stream — with `testValue` unimplemented, so no reducer **or coordinator** touches the system task scheduler directly.

**Resolved in discuss-phase**: the continued-processing task *fully replaces* both the discretionary processing-task path and the execution assertion; neither survives as a secondary tier. The seam stays domain-general in shape, but downloads are its only call site this milestone. `Info.plist` keeps its background-modes declaration and swaps its permitted-identifier entry to the bundle-scoped continued-processing wildcard, so the entitlement surface remained an edit rather than a new capability.

**Plans**: 51/53 plans executed

Plans:

- [x] 15-50-PLAN.md
- [x] 15-51-PLAN.md
- [ ] 15-52-PLAN.md
- [ ] 15-53-PLAN.md

**Wave 1**

- [x] 15-01-PLAN.md — Info.plist continued-processing identifier + AppFeature discretionary-path deletion

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 15-02-PLAN.md — Delete the execution assertion, the drain loop, and their façade endpoints

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 15-03-PLAN.md — Rebuild BackgroundProcessingClient as a main-actor-confined session seam

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 15-04-PLAN.md — Neutral card strings, coordinator injection, session client spy

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 15-05-PLAN.md — Coordinator session lifecycle and the four queue-mobilizing tap sites

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 15-06-PLAN.md — Progress push, completion reconcile, expiration and unavailable coverage

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 15-07-PLAN.md — Topology invariant, roadmap amendment, phase gates and device observation

**Wave 8** *(gap closure — after Wave 7)*

- [x] 15-08-PLAN.md — Session store: cancel abandoned requests, identity-check adoption, store regression suite

**Wave 9** *(gap closure — blocked on 15-08; serialization only, no code dependency — xcodebuild invocations must never overlap on this machine)*

- [x] 15-09-PLAN.md — Coordinator: session-id-stamped teardown and the convergence-point cancel route

**Wave 10** *(gap closure round 2 — blocked on 15-09: real code dependency on the 15-09 session-id lifecycle)*

- [x] 15-10-PLAN.md — Promote the store's session identity into the seam (session handle from start, id-taking finish) and thread it through every completion path, the pause loop, and the progress push; store-side identity regression cases

**Wave 11** *(blocked on 15-10 — real code dependency plus xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-11-PLAN.md — Coordinator identity regressions in a new suite: the drain-then-second-tap interleave, refusal rollback, and the foreign-expiration pause-all gate

**Wave 12** *(gap closure round 3 — blocked on 15-11: real code dependency on the identified seam, plus xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-12-PLAN.md — Seed the start snapshot into the client seam so an adopted task never reports 0 / 0, and give every progress push the client session id the store checks before applying it

**Wave 13** *(blocked on 15-12 — serialization plus a light code dependency on the threaded session identities)*

- [x] 15-13-PLAN.md — Route the vanished-record delete branch through observer notification and the scheduling convergence point, and collapse the duplicated schedulable-work predicate onto one authority

**Wave 14** *(blocked on 15-13 — real code dependency: the expiration pause loop reads the extracted schedulable-work authority)*

- [x] 15-14-PLAN.md — Per-gallery queue-intent generations, an expiration pause that abandons its writes when a newer user action lands and converges afterwards, and a blocking test fixture that cannot leak

**Wave 15** *(blocked on 15-14 — real code dependency: the cases stage on the new fixture control and assert the new guard)*

- [x] 15-15-PLAN.md — The gated expiration-versus-user-action interleave regressions, replacing the foreign-id case that never entered the suspension window

**Wave 16** *(blocked on 15-15 — serialization plus sequencing; contains a blocking owner decision)*

- [x] 15-16-PLAN.md — Owner disposition of the unread background-processing dependency registration, and the end-of-phase device verification handoff

**Wave 17** *(gap closure round 4 — blocked on 15-16 by sequencing; xcodebuild invocations must never overlap on this machine)*

- [x] 15-17-PLAN.md — Defer reconciliation while a client start is in flight so coordinator ownership is never surrendered without a client id, bind the session spy to the live single-session contract and triage the suite behind it, and correct the documentation describing the deleted dependency API

**Wave 18** *(blocked on 15-17 — real code dependency: the new regressions assert session liveness through the deferred-reconciliation contract and run under the corrected spy)*

- [x] 15-18-PLAN.md — State the active-ownership convergence invariant once and satisfy it on every enumerated exit path that clears ownership, with a parameterised failure-injected regression across both delete entry points and both error shapes

**Wave 19** *(blocked on 15-18 — file overlap in the public API, folders and scheduling sources, plus xcodebuild serialization)*

- [x] 15-19-PLAN.md — Remove gallery titles from unified logs, hash-mask identifiers, reclassify every error, description and response-body disclosure in the module, and add a permanent scan that fails the build if any of it returns

**Wave 20** *(gap closure round 5, UAT gap G-15-2 — blocked on 15-19 by xcodebuild serialization)*

- [x] 15-20-PLAN.md — Replace the shrinking progress basis with a session-scoped retirement ledger so a completed gallery keeps its pages on both sides of the fraction, and re-derive the three committed expectations that encoded the defect

**Wave 21** *(blocked on 15-20 — real code dependency: the cases assert the new ledger, and they extend the suite file 15-20 creates)*

- [x] 15-21-PLAN.md — Prove the retirement rule on every other departure path: pause and delete retire only finished pages, a resumed gallery is counted once, and the suite fails when the ledger's contribution is removed

**Wave 22** *(gap closure round 6, UAT gap G-15-2B — blocked on 15-21 by file overlap in the continued-session suites and by xcodebuild serialization)*

- [x] 15-22-PLAN.md — Emit one terminal progress push in the drain branch before the session ends, ordered after the client-session deferral and before the teardown, and replace the synthesized terminal pushes with production-path drains across every exit path

**Wave 23** *(gap closure round 7, review gap G-15-3 — blocked on 15-22 by file overlap in the drain branch and its suites, and by xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-23-PLAN.md — Re-validate drain-ness (not just session identity) behind the terminal push's main-actor hop so a mid-hop mobilization can never lose the session, correct the doc comment that named the wrong suspension, make the client-seam spy suspend like the live seam, and sweep every teardown site against the invariant

**Wave 24** *(gap closure round 7, review gap G-15-4 — blocked on 15-23 by file overlap in DownloadClient+ContinuedSession.swift and the continued-session suites, plus xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-24-PLAN.md — Count a complete-reading record as zero session pages until the session observes it doing real work, so a queued update/redownload can never open the card at its own ceiling; gate the retirement's record read on the same observed-incomplete trust set, and re-derive the one case whose literals encoded the defect

**Wave 25** *(gap closure round 8, review gap G-15-5 — blocked on 15-24 by file overlap in DownloadClient+ContinuedSession.swift and the ledger suite, plus xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-25-PLAN.md — Make the repair's own working-seed preparation mark its record incomplete by blanking manifest hashes for vanished page files, and have the run announce that post-preparation basis to the session before any page work (D-G5-01, both halves), so a repair of a complete-reading record is guaranteed to earn trust through the existing basis — deterministically even at one missing page — and its card climbs instead of pinning at zero; prove the K=1 arc end to end on production-issued pushes with the pre-fix pinned-zero observed

**Wave 26** *(gap closure round 9, review gap G-15-6 — blocked on 15-25 by file overlap in DownloadClient+ContinuedSession.swift, DownloadClient+ExecutionSupport.swift and the ledger suite, plus xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-26-PLAN.md — Withdraw a coordinator-made basis correction from the monotonic floor in the same synchronous stretch that lowers the basis (D-G6-01): the reconciliation gives back exactly the counted portion it blanked — an untrusted complete-reading record withdraws nothing, preserving D-G4-01 — and the session-start seed merges the scalar instead of re-installing the pre-hop total, so a frozen-at-the-pre-correction-total card can no longer outlive the correction; prove the reachable case (the reconciled gallery departs without re-earning, the survivor's next pushes advance) with the pre-fix frozen band observed, and close WR-01 (the schedulable authority unions the active gallery), WR-02 (the silent seed preparation goes private), and WR-03 (the storage.validate consequence documented) in the same pass

**Wave 27** *(gap closure round 11, review gap G-15-10 — blocked on 15-26 by xcodebuild serialization; test-double fidelity lands before the regressions that lean on it)*

- [x] 15-27-PLAN.md — Split the session spy's refusal guard so the one-shot refusal arm is consumed only by the refusal it causes (a live-session guard refusal leaves the arm held), audit every refuseNextStart caller against the changed rule, and pin the armed-refusal-versus-overlapping-start race with a case observed failing first

**Wave 28** *(gap closure round 11, review gap G-15-11 — blocked on 15-27 by xcodebuild serialization; also restores the 999-line file's headroom every later plan needs)*

- [x] 15-28-PLAN.md — Drop the nine public session-lifecycle mutators to internal (zero production callers outside DownloadClient, verified) and route the six the suites use through thin #if DEBUG testing forwarders in the module's established seam; first relocate the expiration-and-teardown case family out of the 999-line DownloadContinuedSessionTests.swift so the re-spell cannot trip the 1000-line file_length error gate

**Wave 29** *(gap closure round 11, review gap G-15-7 — blocked on 15-28: the counted-record regressions drive the preparation through the seam 15-28 chooses; file overlap on the execution-support and continued-session sources)*

- [x] 15-29-PLAN.md — Key the floor withdrawal on the basis MOVEMENT instead of the blanking mechanism (D-G7-01): a non-async bracket reads the index record before and after the preparation (and the enqueue route's initial-manifest write) and withdraws max(before−after, 0) when the basis was counting, so a .redownload/.update of a counted gallery, a validatedManifest mismatch, and every unenumerated future mover are excused by construction; remove the per-mechanism withdrawal from the reconciliation, correct both single-mover doc premises, sweep every downloadIndex writer with dispositions (deletions stay the retirement ledger's), and stage three counted-record regressions with the pre-fix frozen bands observed

**Wave 30** *(gap closure round 11, review gap G-15-9 — blocked on 15-29: same reconciliation function, after the withdrawal has been relocated out of it)*

- [x] 15-30-PLAN.md — Make the destructive half of the reconciliation require a positive signal: surface directory-enumeration failure from the store (PageFileScan with scanSucceeded), refuse to blank on a failed scan and refuse wholesale blanking of a folder whose manifest read succeeded (tradeoff documented), log every real blanking at .notice with count and hash-masked gid, and prove with an execute-only-folder regression that a wholesale scan failure blanks nothing, writes nothing, and withdraws nothing

**Wave 31** *(gap closure round 11, review gap G-15-8 + WR-03 — blocked on 15-30 by file overlap in the public API and by xcodebuild serialization)*

- [x] 15-31-PLAN.md — State the ownership-convergence invariant on moveDownload ("no exit may leave a gid blocked or the queue unconverged") and satisfy it on all six exits; convert the scheduling block set to a reference count with block/release helpers so overlapping same-gid operations can no longer release each other's blocks (WR-03), sweep every insert site to single-release-per-exit, and pin the move-exit convergence with regressions observed failing first

**Wave 32** *(gap closure round 11, review gap G-15-12 — blocked on 15-31: IN-01's note names 15-30's landed refusal shape, and the rename sweep overlaps files every earlier plan touches)*

- [x] 15-32-PLAN.md — Close the six hygiene items: replace resolveSource's dead force-unwrap with the producer's own guard-throw, correct the one authority's false dedupe rationale, write the why-still-reachable note on resumeMode's validate branch, close the log scanner's unclassified-interpolation blind spot RED-first and replace the underived masked-count threshold with a named per-file inventory, rename UncheckedBox to LockedBox target-wide, and add the active-gallery-union coverage with a control assertion — with the 999-line file's headroom disposition recorded and nothing added to it

**Wave 33** *(gap closure round 12, verification gap G-15-13 — blocked on 15-32 by round continuity: it extends the reconciliation 15-30 landed inside the basis suite 15-32 last touched; xcodebuild serialization — invocations must never overlap on this machine)*

- [x] 15-33-PLAN.md — Give the blanking consumer a positive PER-FILE signal (D-G13-01): classify every per-file probe exit exhaustively (usable / rejected / unprobeable), extend PageFileScan with unprobedPages, refuse to blank any listed-but-unanswerable page while keeping the failed-scan and all-or-nothing guards as the outer lines, correct the refusal-site doc's false per-file-en-masse claim, and pin the N-1 mass-partial case (nothing blanked, written, indexed, or withdrawn) RED-first beside the genuine-partial companion (exactly K blanked) so the fix cannot be satisfied by disabling partial blanking

**Wave 34** *(gap closure round 12, verification gap G-15-14 — blocked on 15-33 by file overlap in DownloadClient+ExecutionSupport.swift and xcodebuild serialization)*

- [x] 15-34-PLAN.md — Guard both zero-page range sites (pendingPageIndices, initializePageDownloadState) against the trap, reject a zero-page payload at enqueue, and settle a zero-page refetch as a failed download at the fetch boundary (D-G14-01) — covered by a new three-case zero-page suite whose RED step is deliberately replaced by static derivation because a trapping run wedges testmanagerd on this machine

**Wave 35** *(gap closure round 12, verification gap G-15-15 — blocked on 15-34 by xcodebuild serialization; the rewritten docs must describe post-blocker source)*

- [x] 15-35-PLAN.md — Correct the three contradicted doc premises decide-one each: the nil-client skip states the true drop-not-replay recovery, one canonical non-suspension wording lands at all three suspension-claim sites, and the floor's writer inventory names all five writers including the teardown zero, labeled verified exhaustive by grep — a comment-only diff proven by inspection

**Wave 36** *(gap closure round 12, verification gap G-15-16 — blocked on 15-35 by file overlap in DownloadClient+Manager.swift and xcodebuild serialization)*

- [x] 15-36-PLAN.md — Drop the pause-record helpers' unproducible throws and unread parameter so the compiler forces the dead catch arms out of commitPause (the wrong exit comment dies with them), decide writeSettledPauseRecord's duplicate mutations from a traced enumeration of the cancelled task's teardown writers, and report a scheduling-release imbalance via reportIssue beside the existing log — pinned by a withKnownIssue canary through a new testing forwarder, RED-first

**Wave 37** *(gap closure round 12, verification gap G-15-18 — blocked on 15-36 by file overlap in Scheduling, Manager, the testing seam, and the convergence suite)*

- [x] 15-37-PLAN.md — Land the six hygiene items as dispositioned: request identity established before submission with the endSession paragraph rewritten (WR-08), the superseded-arm ensure dropped with the observable generation-check argument written (WR-09), the probe-collapse invariant bound at the cover path (IN-01), the nine session-state vars internal with a testingContinuedSessionTask forwarder and grep-proven boundary (IN-02), the two expiration-after-removal teardowns fixed per recorded decisions (IN-03), and the submission-failure log type-public/value-private with the privacy scan extended over BackgroundProcessingClient, proven RED against the pre-fix line (IN-04)

**Wave 38** *(gap closure round 12, verification gap G-15-17 — blocked on 15-37: the producer cases assert the post-WR-08 ordering, with file overlap on ContinuedProcessingSession.swift)*

- [x] 15-38-PLAN.md — Give the scheduling spy controllable outcomes (refusesNextRegistration, nextSubmissionError) and an injectable bundle identifier on the internal initializer, execute all three unavailable producers and both nil-launch arms with full release-contract assertions, verify the client's every-endpoint claim, and drive the WR-07 lag staging through testingPauseAllSchedulable asserting the running gallery is among the paused set — the SC2 cancel half as an assertion, not prose

**Wave 39** *(gap closure round 13, verification blocker G-15-19 — blocked on 15-38 by round continuity from the round-12 HEAD and xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-39-PLAN.md — Stop the repair-seed materialization from laundering a SOURCE-side per-file non-answer into a positive absence at the DESTINATION (SC3, D-G13-01 across the route): materializeRepairSeed selects through the full PageFileScan and returns the source scan's unprobed set, setupWorkingFolder hands it back, and prepareWorkingSeed unions it into the destination scan so the EXISTING refusal line covers laundered pages — explicitly NOT the review's refuse-the-seed remedy, which the verifier traced to a strictly-worse all-N hash loss; the consumer sweep re-derived by grep with dispositions, the crossed regression (probe-failure staging × title-change materialization branch) RED-first in a NEW test file beside a genuine-absence companion that keeps destination blanking honest

**Wave 40** *(gap closure round 13, verification gap G-15-20 — blocked on 15-39: WR-03/WR-04 describe the exact seam 15-39 reworks, with file overlap on DownloadStore.swift and DownloadClient+ExecutionSupport.swift)*

- [x] 15-40-PLAN.md — Kill the doc-drift generator (fourth consecutive round): correct the five contradicted claims decide-one each from fresh source enumerations — WR-01's convergence ownership as a settled/superseded category rule, WR-02's writer list replaced by the no-block-on-mobilizers invariant, WR-03's existence-guard rationale decided against the post-15-39 seam, WR-04's unreachable-equality sentence decided by trace (pinning regression required if the comparison changes), IN-01 count-free — and pair every surviving inventory with a drift-failing source-census test (blockScheduling call sites, floor writers) on the DownloadLogPrivacyInvariantTests pattern, retiring the re-run-this-grep comment

**Wave 41** *(gap closure round 13, verification gap G-15-21 — blocked on 15-40 by file overlap on DownloadClient+ExecutionSupport.swift and xcodebuild serialization)*

- [x] 15-41-PLAN.md — Close the hygiene group at the roots: WR-06's dead disjunct deleted and the normalizer renamed to what it does with all callers swept, IN-02's stray indentation leveled, IN-03's max-widened bound replaced by the G-15-14 guard shape (the sweep's one widened site), IN-04's redundant Set rebuild dropped — and restore the basis suite's headroom by splitting DownloadContinuedSessionBasisTests.swift (996/1000) as a pure relocation into an extension file, proven by an unchanged test count and a green full run

**Wave 42** *(gap closure round 14, verification blocker G-15-22 — blocked on 15-41 by round continuity from the round-13 HEAD and xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-42-PLAN.md — Stop the expiration sweep from silently pausing away a just-mobilized download (SC1/SC3): pauseAllSchedulable captures every gallery's queue-intent generation in the SAME synchronous stretch as the gid snapshot — the verifier-endorsed CR-01 hoist, sound because schedulableDownloads() performs no suspending call today — so a tap landing anywhere after the sweep began forces the affected pause to .superseded and its rescue re-ensure; the multi-gallery regression lands the tap BEFORE the target gallery's iteration with a session-start discriminator proving the loop did not return early, the mobilizer census (four advanceQueueIntentGeneration callers, none stamping the session id first) re-derived by grep, and the pause doc corrected to the snapshot rule without restating G-15-24's false authority sentence

**Wave 43** *(gap closure round 14, verification blocker G-15-23 — blocked on 15-42 by file overlap on DownloadClient+ContinuedSession.swift and xcodebuild serialization)*

- [x] 15-43-PLAN.md — Give the refusal family a session voice (SC2, SC1 through D-11): the run-start announcement gates on real page work (the working seed's existingPages short of the manifest's page count — true on all THREE refusal kinds and the proceeding branch alike) and admits the gid to observedIncompleteSessionGIDs explicitly ahead of its push, since the push-side formUnion provably cannot admit a complete-reading record; trust lands at the run's own preparation never queue time (D-G4-01 ceiling pinned), the insert's bracket-side derivation recorded (D-G7-01), the K=N residual and failed-enumeration regressions RED-first in a new ledger extension file through the production retryPages route, the K=1 case byte-unchanged, and the refuted flush-time cost sentence corrected from a fresh trust-writer census

**Wave 44** *(gap closure round 14, verification warning G-15-24 — blocked on 15-43: the corrected sentences must describe post-fix source, with file overlap on DownloadClient+Manager.swift)*

- [x] 15-44-PLAN.md — End the fifth doc-vs-source round at its generator: both one-authority sites corrected from fresh enumerations (schedulableDownloads() has three callers and the scheduler is not one — what is shared is the isSchedulableDownload predicate; the scheduler's own scoped read named, the active-gallery-union divergence recorded as inert behind guard activeTask == nil), the caller list pinned by a schedulableDownloads() call-site census in DownloadSourceInventoryTests, and WR-02's refuted concern closed as the doc item it is: a device-verified note beside ContinuedTaskScheduling.live.register recording that per-session UUID identifiers under the bundle-scoped wildcard make pre-launch registration structurally impossible and that 15-UAT.md test 1 device-proved the post-launch design

**Wave 45** *(gap closure round 14, verification warning G-15-25 — blocked on 15-44 by file overlap on DownloadClient+ContinuedSession.swift and DownloadClient+Scheduling.swift, whose WR-04 blank lines must be located after all prior edits)*

- [x] 15-45-PLAN.md — Close the round-13 hygiene group with decisions, not deferrals: WR-03's always-whole-array prefix dropped with the two-writer equivalence derived, WR-04's two stray blank lines before closing braces deleted, WR-05's unintended parameter-list trailing comma removed, and the public dead API decided delete-or-justify with the caller census re-derived by grep — validPageCount deleted outright, isReadableAssetFile deleted with its attributes-throw fallback pin rerouted through a surviving public surface (or kept with the why recorded at the declaration), the pinned probe behavior owned by a named test either way

**Wave 46** *(gap closure round 15, verification warning G-15-28 — blocked on 15-45 by round continuity from the round-15 HEAD and xcodebuild serialization; sequenced FIRST of the round on the verifier's own instruction, so the regression it unblocks can fail before either blocker fix lands)*

- [x] 15-46-PLAN.md — Make the payload doubles faithful to the route they model: both refusal cases drive retryPages (which stores a page selection) while hand-building a selection-free payload, so the suite has never run the announcement gate against a selection — the repair reproduces BOTH production steps (the fetch places the selection on the payload, the normalizer refines it and early-returns unchanged when the two agree, so normalizing alone keeps a nil selection), censuses all 14 payload call sites across 5 suites with a per-site faithfulness verdict, and pins the helper against the coordinator entry the route writes with the holding production event named; test-target only, and the plan records that both rebuilt cases stay green on both sides so its non-effect on the gate is explicit

**Wave 47** *(gap closure round 15, verification blocker G-15-27 — blocked on 15-46 by file overlap on DownloadContinuedSessionLedgerRefusalTests.swift: this plan's regression only discriminates once the payload rebuild has landed)*

- [x] 15-47-PLAN.md — Gate the announcement on the work the run will actually do (SC2, SC1 through D-11): the shortfall against the manifest ignores the payload's page selection, which survives normalization for every mode but update and is live on exactly the retryPages route, so a selected-page retry that fetches nothing earns trust for its record's FULL page count — the D-G4-01 ceiling reopened by the gate that replaced it; the run's pending page list becomes the single derived predicate, computed ONCE inside the preparation and handed to the page loop (evaluation count grep-proven), the retired equivalence replaced by the derived difference from a fresh enumeration, and the discriminating regression — one page file missing, a different present page retried — RED-first with its non-vacuity asserted

**Wave 48** *(gap closure round 15, verification blocker G-15-26 — blocked on 15-47 by file overlap on DownloadClient+ExecutionSupport.swift: the proof this plan re-owns must record 15-47's single derived predicate, not the shortfall binding it replaced)*

- [x] 15-48-PLAN.md — Give the proof of real page work the lifetime of the RUN it describes (SC2, SC1 through D-11): it is recorded only under a live session and into a session-scoped set both session start and teardown clear, so an unavailable teardown mid-run (three of the session type's four unavailable arms fire inside its own start) and any launch-resumed run (D-07 forbids a session there) both leave a complete-reading repair contributing zero for a whole N-page re-download; the proof moves to run-scoped state written unconditionally, seeded into the session trust set inside ensureContinuedSession's SYNCHRONOUS reset (derived: the opening subtitle is computed from the snapshot taken after it and before the client start), and retired at a point derived over EVERY enumerated exit path with the overlapping-run case dispositioned — three regressions: both orderings RED-first plus a lifetime pin green on both sides that stops the remedy re-crediting a later redo

**Wave 49** *(gap closure round 15, verification warning G-15-29 — blocked on 15-48 by file overlap on DownloadSourceInventoryTests.swift, whose scan scope this plan widens, which changes what every census in that file counts)*

- [x] 15-49-PLAN.md — Close the round-14 hygiene group and own the claim that has now been wrong six rounds running: the retired single-authority sentence survives in TWO test docs where 15-44's Sources-scoped census structurally cannot see it, so both are rewritten from a fresh caller enumeration and the census scan is widened to the downloads test target with a fragment-assembled prose assertion — every pre-existing per-file table and joined total re-derived under the new scoping and asserted unchanged, so the widening cannot silently re-baseline three claims while owning one; plus the page-progress counter 15-45's own prefix removal left dead (deleted at its root after a repository-wide reader derivation, its guard restated on the results collection) and the spy's unreadable parked-update field decided expose-or-delete with the criterion recorded

### Phase 16: Dynamic Type Accessibility

**Goal**: Complete comprehensive Dynamic Type support so every user-facing screen stays readable and operable across the full Dynamic Type range (including accessibility sizes AX1–AX5) with no clipped essential text, overlapping content, or unreachable controls — building on the font-scaling and reflow foundation delivered in Phase 10 (plans 10-10/10-11, verified on-device).
**Depends on**: Phase 10 (Dynamic Type foundation) — runs last, against the fully-settled UI.
**Requirements**: TBD (Dynamic Type accessibility — carried over from Phase 10 criterion 5)
**Implementation mode**: **Human-implemented; agent verify-only.** The agent audits, drives the simulator at accessibility sizes, and reports findings; it does NOT write the reflow fixes. Do not spawn executor agents for this phase — run verification only.
**Success Criteria** (what must be TRUE):

  1. Every user-facing screen remains readable and operable throughout the complete Dynamic Type range, including accessibility sizes (AX1–AX5), without clipped essential text, overlapping content, or unreachable controls.
  2. Layouts adapt via reflow (wrap / `ViewThatFits` / stacking), never by capping Dynamic Type (`dynamicTypeSize` cap) or clipping.
  3. Default-size (`.large`) appearance parity is preserved — no visible change at the default size.
  4. The cosmetic AX5 edge cases surfaced during Phase 10 verification are resolved or explicitly accepted: Detail stats-strip abbreviation, long-tag right-edge clip in the tag cloud, reader total-page counter wrap, Favorites trailing-glyph clip, and the hero-carousel title truncation.
  5. Owner-signed on-device UAT confirms readability/operability at XXL / AX3 / AX5 across every screen, including authenticated content screens (the D-03 gate carried over from Phase 10).

**Foundation already in place (Phase 10):** 7 fixed-pixel font sites scaled with text styles + `@ScaledMetric` (10-10); B1–B10 AX5 reflows via constraint-drop / `@ScaledMetric` at default-size parity (10-11). Prohibitions to preserve: no `dynamicTypeSize` cap, no `GeometryReader`, `minimumScaleFactor` only where already present.

**Plans**: TBD (human-implemented — the agent runs verification only)
