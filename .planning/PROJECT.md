# EhPanda

## What This Is

EhPanda is an open-source iOS / iPadOS client for E-Hentai / ExHentai — browsing, searching, favorites, gallery detail, reading, and downloading — built in SwiftUI on The Composable Architecture, modularized into a thin app shell (`App/`) plus a local Swift package (`AppPackage/`). This milestone is a **dependency-reduction & modernization** pass ahead of the unreleased **v3.0.0**: shrink the third-party surface to a minimal, justified set; move networking to async/await and TCA toward 2.0; retire legacy UI/architecture patterns (screen-metric math, global helpers, parameter drilling); and ratchet up lint — all with **behavior parity**, no user-facing regressions.

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

### Active

<!-- This milestone's scope: 21 locked tasks. Hypotheses until shipped. Grouped by theme; the roadmap phases them. -->

**A · Dependency reduction**
- [ ] 1. Fork **SwiftyOpenCC** — modernize its OpenCC dependency, package requirement & Swift version; rebuild on the latest stack
- [ ] 2. Fork **UIImageColors** — same modernization treatment
- [ ] 3. Migrate **SwiftCommonMark → Apple swift-markdown** (usage is parse-only via `MarkdownUtil`; confirm `DetailView`)
- [ ] 4. Replace **WaterfallGrid** with a custom SwiftUI `Layout` · *feasibility spike first*
- [ ] 5. Replace **SwiftUIPager** with a built-in page-style `TabView` · *feasibility spike first*
- [ ] 6. Investigate inlining **DeprecatedAPI** (`getCFReadStream`) without deprecation warnings; adopt a non-deprecated API if actionable
- [ ] 7. Migrate to the latest **Colorful** (modernization, not reduction)

**B · Concurrency & framework modernization**
- [ ] 8. Migrate **Combine-based requests → async/await** (`NetworkingFeature` request layer + `ApplicationClient`/`AuthorizationClient`/`ImageClient`/`LibraryClient` + consuming reducer effects)
- [ ] 13. Pin **TCA `from: 1.25.3` with traits** (`ComposableArchitecture2Deprecations`, `ComposableArchitecture2DeprecationOverloads`) and resolve all surfaced deprecations

**C · UI architecture**
- [ ] 10. **Modernize adaptive layout** — remove screen-dependent logic (`DeviceUtil` + `DeviceClient`); prefer size classes / `containerRelativeFrame` / `onGeometryChange` / `ViewThatFits`, **avoiding `GeometryReader`**; retire `TouchHandler` via native gestures
- [ ] 11. **Decompose `GenericList`** — let each of its 8 consuming pages build its own list from shared atoms instead of a super-list
- [ ] 12. **Universal device orientation** on every page + remove EhPanda's custom orientation lock (delete `enablesLandscape`), deferring the lock to iOS's built-in feature
- [ ] 15. **Root-level privacy mask** — replace `blurRadius` parameter-drilling (~25 inits, 39 `.autoBlur` sites) with one mask per root surface (app root + ~41 modal roots), driven by shared state
- [ ] 19. **Remove the auto-lock feature** — delete `autoLockPolicy`, the biometric re-auth path, and `AuthorizationClient`; replace the security-section control with a description pointing users to iOS's built-in per-app lock (background blur is kept)

**D · Architecture hygiene**
- [ ] 14. **De-globalize `*Util` → injected clients, kill singletons** — the AppTools Utils (Device/Haptics/UserDefaults/File/Cookie) plus `URLUtil` and `AppUtil`, and the `TouchHandler.shared` / `DataCache.shared` globals; keep pure value types & constants

