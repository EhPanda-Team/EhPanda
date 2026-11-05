# EhPanda

## What This Is

EhPanda is an open-source iOS / iPadOS client for E-Hentai / ExHentai — browsing, searching, favorites, gallery detail, reading, and downloading — built in SwiftUI on The Composable Architecture, modularized into a thin app shell (`App/`) plus a local Swift package (`AppPackage/`). This milestone is a **dependency-reduction & modernization** pass ahead of the unreleased **v3.0.0**: shrink the third-party surface to a minimal, justified set; move networking to async/await and TCA toward 2.0; retire legacy UI/architecture patterns (screen-metric math, global helpers, parameter drilling); and ratchet up lint — all with **behavior parity**, no user-facing regressions. The milestone closes with **3.0 release readiness** (Phase 18). That phase adds the only planned user-facing features: a first-launch age wall, analytics consent and comment moderation. It also adds marketplace distribution (AltStore PAL and others), the visual-regression and marketing work moved from Phase 17, and the reader page-tracking rework.

## Core Value

The load-bearing paths must keep working: reliably **fetch, parse, read, and download** galleries from E-Hentai / ExHentai. Every task in this milestone is a foundation change — parity with today's behavior is the bar; a modernization that regresses browsing, reading, or downloading has failed.

## Requirements

### Validated

<!-- Inferred from the existing codebase (see .planning/codebase/). These already ship and are relied upon. -->

- ✓ Browse & search galleries — Home (Frontpage/Popular/Watched/Toplists/History), Search, Favorites — existing
- ✓ Gallery detail — comments, torrents, archives, previews, tag detail — existing
- ✓ Reading — paged & vertical, dual-page, zoom/pan gestures, reading settings — existing
- ✓ Downloads — concurrent page downloads + background processing task — existing
- ✓ Auth — E-Hentai/ExHentai session cookies via `WKWebView` login — existing
- ✓ Tag translation — EhTagTranslation database + OpenCC Simplified/Traditional conversion — existing
- ✓ Persistence — swift-sharing `@Shared` (no Core Data) + progressive schema-migration engine (all models at v1) — existing
- ✓ Modular architecture — App-shell + `AppPackage` local package; deps centralized in `Package.swift` — existing
- ✓ Fork/modernize SwiftyOpenCC (DEP-01) — de-vendored to the EhPanda-Team fork (`OpenCC`), Simp/Trad parity — Phase 1
- ✓ Fork/modernize UIImageColors (DEP-02) — local `ImageColors` module (renamed; CGImage-in / SwiftUI-Color-out), extraction parity — Phase 1
- ✓ SwiftCommonMark → Apple swift-markdown (DEP-03) — local `MarkdownExt`; parse-only parity — Phase 1
- ✓ Investigate inlining DeprecatedAPI (DEP-06) — inlined as local warning-suppressed `LegacyCFReadStream`; DF request path byte-identical — Phase 1
- ✓ Migrate to latest Colorful (DEP-07) — migrated to ColorfulX 6.1.0 (Metal); gradient behavior parity restored after regression gap G-01-1 — Phase 1
- ✓ Migrate Combine-based requests to async/await (CONC-01) — 44 typed-throws requests, 64 migrated consumers, frozen transport/parse/error parity, and a Combine-free source tree — Phase 4
- ✓ Pin TCA with 2.0 deprecation traits (CONC-02) — TCA 1.25.3 floor resolving 1.26.0, both traits active, all 66 surfaced deprecations migrated with zero warnings — Phase 4
- ✓ Root-level privacy mask (UIARCH-04) — shared scene-driven blur state, one mask per each of 39 runtime presentation roots, and exhaustive foreground/background regression coverage — Phase 7
- ✓ Remove the custom auto-lock feature (UIARCH-05) — deleted biometric re-auth and `AuthorizationClient`, removed dead settings/localizations, and deferred app locking to iOS — Phase 7
- ✓ De-globalize `*Util` → injected clients, kill singletons (HYG-01) — side-effecting AppTools Utils (Device/Haptics/UserDefaults/Cookie) folded into injected clients; `URLUtil`/`FileUtil`/`AppInfo` kept as pure namespaces (D-06); `AppUtil`, `TouchHandler.shared`, and `DataCache.shared` removed; galleryHost threaded explicitly through every request seam — Phase 8
- ✓ Cookie-logging audit (QUAL-01) — no cookie value is emitted to logs at `.public` privacy, enforced by a static gate hardened against aliased-value/renamed-Logger evasion with an executable negative-fixture harness — Phase 8
- ✓ Client-layer test coverage (QUAL-02) — deterministic, green tests for the async `NetworkingFeature`, `CookieClient`, and `ImageClient` (per-test `DataCache`, pixel-dimension assertions) — Phase 8
- ✓ Fix `Category.private.filterValue` (QUAL-03) — the `fatalError` landmine is gone; `.private` reports filter-math misuse and contributes zero, while the ten searchable cases still sum to all 1023 filter bits — Phase 9
- ✓ Structured error handling + user-facing error surface (QUAL-04) — silent `try?` sites classified so genuine failures propagate through typed `throws(AppError)` while intentional fallbacks stay documented; a privacy-safe diagnostic surface (Description / Suggested Solution / Context / Environment) is reached through a persistent, accessible error toast, runtime-verified by simulator UAT — Phase 9
- ✓ Lint hardening capstone + refactor-gated rules (LINT-01) — 8 custom/opt-in SwiftLint rules live at **error** (`sorted_imports`, `multiline_function_chains`, `single_line_trailing_closure`, `labeled_tuple_elements`, `optional_try`, `binding_initializer`, `lifecycle_modifiers`, `unchecked_subscript_index_access`), all violations root-fixed with only 8 owner-reviewed exceptions; test-isolation cleanup removed all 41 `.serialized` traits (suite runs in parallel across 18 targets). Two UAT-caught regressions (detail-mode pagination, page-count icon size) fixed and confirmed — Phase 11
- ✓ Cloudflare login restoration — username/password login restored behind the Cloudflare wall: response-driven challenge detection (403 + `cf-mitigated`), an in-app auto-dismissing `WKWebView` challenge surface, memory-only `(cf_clearance, User-Agent)` capture replayed on the retried POST, bounded retries into a structured error; owner-verified live pass. A forum-side Turnstile CAPTCHA gate (appeared during UAT) is detected and routed to web login as fallback — Phase 12
- ✓ Deep-link hardening — every entry path (custom scheme, clipboard, in-comment link, ShareExtension, iPad tab modal) routes through one `GalleryURLParser` that normalizes and rejects spoofed input; `URLClient` deleted; unsupported links get a distinct non-retryable error whose context drops access-bearing URL components; modal replacement awaits real sheet dismissal instead of a fixed 1s delay, and the routing path no longer sleeps 500ms before swapping a loading toast for an error toast. Backed by a new UI-test target on a non-default retrying `UITests` plan with hermetic fixtures — 9 UI tests covering cold and warm lifecycles on iPhone plus the iPad class — Phase 13

