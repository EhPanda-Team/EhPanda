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
enable them; the mechanical rules sweep last. Later phases restore login, harden deep links, add
analytics, continued downloads and accessibility, and capture the screenshot foundation. Phase 17
closes a reduced screenshot and layout scope. The remaining 3.0 work is split into three phases (owner
msg 1753, 2026-11-05): Phase 18 does the in-app work (first-launch age wall, analytics choice, comment
moderation, the reader page-tracking rework and the other in-app carries); Phase 19 the visual-regression
(screenshot) check moved from Phase 17, covering the new screens, plus a daily live-parsing check (the
marketing export was dropped, owner msg 1949); Phase 20 distribution (the
AltStore PAL marketplace build, notarization, listing, release mechanics, real-device checks) and, last,
the analytics revision with install-source tracking.

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
- [x] **Phase 10: UI Polish** - Monospaced digits and numeric-text transitions; reduce ZStack in favor of overlay/background (completed 2026-07-20)
- [x] **Phase 11: Infra Refactor & Lint Capstone** - Resolve infra-level refactors (incl. test-isolation cleanup), then ratchet SwiftLint to the stricter ruleset at error; mechanical sweep last, refactor-gated rules flipped on (completed 2026-07-22)
- [x] **Phase 12: Cloudflare Login Restoration** - Restore username/password login broken by the Cloudflare wall: detect the challenge, clear it in an in-app browser, replay login with an in-memory cf_clearance (completed 2026-07-23)
- [x] **Phase 13: Deep Link Hardening** - Code-review the deep-link implementation and make it less hacky and more durable at navigating to the correct destination; add UI automation tests covering deep-link navigation (completed 2026-07-23)
- [x] **Phase 14: Analytics Instrumentation (TelemetryDeck)** - Add privacy-first analytics via the TelemetryDeck SDK — on by default with a runtime opt-out in General Settings (D-01 reversed) — instrumenting key user flows (completed 2026-07-27)
- [x] **Phase 15: Continued Background Downloads** - Adopt `BGContinuedProcessingTask` so a user-started gallery download keeps running after backgrounding, with the system-provided progress UI (completed 2026-08-19)
- [x] **Phase 16: Accessibility (Dynamic Type + Assistive Technology)** - Two rounds against the settled UI: full-range Dynamic Type (AX1–AX5, human-implemented, agent verify-only), then a VoiceOver / Voice Control / Reduced Motion / Contrast / Differentiate-Without-Color pass (agent-implemented), held to the App Store Accessibility Nutrition Label bar (completed 2026-09-23)
- [x] **Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization** - Reduced 2026-11-03: capture foundation and the approved 192-image website set, verification of the landed size-class layout, the remaining idiom census and the Release isolation check; regression, marketing export and AltStore work moved to Phase 18 (now split: regression and marketing export → Phase 19, AltStore work → Phase 20) (completed 2026-11-05)
- [x] **Phase 18: In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework** - Two first-launch screens for everyone (age wall, then Minimal/Basic/Full analytics choice, SDK off until chosen), E-Hentai comment report, posting warning, collapsed blocking and a Blocked Users list, the reader page-tracking rework with G1/G2 UI tests, IN-02/IN-03 and `MKSellsDigitalGoods` (completed 2026-11-06)
- [x] **Phase 18.1: Native report form (INSERTED)** - EhPanda's own report form for comments (owner msg 1931): two illegal-content reasons, required email never stored, English prefill, pinned Send Report; the site's page stays as the fallback; no gallery reports (owner msg 1975) (completed 2026-11-07)
- [x] **Phase 19: Visual Regression & Daily Live-Parsing Check** - The screenshot check moved from Phase 17 (snapshot matrix, one owner-approved baseline, the full-matrix CI gate, preview review and the `Scripts/visual/README.md` rewrite), covering the Phase 18 and 18.1 screens, plus a daily CI check that runs the app's parsers on the live pages (owner msg 2006); the 384 export and final gallery selection are dropped (owner msg 1949) (completed 2026-11-11 with deferred items: the hosted gate pass, the candidate run and public snapshot repository, the owner-approved baseline and the hosted controlled regression, owner msgs 3425, 3428, 3573)
- [ ] **Phase 20: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks** - AltStore PAL marketplace build (same features), notarization pipeline, PAL source and listing with decorated store screenshots, website privacy link, the GitHub repository page as the support URL, release mechanics, real-device checks, the repeated Release isolation scan and, last, the analytics revision with install source

## Future milestones (after 3.0)

Recorded 2026-11-06 (owner msg 2001; product lead msgs 2002, 2005). These items do not change the 3.0 scope and have no phase yet; they are TAG-01 and TAG-02 under v2 Requirements in REQUIREMENTS.md.

- **Native tag management page**: EhPanda's own screen for watched and hidden tags, replacing the E-Hentai My Tags web page that Account settings opens today. This closes the last feature reachable only through the website; the remaining web pages (the sign-in and E-Hentai settings globe shortcuts, the Cloudflare check page, the report page fallback) are optional or required by the site.
- **Tag context menu actions**: long-pressing a tag on a gallery page offers its actions in a menu; today voting is only through the buttons on the tag.

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

**Delivered**: 2026-07-13 — rename committed (`cf52fb7de5`); build + full suite green. No plan pipeline (mechanical). Formal phase close-out follows Phase 5 verification.
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
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14 → 15 → 16 → 17 → 18 → 19 → 20

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Isolated Dependency Modernization | 9/9 | Complete    | 2026-07-10 |
| 2. Native Masonry Grid Swap | 4/4 | Complete    | 2026-07-11 |
| 3. Native Reader Paging Swap | 5/5 | Complete    | 2026-07-12 |
| 4. Concurrency & Framework Migration | 14/14 | Complete    | 2026-07-12 |
| 5. Adaptive Layout & Universal Orientation | 18/18 | Complete    | 2026-07-13 |
| 6. GalleryList Rename | — | Delivered (rescoped) | 2026-07-13 |
| 7. Root Privacy Mask & Auto-Lock Removal | 12/12 | Complete    | 2026-07-14 |
| 8. Architecture Hygiene & Client Seams | 18/18 | Complete    | 2026-07-14 |
| 9. Correctness & Structured Error Handling | 13/13 | Complete    | 2026-07-16 |
| 10. UI Polish | 12/12 | Complete    | 2026-07-20 |
| 11. Infra Refactor & Lint Capstone | 32/32 | Complete    | 2026-07-22 |
| 12. Cloudflare Login Restoration | 6/6 | Complete    | 2026-07-23 |
| 13. Deep Link Hardening | 10/10 | Complete    | 2026-07-23 |
| 14. Analytics Instrumentation (TelemetryDeck) | 18/18 | Complete    | 2026-07-27 |
| 15. Continued Background Downloads | 77/77 | Complete    | 2026-08-19 |
| 16. Dynamic Type Accessibility | 26/26 | Complete    | 2026-09-23 |
| 17. Screenshot Automation, Visual Regression & OS 27 Modernization | 13/13 | Complete    | 2026-11-05 |
| 18. In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework | 12/12 | Complete    | 2026-11-06 |
| 18.1. Native report form (INSERTED) | 5/5 | Complete    | 2026-11-07 |
| 19. Visual Regression & Daily Live-Parsing Check | 15/17 | Complete with deferred items | 2026-11-11 |
| 20. 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks | 8/14 | In Progress |  |

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

**Plans**: 76/77 plans executed

Plans:

- [x] 15-50-PLAN.md
- [x] 15-51-PLAN.md
- [x] 15-52-PLAN.md
- [x] 15-53-PLAN.md
- [x] 15-54-PLAN.md
- [x] 15-55-PLAN.md

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

**Wave 55** *(gap closure round 19, UAT gap G-15-2C — blocked on 15-54 by round continuity from the round-18 HEAD and xcodebuild serialization; invocations must never overlap on this machine)*

- [x] 15-55-PLAN.md — Change the pushed gallery count's basis to the denominator's coverage (D-G2C-01): live schedulable galleries plus departed galleries whose positive retirement contributed pages to Y, computed by one shared helper after the ledger reconcile and used by both subtitle writers — the diagnosis proved the 15-22 terminal push fires correctly on every drain route and the system card still renders the prior frame, so the render-race dependency is removed rather than raced harder; the D-G2-01 count contract rewritten, every coordinator-computed subtitle pin across ten suites recomputed from the rule (rewritten, never supplemented) with the zero-retirement boundary pinned from both sides, and client pass-through fixtures classified rather than edited

**Wave 56** *(gap closure round 19, UAT gap G-15-5 root fix — blocked on 15-55 by xcodebuild serialization)*

- [x] 15-56-PLAN.md — Make a missingFiles validation verdict durable (D-G5B-01): validateImageData runs the same D-G5-01 positive-signal blanking loop a repair's seed preparation runs, inside the same counted-basis bracket, so the record honestly reads incomplete, validationErrors clears on the durable arm (it outranks everything in displayStatus — the diagnosis's hazard), Resume enables through the existing gates, resumeMode resolves .repair, and the state survives relaunch with both count bases converged; the refusal family (failed scan / wholesale-blank guard) keeps the transient error surface deliberately with its residuals dispositioned, and the piecewise suite crosses the durable/refusal boundary with relaunch and the validate-to-queued-repair arc pinned on production entry points

**Wave 57** *(gap closure round 19, UAT gap G-15-5 affordance + predicate sweep — blocked on 15-56: the widened retry exists FOR the refusal family 15-56 leaves on the .error surface, and xcodebuild serialization)*