**E · Correctness, security & tests (folded-in concerns, later timing)**
- [ ] 16. **Move session cookies to Keychain** (during #14's CookieClient work) + audit that no cookie values are ever logged
- [ ] 17. **Client-layer test coverage** — `NetworkingFeature` (during #8), `CookieClient` & `ImageClient` (during #14)
- [ ] 18. **Fix `Category.private.filterValue`** — remove the `fatalError` landmine
- [ ] 20. **Structured error handling + user-facing error surface** (gates the `optional_try` rule) — replace silent `try?` (144 sites) with proper `do/catch` that surfaces user-relevant failures through a structured error surface (Description / Suggested Solution / Context / environment info; non-blocking failure toast → tap for detail), keeping best-effort parsing explicitly optional

**F · UI polish**
- [ ] 21. **Numeric text polish** — apply `.monospacedDigit()` + `.contentTransition(.numericText())` to most number-bearing text (counts, page numbers, sizes, ratings)

**G · Lint hardening (capstone + refactor-gated)**
- [ ] 9. Enable the commented-out custom rules + opt-in `multiline_function_chains` & `sorted_imports` + a new **labeled-tuple-elements** rule, all at **error** level. Mechanical rules (`sorted_imports`, `multiline_function_chains`, `single_line_trailing_closure`, labeled-tuples) land as a capstone sweep; refactor-gated rules sequence **with** their refactors: `optional_try` → #20, plus `binding_initializer`, `lifecycle_modifiers`, `unchecked_subscript_index_access`

### Out of Scope

<!-- Explicit boundaries to prevent re-adding. -->

- **ParserFeature complexity refactor** (extract per-field sub-parsers) — real value but rides on nothing else here; deferred to a future milestone
- **DownloadClient decomposition** (555+ line files) — large standalone refactor; deferred
- **Broad client-layer tests beyond networking/cookie/image** (Reading/Home/Search/Favorites features) — deferred; this milestone covers only the seams already being reworked
- **Post-release v2 schema migrations + migration-mock cleanup** — deferred until v3.0.0 ships; models stay at v1 this milestone
- **Any visual redesign** — the UI-architecture tasks are mechanism swaps, not re-skins; behavior/appearance parity required
- **Re-enabling `function_body_length` / `cyclomatic_complexity` / `type_body_length`** — kept disabled; `ParserFeature` relies on it and it wasn't requested

## Context

- **v3.0.0 in flight, unreleased.** Last release was v2.8.0; ~600+ commits of refactoring since (persistence drop-to-`@Shared`, navigation refactor, migration engine — all landed). This milestone is the next batch: dependency reduction + modernization before v3.0.0 ships.
- **Codebase map** lives at `.planning/codebase/` (STACK, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, INTEGRATIONS, CONCERNS).
- **Reference designs** for the structured error surface (#20) and the refactor-gated lint rules (#9) have been captured name-free; the plan phase needs no external lookup.
- **Two tasks carry parity risk** and are spiked first: SwiftUIPager→`TabView` (core reading UX) and WaterfallGrid→custom `Layout` (masonry column balancing).

## Constraints

- **Tech stack**: Swift 6.3.1, iOS/iPadOS 26 minimum, SwiftUI + TCA 1.25.x + swift-sharing; Xcode-only build/test (bare `swift build` fails); SwiftLint runs as a build-tool plugin.
- **Parity**: No user-facing behavior or appearance regressions — this is a foundation milestone, not a feature or redesign one.
- **Schema**: Persisted `@Shared` models stay at **v1**, edited in place, for the whole pre-release milestone — no `VersionedSchema` v2 / migration until v3.0.0 releases.
- **Lint**: SwiftLint-as-error; never suppress, disable, or add `// swiftlint:disable` without explicit user permission.
- **Reference privacy**: Never record the name of any local project consulted for implementation references in any repository artifact (see AGENTS.md) — absolute and non-waivable.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Combine→async/await stays in this milestone (not split out) | One coherent modernization milestone; sequence it after the isolated dep removals | — Pending |
| Spike-first for WaterfallGrid→Layout and SwiftUIPager→TabView | "Bet on native parity" items that can genuinely fail; reading is core UX | — Pending |
| Avoid `GeometryReader`; prefer size classes / `containerRelativeFrame` / `onGeometryChange` / `ViewThatFits` | Most cases don't need it; it's greedy and layout-disruptive | — Pending |
| Retire `TouchHandler` via `SpatialTapGesture.location` + `MagnifyGesture.startAnchor` | Native gestures (iOS 17+) cover all three uses; kills a global singleton | — Pending |
| Remove auto-lock (use iOS built-in per-app lock); **keep** background blur | OS app-lock supersedes the custom biometric flow; app-switcher blur stays as standalone privacy | — Pending |
| `@Shared` models edited in place at v1 until v3.0.0 ships | No released data to migrate from pre-release; defers first real v2 to post-release | — Pending |
| De-`Util` package-wide (incl. `URLUtil`, `AppUtil`) | Injected clients over singletons/global helpers; consistent architecture | — Pending |
| Fold in cookies→Keychain, networking/cookie/image tests, `.private.filterValue` fix; defer Parser/Download refactors | Coupled concerns are cheap while their seams are open; standalone refactors are separate scope | — Pending |
| Recommended sequence: small-blast deps → swaps/spikes → migrations (#8/#13) → architecture (#10/#11/#12/#14/#15/#19) → concerns (#16–18,#20) → lint capstone (#9) | Minimize churn; write new code to the new bar; lint ratchets last | — Pending |

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
*Last updated: 2026-07-09 after initialization*