- ✓ Dynamic Type and assistive-technology accessibility (A11Y-01/A11Y-02) — 26 plans, owner-signed sampled visual/runtime evidence, retained semantics and motion gates, and current iOS 27 regression gates; best-effort scope with explicit accepted/deferred/unmeasured limits — Phase 16
- ✓ Screenshot capture foundation, website screenshots, Release isolation and the landed size-class layout (CAP-17-01 fixture part, CAP-17-04 amended, CAP-17-06 bounded part, CAP-17-07 amended): checksummed offline real-gallery fixtures, the owner-approved website image set (192 coordinates, 2026-11-04 recapture), a Release build with no capture code, and the size-class migration verified with the owner's idiom census. Reduced scope; moved parts go to Phase 18 — Phase 17

### Active

<!-- This milestone's scope: 22 locked tasks. Hypotheses until shipped. Grouped by theme; the roadmap phases them. -->

**A · Dependency reduction** <!-- items 1, 2, 3, 6, 7 shipped at parity in Phase 1 → Validated -->
- [ ] 4. Replace **WaterfallGrid** with a custom SwiftUI `Layout` · *feasibility spike first*
- [ ] 5. Replace **SwiftUIPager** with a built-in page-style `TabView` · *feasibility spike first*

**C · UI architecture**
- [ ] 10. **Modernize adaptive layout** — remove screen-dependent logic (`DeviceUtil` + `DeviceClient`); prefer size classes / `containerRelativeFrame` / `onGeometryChange` / `ViewThatFits`, **avoiding `GeometryReader`**; retire `TouchHandler` via native gestures
- [ ] 11. **Decompose `GenericList`** — let each of its 8 consuming pages build its own list from shared atoms instead of a super-list
- [ ] 12. **Universal device orientation** on every page + remove EhPanda's custom orientation lock (delete `enablesLandscape`), deferring the lock to iOS's built-in feature

**F · UI polish**
- [ ] 21. **Numeric text polish** — apply `.monospacedDigit()` + `.contentTransition(.numericText())` to most number-bearing text (counts, page numbers, sizes, ratings)
- [ ] 22. **Reduce `ZStack` usage** — prefer `.overlay`/`.background` where a child overlays/underlays primary content (per-site judgment; overlay/background size to the primary child, `ZStack` to the union), at layout/appearance parity