- [x] 15-57-PLAN.md — Give the refusal family its start and sweep the predicates the diagnosis named: the inspector retry basis widens to failed-plus-pending exactly for the .error/fileOperationFailed shape (D-G5C-01, one computed basis feeding both gate and send, routed into the existing retryPages whose enqueue clears the transient error — asserted .queued on the production path), Detail's downloadNeedsRepair reads record honesty (completedPageCount < pageCount, D-G5D-01) so a mid-run file failure with landed pages offers the non-destructive repair while complete-claiming records deliberately keep redownload, and the consumerless row-retry predicate is deleted with the stale basis-suite comment re-derived

**Wave 58** *(gap closure round 19b, owner-decided SSOT design extension G-15-SSOT — blocked on 15-57: this plan rewrites 15-56's corrupt-in-place refusal pins and 15-57's rationale comments, and xcodebuild serialization)*

- [x] 15-58-PLAN.md — Extend the durable reconciliation with the content-evidence arm (D-SSOT-01..06): a readable file whose fresh hash mismatches its recorded hash blanks durably with the file removed under guards — removal is mandatory because the repair fetch skips pending pages whose file exists and finalize re-hashes blank-hash pages from current bytes, which would launder corruption — the wholesale irreversibility guard evaluates the combined absent∪mismatched set before any destructive step, a read failure stays a per-page hold, validationErrors becomes an exclusively operation-level contract, and the AGENTS.md invariant's stale presence-scan refusal example is revised to the new license

