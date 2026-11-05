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

- [x] **HYG-01**: De-globalize `*Util` into injected clients and remove singletons.
  - The AppTools Utils (Device/Haptics/UserDefaults/File/Cookie) plus `URLUtil` and `AppUtil` are converted to / folded into injected clients; `TouchHandler.shared` and `DataCache.shared` globals removed; pure value types and constants retained; no remaining static global helper with side effects.

### QUAL — Correctness, security & tests

- [x] **QUAL-01**: Audit cookie logging.
  - No cookie value is ever emitted to logs at `.public` privacy; the former at-rest migration was dropped per D-01 as out of milestone rather than deferred.
  - D-06 tightens HYG-01: retain `URLUtil` and `FileUtil` as pure namespaces rather than converting them to clients, in keeping with the anti-wrapper rule; D-07 eliminates `AppUtil` after relocating its surviving metadata facts.
- [x] **QUAL-02**: Add client-layer test coverage for the reworked seams.
  - `NetworkingFeature` covered (during CONC-01); `CookieClient` and `ImageClient` covered (during HYG-01); tests are deterministic and green.
- [x] **QUAL-03**: Fix the `Category.private.filterValue` `fatalError` landmine.
  - `filterValue` no longer crashes for `.private`; no callsite iterating all categories can trap; covered by a test.
- [x] **QUAL-04**: Replace silent `try?` with structured error handling and a user-facing error surface (gates the `optional_try` rule).
  - A structured `AppError` (description / suggested solution / typed context) exists; user-relevant failures surface via a non-blocking failure toast that opens a detailed, dismissable error surface (Description / Solution / Context / environment info); network/file/decode `try?` sites become proper `do/catch`; genuinely best-effort parsing stays explicitly optional (not every one prompts); `optional_try` can be enabled at error with zero violations.

### POLISH — UI polish

- [x] **POLISH-01**: Apply `.monospacedDigit()` + `.contentTransition(.numericText())` to most number-bearing text.
  - Counts, page numbers, sizes, ratings, and similar numeric text use monospaced digits and animate as numeric transitions where it makes sense; no layout jitter on value change.
- [x] **POLISH-02**: Reduce `ZStack` usage in favor of `.overlay`/`.background`.
  - `ZStack`s that express an overlay/background relationship (a child layered over or under primary content) become `.overlay`/`.background`, sized to the primary content, at layout/appearance parity; genuine union-sized multi-child stacks stay `ZStack`; no visual or layout regressions.
- [x] **POLISH-03**: Migrate legacy `PreviewProvider` previews to the `#Preview` macro and enrich them to cover all realistic states.
  - Every `_Previews: PreviewProvider` struct is converted to the `#Preview` macro; where a view has meaningful states, previews are enriched into multiple named `#Preview("…")` cases covering all realistic cases (e.g. empty / loading / loaded / error, boundary values such as min/max ratings, counts, page numbers, long vs. short text) using modern preview features — `@Previewable` for interactive state, preview traits (`.sizeThatFitsLayout`), and environment/Dynamic Type/color-scheme variants where useful. No `PreviewProvider` remains in the codebase.

### LINT — Lint hardening

- [x] **LINT-01**: Enable the stricter SwiftLint ruleset at error level.
  - The 5 commented custom rules (`binding_initializer`, `lifecycle_modifiers`, `optional_try`, `single_line_trailing_closure`, `unchecked_subscript_index_access`), opt-in `multiline_function_chains` & `sorted_imports`, and a new `labeled_tuple_elements` rule are all enabled at **error**; every violation resolved at its root, with **no unapproved suppressions** — an approved exception carries a `// reason:` comment plus `// swiftlint:disable:next`, and is owner-reviewed in the phase-end batch (D-01/D-02). Mechanical rules landed as a capstone sweep; the refactor-gated rules were resolved *in this phase*, not inherited clean from their coupled refactors.
  - **Delivered:** all 8 rules live at `severity: error`; **0 violations in 452 files** across `AppPackage/Sources`, `AppPackage/Tests`, `App` and `ShareExtension`, with every rule proven to fire by negative-control probe. **8 approved exceptions** repo-wide (6 `lifecycle_modifiers`, 2 `unchecked_subscript_index_access`), inventoried in `.planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md`; the other six rules shipped with zero. `optional_try` is enforced in test code too, with no path exclusion (D-15). `.serialized` is gone entirely and the full 565-test suite runs in parallel across 18 targets.
  - **Fell short:** D-13's `@MainActor` sweep freed only **17 of 186 cases** — 84% remain main-actor-isolated because TCA's `TestStore` is main-actor-bound — with no measurable wall-clock gain. D-09's stable preview identities are **half-done**: `PreviewSupport` ships, but `AppModels`' shared `Gallery` fixtures still mint random `UUID()`. 11-02's "unparseable list page throws" must-have is **inert** — D-04 Group A's degradation helper makes row-level failures non-throwing, so the conversion changed nothing observable. There is still **no network seam** (`urlSession: URLSession = .shared` as an init default at 50 sites), which capped reducer test coverage across plans 11-07…11-10.