<!-- item 9 (Lint hardening, LINT-01) shipped in Phase 11 → Validated -->

**G · 3.0 release readiness (Phase 18; emerged during Phase 17, owner msgs 1287, 1289, 1294, 1305 and the 2026-11-02 standards)**
- [ ] First-launch age wall and analytics consent in every build (AGE-18-01, CONSENT-18-01)
- [ ] Comment report/block/contact and posting filter in every build (UGC-18-01)
- [ ] Release mechanics, marketplace build, listing and notarization pipeline (REL-18-01, DIST-18-01..03)
- [ ] Snapshot regression, marketing export and AltStore promotional images, moved from Phase 17 (VIS-18-01, MKT-18-01; CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/04/06)
- [ ] Reader page tracking on one source of truth, with committed UI tests for the WR-01 rebuild paths and RTL page sync (Phase 18 Step 4b)
- [ ] Real-device checks and the final analytics revision with install source (DEV-18-01, ANALYTICS-02)


### Out of Scope

<!-- Explicit boundaries to prevent re-adding. -->

- **Accessibility Nutrition Label recommendation or universal conformance guarantee** — owner superseded the original Phase 16 bar on 2026-09-15. Preserve the approved limitations in `phases/16-dynamic-type-accessibility/16-VERIFICATION.md`; future work must not describe proxy or unreached evidence as measured passes.

- **ParserFeature complexity refactor** (extract per-field sub-parsers) — real value but rides on nothing else here; deferred to a future milestone
- **DownloadClient decomposition** (555+ line files) — large standalone refactor; deferred
- **Broad client-layer tests beyond networking/cookie/image** (Reading/Home/Search/Favorites features) — deferred; this milestone covers only the seams already being reworked
- **Post-release v2 schema migrations + migration-mock cleanup** — deferred until v3.0.0 ships; models stay at v1 this milestone
- **Session cookies → Keychain (at-rest migration)** — dropped per D-01 as out of milestone (sideload-distribution reliability tradeoff); QUAL-01 covers cookie-logging privacy only, not at-rest storage
- **Any visual redesign** — the UI-architecture tasks are mechanism swaps, not re-skins; behavior/appearance parity required
- **Re-enabling `function_body_length` / `cyclomatic_complexity` / `type_body_length`** — kept disabled; `ParserFeature` relies on it and it wasn't requested

## Context