**Wave 59** *(gap closure round 19b — blocked on 15-58: recomposes 15-57's retry basis over the shrunken refusal surface, and xcodebuild serialization)*

- [x] 15-59-PLAN.md — Derive inspector page states from the manifest instead of a live file scan (D-SSOT-07: non-empty hash → downloaded, recorded failure → failed, blank → pending; the listing survives only to resolve thumbnail fileURLs), so badge and inspector share one persisted basis by construction and pre-validate divergence shows the record's claim until Validate senses it; the operation-level-error retry basis becomes the full page set (D-SSOT-08 — manifest-derived pending is empty for the wholesale-refusal family, so the failed∪pending union would silently re-open the G-15-5 dead end), with the divergence window and the non-leak boundary pinned from both sides and every presence-state consumer swept

**Wave 60** *(gap closure round 19b — blocked on 15-59: asserts properties of the state 15-55..15-59 leave behind, and xcodebuild serialization)*

- [x] 15-60-PLAN.md — The SSOT property suite (D-SSOT-09): over a reproducible generated family crossing every regime boundary, assert count-basis agreement (every displayed record-completeness quantity is the same manifest-derived function, in-session and across relaunch), derivation totality via the external-mutation probe (deleting or corrupting files outside the app moves no displayed quantity or predicate until Validate senses it), and no-dead-end (every non-terminal incomplete state reaches .queued through a driven production affordance — the property whose absence let G-15-5 ship green through 888 tests), with the run-measured session card explicitly out of scope so the round-18 redesign is not undone

**Wave 61** *(gap closure round 20, verification blocker CR-02 — blocked on 15-60 and serialized xcodebuild)*

- [x] 15-61-PLAN.md — Scope incomplete-record observation to queue-intent generation so a gallery re-queued while the same continued session remains alive receives zero predecessor credit until its successor run establishes a measured basis; RED-first two-gallery regression keeps the session identity unchanged.

**Wave 62** *(gap closure round 20, verification blocker CR-01 — blocked on 15-61 and serialized xcodebuild)*

- [x] 15-62-PLAN.md — Make validation classification non-mutating until the combined absent/rejected/mismatched wholesale guard authorizes correction; retain rejected page identity, remove only after authorization, and pin one-page refusal with both disk and manifest unchanged.

**Wave 63** *(gap closure round 20, security blocker CR-03 — blocked on 15-62 by DownloadStore+Operations.swift overlap and serialized xcodebuild)*

- [x] 15-63-PLAN.md — Move folder rename behind a store-owned direct-child boundary that rejects traversal, absolute/nested sources, normalization-changing aliases, and symlink escapes, with containment re-checked immediately before move.

**Wave 64** *(gap closure round 20, verification blocker CR-04 — blocked on 15-63 and serialized xcodebuild)*

- [x] 15-64-PLAN.md — Preserve retry selection as three states end to end: nil alone is unrestricted, explicit empty/all-invalid fails before queue mutation, mixed input carries only its valid subset, and payload normalization cannot widen explicit emptiness to whole-gallery repair.

Gap closure round 19 (verification 2026-08-10, gaps 1-4):

- [x] 15-65-PLAN.md — Wrap the queue-intent generation advance in its own D-G7-01 withdrawal bracket so the credited-basis drop is withdrawn at every present and future call site by construction; one-at-a-time keeper regression asserts the pushed numerator moves on the first post-requeue page.
- [x] 15-66-PLAN.md — Flip every discardingRejected default to non-mutating so reads never delete: sweep the whole validate/scan/probe family with per-caller dispositions, delete the side-effect-only scanCompletedFolder sweep, and pin zero-byte loadManifest/resumeMode non-mutation from both sides.
- [x] 15-67-PLAN.md — Measure the wholesale blanking guard over the combined positively-refuted set and give the repair-seed route the validated-record pass's classify-authorize-remove ordering, so a per-page hold cannot relax the threshold and no record claims a page over refuted surviving bytes.
- [x] 15-68-PLAN.md — Route every user-folder mutation (delete, create, move destination, enqueue parent) through the store-owned confined boundary with a deleteUserFolder that re-checks inside the operate closure; symlink-harden removeFolder and pin the six-argument delete escape suite plus three-store record convergence.
- [x] 15-69-PLAN.md — Surface retry refusals as a distinct localized error with a failure-branch toast, and make a fetch-time selection collapse throw a named error at normalizeFetchedPayload before any run work, so drift never settles a gallery into a false whole-manifest failure record.

Gap closure round 21 (verification 2026-08-10, gaps 1-5, plus the two 15-UAT.md deferred follow-ups; waves strictly sequential — one xcodebuild test invocation at a time):

- [x] 15-70-PLAN.md — Make the delete/rename confinement predicate agree with the listing that produces its names: an admission test that cannot refuse a listed folder (structural refusals all kept, destinations still normalizing), the positive half of the escape catalog (own-on-disk non-normalized names delete and rename with record convergence), and the dead removeFolder(relativePath:) reconstruction deleted.
- [x] 15-71-PLAN.md — Convert materializeRepairSeed's source page scan to the non-mutating default so no app act deletes a page file without reconciling the record that claims it; per-site entitlement verdicts at every surviving discardingRejected true site, an entitlement census, and an interrupted repair-with-rename regression pinning source record/disk agreement and index-winner truthfulness.
- [x] 15-72-PLAN.md — Share the validate route's recover-once-and-log compensation with the seed route through one lifted implementation (bracket law preserved), sweep all three post-removal exits with dispositions, and make the announced basis structurally unable to over-report by never presuming this pass's removed pages done; regressions on the failed-write and failed-rescan exits.
- [x] 15-73-PLAN.md — Surface toggleDownloadPauseDone(.failure) through the inspector's toast, rename the mapping to actionFailureToast, and sweep every result-carrying Done action in both reducers with stated reports-or-deliberately-silent dispositions so no future branch lands silently.
- [x] 15-74-PLAN.md — Own the unowned invariants: honest bracket-nesting docs plus a withdrawal-depth reportIssue detector (and a corrected 15-65-SUMMARY claim), a self-consistent source-inventory suite with the unused scanner deleted, and explicit one-second bounds at the two missing-notification detectors.
- [x] 15-75-PLAN.md — One RLocalizable key spelling across all 19 DownloadClient call sites (IN-02, split from 15-74): move the module-local keys into the shared Resources catalog byte-verbatim with hand-written labeled symbols, rewrite the nine bare call sites, and retire the module-local catalog with zero translation drift.
- [x] 15-76-PLAN.md — UAT-FU-1: rename the user-visible logs folder to `Logs` via the single path constant, with a regime-complete one-time launch migration (legacy-only rename, case-only rename on case-insensitive volumes, both-exist merge with a stated collision disposition, race-tolerant against concurrent launch logging, never-throwing failure containment) and piecewise tests per regime.
- [x] 15-77-PLAN.md — UAT-FU-2 (spike-gated, owner checkpoint): Candidate 0 of the swipe-deletion choreography — drop the destructive role on the swipe delete (tint red), animate the confirmed removal, region-scoped source regression — then a blocking owner device evaluation carrying the research's gate criteria verbatim; on kill, record it and route Candidate 1 to a follow-up round unbuilt.

### Phase 16: Accessibility (Dynamic Type + Assistive Technology)

**Goal**: Make EhPanda accessible across six of the nine App Store Accessibility Nutrition Label
categories, in two sequential rounds. **Round 1 (Dynamic Type)** completes full-range readability and
operability (AX1–AX5) on the Phase 10 font/reflow foundation. **Round 2 (assistive technology)** adds
systematic support for VoiceOver, Voice Control, Reduced Motion, Sufficient Contrast, and Differentiate
Without Color. Round 1 runs first so round 2 lands against settled layout; a targeted re-sweep closes
the staleness window (D-25).
**Depends on**: Phase 10 (Dynamic Type foundation) — runs last, against the fully-settled UI.
**Requirements**: A11Y-01 (round 1), A11Y-02 (round 2)
**Implementation mode**: **Split by round.**

  - **Round 1 is human-implemented; agent verify-only.** The owner finds and fixes every Dynamic Type
    breakage himself; the agent audits, drives the simulator, and reports. Do not spawn executor agents
    for round-1 reflow work. One carve-out: the agent authors the four error-level SwiftLint rules that
    lock the foundation in.

  - **Round 2 is agent-implemented, owner-reviewed.** Label, input-label, motion-gating and contrast work
    is high-volume and mechanical; the owner reviews and signs off. Sufficient Contrast and Differentiate
    Without Color are **audit-first** — measure what already exists before building anything.
**Target bar**: the **App Store Accessibility Nutrition Label** pass/fail criteria, which require every
common user task to work, not just the main screen. Dark Interface is expected to already pass; Captions
and Audio Descriptions are not applicable (no video). If a category proves unclaimable, the agent returns
to the owner with the measurements rather than accepting the gap (D-24).

**Success Criteria** (what must be TRUE):

  1. Every user-facing screen remains readable and operable throughout the complete Dynamic Type range, including accessibility sizes (AX1–AX5), without clipped essential text, overlapping content, or unreachable controls.
  2. Layouts adapt via reflow (wrap / `ViewThatFits` / stacking), never by capping Dynamic Type (`dynamicTypeSize` cap) or clipping.
  3. Default-size (`.large`) appearance parity is preserved — no visible change at the default size. This outranks every other rule in round 1, including the `minimumScaleFactor` ban.
  4. The cosmetic AX5 edge cases surfaced during Phase 10 verification are resolved or explicitly accepted: Detail stats-strip abbreviation, long-tag right-edge clip in the tag cloud, reader total-page counter wrap, Favorites trailing-glyph clip, and the hero-carousel title truncation.
  5. Owner-signed UAT confirms readability/operability at XXL / AX3 / AX5 across every screen, including authenticated content screens (the D-03 gate carried over from Phase 10).
  6. `minimumScaleFactor` is gone from the source tree (5 sites → 0), and four error-level SwiftLint custom rules enforce the foundation: `minimumScaleFactor`, `.dynamicTypeSize(` as a view modifier (environment *reads* stay legal), `GeometryReader`, and numeric-literal `.system(size:)`.
  7. Every interactive element is reachable and correctly announced under VoiceOver — icon-only controls carry labels, decorative images are hidden, state is expressed as traits rather than label text, and reading order and post-navigation focus are correct.
  8. Every interactive element is actuatable by Voice Control — it appears under "Show numbers" and "Show names", and its input label matches its visible text.
  9. Meaningful motion is gated on `accessibilityReduceMotion` (replaced with a dissolve or removed); decorative motion is dropped. Subtle crossfades and `.contentTransition(.numericText())` are deliberately out of scope — they are not vestibular triggers.
  10. All text meets WCAG 4.5:1 and non-text elements 3:1, in light and dark and under Increase Contrast. Gallery **category background colors stay byte-identical** (all 84 variants, both hosts); the badge *text* color becomes adaptive black/white by resolved background luminance, which passes 84/84 with a structural floor of 4.58:1 for any possible color (D-21).
  11. No information is conveyed by color alone — every color-coded state also carries a shape, glyph, or text.
  12. A Nutrition Label recommendation is produced, stating which categories are claimable and why.
      *Superseded 2026-09-15 (owner):* EhPanda is not distributed on the App Store, so accessibility work is best effort and no Nutrition Label recommendation is produced. Round 2 closes instead with an agent-run walkthrough of the main flows (in-simulator VoiceOver, Voice Control label proxy, display settings; the owner only listens to named utterances), the D-25 re-sweep, the closing gates and owner sign-off. The Nutrition Label wording in the goal and target bar above is kept as the original record.

**Foundation already in place (Phase 10):** 7 fixed-pixel font sites scaled with text styles + `@ScaledMetric` (10-10); B1–B10 AX5 reflows via constraint-drop / `@ScaledMetric` at default-size parity (10-11). Prohibitions to preserve: no `dynamicTypeSize` cap, no `GeometryReader`, and — as of this phase — no `minimumScaleFactor` at all.

**Accessibility baseline measured 2026-08-23:** 13 accessibility call sites repo-wide, all added opportunistically in Phases 5/7/9/10/15; 0 `accessibilityInputLabels`; 5 `accessibilityReduceMotion` reads against ~107 animation sites; 45 of 84 category-color variants below 4.5:1, with the Increase Contrast variants *less* contrasty than their standard counterparts in nearly every case.

**Plans**: 25/26 plans executed

Plans:
**Wave 1**

- [x] 16-01-PLAN.md — Four Dynamic Type / a11y SwiftLint rules at error severity with positive/negative probes (D-16/17/18/30); assumption-delta decision
- [x] 16-02-PLAN.md — `16-SWEEP.md` skeleton: 42-surface inventory, 12-cell matrix, D-13 named rows, D-04 checklist, D-25 section

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 16-03-PLAN.md — D-09 owner hand-login checkpoint; record sweep infrastructure, baselines and pre-flight

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 16-04-PLAN.md — iPhone sweep, group A (rows 1–13) at XXL/AX3/AX5 × portrait/landscape

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 16-05-PLAN.md — iPhone sweep, group B (rows 14–27) + `.large` parity baselines for the shrink sites

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 16-06-PLAN.md — iPhone sweep, group C (rows 28–42)

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 16-07-PLAN.md — iPad sweep, group A (rows 1–13)

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 16-08-PLAN.md — iPad sweep, group B (rows 14–27)

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 16-09-PLAN.md — iPad sweep, group C (rows 28–42); matrix complete

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 16-10-PLAN.md — Round-1 report committed; owner dispositions recorded item by item, checkpoint resolved 2026-09-11 (D-01 amended)

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 16-11-PLAN.md — Re-verification batches recorded; round-1 findings loop closed on ROUND1-CLEAR 2026-09-11 (D-15 parity)

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 16-12-PLAN.md — `no_minimum_scale_factor` rule after the 5 removals; owner-signed UAT gate (criterion 5)

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 16-13-PLAN.md — `16-CONTRAST-AUDIT.md`: category / Increase Contrast / non-category / DWC audit; owner colour decisions checkpoint (D-22)
- [x] 16-14-PLAN.md — `Color+Contrast` helper + category colorset invariant test (84/84, two hash pins) (D-26/27)

**Wave 13** *(blocked on Wave 12 completion)*

- [x] 16-15-PLAN.md — Adaptive `CategoryLabel` / `CategoryCell` text; Increase Contrast variants per decision

**Wave 14** *(blocked on Wave 13 completion)*

- [x] 16-16-PLAN.md — VoiceOver semantics: Detail, Comments, Archives, Torrents, FolderManager

**Wave 15** *(blocked on Wave 14 completion)*

- [x] 16-17-PLAN.md — VoiceOver semantics: Setting screens (toggles, rows, values) and DateSeek

**Wave 16** *(blocked on Wave 15 completion)*

- [x] 16-18-PLAN.md — VoiceOver semantics: Reader control panel, slider, named page/zoom actions, focus

**Wave 17** *(blocked on Wave 16 completion)*

- [x] 16-19-PLAN.md — VoiceOver semantics: toolbar menus, RatingView, tag cloud, list cells, Downloads

**Wave 18** *(blocked on Wave 17 completion)*

- [x] 16-20-PLAN.md — Reduce Motion gating: Detail and Reader (D-29)

**Wave 19** *(blocked on Wave 18 completion)*

- [x] 16-21-PLAN.md — Reduce Motion gating: lists, sheets, settings + source-scan pin test

**Wave 20** *(blocked on Wave 19 completion)*

- [x] 16-22-PLAN.md — Differentiate-Without-Color remediation: view-side log-level symbols, Laboratory glyph if weak, re-measured (D-20)

**Wave 21** *(blocked on Wave 20 completion)*

- [x] 16-23-PLAN.md — Non-category contrast fixes and the rating-star decision per audit decisions, re-measured (D-28)

**Wave 22** *(blocked on Wave 21 completion)*

- [x] 16-24-PLAN.md — `AccessibilityAuditUITests` on the `UITests` plan over fixture-reachable surfaces; owner-approved exclusion checkpoint (D-31, D-22)

**Wave 23** *(blocked on Wave 22 completion)*

- [x] 16-25-PLAN.md — Agent-run VoiceOver (in-simulator) / Voice Control label proxy (English) / display-settings walkthrough of the main flows, iPhone only, with one owner listening checkpoint (D-31, D-30; rescoped 2026-09-15)

**Wave 24** *(blocked on Wave 23 completion)*

- [x] 16-26-PLAN.md — D-25 targeted re-sweep (iPhone), phase-close gates, owner sign-off; no Nutrition Label document (D-21; rescoped 2026-09-15)

**Cross-cutting constraints:**

- Findings are recorded and the sweep moves on; screenshots stay under the evidence root (`$HOME/Library/Caches/ehpanda-phase16/`); before/after paths go to the owner in chat (D-02, D-32, D-33).
- Three sizes only, AX5 the maximum, large end only (D-05, D-06, D-07).

### Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization

**Goal**: Close the screenshot and OS 27 layout work that 3.0 needs, at reduced scope (owner decision 2026-11-03, msg 1305). Keep the delivered capture foundation (17-01 to 17-06, 17-24) and the owner-approved 192-image website screenshot set as the screenshot-export result. Confirm the size-class layout migration that already landed through quick task `261015-duo-session-record`, close the remaining device-idiom census with the owner, prove once that Release ships no capture or test code, and verify the phase honestly. The visual-regression matrix, baselines, CI snapshot gate, preview tooling, 384-image marketing export, final gallery selection and AltStore promotional images move to Phase 18; they are moved, not satisfied.
**Depends on**: Phase16 — current owner-approved verification and explicit evidence bounds; historical pending wording is superseded.
**Requirements**: CAP-17-01 (fixture part), CAP-17-04 (amended 2026-11-03), CAP-17-06 (bounded part), CAP-17-07 (amended 2026-11-03). CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01 and CAP-17-06 map to Phase 18.

**Scope and owner decisions**:

1. Explicit real-gallery acquisition/refresh produces versioned provenance and checksummed offline fixtures (17-03, 17-04, 17-06). The owner-approved website fixtures (16 immutable versions, `quick/261101-website-review/APPROVAL-20261102.md`) were the website selection of 2026-11-02; since the 2026-11-04 recapture (owner msg 1581) the fixture repository keeps only the 11 versions the current set uses (fixture commit `8ee4fc2`, owner msgs 1645 and 1647). Public regression test-data dispatch (17-11) and the final 384 reacquisition (17-21) move to Phase 18.
2. Screenshot export (CAP-17-04, amended): met by the 192 owner-approved iPhone Air website images of 2026-11-02 (two content sets × six locales × two themes × eight screens). The communicated website contract drops D-16's iPad axis. The 384-coordinate export tooling and its handoff validator (17-07) move to Phase 18. *Clarified 2026-11-05 (owner msg 1640):* the requirement means the current website image set, the 2026-11-04 recapture (quick task `261104-website-recapture`: 17 recaptures and 101 status-bar edits, 118 files serving the same 192 coordinates), approved by the owner in msg 1581 (17-FINAL-VALIDATION.md section 3).
3. Layout (CAP-17-07, amended): the device-idiom → size-class migration landed in quick task `261015-duo-session-record` (`605b4e4749` routes screens by window size classes at the app root; `e03456839a` picks view layouts by size class; `30ef583d21` sizes NewDawn for wide sheets; `7cf9ff16ef` seeds the reader pager from its measured size) **before** snapshot coverage existed, against D-27's intended order. 17-16 to 17-18 close as already landed after a short verification; 17-19 is reduced to the census of the remaining idiom reads with an owner keep/change checkpoint.
4. Release isolation (CAP-17-07): 17-14 is reduced to its T2 Release isolation check, run once at Phase 17 close; its T1/T3 CI snapshot gate moves to Phase 18, which repeats the scan on the final 3.0 Release build.
5. OS27/Swift6.4 native behavior (CAP-17-06): signed off with bounded evidence (existing behavioral tests, the recorded standard/AX1/AX3/AX5 title/search/top-edge checks). The snapshot-measured parts (17-09-T2 native visual policy tests, 17-15 preview review) move to Phase 18.
6. The 17-06 open items are settled by the owner's 2026-11-02 approval of the complete 192-image website set: the 16-frame review, the explicit-set preparation and the fixed 9:41 status bar per theme on the website images. The iPad Toplists gap between Yesterday and Past Month is resolved as fixture-caused (owner, 2026-11-03): the capture fixtures hold three galleries per period while the regular-width grid shows six (`HomeView+Sections.swift` regularWidthGrid), so the empty right-hand column read as a gap. The app is unchanged; Phase 18 fixtures carry at least six galleries per Toplists period.
7. Keep capture activation, assets and SnapshotTesting outside Release. Preserve download manifest SSOT, same-run folder deletion, strict lint and warning cleanliness.

**Success Criteria** (what must be TRUE):

  1. The reduced plan set (17-01 to 17-06, 17-24, 17-14 T2, 17-16 to 17-19, 17-23) has summaries with evidence; the moved plans carry `status: superseded` and a pointer to Phase 18.
  2. The 192 approved website images and their fixtures are recorded as meeting the amended CAP-17-04, citing the 2026-11-02 approval and the 2026-11-04 approval of the current set (owner msg 1581; 118 files serving the same 192 coordinates).
  3. The landed size-class routing and layout pass the existing reducer tests and one simulator check on iPad full width, a narrow iPad window and iPhone landscape; every remaining idiom read has an owner keep/change disposition.
  4. The 3.0-candidate Release build contains no capture code, fixtures, test assets or SnapshotTesting linkage, and no environment flag activates capture.
  5. FeatureTests and UITests pass on phone then tablet, one invocation at a time, with strict no-cache lint.
  6. CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/06 are listed as moved to Phase 18, never as satisfied.
  7. Phase 17 closes only through the GSD close steps: the execute-phase gates (code review, regression gate, `gsd-verifier` writing `17-VERIFICATION.md`), then verify-work (UAT), secure-phase and validate-phase.

**Plans**: 13/13 plans complete (11 plans moved to Phase 18 and marked `status: superseded`). Phase complete 2026-11-05: the GSD close steps passed (17-VERIFICATION.md `passed` 8/8, 17-UAT.md 31/31, 17-SECURITY.md `verified` with 0 open threats, 17-VALIDATION.md `validated` with `nyquist_compliant: false`; gaps G1/G2 get committed UI tests in Phase 18 Step 4b). The phase code review's WR-01 and IN-01 are fixed (`92181ccd2`, `18ec91b86`) and the gate passes again at `891103afa`. 17-23 is complete: at `97b31b063` FeatureTests and UITests pass on phone and tablet with 0 failures and 0 Repetition, strict lint is clean and the repeated Release scan has 0 findings; the gate's reader page-sync fixes (`adbd63809`, `8f0d09fff`, `2539331b2`, `4372e4b8f`, `346a3ea87`) and the reader's soft bottom edge (`90d6a6339`) and home-indicator rule (`e745f38f6`) landed with it. Known limit: at `97b31b063` the iPad page-sync stress ran 5 iterations, not 20 (owner, 2026-11-04); at the closing source `891103afa` both phone and iPad ran ×5 (40/40 each; the ×20 phone run is at `e745f38f6`, before WR-01/IN-01), accepted by the owner as a known limit (owner msg 1640). 17-19 is complete: the owner kept all five remaining device-idiom places (2026-11-03, msg 1409). 17-14 (T2) is complete: at `1829841d8` the Release scan has 0 findings, strict lint is clean, and FeatureTests and UITests pass on phone and tablet with 0 failures and 0 Repetition. It took two app fixes (`d8567a8f8` Library/gallery-list row restore, `ef625c0cb` Auto-Play menu) and test fixes (see 17-14-SUMMARY.md).

Plans:
**Wave 1**

- [x] 17-01-PLAN.md — Prove clean SnapshotTesting and actual-screen full-content capture

**Wave 2** *(complete)*

- [x] 17-24-PLAN.md — Measure actual geometry and validate the tracked rendering pin before matrix production

**Wave 3** *(complete)*

- [x] 17-02-PLAN.md — Run explicit complete regression coordinates using the verified environment pin

**Wave 4** *(complete)*

- [x] 17-03-PLAN.md — Acquire versioned provisional real marketing fixtures safely

**Wave 5** *(complete)*

- [x] 17-04-PLAN.md — Activate isolated offline capture scenes through existing app launch

**Wave 6** *(complete)*

- [x] 17-05-PLAN.md — Drive verified native app screens and capture normal device frames

**Wave 7** *(complete; open owner review superseded by the 2026-11-02 website approval)*

- [x] 17-06-PLAN.md — Render deterministic Live Text and coherent Downloads in actual UI

**Wave 8** *(complete)*

- [x] 17-16-PLAN.md — Verify the landed size-class view layouts (closed as landed via `261015-duo-session-record`)

**Wave 9** *(complete)*

- [x] 17-17-PLAN.md — Verify the landed Home and Library gallery routing by window size classes

**Wave 10** *(complete)*

- [x] 17-18-PLAN.md — Verify the landed Search and Downloads routing and the removed idiom helper

**Wave 11** *(complete; owner kept all five idiom places)*

- [x] 17-19-PLAN.md — Verify Settings presentation, census the remaining idiom reads and record the owner's keep/change decisions

**Wave 12** *(complete; T2 gate passes at `1829841d8`)*

- [x] 17-14-PLAN.md — Prove Release ships and activates no capture facilities (T2 only; T1/T3 moved to Phase 18)

**Wave 13** *(complete; reduced gate passes at `97b31b063`)*

- [x] 17-23-PLAN.md — Verify the reduced phase delivery and record moved requirements honestly

**Moved to Phase 18** *(owner decision 2026-11-03, msg 1305; plan files kept in place with `status: superseded`)*:

- 17-07-PLAN.md — Produce all 384 marketing outputs and a complete local handoff (moved to Phase 19, then dropped 2026-11-06, owner msg 1949)
- 17-08-PLAN.md — Expand regression coverage for browsing and gallery content (now Phase 19)
- 17-09-PLAN.md — Cover reader modes and overlays across complete regression axes (now Phase 19)
- 17-10-PLAN.md — Cover settings, utilities and remaining presentation states (now Phase 19)
- 17-11-PLAN.md — Establish public native dispatch before scenario expansion (now Phase 19)
- 17-12-PLAN.md — Compare native and hosted images strictly and build the review report (now Phase 19)
- 17-13-PLAN.md — Review and approve the initial complete snapshot baseline (now Phase 19)
- 17-14 T1/T3 — Full-matrix PR/release snapshot gate and clean-checkout acceptance (now Phase 19)
- 17-15-PLAN.md — Document and validate reusable Xcode agent preview review (now Phase 19)
- 17-20-PLAN.md — Review and approve post-audit snapshot changes (no longer needed separately: the layout migration already landed, so Phase 18's single baseline approval covers it; now Phase 19)
- 17-21-PLAN.md — Replace provisional galleries with final owner selections (moved to Phase 19, then dropped 2026-11-06, owner msg 1949)
- 17-22-PLAN.md — Hand off sources to the designer and validate promotional delivery (now Phase 20)

Phase 17 is complete (2026-11-05) at the reduced scope above. The moved plans are not executed or approved; Phase 18 owns them.

*Note (2026-11-05, owner msg 1753):* after Phase 17 closed, Phase 18 was split into Phases 18, 19 and 20. Where this section says "Phase 18", read: snapshot tests, the CI gate, preview review, the 384 export and the six-per-period Toplists fixtures → Phase 19; AltStore promotional images (17-22, CAP-17-05) and the repeated Release isolation scan → Phase 20; the reader rework with the G1/G2 UI tests and IN-02/IN-03 stay in Phase 18. The record above is otherwise unchanged; the split map is at the end of the Phase 18 section.

### Phase 18: In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework

**Goal**: Finish every in-app change 3.0 needs, in every build, before the visual baseline and distribution work start. Every user, upgraders included, sees two first-launch screens once: an age wall, then an analytics choice (None / Basic / Full, nothing pre-selected); no content, network request or analytics SDK start happens before them. Comments gain an E-Hentai report action, a posting warning and local blocking with a Blocked Users list in Settings (App Review Guideline 1.2). The reader gets one source of truth for its current page, with committed UI tests for Phase 17's gaps G1/G2. The other in-app carries from Phase 17 (IN-02, IN-03) and the app-code release fix (`MKSellsDigitalGoods`) land here too.
**Depends on**: Phase 17. UI tasks also wait for the UI-SPEC from the designer (Colo, msg 1757), or for `/gsd-ui-phase 18`.
**Requirements**: AGE-18-01, CONSENT-18-01, UGC-18-01 (report, posting warning, blocking; the contact part maps to Phase 20), DIST-18-01 (`MKSellsDigitalGoods` only; the marketplace build flavor maps to Phase 20). Carried from Phase 17's close without an ID: the reader page-tracking rework with the G1/G2 UI tests, and IN-02/IN-03.

**Scope and owner decisions** (context: [18-CONTEXT.md](phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-CONTEXT.md)):

1. Split (owner msg 1753, 2026-11-05): the original Phase 18 becomes three phases. This phase is the in-app work; Phase 19 takes visual regression and the marketing export, Phase 20 distribution. The split map is at the end of this section.
2. First launch (owner msg 1753): two screens, everyone once: the age wall, then the analytics choice. Upgraders from 2.x and the 3.0.0 pre-release see both too. The age-wall checkbox sentence is the owner-approved website sentence (msgs 1454, 1457), unchanged and with no list of examples.
3. Analytics (owner msg 1753): levels None / Basic / Full, none pre-selected. The SDK does not start before the choice, and never with None. A Settings picker replaces today's toggle.
4. Comments (owner msgs 1753, 1765, 1780): reporting goes to E-Hentai only (the gallery's report page; no email). No in-app contact option now (Ampo msg 1774); the published contact link is Phase 20 work. A comment that trips the filter gets a warning and can be posted anyway, edits included. A blocked user's comments collapse into "Comment from a user you've blocked" (Show / Unblock, name not shown). Settings gets a Blocked Users list.
5. Copy (owner msgs 1767, 1780): the approved six-language strings in [18-COPY-FIRST-LAUNCH.md](phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-FIRST-LAUNCH.md) and [18-COPY-COMMENTS.md](phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-COMMENTS.md) are canonical and used verbatim.
6. Design (msg 1757): Colo owns the layout spec and mockups for the age wall, the analytics choice, the comment report/block UI and the Blocked Users list. Plans leave a UI-SPEC input for him; UI execution waits for it.
7. Carried from Phase 17's close: the reader page-tracking rework to one source of truth (owner msg 1630, product lead msg 1631; was Step 4b) with committed UI tests for G1/G2, and the code-review items IN-02 and IN-03 (owner msg 1627; was part of Step 7), closed before Phase 20's final Release scan.
8. App-code release fix: `MKSellsDigitalGoods` = `NO` in `App/Info.plist`, for every build (DIST-18-01; was part of Step 1).

**Success Criteria** (what must be TRUE):

  1. On the first 3.0 launch, for fresh installs and upgraders alike, the age wall appears before any content is shown or any network request is made. Continue stays dimmed until the approved declaration is ticked; there is no skip and nothing else in the app works until then. The answer is stored on the device.
  2. The analytics choice follows the age wall: None, Basic and Full, equally prominent and none pre-selected. Tests prove no analytics SDK call before the choice and none at all under None; each level sends only what its approved description says.
  3. Settings has an analytics picker with the three levels in place of the toggle, a footer showing the selected level's description and a Privacy Policy row; the old "installation is still counted" footer is gone.
  4. Every comment has "Report on {site}", which confirms and then opens the gallery's report page on E-Hentai or ExHentai; there is no email or other contact path.
  5. Posting or editing a comment that matches the filter shows the posting warning (Edit by default, Post Anyway), never names the matched word, and keeps the typed text.
  6. Blocking a user collapses their comments, in the comments list and the Detail preview, into "Comment from a user you've blocked" with Show and Unblock, without the name. The block is stored on this device only. Settings lists blocked users, with an empty state and a swipe to unblock. *Amended 2026-11-05 (owner msg 1918):* a block matches the poster's E-Hentai member ID, not the display name; a comment without a member ID cannot be blocked.
  7. All new strings come verbatim from the two approved copy files, every `.xcstrings` key is filled for all six locales, and the six READMEs' Analytics sections describe the three levels.
  8. The reader keeps one source of truth for the page shown and the number displayed, at visible parity. Committed UI tests cover Reload All Images then a page turn, a reading-direction change during Auto-Play, and a left-to-right/right-to-left switch (G1/G2), and pass.
  9. IN-02 (`captureSystemOverlay` in `verify-release.py`'s `FORBIDDEN_CONTENT`, with a `test_release.py` case) and IN-03 (RootView's `import AppComponents` inside its `#if DEBUG` block) are closed, and `MKSellsDigitalGoods` is `NO`.
  10. The UI matches the UI-SPEC, and FeatureTests and UITests pass on phone then tablet with 0 failures and 0 Repetition, with strict no-cache lint.

**Plans**: 12/12 plans complete in 4 waves (planned 2026-11-05; list below); phase verification passed 10/10 (`18-VERIFICATION.md`). *Amended 2026-11-05 (owner msgs 1805, 1818; CONTEXT D-06a to D-06c):* the level None is now Minimal, which sends only one install signal with its install source; the SDK never starts under Minimal, so no level sends nothing. *Amended again (owner msgs 1830, 1839; CONTEXT D-06d):* Basic's description now builds on Minimal ("Everything in Minimal, plus ...", Revision 3 of `18-COPY-MINIMAL.md`); what Basic sends is unchanged. *Amended again (owner msgs 1844, 1854, 1864; CONTEXT D-06e):* the analytics intro (`consent.body`) is now one short line, "Anonymous analytics. Your searches and the galleries you view are never sent." (Revision 5); the purpose and TelemetryDeck's name move to the website's Privacy Policy (Phase 20). *Amended again (owner msgs 1869, 1880, 1882; CONTEXT D-06f):* the screen and feature signals move from Full to Basic (Full keeps reading and download activity and the main settings), with new Basic and Full descriptions (Revision 6); Basic is marked "Recommended" on the first-launch choice, and nothing is pre-selected.

Ordered plan outline (old step numbers are the original Phase 18's):

- **Launch gate and age wall** (was Step 2; AGE-18-01). The gate logic can go first; the screen waits for the UI-SPEC.
- **Analytics choice** (was Step 3; CONSENT-18-01): first-launch screen, Settings picker, SDK lifecycle by level. This replaces Phase 14's on-by-default opt-out.
- **Comment report, posting warning, blocking and the Blocked Users list** (was Step 4; UGC-18-01 without its contact part).
- **Reader page-tracking rework** (was Step 4b): replace the reader's separate copies of "the current page" (page-model index, pager scroll position, shown pager position, displayed slider value, saved reading progress and the vertical list's position, reconciled today by timing-dependent rules) with one source of truth, as one task, not more patches, and add the G1/G2 UI tests. Sources: STATE.md, 17-FINAL-VALIDATION.md section 9, [`17-READER-ROOT-CAUSE.md`](phases/17-localized-screenshot-capture-harness/17-READER-ROOT-CAUSE.md), 17-VERIFICATION.md R5-1.
- **In-app carries and release fix** (from Steps 1 and 7): IN-02, IN-03 (17-REVIEW.md, 17-REVIEW-DISPOSITION.md) and `MKSellsDigitalGoods`.

**Split of the original Phase 18** (owner msg 1753, 2026-11-05). The original Phase 18, "3.0 Release Readiness: Age Wall, Consent, Marketplace Distribution & Visual Regression" (added 2026-11-03), is split as follows; every item lands in exactly one phase:

- Requirements: AGE-18-01 and CONSENT-18-01 → 18. UGC-18-01 → 18 (report, posting warning, blocking) and 20 (published contact link). DIST-18-01 → 18 (`MKSellsDigitalGoods`) and 20 (marketplace build flavor). VIS-18-01 → 19. MKT-18-01 → 19 (384 export tooling, final selection, regeneration) and 20 (promotional images and store screenshots). DIST-18-02, DIST-18-03, DEV-18-01, REL-18-01 and ANALYTICS-02 → 20. From Phase 17: CAP-17-02, CAP-17-03 and the moved parts of CAP-17-01 and CAP-17-06 → 19; CAP-17-05 → 20; CAP-17-04's moved 384 export → 19 (under MKT-18-01).
- Outline steps: 1 → 18 (`MKSellsDigitalGoods`) and 20 (workflows, build number, AltStore.json history, marketplace flavor; the `3.0.0` tag checkpoint is dropped, owner msg 1753). 2, 3, 4 and 4b → 18. 5, 6 and 8 → 19. 7 → 19 (CI gate, preview docs), 18 (IN-02/IN-03) and 20 (final Release scan). 9, 10, 11 and 12 → 20.
- Scope items: 1 → 19 (snapshot tests, 384 export) and 20 (promotional images). 2 → 20 (the analytics revision is the last plan of Phase 20). 3 → 18 (contact details → 20). 4 → 18. 5 and 6 → 20. 7 → 18. 8 → 19.
- Success criteria: 1 → 20 (its `MKSellsDigitalGoods` part → 18; tag wording replaced, owner msg 1753). 2, 3 and 4 → 18 (criterion 4's contact part → 20; its support-contact fallback dropped, owner msg 1753). 5 → 19. 6 → 19 (export, selection, 384) and 20 (promotional images). 7, 8, 9 and 10 → 20.

*Note (2026-11-06, owner msg 1949; lead msg 1952):* the parts of this map that send the 384 export, its tooling, the final gallery selection, the 384 regeneration and the six-per-period Toplists fixtures to Phase 19 no longer apply: they were dropped, not moved. Phase 19 is now the screenshot check plus a daily live-parsing check (owner msg 2006).

Plans:

**Wave 1**
- [x] 18-01-PLAN.md — IN-02, IN-03 and `MKSellsDigitalGoods = NO`
- [x] 18-02-PLAN.md — first-launch gate logic and storage (AGE-18-01, CONSENT-18-01)
- [x] 18-04-PLAN.md — moderation core: filter, report target, own-comment rule, block store, session cookies (UGC-18-01)
- [x] 18-06-PLAN.md — every approved string, verbatim in six languages, with the copy check
- [x] 18-07-PLAN.md — reader page tracking on one `ReaderPosition`

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 18-03-PLAN.md — the three analytics levels and the install signal (CONSENT-18-01)
- [x] 18-05-PLAN.md — moderation reducers: posting warning, report, block, show-once (UGC-18-01)
- [x] 18-08-PLAN.md — DEBUG launch keys and the G1/G2 reader UI tests

**Wave 3** *(blocked on Wave 2 completion; UI tasks follow the committed UI-SPEC)*
- [x] 18-09-PLAN.md — age wall and analytics choice screens at the root, with the title line-break check
- [x] 18-10-PLAN.md — Settings analytics picker and Blocked Users
- [x] 18-11-PLAN.md — comment moderation UI, report sheet with the app's sign-in

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 18-12-PLAN.md — README Analytics sections, the phase gate, the owner's live report-page check *(gate passed on `e3c95a3bf`; Task 3's live report-page check verified by an agent per owner rule msg 1652, 2026-11-05)*

**Cross-cutting constraints:**
- Every UI task here follows the committed `18-UI-SPEC.md` (the final spec, msg 1826, with the C-3 title rule) as the design contract; layout calls are the designer's and are not changed in execution (D-17, D-17a).

### Phase 18.1: Native report form (INSERTED)

**Goal:** Replace Phase 18's report alert and web sheet with EhPanda's own native "Report on {site}" form for comments (owner msg 1931, "Our own form"): two reasons only, child pornography and other illegal content (owner msg 1950), a required email that is never stored, Details prefilled in English with the reported comment, and Send Report in a pinned bar with no background (owner msgs 1955, 1965). The form posts the site's own report fields to the gallery's site; the site's report page stays as the fallback. There are no gallery reports, now or later, unless distribution is blocked without them (owner msg 1975).
**Requirements**: UGC-18-01 (native report route)
**Depends on:** Phase 18
**Context:** [`18.1-CONTEXT.md`](phases/18.1-native-report-form/18.1-CONTEXT.md); design contract UI-SPEC C-13 in the Phase 18 spec (Colo msg 1978, mockups 25–31, 33, 34); copy [`18.1-COPY-REPORT-FORM.md`](phases/18.1-native-report-form/18.1-COPY-REPORT-FORM.md) (approved, owner msg 1975).

**Success Criteria** (what must be TRUE):
  1. Report on a comment by someone else opens the native form directly, from the comments list and the Detail strip, with no alert; the retired confirm strings are gone.
  2. The form reads the site's report form first and shows every C-13 state: loading, ready, sending, sent, failed (Retry / Open Report Page / Cancel) and unavailable (Open Report Page).
  3. The request matches the site's own form (`report_type`, `r_email`, `r_details`, `sendreport`), goes only to the gallery's site, is never retried automatically, and the email is never stored or logged; no analytics.
  4. All 23 approved strings ship verbatim in six languages; the six gallery-only strings do not ship.
  5. FeatureTests and a UI test for each C-13 state pass on iPhone and iPad; lint is clean; the Release product carries no UI-test key.
  6. An agent's live check on the real site, with Proxyman blocking the report POST, shows the form loaded and the request built correctly, with no report filed (owner msgs 1933, 1652).

**Plans:** 5/5 plans executed

Plans:

**Wave 1**
- [x] 18.1-01-PLAN.md — fixtures, report form parser, per-type report URL and the one-attempt requests
- [x] 18.1-02-PLAN.md — the 23 approved report strings in six languages, with the copy check *(22 ship: the lead dropped `report.reason.choose`, msgs 1980/1983)*

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 18.1-03-PLAN.md — `ReportFormFeature` reducer, client and English prefill; Report routed to the form from both screens

**Wave 3** *(blocked on Wave 2 completion; UI tasks follow the committed UI-SPEC C-13)*
- [x] 18.1-04-PLAN.md — `ReportFormView` per C-13, the retired confirm keys, UI-test stubs and a UI test for each state

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 18.1-05-PLAN.md — phase gate on both devices and in Release, then the agent-run live check (the phase's only checkpoint) *(gate green at `270d7c3d4`; the live check passed under a local mitmdump, owner msg 2066 and the tool change, 2026-11-07)*

### Phase 19: Visual Regression & Daily Live-Parsing Check

**Goal**: Complete the visual-regression (screenshot) check moved from Phase 17, against the settled 3.0 UI and including every Phase 18 and Phase 18.1 screen: the snapshot scenario matrix, public real-app dispatch, strict never-record comparison and the review report, one owner-approved baseline, the full-matrix CI gate on every PR and release, preview review documentation and the `Scripts/visual/README.md` rewrite. Add a daily live-parsing check: a scheduled CI workflow that runs the app's own parsers on the live pages EhPanda reads and reports a break through one GitHub issue (owner msg 2006). No marketing pictures are produced here (owner msg 1949).
**Depends on**: Phase 18 and Phase 18.1 (every UI change, the native Report form included, lands before the one baseline approval).
**Requirements**: VIS-18-01, VIS-19-01 (daily live-parsing check); moved from Phase 17: CAP-17-02, CAP-17-03, and the moved parts of CAP-17-01 (17-11) and CAP-17-06 (17-09-T2, 17-15). MKT-18-01's 384 export tooling, final gallery selection and regeneration, CAP-17-04's moved 384 export and 17-21 were dropped (owner msg 1949); MKT-18-01's remaining part maps to Phase 20.

**Scope and owner decisions** (context: [19-CONTEXT.md](phases/19-visual-regression-marketing-export/19-CONTEXT.md); discussed, decisions D-01 to D-28):

1. Owner msg 1305: the snapshot tests (17-08 to 17-13, 17-14 T1/T3, 17-15, 17-20) are moved, not deferred past 3.0. 17-20's separate re-approval folds into the one baseline approval.
2. Owner msg 1753: three phases; this one runs after the in-app work so the baseline is approved once, against final UI.
3. Coverage includes the Phase 18 and 18.1 screens: age wall, analytics choice, the Settings analytics picker, the native Report form (Phase 18.1), the posting warning, the collapsed blocked-comment row and the Blocked Users list with its empty state.
4. Removed from this phase (owner msg 1949; lead msg 1952; restated by the product lead in msg 1993): no regenerated iPhone marketing pictures and no iPad marketing pictures are planned. The 384-coordinate export tooling and its handoff validator (17-07), the final gallery selection and the 384 regeneration (17-21) are dropped, not moved. The "at least six galleries per Toplists period" fixture requirement (Phase 17 scope 6) existed only for the regular-width grids of those pictures and is dropped with them; the fixtures keep three per period.
5. Rewrite `Scripts/visual/README.md` (was scope item 8): the fixture index is now `website-capture-20261104.json` (11 fixture versions), not `website-capture-20261102.json`, and this phase, not 17-02, 17-05 or 17-07, owns the regression runner.
6. Phase 17's decisions for the moved snapshot plans carry unchanged (17-CONTEXT.md D-07, D-12 to D-14). Pushing the fixture repository commits (R4-3) stays the owner's decision.
7. Run limits (owner msg 1949): one full check may take up to 2 days before options go back to the owner; weekly dependency updates also wait for the full check; per-simulator serial capture is allowed for screenshot runs only, with several simulators running in parallel; the screenshot check goes first.
8. Matrix size and storage (owner msg 1949): the owner questioned the image count and the 30–100 GB storage estimate ("I expected hundreds of reference pictures"; "swift-snapshot-testing snapshots won't take so much space"). Both are re-derived with swift-snapshot-testing during the discussion. A spike measured package-test snapshots at about 27, 80 and 124 KB per light image at 1x, 2x and 3x, but found that package tests cannot render Liquid Glass, materials, alerts or sheets, so the capture path (app-hosted or package tests) is decided in the discussion.
9. Daily live-parsing check (owner msg 2006; product lead msg 2007): a scheduled GitHub Actions workflow runs once a day, fetches the live pages EhPanda parses (at least the Home front page, search, Popular, Toplists, a gallery with comments, the reader page and its image data, tag suggestions and the native Report form page) and runs the app's own parsers on them. It is read-only: it never sends a report, comment, vote, favorite or rating. On a failure it opens or updates one GitHub issue naming the page and what the parser expected, and closes that issue on the next clean run. Issues and logs carry no page content, images, gallery titles or account details, because the repository is public. Pages that need sign-in (Watched, Favorites, ExHentai) need a sign-in kept as a GitHub secret, which the owner supplies later; until then they are covered by saved fixtures only. Whether E-Hentai admits GitHub runner IPs is checked early; if it does not, options go back to the owner.

**Success Criteria** (what must be TRUE):

  1. The snapshot matrix covers every screen and state, the Phase 18 and 18.1 UI included, across six locales, three Dynamic Type sizes (xSmall, Large and AX5; owner msgs 2247, 2249), portrait and landscape, iPhone and iPad, and light and dark; each coordinate is captured, failed or justified not applicable. The matrix size and storage are re-derived in the discussion (scope item 8).
  2. Comparison is strict and never records; the screen-grouped baseline/actual/diff report is filterable, and a controlled regression proves detection.
  3. One owner-approved baseline covers the complete set, including the landed layout (17-20 folded in).
  4. The complete matrix gates every PR and release in CI, with its runtime reported; the native visual policy tests (17-09-T2) run in it.
  5. Preview review is documented and validated (17-15).
  6. A scheduled workflow runs the app's own parsers once a day on the live pages listed in scope item 9, sends nothing to the site beyond page reads, opens or updates one GitHub issue per failure naming the page and the expected structure, closes it on the next clean run, and leaves no page content, images, gallery titles or account details in issues or logs. Sign-in pages are covered by saved fixtures until the owner supplies the sign-in secret, and the runner-IP result is recorded.
  7. `Scripts/visual/README.md` matches the reduced Phase 17 harness and this phase's regression runner.
  8. Release builds still contain no capture code, fixtures, test assets or SnapshotTesting linkage.

**Plans**: 15/17 plans executed; phase complete 2026-11-11 with deferred items: 19-12 and 19-13 are not executed, and the hosted parts of 19-10 (green gate run) and 19-17 (controlled regression) are owed (owner msgs 3425, 3428); security: four threats accepted-deferred (owner msg 3573); success criteria 2, 3 and 4 are not proven until those run, see `19-VERIFICATION.md` (planned 2026-11-07; research: [19-RESEARCH.md](phases/19-visual-regression-marketing-export/19-RESEARCH.md), validation: [19-VALIDATION.md](phases/19-visual-regression-marketing-export/19-VALIDATION.md))

Plans:

**Wave 1**

- [x] 19-01-PLAN.md — app-hosted capture core, the 18-configuration test plan and a three-scenario tracer on both devices; local clone measurement
- [x] 19-11-PLAN.md — native visual policy XCUITests the matrix cannot cover (17-09-T2)

**Wave 2** *(blocked on 19-01)*

- [x] 19-02-PLAN.md — the schema-2 scenario inventory with reasoned not-applicable rules, the local runner and the deterministic 20-shard plan
- [x] 19-03-PLAN.md — the guard-free live-check test target and the runner-IP probe on GitHub's hosted Mac *(checkpoint: owner go-ahead before the push, OQ-6)*

**Wave 3** *(blocked on Wave 2)*

- [x] 19-05-PLAN.md — scenarios: first launch (age wall, analytics choice), the shell and the browsing pages
- [x] 19-06-PLAN.md — scenarios: search, quick search, filters, date seek, Favorites, Downloads and gallery detail
- [x] 19-07-PLAN.md — scenarios: detail pages, comments (posting warning, collapsed blocking), the Report form and the reader
- [x] 19-08-PLAN.md — scenarios: Settings and its pages (analytics picker, Blocked Users) and the app-wide presentations
- [x] 19-09-PLAN.md — the aggregate logic (a missing result never passes) and the screen-grouped, filterable review report
- [x] 19-14-PLAN.md — the live check's pages, block-versus-break classification and enum-only results

**Wave 4**

- [x] 19-04-PLAN.md — hosted measurement of picture cost, clone count and run-to-run identity; the measured shard plan *(checkpoint: owner go-ahead and billing, R-1)* — closed on the interim 2 workers (`source: model`): runs 42455556948, 42475531683 and 42533872440 chose no count under D-15's rule; billing `{}` ([summary](phases/19-visual-regression-marketing-export/19-04-SUMMARY.md))
- [x] 19-15-PLAN.md — the live check's runner choice, single-issue reporting, entry script, workflow and timer template *(checkpoint: owner picks the runner)*

**Wave 5**

- [x] 19-10-PLAN.md — inventory closed; the CI gate: 20 shards with retries, triage, aggregate and the native policy job *(checkpoint: owner go-ahead for the hosted proof on a `ci/` branch)* — closed without a passing hosted run (owner msg 3425): Tasks 1 to 3 done, hosted runs 1 to 3 failed and were fixed, run 42951290351 unread; the green run is deferred and owed before release day ([summary](phases/19-visual-regression-marketing-export/19-10-SUMMARY.md), [proof](phases/19-visual-regression-marketing-export/19-10-PROOF.md))
- [x] 19-16-PLAN.md — deploy the daily live check on the chosen runner and prove one real run *(checkpoint: owner go-ahead)*

**Wave 6**

- [ ] 19-12-PLAN.md — the full hosted candidate set and the public snapshot repository *(checkpoints: owner go-ahead for the run and for creating the repository)* — deferred, not executed (owner msg 3428); owed before any baseline publication

**Wave 7**

- [ ] 19-13-PLAN.md — agent pre-check of every picture, the owner's one approval, the push and the pinned baseline *(checkpoints: the approval, D-17, then the push go-ahead)* — deferred, not executed (owner msg 3428); owed before release day

**Wave 8**

- [x] 19-17-PLAN.md — the README rewrite, preview review docs, the controlled regression (red then green) and the phase gate *(checkpoints: the hosted regression and the owner's required-check choice)* — done except the hosted controlled regression (deferred, owner msg 3428) and the real preview render; required check: not required (owner msg 3431), for now; local gate green with the UITests first-run flakes and iPad retries accepted (owner msgs 3539, 3554), so `nyquist_compliant` is true ([summary](phases/19-visual-regression-marketing-export/19-17-SUMMARY.md))

Cross-cutting constraints:

- Scenario plans 19-05 to 19-08 pass candidate then two compares in `en-large` on both devices with 0 `changed`, `timeout` or `error`, and `ja-accessibility5` and `de-xSmall` on the phone (D-09, D-10).
- Scenario plans never edit `scenarios.json`; a state that cannot be rendered is proposed as a not-applicable rule with its reason, and 19-10 applies it (D-05).
- Only one `xcodebuild` runs at a time on a host (TESTING.md); nothing is pushed and no hosted run starts without the owner's go-ahead.

### Phase 20: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks

**Goal**: Make 3.0 distributable on the GitHub/AltStore Classic channel and on AltStore PAL: the marketplace build (same features as the GitHub IPA), the PAL source and listing with store screenshots decorated by the designer, the notarization pipeline through the collaborator's App Store Connect account, the website dependencies (the privacy policy and the PAL source URL; the support URL is the GitHub repository page), the fixed release mechanics and the two real-device checks. The last plan revises analytics for every 3.0 change, including the install source; the closing gate repeats the Release isolation scan on that final build. Tag creation and release order are not planned (owner msg 1753).
**Depends on**: Phase 19, relaxed by owner msg 2770: only store screenshots from the approved reference set and the release's reliance on the screenshot check wait for it (product lead msg 2771; CONTEXT D-13, D-14). Phases 18 and 18.1 are complete.
**Requirements**: DIST-18-01 (marketplace build flavor), DIST-18-02, DIST-18-03, DEV-18-01, REL-18-01, MKT-18-01 (promotional images and store screenshots), UGC-18-01 (its published contact link is dropped, owner msg 3501), ANALYTICS-02 (last plan); moved from Phase 17: CAP-17-05.

**Scope and owner decisions** (context: [20-CONTEXT.md](phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md); discussed 2026-11-09, decisions D-01 to D-22; OQ-1, the marketplace build's primary icon, resolved by D-22 (product lead msg 2775: the current icon is kept); items 3 and 5 are amended there by D-04, D-17 and D-19):

1. Marketplace build (owner msgs 1287, 1753): same features as the GitHub IPA, listed on AltStore PAL only; something is hidden only if Apple objects. Its own bundle ID comes through the existing `BUNDLE_ID_SUFFIX` setting, for the app and the share extension.
2. Apple-service actions (App IDs, the app record, certificates, API keys, marketplace registration, trader status) happen in the collaborator's App Store Connect account, by the collaborator or with the owner's explicit OK at that time; agents never create them on their own.
3. Store screenshots (owner msg 1753; msgs 1751, 1757): the website screenshots plus extra decorations by the designer Colo, who starts when this phase starts. The AltStore listing uses only non-adult pictures (guideline 2.3.8). This covers the AltStore promotional images moved from Phase 17 (17-22). No "Apple-approved" wording anywhere.
4. Website dependencies (website owner Leto): the privacy policy URL and the PAL source's public URL, and a support URL, needed before the AltStore build goes to Apple (Ampo msg 1774). The website privacy page is rewritten for the three analytics levels when 3.0 ships, not before.
   *Amended 2026-11-11 (owner msg 3501; product lead msg 3502):* The website gets no GitHub Issues link (owner msg 3501; product lead msg 3502): its existing GitHub link is enough, and installation questions are not answered. The published contact link is out of the 3.0 plan. The App Store Connect Support URL is the GitHub repository page, https://github.com/EhPanda-Team/EhPanda, whose Issues tab is the contact route; no website change is needed for it. Basis: Apple's guideline 1.5 (Developer Information: the app and its Support URL include an easy way to contact you) is one of the Notarization Review Guidelines; guideline 1.2 (UGC, published contact information) is not (checked 2026-11-11 at https://developer.apple.com/app-store/review/guidelines/).
5. Release mechanics (REL-18-01): build number above 158; `AltStore.json` keeps its version history and shows non-explicit screenshots; the AltStore download URL resolves to the release's actual asset. Owner msg 1753, "Tagging is not your business": no tag-style decision, no plan to remove or rename the `3.0.0` tag, no tag creation and no release order in the plans.
6. Real-device checks on owner hardware (DEV-18-01): the iPad Gallery Detail stall on a Release build, continued background downloads on an iPhone.
7. Analytics revision last (ANALYTICS-02; owner msgs 1289, 1753): it sits at the end of this phase because the install source needs the marketplace build and PAL distribution, which first exist here.
8. Closing gate: the Release isolation scan runs again on the final build, which includes the analytics revision (IN-02/IN-03 closed in Phase 18).

**Success Criteria** (what must be TRUE):

  1. A marketplace build flavor exists with its own bundle ID for the app and the share extension and the same features as the GitHub IPA; the unsigned IPA build and private local signing are unchanged.
  2. A PAL source JSON (`marketplaceID`, `nsfw: true`, ADP download URLs, version history) exists; the Classic `AltStore.json` stays for unsigned IPAs.
  3. The listing has an all-ages icon and owner-approved store screenshots built from the website screenshots with the designer's decorations, non-adult pictures only on the AltStore listing; the privacy policy is reachable in the app and on the listing, with a support URL, and no "Apple-approved" wording exists.
  4. The App Store Connect Support URL is the GitHub repository page (https://github.com/EhPanda-Team/EhPanda) and returns 200 before the AltStore build goes to Apple. *Amended 2026-11-11 (owner msg 3501):* this replaces "The website's published contact link (GitHub Issues) is live before the AltStore build goes to Apple"; the website gets no Issues link.
  5. A CI job submits for notarization, waits for the ADP and publishes it to the PAL source; whether an App Manager API key can create the version and submit is tested and recorded.
  6. The release workflows produce a build number above 158, keep the Classic `AltStore.json` version history with non-explicit screenshots, and point the AltStore download URL at the release's actual asset; no plan creates, removes or renames a tag or sets the release order.
  7. The iPad Gallery Detail stall is checked on a Release build and continued background downloads on an iPhone, on owner hardware.
  8. As the last plan, analytics record every 3.0 flow under the consent levels, within ANALYTICS-01's rules: the install signal carries the distribution channel at every level, Minimal sends nothing else, and nothing is sent before a level is chosen. *(Wording revised at 20-12, OQ-E: there is no level called None since Phase 18.)*
  9. The final 3.0 Release build, including the analytics revision, passes the Release isolation scan with 0 findings.

**Plans**: 14 plans in 8 waves (the waves follow the fixed order below, with two exceptions: 20-07, 20-09 and 20-12 start in wave 1 (CONTEXT D-23, product lead msg 2783 answering OQ-G), and 20-08, the PAL submission, comes last, after the Classic release (CONTEXT D-26, owner msg 2802)).

Ordered plan outline (CONTEXT D-14; product lead msg 2771; old step numbers are the original Phase 18's):

- **(a) Marketplace build flavor and release mechanics fixes** (was Step 1 without `MKSellsDigitalGoods` and without the tag checkpoint; REL-18-01, DIST-18-01): `Config/Marketplace.xcconfig` with the channel stamp set at build time, `PrivacyInfo.xcprivacy` (D-18), the build-number check in `deploy.yml` and the bump above 158. **Checkpoint (owner):** creating `EhPanda-Team/ehpanda-assets` on GitHub (D-17).
- **(b) PAL source JSON** (was part of Step 9; DIST-18-02): template, `assetURLs` support in the version filter, checks.
- **(c) Notarization CI job** (was Step 10; DIST-18-03). **Checkpoints (collaborator and owner, at the time):** Apple-account setup, keys, secrets and the first submission with the App Manager key test (D-07, D-21).
- **(d) Website dependencies check** (Leto): privacy policy, the support URL (the GitHub repository page), the PAL source URL. *Amended 2026-11-11 (owner msg 3501):* the published contact link and the support page are dropped.
- **(e) Real-device checks** (was Step 11; DEV-18-01). **Checkpoint (owner hardware).**
- **(f) Needs Phase 19** (D-14): PAL listing assets and store screenshots from the approved reference set (MKT-18-01 remaining part, from 17-22; the current icon is kept, D-22), and the release's reliance on the screenshot check. **Checkpoint (owner):** store screenshots and listing assets.
- **(g) Analytics revision** (was Step 12; ANALYTICS-02; the distribution channel is already in the install signal, D-06).
- **(h) Closing gate:** the Release isolation scan on the final build (from Step 7).

Plans:

**Wave 1** — (a); and (d), (e) and (g) part 1, which may start now (D-23)

- [x] 20-01-PLAN.md — the marketplace flavor (`Config/Marketplace.xcconfig`, channel stamp as a build setting), its hand-off scheme, and `PrivacyInfo.xcprivacy`
- [x] 20-02-PLAN.md — the build-number check in `deploy.yml`, the bump above 158, history and URL tests *(checkpoint: owner OK to create and push `EhPanda-Team/ehpanda-assets`)*
- [ ] 20-07-PLAN.md — the "Apple-approved" wording guard and the website check *(checkpoint: Leto, privacy and PAL source URLs live; amended 2026-11-11, owner msg 3501: no contact link, support URL is the GitHub repository page)*
- [ ] 20-09-PLAN.md — real-device checks *(checkpoints: owner hardware — iPad Release stall, iPhone background downloads)*
- [x] 20-12-PLAN.md — the analytics vocabulary proposal *(checkpoint: product lead and owner sign-off, OQ-E)*

**Wave 2** *(blocked on 20-01 and 20-02)* — (b)

- [x] 20-03-PLAN.md — the PAL source template, the filter's `assetURLs` support and the PAL checks, with no live ADP

**Wave 3** *(blocked on 20-03)* — (c)

- [x] 20-04-PLAN.md — offline-tested submit side: App Store Connect client, signing helper, dispatch-only submit job

**Wave 4** *(blocked on 20-04)* — (c)

- [x] 20-05-PLAN.md — offline-tested publish side: ADP, AltStore processing, release assets, PAL source update
- [ ] 20-06-PLAN.md — the collaborator's account setup and the GitHub environment *(checkpoints: App IDs, certificate, profiles, API key; agreements, marketplace, trader status, ratings, privacy answers, countries; environment and secrets; D-07)*

**Wave 5** *(blocked on 20-03, 20-05, 20-09 and Phase 19)* — (f)

- [x] 20-10-PLAN.md — store screenshots from Phase 19's approved references *(checkpoints: owner's screens, decoration and wording; owner approval, push and upload)* — *closed 2026-11-10 by product lead msg 3168 (owner msg 3167) with the owner's seven decorated iPhone screenshots (owner msg 2628; assets `41f9a13`), now in the PAL template; no longer depends on Phase 19. The App Store Connect upload, the PAL copy approval and any iPad set move to 20-08 (`20-10-SUMMARY.md`).*
- [x] 20-11-PLAN.md — the release and the PAL submission require the screenshot check's verdict *(checkpoint: OQ-F, answered by owner msg 3346: main-first; `main` merged 2026-11-11; the live reads exit 1 because Phase 19's gate pass is deferred, `20-11-GATE.md`)*

**Wave 6** *(blocked on Wave 5 and 20-12)* — (g)

- [ ] 20-13-PLAN.md — the signed-off signals, call sites, tests, and README in six languages

**Wave 7** *(blocked on 20-09 and 20-13)* — (h)

- [ ] 20-14-PLAN.md — the Release isolation scan in both flavors and the phase gate

**Wave 8** *(blocked on Waves 4 to 7, 20-07, and the 3.0 GitHub and Classic release, D-26)* — (c), the PAL submission

- [ ] 20-08-PLAN.md — the first live submission, which is also the final build; the App Manager key test, Apple's verdict and a dry-run publish *(checkpoints: OQ-A/OQ-B as D-26 settles them; owner OK per dispatch; real ADP layout; pauses for Colo if the icon is rejected under 2.3.8, D-22)*