### ANALYTICS — Usage analytics

- [x] **ANALYTICS-01**: Instrument the four flow families — lifecycle & navigation, search & discovery, reading & downloads, errors & feature adoption — through a type-closed, privacy-redacted signal vocabulary carried by the TelemetryDeck SDK.
  - The public signal API accepts no bare `String` apart from one audited exception — `SearchShape(keyword:)`, whose reduction is proven by sentinel reflection tests to transmit no keyword text (D-19) — so a title, keyword, tag value or URL cannot be transmitted even by accident; every counter and duration ships as a bucket, with two documented exceptions: exact search-keyword length, and exact per-namespace tag counts (D-16); the client no-ops entirely when the build carries no ingestion credential, keeping contributor clones, forks and the test workflow out of the dataset, while the two deploy workflows inject the credentials from repository secrets so official releases do report (the D-13 amendment recorded in `14-DECISIONS.md`); a runtime opt-out in General Settings stops every app-authored signal and empties the per-signal settings snapshot, leaving only the SDK's own session signal so installs still count (the D-01 reversal); and every signal carries a per-signal snapshot of the feature-adoption settings rather than a value frozen at launch.

### A11Y — Accessibility

- [x] **A11Y-01**: Complete full-range Dynamic Type readability and operability (AX1–AX5) on the Phase 10 font/reflow foundation.
  - Every user-facing app screen and sheet stays readable and operable at XXL / AX3 / AX5 with no *information loss* relative to the default size — no clipped or newly truncated text, no overlap, no unreachable control; dropping decoration to save space is acceptable, dropping contents is not. Layouts adapt by reflow only: no `dynamicTypeSize` cap, no `GeometryReader`, and `minimumScaleFactor` removed entirely (5 sites → 0). Default `.large` appearance parity is preserved and **outranks the `minimumScaleFactor` ban** where the two collide. Four error-level SwiftLint custom rules enforce the foundation (`minimumScaleFactor`, `.dynamicTypeSize(` as a modifier with environment reads still legal, `GeometryReader`, numeric-literal `.system(size:)`). Verified by an owner-signed simulator sweep across iPhone + iPad × portrait + landscape × three sizes, on a hand-logged-in simulator so authenticated content screens are reachable.