- **v3.0.0 in flight, unreleased.** Phase 17 (Screenshot Automation, Visual Regression & OS 27 Modernization) is complete at its reduced scope (2026-11-05): verification passed 8/8, UAT 31/31, security verified, and validation validated with Nyquist gaps G1/G2 carried to Phase 18. Phase 18 (3.0 Release Readiness) is the remaining phase and is next for discussion and planning. Earlier phases retain their own roadmap statuses. The iOS 27/native-navigation/soft-top-edge migration landed in quick task `260921-f5u` and Phase 17 preserved it.
- **Codebase map** lives at `.planning/codebase/` (STACK, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, INTEGRATIONS, CONCERNS).
- **Reference designs** for the structured error surface (#20) and the refactor-gated lint rules (#9) have been captured name-free; the plan phase needs no external lookup.
- **Two tasks carry parity risk** and are spiked first: SwiftUIPager→`TabView` (core reading UX) and WaterfallGrid→custom `Layout` (masonry column balancing).

## Constraints

- **Tech stack**: Swift tools 6.4, iOS/iPadOS 27 minimum, SwiftUI + TCA (1.25.3 package floor) + swift-sharing; Xcode-only build/test (bare `swift build` fails); SwiftLint runs as a build-tool plugin.
- **Parity**: No user-facing behavior or appearance regressions — this is a foundation milestone, not a feature or redesign one.
- **Schema**: Persisted `@Shared` models stay at **v1**, edited in place, for the whole pre-release milestone — no `VersionedSchema` v2 / migration until v3.0.0 releases.
- **Lint**: SwiftLint-as-error; never suppress, disable, or add `// swiftlint:disable` without explicit user permission.
- **Reference privacy**: Never record the name of any local project consulted for implementation references in any repository artifact (see AGENTS.md) — absolute and non-waivable.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Combine→async/await stays in this milestone (not split out) | One coherent modernization milestone; sequence it after the isolated dep removals | ✓ Validated in Phase 4 |
| Spike-first for WaterfallGrid→Layout and SwiftUIPager→TabView | "Bet on native parity" items that can genuinely fail; reading is core UX | — Pending |
| Avoid `GeometryReader`; prefer size classes / `containerRelativeFrame` / `onGeometryChange` / `ViewThatFits` | Most cases don't need it; it's greedy and layout-disruptive | — Pending |
| Retire `TouchHandler` via `SpatialTapGesture.location` + `MagnifyGesture.startAnchor` | Native gestures (iOS 17+) cover all three uses; kills a global singleton | — Pending |
| Remove auto-lock (use iOS built-in per-app lock); **keep** background blur | OS app-lock supersedes the custom biometric flow; app-switcher blur stays as standalone privacy | ✓ Validated in Phase 7 |
| `@Shared` models edited in place at v1 until v3.0.0 ships | No released data to migrate from pre-release; defers first real v2 to post-release | — Pending |
| De-`Util` package-wide (incl. `URLUtil`, `AppUtil`) | Injected clients over singletons/global helpers; consistent architecture | ✓ Validated in Phase 8 |
| Keep `URLUtil`/`FileUtil`/`AppInfo` as pure namespaces, not thin client wrappers (D-06) | Pure deterministic helpers gain no substitutability from a client wrapper | ✓ Validated in Phase 8 |
| Drop the cookies→Keychain at-rest migration; QUAL-01 audits cookie logging only (D-01) | Sideload-distribution reliability tradeoff; out of milestone rather than deferred | ✓ Validated in Phase 8 |
| Fold in networking/cookie/image tests, `.private.filterValue` fix; defer Parser/Download refactors | Coupled concerns are cheap while their seams are open; standalone refactors are separate scope | Tests validated in Phase 8; `.private.filterValue` pending |
| Recommended sequence: small-blast deps → swaps/spikes → migrations (#8/#13) → architecture (#10/#11/#12/#14/#15/#19) → concerns (#16–18,#20) → lint capstone (#9) | Minimize churn; write new code to the new bar; lint ratchets last | Migrations validated through Phase 4 |
| Expand the TCA trait migration to the complete 66-site compiler inventory | D-11 found 45 presentation scopes, 11 Store scopes, and 10 reducer Scope initializers rather than the expected 24 sites | ✓ Owner-approved and validated in Phase 4 |
| Deep-link entry paths converge on one `GalleryURLParser`; `URLClient` is deleted rather than refactored | A single parse/normalize/reject seam is what makes spoofed-input rejection and destination correctness testable; a second URL abstraction only re-splits it | ✓ Validated in Phase 13 |
| Deep-link correctness is proven by a real UI-test target on a second, non-default `UITests` plan | Routing bugs live in the app's actual launch/foreground lifecycle, which TestStore cannot reach; keeping the plan non-default holds the ordinary scheme unit-only and fast | ✓ Validated in Phase 13 |
| Masonry grid columns derive from the `Layout`'s own container width via an adaptive rule (min cell width 185pt, min 2 columns); all cells share one identical flexible width; exact 2/4/5 count parity dropped | Owner requirement is stable, content-independent tiling at any width — not exact counts; kills the deprecated `UIScreen.main` + `isPadWidth` reads at the grid call site | — Pending |
| Accessibility closes through bounded evidence and explicit owner dispositions | Unreached sites, speech activation and contrast limits cannot be converted into universal guarantees | ✓ Phase 16 signed off; 26/26 consolidated checks passed |
| Keep native iOS 27 title/search behavior and existing reader index synchronization | Owner accepted focus limitations and the native VoiceOver mock page 1-to-41 evidence; withdrawn workarounds are not pending deliverables | ✓ Phase 16; retain page-agreement regressions |
| Current closing gates require zero failures and zero test Repetition nodes | A retried green result does not establish a first-try pass | ✓ Phase 16 FeatureTests and full iPhone/iPad UI gates |
| Reduce Phase 17 and move snapshot regression, the 384 export and AltStore images to Phase 18 (owner msg 1305) | 3.0 needed the capture foundation and website screenshots first; moved work is recorded as moved, never as satisfied | ✓ Phase 17 closed 2026-11-05; moved parts pending in Phase 18 |
| The website image set satisfies the screenshot-export requirement (CAP-17-04, amended) | The communicated website contract is iPhone-only: 192 coordinates, current set from the 2026-11-04 recapture (owner msgs 1581, 1640) | ✓ Phase 17 |
| Accept the idiom → size-class migration that landed before snapshot coverage, verified by reducer tests, one simulator pass and an owner idiom census | The migration had already landed in quick task `261015-duo-session-record`; the owner kept all five remaining idiom reads (msg 1409) | ✓ Phase 17; snapshot measurement in Phase 18 |
| Rework reader page tracking to one source of truth instead of more patches (owner msg 1630, product lead msg 1631) | Several copies of "the current page" reconciled by timing rules caused the WR-01 class of bugs | — Pending (Phase 18 Step 4b) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-05 after Phase 17*