- [x] **A11Y-02**: Support VoiceOver, Voice Control, Reduced Motion, Sufficient Contrast, and Differentiate Without Color to the App Store Accessibility Nutrition Label bar.
  - Every interactive element is reachable and correctly announced under VoiceOver (icon-only controls labeled, decorative images hidden, state as traits not label text, correct reading order and post-navigation focus) and actuatable by Voice Control (present under "Show numbers"/"Show names", input label matching visible text). Meaningful motion is gated on `accessibilityReduceMotion` and decorative motion dropped; subtle crossfades and `.contentTransition(.numericText())` are deliberately excluded as non-vestibular. All text meets 4.5:1 and non-text 3:1 in light, dark and Increase Contrast — achieved without moving a single gallery category background color, by making the badge text color adaptive black/white on resolved background luminance (84/84 variants pass; structural floor 4.58:1 for any color). No information is conveyed by color alone. Verified by `performAccessibilityAudit()` on the non-default `UITests` plan plus a manual VoiceOver/Voice Control walkthrough, and closed by a Nutrition Label recommendation stating which categories are claimable.
  - *Superseded 2026-09-15 (owner):* EhPanda is not on the App Store; the bar is best effort, not the Nutrition Label. No Nutrition Label recommendation is produced. Contrast is not guaranteed by the UI audit (2026-09-14: the audit keeps only `hitRegion`, `sufficientElementDescription` and `trait`); the category colorset and contrast unit tests were initially retained. The subsequent owner reversal `f68610b270` removed the adaptive contrast helper and `ColorContrastTests`; current `CategoryColorsetInvariantTests` retain colorset pins only, with no text-contrast guarantee. The manual walkthrough becomes an agent-run walkthrough of the main flows (in-simulator VoiceOver, Voice Control label proxy, display settings) with the owner listening only to named utterances, closed by the D-25 re-sweep, the phase gates and owner sign-off.

### CAP — Screenshot capture and visual regression (Phase 17)

The current Phase 17 context supersedes older roadmap wording. The OS 27 modernization has already landed; this phase preserves it. The owner authorized provisional marketing selections on 2026-10-02 and will supply final identifiers before phase closure.

*Reduced 2026-11-03 (owner, msg 1305):* Phase 17 closes small. CAP-17-04 and CAP-17-07 are amended below. CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01 and CAP-17-06 move to Phase 18 with their plans (17-07 to 17-13, 17-14 T1/T3, 17-15, 17-20 to 17-22); they are moved, not satisfied. *Split 2026-11-05 (owner msg 1753):* when Phase 18 became Phases 18 to 20, these moved items went to Phase 19, except CAP-17-05 (17-22), which went to Phase 20.

- [x] **CAP-17-01**: Acquire and refresh versioned real-gallery fixtures explicitly, with provenance and asset checksums; replay capture runs offline without a real account, private library or credentials in artifacts.
  - Track provisional versus final selections. The agent may choose provisional real marketing content; final owner identifiers, set assignments, ordering and reader pages must replace it before closure, followed by capture regeneration and revalidation. Test data may be public synthetic, real or mixed independently of marketing content. Preserve manifest SSOT and the same-run download-folder deletion invariant.
  - *Split 2026-11-03 (owner, msg 1305):* the fixture acquisition, provenance and offline replay delivered by 17-03, 17-04 and 17-06, and the website fixture versions (16 owner-approved on 2026-11-02, `quick/261101-website-review/APPROVAL-20261102.md`, last held at fixture commit `134cbf3`; since `8ee4fc2` the repository keeps the 11 that the 2026-11-04 set uses) stay with Phase 17. Public regression test-data dispatch (17-11) and the final 384 reacquisition (17-21) move to Phase 18 (VIS-18-01, MKT-18-01).
- [ ] **CAP-17-02**: Implement SnapshotTesting coverage for an explicit current screen/state inventory across six locales, all twelve Dynamic Type sizes, portrait/landscape, iPhone/iPad and light/dark.
  - Account for all 576 requested coordinates per scenario as captured, failed or justified not applicable. Establish actual-screen full-content ScrollView/List/lazy capture through bounded completeness evidence; include native menus, dialogs, sheets and reader panels with actual-app captures. No reduced-window iPad dimension or representative-only substitution. Pin geometry, safe areas, traits, scale, runtime, time, ordering, IDs, readiness and animation state.
  - *Moved 2026-11-03 (owner, msg 1305):* to Phase 18 under VIS-18-01, with 17-08 to 17-12.
- [ ] **CAP-17-03**: Commit reviewed public-distributable snapshot baselines alongside tests and run the complete matrix on every PR and release.
  - Routine comparisons never record or replace missing references. Explicit candidates receive complete agent visual review and final owner approval before promotion. Provide a screen-grouped, filterable baseline/actual/diff report and actionable failures; prove controlled-regression failure and clean restoration. Document any measured comparison tolerance.
  - *Moved 2026-11-03 (owner, msg 1305):* to Phase 18 under VIS-18-01, with 17-12, 17-13 and 17-14 T1/T3. 17-20's separate post-layout approval is folded into Phase 18's single baseline approval because the layout migration already landed.
- [x] **CAP-17-04**: Produce a separate actual-app local website export covering all 384 locked screen/locale/theme/device/content-set coordinates.
  - Use the eight states from D-15, portrait iPhone Air and iPad Pro 11-inch (M5), pinned text size/runtime, normal device dimensions, 9:41 status bar and verified capsule removal. Verify state and settled content before capture and byte-identical cold reruns. Deliver images, complete inventory including failures/missing outcomes, provenance, dimensions/hashes, instructions and results; keep canonical locale casing in metadata and lowercase Chinese filename tokens. No duplicate visible gallery within one screen. Final owner selections gate final delivery.
  - *Amended 2026-11-03 (owner approval, msg 1305):* met by the 192 owner-approved website images of 2026-11-02 (`quick/261101-website-review/APPROVAL-20261102.md`): iPhone Air portrait, eight screens × six locales × two themes × two content sets, with fixed 9:41 status bars and verified artifact and browser checks. The communicated website contract drops the iPad axis (`quick/261101-website-review/PLAN.md`), so the 192 images replace the 384-coordinate count for this requirement. The 384 export tooling, its handoff validator and the 384 regeneration (17-07, 17-21) move to Phase 18 under MKT-18-01.
  - *Clarified 2026-11-05 (owner msg 1640):* the requirement means the current website image set, the 2026-11-04 recapture (quick task `261104-website-recapture`: 17 recaptures and 101 status-bar edits, 118 files serving the same 192 coordinates), approved by the owner in msg 1581 and recorded in the website repository's 2026-11-04 screenshot provenance record (`develop`, commit `d4393bd`) alongside the 2026-11-02 approval (17-FINAL-VALIDATION.md section 3).
- [ ] **CAP-17-05**: Assign AltStore promotional composition to a separate designer agent and validate its local consumer handoff.
  - Deliberately designed App Store-style images are required; raw captures alone do not satisfy delivery. The designer chooses its own screen list, matrix, composition/copy/dimensions and additional source needs; the capture pipeline supplies source material and metadata. Validate intended AltStore references without public publishing or inventing the design in capture planning.
  - *Moved 2026-11-03 (owner, msg 1305):* to Phase 18 under MKT-18-01 and DIST-18-02, with 17-22.
- [x] **CAP-17-06**: Preserve the implemented iOS/iPadOS 27, Swift 6.4 and native navigation/search/toolbar/top-edge behavior.
  - Verify native root and sheet titles, search focus/query/orientation, cold entry and live size changes at standard/AX1/AX3/AX5 on both families; native overflow/Picker/Toggle behavior and stable action-source anchors; soft top edges at effective hosts and independent presentation roots. Preserve current Phase 16 owner dispositions and evidence bounds. Research Xcode 27 agent preview tools and verify returned destination before using their images as development/review evidence.
  - *Split 2026-11-03 (owner, msg 1305):* Phase 17 signs off with bounded evidence (existing behavioral tests and the recorded standard/AX1/AX3/AX5 title, search and top-edge checks). The snapshot-measured parts (17-09-T2 native visual policy tests, 17-15 preview review) move to Phase 18 under VIS-18-01.
- [x] **CAP-17-07**: Isolate capture controls/fixtures/dependencies from Release and replace device-idiom layout decisions only after snapshot coverage is implemented.
  - Inspect Release payload and dependency graph; no capture/test assets or activation path ships. Audit direct and client-mediated idiom reads and derived layout flags, replace actual layout decisions with size classes/container fitting, and preserve non-layout capabilities. Verify changes through completed snapshots plus behavioral/accessibility checks; no lint or warning suppression.
  - *Amended 2026-11-03 (owner approval, msg 1305):* the idiom → size-class layout migration landed through quick task `261015-duo-session-record` (`605b4e4749`, `e03456839a`, `30ef583d21`, `7cf9ff16ef`) **before** snapshot coverage existed, not after it. It is verified through the existing reducer tests, one simulator pass (iPad full width, a narrow iPad window, iPhone landscape) and a census of the remaining idiom reads with owner keep/change decisions (17-16 to 17-19). Release isolation is proven by 17-14 T2. Snapshot measurement of the layout moves to Phase 18 (VIS-18-01).

### Phases 18 to 20 — 3.0 release readiness

Owner decisions 2026-11-02 and 2026-11-03 (msgs 1287, 1289, 1294, 1299, 1305). Every requirement here applies to every build unless it names the marketplace build.

*Split 2026-11-05 (owner msg 1753):* the original Phase 18 is now three phases: 18 (in-app work), 19 (visual regression and marketing export) and 20 (distribution). The requirement IDs keep their `-18-` names. Each requirement below names its phase; the 2026-11-05 owner decisions (msgs 1753, 1765, 1767, 1780) are recorded as amendments.

- [ ] **REL-18-01**: Fix the 3.0 release mechanics.
  - The release and pre-release workflows use one tag style for the GitHub release and the AltStore `downloadURL` (today the tag is `3.0.0` while the link uses `v3.0.0`). The existing `3.0.0` tag is removed or renamed only with the owner's OK at that time. The build number is above 158. The AltStore Classic listing (`AltStore.json`) shows new non-explicit screenshots and keeps its version history instead of overwriting the previous entry. The final 3.0 Release build passes the Release isolation scan again.
  - *Amended 2026-11-05 (owner msg 1753, "Tagging is not your business"):* the tag-style choice and the removal or renaming of the existing `3.0.0` tag are dropped from the plans; no plan creates a tag or sets the release order. The AltStore download URL must still resolve to the release's actual asset. Phase 20.
- [ ] **DIST-18-01**: Prepare the app for marketplace distribution.
  - `App/Info.plist` declares `MKSellsDigitalGoods` = `NO`. A marketplace build flavor uses its own bundle ID (through the existing bundle-ID suffix setting, not the canonical `app.ehpanda`) for the app and share extension, without changing the existing unsigned IPA build or private local signing settings.
  - *Split 2026-11-05 (owner msg 1753):* `MKSellsDigitalGoods` (app code, every build) is Phase 18; the marketplace build flavor is Phase 20. The marketplace build has the same features as the GitHub IPA, and something is hidden only if Apple objects.
- [ ] **AGE-18-01**: Add a first-launch age wall.
  - On first launch, before any content is shown or any network request is made, the user must confirm they are an adult, and legally allowed to view explicit content under every law that applies to them, wherever it comes from (for example where they are, where they live, or their citizenship). Not just "18 or older", and not only the law of the place they live; e.g. an American citizen living abroad. Until they do, nothing else in the app works, and there is no skip. Answering no keeps them on that screen. The answer is stored on the device. The website's adult-mode declaration uses the same wording (website dependency).
  - *Clarified 2026-11-05 (owner msg 1753):* Phase 18. Two first-launch screens, shown once to everyone, upgraders included: the age wall, then the analytics choice. The on-screen declaration is the owner-approved website sentence (msgs 1454, 1457), word for word, with no list of examples; the examples above describe the intent. The screen has no "No" button: Continue stays dimmed until the declaration is ticked. Copy approved in owner msg 1767 (`18-COPY-FIRST-LAUNCH.md`).
- [ ] **CONSENT-18-01**: Collect no analytics until the user chooses.
  - A first-launch screen offers a few levels of sharing, including none. The analytics SDK is not started before consent. The choice can be changed later in Settings. This replaces Phase 14's "on by default, switch off in Settings" (ANALYTICS-01's opt-out). Guideline 5.1.1: consent is needed even for anonymous usage data.
  - *Clarified 2026-11-05 (owner msg 1753):* Phase 18. Three levels, None / Basic / Full, none pre-selected; a Settings picker replaces the toggle. Copy approved in owner msg 1767 (`18-COPY-FIRST-LAUNCH.md`).
- [ ] **UGC-18-01**: Moderate comments for App Review Guideline 1.2, in every build.
  - Every comment offers a report action: it links to E-Hentai's own report option where the site provides one, otherwise to the support contact. Blocking a user hides their comments locally on this device. Contact details appear on the support page and in Settings. Comment posting passes a filter for objectionable content. Ships to all users in every build, not only the marketplace build.
  - *Amended 2026-11-05 (owner msgs 1753, 1765, 1780):* Phase 18, except the contact part. Reporting goes to E-Hentai only (the gallery's report page), with no support-contact fallback. The filter warns and lets the user post anyway, for edits too. Blocking collapses the comment into "Comment from a user you've blocked" (Show / Unblock, name not shown) instead of hiding it, and Settings has a Blocked Users list. No in-app contact option is added now (msg 1774); the contact part becomes a published contact link (GitHub Issues on the website), needed before the AltStore build goes to Apple: Phase 20. Copy approved in owner msg 1780 (`18-COPY-COMMENTS.md`).
- [ ] **VIS-18-01**: Complete snapshot regression, moved from Phase 17 (CAP-17-02, CAP-17-03, moved parts of CAP-17-01/06).
  - Scenarios, public real-app dispatch, strict never-record comparison and the review report (from 17-08 to 17-12) cover every screen, including the age wall, consent and comment-moderation UI. One owner baseline approval (from 17-13) covers the landed layout too, so 17-20's separate post-layout approval is not needed. The complete matrix gates every PR and release (from 17-14 T1/T3), and preview review is documented (from 17-15).
  - *Phase 19 (split 2026-11-05, owner msg 1753).* The new screens include the Phase 18 Settings analytics picker and the Blocked Users list. Fixtures carry at least six galleries per Toplists period.
- [ ] **MKT-18-01**: Complete the marketing export and AltStore promotional images, moved from Phase 17 (CAP-17-05, moved parts of CAP-17-01/04).
  - The 384-coordinate export tooling and handoff validator (from 17-07), the final owner gallery selection and 384 regeneration (from 17-21), and designer-made AltStore promotional images with a validated local handoff (from 17-22), each with its owner checkpoint.
  - *Split 2026-11-05 (owner msg 1753):* the export tooling, final selection and 384 regeneration are Phase 19. The promotional images are Phase 20, as store screenshots: the website screenshots plus the designer's decorations, with only non-adult pictures on the AltStore listing (msgs 1751, 1757).
- [ ] **DIST-18-02**: Prepare the marketplace listing.
  - A separate AltStore PAL source JSON with `marketplaceID`, `nsfw: true` and ADP download URLs, keeping version history; the Classic `AltStore.json` stays for unsigned IPAs. All-ages (4+) icon and listing screenshots. The privacy policy is reachable in the app and on the listing, with a support URL (the pages are website work owned by another team member; this requirement records the dependency). No "Apple-approved" wording anywhere.
  - *Phase 20 (split 2026-11-05).* AltStore PAL is the only marketplace listing for 3.0 (owner msg 1753).
- [ ] **DIST-18-03**: Automate notarization and publishing.
  - Submission for notarization runs through the collaborator's App Store Connect account. Test and record whether an App Manager API key can create the version and submit. A CI job submits for notarization, waits for the ADP and publishes it to the PAL source. Account setup, keys and the first submission are a collaborator and owner checkpoint; agents never create Apple-service records on their own.
  - *Phase 20 (split 2026-11-05).*
- [ ] **DEV-18-01**: Run the two outstanding real-device checks on owner hardware.
  - The iPad Gallery Detail stall (deferred in Phase 16) on a Release build, and continued background downloads (Phase 15) on an iPhone.
  - *Phase 20 (split 2026-11-05).*
- [ ] **ANALYTICS-02**: Revise analytics for Phase 18, as the last plan.
  - Track which marketplace or install source the app came from, and update the signal vocabulary for every other Phase 18 change (age wall, consent, comment moderation, marketplace build), within the consent levels and ANALYTICS-01's type-closed, privacy-redacted rules.
  - *Placed 2026-11-05 (owner msg 1753):* the last plan of Phase 20, because the install source needs the marketplace build, which first exists there. It covers the changes of Phases 18 to 20.

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
| HYG-01 | Phase 8 | Complete |
| QUAL-01 | Phase 8 | Complete |
| QUAL-02 | Phase 8 | Complete |
| QUAL-03 | Phase 9 | Complete |
| QUAL-04 | Phase 9 | Complete |
| POLISH-01 | Phase 10 | Complete |
| POLISH-02 | Phase 10 | Complete |
| POLISH-03 | Phase 10 | Complete |
| LINT-01 | Phase 11 | Complete |
| ANALYTICS-01 | Phase 14 | Complete |
| A11Y-01 | Phase 16 | Complete |
| A11Y-02 | Phase 16 | Complete |
| CAP-17-01 | Phase 17 (moved parts: Phase 19) | Complete (Phase 17 part; moved parts under VIS-18-01, MKT-18-01) |
| CAP-17-02 | Phase 19 (moved 2026-11-03; split 2026-11-05) | Pending |
| CAP-17-03 | Phase 19 (moved 2026-11-03; split 2026-11-05) | Pending |
| CAP-17-04 | Phase 17 (amended 2026-11-03) | Complete |
| CAP-17-05 | Phase 20 (moved 2026-11-03; split 2026-11-05) | Pending |
| CAP-17-06 | Phase 17 (moved parts: Phase 19) | Complete (Phase 17 part; moved parts under VIS-18-01) |
| CAP-17-07 | Phase 17 (amended 2026-11-03) | Complete |
| REL-18-01 | Phase 20 | Pending |
| DIST-18-01 | Phase 18 (`MKSellsDigitalGoods`), Phase 20 (marketplace build flavor) | Pending |
| AGE-18-01 | Phase 18 | Pending |
| CONSENT-18-01 | Phase 18 | Pending |
| UGC-18-01 | Phase 18 (published contact link: Phase 20) | Pending |
| VIS-18-01 | Phase 19 | Pending |
| MKT-18-01 | Phase 19 (promotional images: Phase 20) | Pending |
| DIST-18-02 | Phase 20 | Pending |
| DIST-18-03 | Phase 20 | Pending |
| DEV-18-01 | Phase 20 | Pending |
| ANALYTICS-02 | Phase 20 (last plan) | Pending |

**Coverage:**

- v1 requirements: 44 total
- Mapped to phases: 44 ✓
- Unmapped: 0

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-11-05 — Phase 18 split into Phases 18 to 20 (owner msg 1753): AGE-18-01 and CONSENT-18-01 in 18; VIS-18-01 and the moved CAP-17-02/03 and CAP-17-01/06 parts in 19; REL-18-01, DIST-18-02, DIST-18-03, DEV-18-01, ANALYTICS-02 and CAP-17-05 in 20; DIST-18-01, UGC-18-01 and MKT-18-01 split across two phases. Owner decisions of 2026-11-05 (msgs 1753, 1765, 1767, 1780) recorded as amendments; 44/44 mapped.*
*Previously updated: 2026-11-05 — Phase 17 complete: CAP-17-04 and CAP-17-07 (amended) complete; CAP-17-01 and CAP-17-06 complete for their Phase 17 parts, moved parts under VIS-18-01 and MKT-18-01; CAP-17-02, CAP-17-03 and CAP-17-05 stay pending in Phase 18 (moved, not satisfied). Marked by hand at the transition because `phase.complete` could not parse the Phase 17 **Requirements** line and marked nothing.*
*Previously updated: 2026-11-03 — Phase 17 reduced (owner, msg 1305): CAP-17-04 and CAP-17-07 amended; CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/06 mapped to Phase 18; eleven Phase 18 requirements added (msgs 1287, 1289, 1294, 1299, 1305 and the 2026-11-02 age-wall and consent standards); 44/44 mapped. 2026-11-05: CAP-17-04's referent clarified as the current website image set (owner msg 1640).*
*Previously updated: 2026-10-02 — Phase 17 capture requirements assigned; provisional selections authorized, final owner identifiers required before closure.*
*Previously updated: 2026-09-23 — A11Y-01/A11Y-02 complete under the signed best-effort scope; see Phase 16 verification and its explicit overrides.*
*Previously updated: 2026-07-26 — ANALYTICS-01 restated after the 14-18 owner checks: D-01 reversed for a runtime opt-out, and D-13 amended so the deploy workflows inject credentials while clones, forks and the test workflow stay silent; 23/23 mapped*
