# Phase 11: Infra Refactor & Lint Capstone - Research

**Researched:** 2026-07-20
**Domain:** SwiftLint ruleset ratchet (custom regex rules, built-in opt-in rules), TCA lifecycle refactor, Swift Testing parallelization
**Confidence:** HIGH — all violation counts and tool behaviors verified empirically in this session against HEAD (`202594e8`) with the project's own SwiftLint 0.65.0 binary

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### optional_try (exception-gated ban)
- **D-01:** Every `try?` is a violation by default. An exception exists only when the code genuinely cannot be implemented without `try?`; each exception is requested, then individually reviewed and granted by the owner.
- **D-02:** Approved exceptions are expressed as `// reason: …` + `// swiftlint:disable:next optional_try` (the form the existing `swiftlint_disable_requires_reason` custom rule polices). Success criterion 3 is amended accordingly: "no **unapproved** disables" rather than "no disables".
- **D-03:** Refactored sites bring the error to the nearest surface — the owning reducer — which decides whether to present it to the user via the Phase 9 ErrorInfo/toast machinery.
- **D-04:** ParserFeature degradation sites split by group:
  - **Group A (per-row drops, 23 sites)** and **Group B (per-field defaults, 13 sites)**: converted to explicit `do/catch` that logs the swallowed failure via `OSLog.Logger` (file-top `private let logger` convention) while exactly mirroring current behavior — row skipped, field defaults to `nil`/`[]`. No `try?` survives.
  - **Group C (whole-parse collapses, 6 sites** — `Parser+List.swift:10–29` empty-list fallbacks, `Parser+Detail.swift:128`, `Parser+Shared.swift:38` static-regex compile**)**: propagate to the owning reducer as real errors. An unparseable page must no longer silently render as "no results".

#### Refactor-gated rules (binding / lifecycle / subscript)
- **D-05:** `binding_initializer` is narrowed to ban only closure-based `Binding(get:set:)`. `Binding($x)` (Optional-unwrap / `@Shared`-projection, the canonical TCA+Sharing idiom, ~29 sites) stays legal. The one real `get:set:` site (`AppPackage/Sources/AppComponents/AppAlertState.swift:235`) is refactored or reviewed.
- **D-06:** `lifecycle_modifiers` is a blanket ban on `.onAppear`/`.onDisappear`/`.task` (~46 sites). All lifecycle work migrates into reducers. Self-contained store-less components that cannot be implemented without a lifecycle modifier may be owner-reviewed exceptions (same reason + disable:next form).
- **D-07:** Replacement mechanism is presentation-driven lifecycle: the reducer that presents a screen kicks off its lifecycle — setting `Destination`/`StackState` (or handling the navigation action) runs the child's former `onAppear` effect. Lifecycle becomes a state transition, not a view callback.
- **D-08:** `unchecked_subscript_index_access` violations resolve via inherently safe idioms (first/last, `prefix`, `indices.contains` guard, `zip`, `[validatedIndex]` local). Where indexing is genuinely required, adopt the checked-subscript idiom from a reference project: a `precondition(collection.indices.contains(index))` bounds check wrapping the single sanctioned `// reason:` + `swiftlint:disable:next unchecked_subscript_index_access`.
- **D-09:** Also adopt the reference project's stable preview-identity design: a PreviewSupport-style module holding a fixed table of stable UUID strings (count-asserted, `compactMap(UUID.init(uuidString:))`), exposed **only** through that checked static subscript, giving previews deterministic fixture identities instead of random `UUID()`.

#### labeled-tuple-elements rule (new)
- **D-10:** The rule requires labels on every element of every multi-element tuple **type** — return types, properties, typealiases, and closure signatures (~27 current unlabeled sites). Construction literals (`return (a, b)`) are not policed.
- **D-11:** A small named struct is an equally valid root fix where labels are awkward or the compiler misbehaves (Phase 4 hit a compiler crash on a labeled-tuple expression in a task group), and is **required** whenever a tuple would break the built-in `large_tuple` rule (which stays enabled at its defaults).

#### Test parallelization
- **D-12:** Production seam changes are in scope as the sanctioned root fix for serialization: wherever a fixed global path or singleton forces `.serialized` (e.g. FileClient's live importer writing fixed real Caches/Application Support paths), add an injectable seam (directory root, dependency) — the Phase 8 DataCache-injection precedent.
- **D-13:** `@MainActor` survives on a test only when the test actually requires the main actor or becomes meaningless without it; every other occurrence is removed.
- **D-14:** Governing criterion for retained serialization: it survives only where the test becomes meaningless (or incorrect) without it, documented by an in-file rationale comment. `DidLoginKeyTests` qualifies and stays a deliberately single sequential test: Sharing's reference cache is a process-global weak table keyed by the key's constant id, and per-test key ids would stop testing the production `.didLogin` key.

### Claude's Discretion
- Enforceable regex shape for the new labeled-tuple-elements rule while implementing D-10 (chosen scope: type positions only).
- Per-suite diagnosis of what shared state forces each of the 39 DownloadsFeatureTests suites (helpers already use UUID-scoped roots; Kingfisher's shared disk cache appears in two suites) and the matching injection design, within the D-12/D-14 policy.
- Mechanical-rule configs without decision points (`sorted_imports` ordering, `multiline_function_chains` threshold) follow SwiftLint defaults/conventions.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LINT-01 | Enable the stricter SwiftLint ruleset at error level: the 5 commented custom rules, opt-in `multiline_function_chains` & `sorted_imports`, and a new labeled-tuple-elements rule, all at **error**; every violation resolved at root (no unapproved suppressions per D-02); mechanical rules land as a capstone sweep, refactor-gated rules land with their refactors | Full violation inventory verified by running SwiftLint 0.65.0 with all draft rules enabled (see Verified Violation Inventory); rule-by-rule resolution patterns, regex redefinitions (D-05 narrowing, D-10 new rule), autocorrect coverage, and test-parallelization seam designs below |
</phase_requirements>

## Summary

This phase is almost entirely codebase-internal; the research product is a **verified violation inventory** (obtained by actually running the project's pinned SwiftLint 0.65.0 with every draft rule enabled) plus the mechanics for each resolution pattern. Headline numbers at HEAD: 1,810 total violations across the seven rules-to-enable, of which 870 are `sorted_imports` (auto-correctable — verified `--fix` works and sorts by module name ignoring `@testable`), 316 are `optional_try` (127 in Sources matching CONTEXT, **plus 189 in Tests that the CONTEXT scope correction did not count** — test targets carry the lint build plugin, so this needs a scope decision), 239 are `unchecked_subscript_index_access` (far more than any prior estimate; many are Optional-returning Dictionary subscripts that are already safe), 223 are `single_line_trailing_closure`, 85 `multiline_function_chains`, 47 `lifecycle_modifiers`, and 30 `binding_initializer` (of which exactly 1 is the closure-based form D-05 actually bans).

The refactor work splits cleanly: (1) `try?` elimination — 42 ParserFeature sites already grouped A/B/C by D-04, 36 DownloadClient + 17 AppTools + 32 others each needing do/catch+logger, reducer propagation, or an owner-granted exception; (2) lifecycle migration — ~43 real view-modifier sites (the regex also matches 3 reducer `case .onAppear(` lines, meaning the migration must also rename the TCA actions themselves or the rule still fires); (3) subscript-safety triage across 16 modules; (4) test parallelization — 41 `.serialized` suites and 45 `@MainActor` test files, where the existing per-sessionID `SharedSessionStubURLProtocol` and UUID-scoped roots mean much of the isolation machinery already exists and `.serialized` is partly vestigial.

**Primary recommendation:** Plan in three tracks — (A) refactor-gated rule resolution (try?/lifecycle/binding/subscript, per-module waves), (B) test-isolation cleanup (seams first, then trait removal), (C) the mechanical capstone sweep LAST (`swiftlint --fix` for sorted_imports, manual for the rest), with the config flip per rule landing in the same commit as its last violation fix so the build gate proves zero violations.

## Project Constraints (from CLAUDE.md)

- **Reducer naming:** `Feature` suffix (e.g. `SettingFeature`) — any new sub-reducers created during lifecycle migration must follow it.
- **SwiftLint coverage for new modules:** a new module (e.g. the D-09 PreviewSupport-style module) MUST get a `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml` at its root (60 such per-module configs exist today; every Sources/ and Tests/ module has one).
- **Read `.swiftlint.yml` before writing Swift:** suppressing/disabling any rule is forbidden without explicit owner permission — this phase's D-01/D-02 exception mechanism (`// reason:` + `swiftlint:disable:next`) IS that permission channel, granted per-site by the owner.
- **Labeled localized-format arguments / non-translated keys:** apply if any `.xcstrings` entries are touched (unlikely this phase).
- **Confirmation dialog/alert placement:** relevant when refactoring `AppAlertState.swift` (D-05 site) — the alert modifier placement rules must be preserved.
- **Local project reference privacy (ABSOLUTE):** the checked-subscript + stable-UUID design came from a local reference project; it is reproduced name-free in CONTEXT.md — no plan/artifact may name the source project.
- **No absolute home paths in generated docs:** tool paths below are written `$HOME/…`.

## Architectural Responsibility Map

| Capability | Primary Owner | Secondary | Rationale |
|------------|--------------|-----------|-----------|
| Rule definitions & severities | root `.swiftlint.yml` (+ 60 `parent_config` stubs) | — | Single config; per-module files only chain to parent |
| Lint enforcement | SwiftLintBuildToolPlugin (per-target, build-time) | standalone binary for sweeps | Plugin attached to all source AND test targets, plus both Xcode app targets |
| Error propagation (D-03/D-04 C) | Owning reducers (TCA) | Phase 9 ErrorInfo/toast machinery | Reducer decides presentation; parser stays pure throwing |
| Swallowed-failure logging (D-04 A/B) | ParserFeature file-top `private let logger` | OSLogExt `Logger` init convention | 31 existing `private let logger` precedents |
| Lifecycle effects (D-07) | Presenting reducer (Destination/StackState transition) | child reducer action | Presentation is a state transition; `ifLet`/`forEach` auto-cancel child effects on dismissal |
| Preview fixture identity (D-09) | New PreviewSupport-style module (AppPackage) | consuming previews | Only exposure is the checked static subscript |
| Test isolation seams (D-12) | Production clients (injectable roots/deps) | test helpers | Phase 8 DataCache/rootURL precedent; seams live in production code |

## Standard Stack

### Core (all already installed — no new packages)

| Tool/Library | Version | Purpose | Verification |
|---------|---------|---------|--------------|
| SwiftLint (via SwiftLintPlugins) | 0.65.0 (resolved in `AppPackage/Package.resolved`; artifactbundle binary reports 0.65.0) | Rule enforcement, `--fix` autocorrect | [VERIFIED: ran binary this session] |
| Swift Testing | bundled with toolchain | Parallel-by-default test runner; `.serialized` trait removal target | [VERIFIED: in-repo usage] |
| ComposableArchitecture | 1.25.3+ w/ traits (Phase 4) | Presentation-driven lifecycle target architecture | [VERIFIED: in-repo] |
| OSLog (via OSLogExt) | system | D-04 A/B swallowed-failure logging | [VERIFIED: in-repo, 31 `private let logger` precedents] |

**Installation:** none. This phase adds zero dependencies.

**Standalone lint binary** (for sweep/verification outside builds — not on PATH):
`$HOME/Library/Developer/Xcode/DerivedData/AppPackage-glhpivzptobywqasgqylwdgfzzei/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint` [VERIFIED: exists, version 0.65.0]. If that DerivedData folder is ever purged, re-resolve the package to regenerate it (find with `find ~/Library/Developer/Xcode/DerivedData -path '*SwiftLintBinary*macos/swiftlint'`).

## Package Legitimacy Audit

No packages are installed by this phase. All tooling (SwiftLintPlugins 0.65.0) is already declared in `AppPackage/Package.swift` and pinned in `Package.resolved`.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Verified Violation Inventory

All numbers produced this session by running SwiftLint 0.65.0 over `AppPackage/Sources AppPackage/Tests App ShareExtension` with a config that uncomments all 5 draft rules and opts in `sorted_imports` + `multiline_function_chains`. [VERIFIED: local lint run]

| Rule | Sources | Tests | Total | Files | Auto-fix? |
|------|--------:|------:|------:|------:|-----------|
| `sorted_imports` | 565 | 305 | 870 | 319 | **Yes** (verified `--fix`) |
| `optional_try` | 127 | 189 | 316 | — | No — refactor |
| `unchecked_subscript_index_access` | 239 | 0 (draft rule excludes `*Tests.swift`) | 239 | — | No — refactor |
| `single_line_trailing_closure` | 149 | 74 | 223 | 106 | No — manual rewrap |
| `multiline_function_chains` | 85 | 0 | 85 | 20 | No — manual |
| `lifecycle_modifiers` | 46 | 1 | 47 | — | No — refactor |
| `binding_initializer` (draft regex = all `Binding(`) | 30 | 0 | 30 | — | D-05 narrows to 1 real site |
| **Total** | | | **1,810** | | |

### `try?` by module (Sources, 127 total)

| Module | Count | Notes |
|--------|------:|-------|
| ParserFeature | 42 | D-04 groups: A=23 per-row, B=13 per-field, C=6 whole-parse |
| DownloadClient | 36 | Phase 9 documented all 20 scoped + more as intentional probes/cleanup — now each needs refactor or owner exception |
| AppTools | 17 | encoding/decoding nil-contracts, URL detector, regex (per Phase 9 decisions) |
| AppModels | 6 | includes JSONValue's 6 sequential decode probes |
| SettingFeature | 5 | |
| LogsClient / LibraryClient / ImageClient | 4 each | |
| NetworkingFeature | 3 | HTML repair etc. |
| AppComponents | 2 | |
| ReadingFeature / MarkdownExt / FileClient / DetailFeature | 1 each | |

Phase 9 left in-code `// … intentionally …` rationale comments on most of these sites (see `Parser+List.swift`, `Parser+Shared.swift`) — those comments are the per-site triage input for D-01 exception requests vs. D-03/D-04 refactors.

### Lifecycle-modifier sites (46 in Sources)

| Module | Count | Character |
|--------|------:|-----------|
| DetailFeature | 14 | mostly `.onAppear { store.send(.onAppear(gid)) }` + 3 reducer `case .onAppear(` matches |
| ReadingFeature | 8 | mix: store sends + view-local (`tryScrollTo`, image `.task(id:)` loader in `ReadingViewComponents`) |
| HomeFeature | 7 | sub-page fetch-on-appear + `GalleryCardCell` color animation |
| SettingFeature | 5 | Account/Eh/General/ActivityLogs onAppear (+onDisappear) |
| SystemNotification | 3 | toast auto-dismiss `onAppear`/`onDisappear`/`task(id:)` — store-less component, prime D-06 exception candidate |
| SearchFeature / DownloadsFeature / AppComponents | 2 each | AppComponents = `AppAlertState` focus hop + `PreviewImageView.task(id:)` |
| GalleryListComponents / FiltersFeature / FavoritesFeature | 1 each | GalleryList auto-load-on-scroll `.onAppear` (Phase 2 D-36) |

**Critical regex fact [VERIFIED]:** the draft `lifecycle_modifiers` regex `\.(onAppear|onDisappear|task)\s*(\(|\{)` also matches **TCA action usage** — `case .onAppear(let gid):` (ReadingReducer+Body.swift:79, DetailReducer+Actions.swift:70, PreviewsReducer.swift:106) and every `store.send(.onAppear(gid))`. The D-07 migration must therefore also **rename or remove the `.onAppear` actions themselves** (natural anyway: the action becomes a presentation transition), or the rule can never reach zero.

### `unchecked_subscript_index_access` (239 in Sources) — the surprise

Top modules: ReadingFeature 61, ParserFeature 43, DownloadClient 29, ImageColors 27, AnimatedImageFeature 14, AppModels 13, NetworkingFeature 12, HomeFeature 10, URLClient 8, FavoritesFeature 7, + 6 more modules.

The draft rule is **name-based**: it fires on `x[<int literal>]`, `x[expr ± int]`, and `x[i|j|k|idx|index|offset|position|row|section]`. Two consequences the planner must account for:
1. **Many matches are already safe.** ReadingFeature's `imageURLs[index]`, `localPageURLs[index]`, `previewLoadingStates[index]` are `[Int: …]` **Dictionary** subscripts returning Optional — inherently safe. Resolution for these is renaming the key variable to a semantically honest non-policed name (e.g. `page`) or leaving a guard-validated `validatedIndex` local (both sanctioned by D-08's idiom list; the rule deliberately polices names, so honest naming IS the fix, not a dodge).
2. **The draft's `excluded:` file patterns work** [VERIFIED: 0 Tests hits] — `.*/[^/]*Tests\.swift$` excludes test files, so tests are out of scope for this rule.

ImageColors' 27 hits are the vendored algorithm's histogram loops — likely `precondition`-checked-subscript or owner-exception territory rather than restructuring a verbatim-ported algorithm.

### `binding_initializer` (D-05 narrowed)

Exactly **1** closure-based site exists: `AppAlertState.swift:235` `isPresented: Binding(get: { item != nil }, set: …)` (multiline). The other 29 are legal `Binding($x)` projections. The rule regex must be rewritten to match only the `get:` form across newlines, e.g. `\bBinding\s*(?:<[^>]*>)?\s*\(\s*get\s*:` (custom-rule regexes run over whole file contents; `\s` crosses newlines — the current draft proves multiline matching works). The one site can likely be refactored to `item.isPresent()`-style or a computed binding off `$item` — or owner-reviewed.

### Unlabeled tuple types (D-10, new rule)

Rough grep found ~29 `-> (T, U)` return-type sites + ~6 property/closure-type sites — consistent with CONTEXT's ~27 after dedup. Concentrations: `(String, TagTranslation?)` translateAction closure type repeated ×10 across GalleryListComponents/DetailFeature; ParserFeature returns `(String, String)`, `(GalleryDetail, GalleryState)`, `(URL?, Int)`, `(String, URL)`; NetworkingFeature `(PageNumber, [Gallery])` ×2, `(String, [Int: String])`; DownloadClient `(DownloadedGallery, DownloadManifest)`, `(Data, URLResponse)` ×2.

### Test parallelization inventory

| Item | Count | Detail |
|------|------:|--------|
| `.serialized` suites | 41 | DownloadsFeatureTests 39, FileClientTests 1, ImageClientTests 1 |
| `@MainActor` test files | 45 | DownloadsFeatureTests 27, SettingFeatureTests 9, ReadingFeatureTests 3, AppFeatureTests 2, DetailFeatureTests 2, ImageClientTests 2 |

**Isolation machinery that already exists** [VERIFIED: read helpers]:
- `SharedSessionStubURLProtocol` keys handlers **per sessionID** (`setHandler(for:)`/`removeHandler(for:)`); `URLProtocol.registerClass` is global but registration is idempotent — handler routing is already parallel-safe by design.
- DownloadsFeatureTests helpers write fixtures to temporary (UUID-scoped) files; coordinators use UUID-scoped roots.
- ImageClientTests already uses `makeIsolatedDataCache()` per test + per-sessionID stubs — its `.serialized` appears vestigial (candidate for simple removal + verification run).
- **Known real shared state:** `KingfisherManager.shared.cache` used in `DownloadImageParsingTests.swift` and `DownloadImageParsingCacheTests.swift` (disk cache, shared keys w/ defer cleanup) — needs an injectable Kingfisher cache seam or unique-per-test cache keys.
- FileClientTests: in-file rationale documents fixed real Caches/Application Support paths in the tag-translation cache/import endpoints — this is D-12's named FileClient seam (injectable directory root).
- `DidLoginKeyTests` has **no in-file rationale comment yet** [VERIFIED: grep found none above `.serialized`] — D-14 requires adding one.
- Only 39 of the DownloadsFeatureTests `.serialized` suites lack individual diagnosis — Claude's-discretion work during planning/execution.

## Architecture Patterns

### Pattern 1: D-04 Group A/B — do/catch that logs and mirrors current behavior

```swift
// file top (existing convention, 31 precedents):
private let logger = Logger(category: .init(describing: Parser.self))

// Group A (per-row drop) — before: rows.compactMap { try? parseRow($0) }
rows.compactMap { row in
    do {
        return try parseRow(row)
    } catch {
        logger.error("Dropped malformed gallery row: \(error)")
        return nil
    }
}
```
Behavior byte-identical (row skipped / field nil), failure now observable. **Security note:** log the error and a stable descriptor, never raw HTML/URL content (cookie-logging privacy gate from Phase 8 scans production sources).

### Pattern 2: D-04 Group C — propagate to owning reducer

`parseGalleries` currently collapses malformed lists to `[]` via `(try? parse…) ?? []` and only throws if a response-error banner is also present. Refactor: each mode branch `try`s directly; the existing `throws` signature already reaches every call site (gallery-list reducers), which already handle `AppError` via Phase 9 toast machinery. **Tests asserting empty-list fallbacks must be updated to assert thrown errors** — check `ParserFeatureTests` fixtures for malformed-list cases.

### Pattern 3: D-07 presentation-driven lifecycle (TCA)

The presenting reducer triggers the child's initial load when it creates the child state:

```swift
// Parent, on navigation:
case .galleryTapped(let gid):
    state.path.append(.detail(DetailFeature.State(gid: gid)))
    return .send(.path(.element(id: state.path.ids.last!, action: .detail(.load))))
// or, equivalently, handle the DidAppear-equivalent inside the parent's
// .path(.element(id:action:)) / .destination(.presented(…)) interception.
```

Key mechanics [VERIFIED: TCA in-repo version behavior, pfw-composable-architecture patterns]:
- `ifLet`/`forEach` **auto-cancel child effects when child state is dismissed/popped** — this replaces `.task`'s cancel-on-disappear semantics for free.
- Presentation-driven lifecycle fires **once per presentation**, NOT again when popping back from a deeper push (unlike `.onAppear`). Audit each site: most EhPanda `onAppear` sends are `fetch-if-empty`-guarded (idempotent → parity holds); any site relying on re-fire-on-return (e.g. AccountSetting login-state re-check) needs the parent to re-send on pop, or an owner parity decision.
- Alternative for child-owned initiative: give the child an explicit `.load` action the parent sends; do NOT hide effects in `State.init` (untestable, runs on every state copy).
- Rename the old `.onAppear` actions during migration (see regex fact above).

### Pattern 4: D-08/D-09 checked subscript + stable preview identities

Reproduced name-free from CONTEXT (design is fully specified there): a `public enum PreviewIdentifiers`-style table of 1,000 stable UUID strings; `static let all = strings.compactMap(UUID.init(uuidString:))` with count `assertionFailure`; sole access via
```swift
public static subscript(index: Int) -> UUID {
    precondition(all.indices.contains(index), "index out of bounds")
    // reason: bounds are precondition-checked immediately above.
    // swiftlint:disable:next unchecked_subscript_index_access
    return all[index]
}
```
The table file carries reason-annotated `file_length`/`type_body_length` disables. New module ⇒ needs its own `.swiftlint.yml` with `parent_config` and a `Package.swift` target with `swiftLintPlugins`. 5 Sources files currently combine `#Preview` with `UUID()` — the initial consumers.

### Pattern 5: D-12 injectable seams (Phase 8 precedent)

FileClient: add an injectable root-directory parameter/dependency to the tag-translation cache/import endpoints (mirror `DownloadClient`'s injectable `rootURL`). Kingfisher: inject the `ImageCache` (or a cache path) into the code under test instead of `KingfisherManager.shared.cache`. Per memory precedent: fix parallel pollution by **injecting the global, never by `.serialized`** (inject-over-serialize), and per-test instances (DataCache precedent).

### Pattern 6: D-10 labeled-tuple-elements custom rule (recommended starting shape)

Type positions only (after `->` or `:`), first element unlabeled ⇒ violation:

```yaml
labeled_tuple_elements:
  name: "Labeled Tuple Elements"
  regex: '(?:->|:)\s*\(\s*(?![_a-zA-Z][a-zA-Z0-9_]*\s*:)[^(){}\[\]]*,'
  message: "Label every element of a multi-element tuple type, or use a small named struct."
  excluded_match_kinds: [comment, string]
  severity: error
```

Known limits to iterate against the ~35-site inventory during execution: nested closure types (`((String) -> (String, TagTranslation?))?` — inner `-> (` is caught), generic argument lists containing `:` (dictionaries have `[`/`]`, excluded by the char class), and enum associated values (not preceded by `->`/`:` — correctly ignored, matching D-10's "types only"). Since only ~35 sites exist, fixing all sites first and then tuning the regex to zero false positives on the clean codebase is the low-risk order.

### Anti-Patterns to Avoid

- **Renaming index variables purely to dodge the subscript rule at genuinely-unsafe Array sites** — the name-based rule works only if names stay honest; renames are for provably-safe (Dictionary/guarded) accesses.
- **`// swiftlint:disable` without a preceding `// reason:`** — the existing `swiftlint_disable_requires_reason` rule makes this a build error.
- **Effects in `State.init`** for lifecycle migration.
- **Blanket `.serialized` removal before seams land** — order is seam first, trait removal second, parallel suite run third.
- **Running `swiftlint --fix` for sorted_imports across files with `#if`-wrapped imports without review** — 3 conditional-import files exist (`CookieClient.swift`, `ColorCodable.swift`, `DeviceType.swift`); verify fix output there manually.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Import sorting (870 sites) | manual edits or a script | `swiftlint --fix` with `sorted_imports` enabled | Verified: correctable, sorts by module name, `@testable` attribute ignored correctly |
| Effect cancellation on screen dismissal | manual `.cancellable`/`.cancel` bookkeeping | TCA `ifLet`/`forEach` automatic child-effect cancellation | Built into the presentation machinery the D-07 migration adopts |
| Test HTTP stubbing | new per-suite stubs | existing `SharedSessionStubURLProtocol` (per-sessionID) | Already parallel-safe by design |
| Test file isolation | lock files / `.serialized` | UUID-scoped temp roots + injected directory seams | Phase 8 precedent; D-12 sanctions production seams |
| Violation counting for verification | grep approximations | the SwiftLint binary with the real config (`--reporter json`) | Grep and the rule regex diverge (proven: lifecycle 46 grep vs 47 lint; binding 30 vs 1 real) |

**Key insight:** the rules are regex-based, so *the rule itself is the verification tool* — every plan's success check should be "lint run reports 0 for rule X on paths Y", not a grep proxy.

## Runtime State Inventory

This is a refactor phase (no renames of persisted identifiers, services, or artifacts).

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — no persisted key/collection/user-id changes; `@Shared` models untouched (v1 schema policy) | none |
| Live service config | None — no external services | none |
| OS-registered state | None | none |
| Secrets/env vars | None | none |
| Build artifacts | `AppPackage/.build` exists — stale lint plugin outputs are regenerated per build; standalone lint runs must NOT traverse it (pass explicit paths) | use explicit lint paths |

## Common Pitfalls

### Pitfall 1: `optional_try` fires 189× in Tests — scope never decided
**What goes wrong:** test targets carry the SwiftLint build plugin (verified in `Package.swift`), so flipping `optional_try` to error breaks every test build: 189 `try?` sites in Tests (`defer { try? FileManager…removeItem }` cleanup, probe patterns). CONTEXT's scope correction counted only Sources (127).
**How to avoid:** surface as a plan-time decision. Recommended: add `excluded: [".*/Tests/.*"]`-style path exclusion to the `optional_try` custom rule (exact precedent: the draft `unchecked_subscript_index_access` rule already excludes `*Tests.swift` and it verifiably works). Owner may instead want tests included — ask before locking (see Open Questions).

### Pitfall 2: `lifecycle_modifiers` regex matches TCA action names
**What goes wrong:** after migrating all view modifiers, `case .onAppear(` and `store.send(.onAppear…)` still trigger the rule (not in `excluded_match_kinds`) — 3+ reducer-side matches today.
**How to avoid:** the migration renames/removes `.onAppear` actions as part of D-07 (they become presentation transitions). Final verification must be a lint run, not a view-file grep.

### Pitfall 3: `unchecked_subscript_index_access` is 239 sites, not a handful
**What goes wrong:** plans sized off the CONTEXT (which gave no number for this rule) will blow up; a large fraction are safe Dictionary subscripts where "fixing" is renaming or guard-locals, and ImageColors' 27 are a verbatim-ported algorithm.
**How to avoid:** budget a triage pass per module (safe-Optional rename / safe idiom / precondition-checked exception request); treat ImageColors as a likely block-level owner conversation.

### Pitfall 4: Presentation-driven lifecycle ≠ onAppear semantics
**What goes wrong:** `.onAppear` re-fires when returning from a deeper push; presentation transitions fire once. A screen that silently depended on re-fire (refresh-on-return) changes behavior.
**How to avoid:** per-site audit of the ~25 `store.send(.onAppear…)` sites; most are fetch-if-empty (idempotent — parity holds); flag any non-idempotent site for owner parity review. Deep-link/URL/clipboard presentation paths must also trigger the lifecycle — every place that constructs the child state, not just the tap path.

### Pitfall 5: Standalone lint runs traverse `.build` and use a stale exclusion
**What goes wrong:** running the binary from repo root lints `AppPackage/.build` checkouts (memory precedent: delete `.build` first); the root config's `excluded: EhPanda/App/Generated` points at a directory that no longer exists (verified) — harmless but stale.
**How to avoid:** always pass explicit paths: `swiftlint lint --quiet AppPackage/Sources AppPackage/Tests App ShareExtension`. Optionally fix the stale exclusion while touching the config.

### Pitfall 6: The app-scheme build gate skips Tests lint
**What goes wrong:** building the `EhPanda` scheme lints only Sources targets — a Tests/ violation (sorted_imports ×305, single_line ×74…) ships unnoticed and breaks the next test build (memory: e8589355 incident).
**How to avoid:** every commit touching Tests/ must be verified with a test build (`xcodebuild test`), which is also the phase's parallel-suite gate.

### Pitfall 7: Group C behavior change breaks existing parser tests
**What goes wrong:** ParserFeature tests asserting `[]`-on-malformed will fail once Group C throws.
**How to avoid:** update fixtures/assertions in the same plan as the Group C refactor; the new expected outcome is a thrown `AppError` surfaced by the owning reducer.

### Pitfall 8: `@MainActor` removal exposes real main-actor needs
**What goes wrong:** blanket removal from 45 files surfaces compiler errors (e.g. `TestStore` usage patterns, UIKit-touching helpers like `UIImage` fixture rendering) or flaky isolation.
**How to avoid:** D-13's criterion per file: remove, compile, run; keep only where the test "becomes meaningless (or incorrect) without it" + in-file rationale. UIImage-based image tests (scale-1 rendering, memory precedent) are the likely genuine keepers.

### Pitfall 9: One xcodebuild test invocation at a time
**What goes wrong:** overlapping/killed test runs wedge `testmanagerd` (requires reboot — memory precedent).
**How to avoid:** plans must serialize their test invocations; never `pkill -9` a mid-launch run.

### Pitfall 10: Config flip separated from last fix
**What goes wrong:** enabling a rule in a commit before its violations hit zero breaks every subsequent build; enabling long after leaves a regression window.
**How to avoid:** per rule, flip severity/uncomment in the same commit as the final violation fix; the build gate then enforces it forever.

## Code Examples

### Enabling the mechanical rules (config delta)

```yaml
opt_in_rules:
  - force_try
  - force_unwrapping
  - multiline_function_chains   # 85 violations, 20 files, manual
  - sorted_imports              # 870 violations, 319 files, `--fix`

sorted_imports:
  severity: error
multiline_function_chains:
  severity: error               # defaults otherwise, per Claude's-discretion note
```

### Verified sorted_imports autocorrect behavior

```
# input:                        # after `swiftlint lint --fix`:
import Zebra                    import Apple
import Apple                    import Banana
@testable import Middle         @testable import Middle
import Banana                   import Zebra
```
Sorted by module name; `@testable` attribute ignored for ordering. [VERIFIED: ran this session]

### Narrowed binding_initializer (D-05)

```yaml
binding_initializer:
  name: "Binding Initializer"
  regex: '\bBinding\s*(?:<[^>]*>)?\s*\(\s*get\s*:'
  message: "Closure-based Binding(get:set:) is banned. Prefer a projected Binding."
  excluded_match_kinds: [comment, string]
  severity: error
```
Matches the single multiline `AppAlertState.swift:235` site; leaves all 29 `Binding($x)` projections legal. (Custom-rule regexes match across lines — the current draft already relies on this.)

### Sweep/verification command (exact per-rule zero check)

```bash
SWIFTLINT="$HOME/Library/Developer/Xcode/DerivedData/AppPackage-glhpivzptobywqasgqylwdgfzzei/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"
"$SWIFTLINT" lint --quiet --reporter json AppPackage/Sources AppPackage/Tests App ShareExtension \
  | python3 -c "import json,sys,collections; print(collections.Counter(v['rule_id'] for v in json.load(sys.stdin)))"
```

## State of the Art

| Old Approach (current HEAD) | Target Approach | Driver |
|--------------|------------------|--------|
| `try?` + rationale comments (Phase 9's "documented intentional" sites) | do/catch+log, reducer propagation, or owner-granted `reason:`+disable | D-01–D-04 supersede Phase 9's keep decisions |
| View `.onAppear { store.send(.onAppear) }` | presentation-driven lifecycle in presenting reducer | D-06/D-07 |
| `.serialized` + `@MainActor` as isolation crutch | injected seams + parallel-by-default Swift Testing | D-12–D-14 |
| Random `UUID()` in previews | PreviewSupport stable-identity table via checked subscript | D-09 |
| 5 commented-out draft rules | all enabled at error (2 with redefined regexes, 1 brand-new) | LINT-01 |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | TCA `ifLet`/`forEach` auto-cancel child effects on dismissal in the pinned TCA 1.25.3+ | Pattern 3 | Lifecycle migration would need explicit `.cancellable` bookkeeping; verify with one migrated site's test before scaling |
| A2 | The 39 DownloadsFeatureTests `.serialized` suites are forced only by the Kingfisher shared cache (2 suites) and possibly-vestigial caution elsewhere | Test inventory | More hidden globals ⇒ more seam work; D-12 policy covers it, but plan sizing grows. Per-suite diagnosis is explicitly Claude's discretion |
| A3 | `Binding($x)` projections produce no other closure-based sites hidden across lines beyond AppAlertState:235 | D-05 | Narrowed-regex lint run is the authoritative check once the regex lands (grep for multiline `Binding(\n get:` found exactly one) |

All other quantitative claims in this document were verified by running the pinned SwiftLint binary or by direct grep/read this session.

## Open Questions (RESOLVED)

All four questions were answered after this research session — see CONTEXT.md's post-research scope decisions (owner-answered 2026-07-20). Executors need not re-ask.

1. **Does `optional_try` apply to test code (189 sites)?** — **RESOLVED by D-15:** yes, test code too; NO Tests path exclusion. All 316 sites (127 Sources + 189 Tests) are root-fixed or owner-reviewed; in Swift Testing most test `try?` sites become plain `try`.
   - What we know: test targets are lint-gated; CONTEXT counted only Sources; the draft subscript rule already models a Tests exclusion.
   - (Original recommendation to exclude Tests/ was overruled by the owner.)
2. **Owner exception approval flow timing** — **RESOLVED by CONTEXT's exception-review flow:** no mid-execution pauses or checkpoints. Executors write candidates in the D-02 form (`// reason: …` + `// swiftlint:disable:next`) as they arise; the owner reviews the full batch at phase-end verification (plan 11-29's `11-EXCEPTIONS.md`); unapproved entries get reworked, not shipped.
3. **Non-idempotent onAppear sites** — **RESOLVED procedurally:** no upfront decision needed. Plans 11-07/11-08/11-10 flag any site that relied on re-fire-on-return in their SUMMARYs (fetch-if-empty-guarded sites are idempotent — parity holds); the owner reviews the flags site-by-site at phase-end verification.
4. **ImageColors' 27 subscript hits** — **RESOLVED by D-16:** refactor to the checked idiom (D-08 safe idioms / precondition-checked subscripts); no module-level exception. The 3 parity fixtures must pass unchanged as the behavioral proof.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| SwiftLint standalone binary (artifactbundle) | sweeps, `--fix`, zero-checks | ✓ | 0.65.0 | re-resolve package to regenerate |
| SwiftLintBuildToolPlugin | build-time gate (all targets incl. tests + both app targets) | ✓ | 0.65.0 (Package.resolved) | — |
| xcodebuild + iOS simulator | build/test verification (bare `swift build` fails — Xcode-only project) | ✓ | schemes verified: per-module + `EhPanda`; no `AppPackage-Package` aggregate scheme — use `EhPanda` scheme or per-module schemes for tests | — |
| python3 (JSON violation counting) | verification commands | ✓ | system | jq |

**Missing dependencies with no fallback:** none.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (parallel by default — the phase's target property) |
| Config file | none (trait-driven) |
| Quick run command | `xcodebuild test -scheme <Module> -destination 'platform=iOS Simulator,name=iPhone Air'` (per-module schemes exist for every module) |
| Full suite command | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LINT-01 (rules at zero) | each enabled rule reports 0 violations | lint (the rule IS the test) | standalone binary `--reporter json` zero-check + clean build under plugin | ✅ (config + binary) |
| LINT-01 (criterion 3) | no unapproved disables | lint | `swiftlint_disable_requires_reason` already at error; approved list cross-checked in review | ✅ |
| LINT-01 (criterion 4) | full suite parallel, no `.serialized`/`@MainActor` except documented | test run + grep | full `xcodebuild test` (parallel default) + grep for the two tokens against the approved-exception list | ✅ existing suites |
| D-04 A/B parity | row-drop/field-default behavior unchanged | unit | existing ParserFeatureTests fixtures (must stay green unmodified for A/B) | ✅ |
| D-04 C propagation | malformed page throws | unit | ParserFeatureTests — **updated** assertions (Wave-0-style edit inside the Group C plan) | ❌ needs edits |
| D-07 parity | former onAppear effects fire on presentation | unit | existing feature TestStore tests updated: assert load effect on presentation action instead of `.onAppear` | ❌ needs edits |
| D-12 seams | FileClient/Kingfisher injected roots | unit | FileClientTests rewritten off fixed paths; new seam tests | ❌ Wave 0 gaps |

### Sampling Rate
- **Per task commit:** affected module's scheme test run + `EhPanda` scheme build (lint gate)
- **Per wave merge:** full `xcodebuild test -scheme EhPanda` (also proves parallel-suite stability once traits are removed)
- **Phase gate:** full suite green **in parallel** + all seven rules at zero via the standalone JSON check + build clean under plugin

### Wave 0 Gaps
- [ ] FileClient seam tests (post-D-12 injectable root) — replaces the serialized fixed-path suite
- [ ] Kingfisher cache-injection seam coverage in the two affected DownloadsFeatureTests suites
- [ ] D-14 rationale comment added to `DidLoginKeyTests` (currently absent)
- Framework install: none needed

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no auth changes this phase |
| V3 Session Management | no | cookie machinery untouched |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Group C makes malformed-HTML handling *stricter* (throws instead of silent empty) — a net validation improvement; parser stays pure throwing |
| V6 Cryptography | no | — |
| V7/V9 Error Handling & Logging | **yes** | New D-04 A/B `logger.error` calls MUST NOT emit cookie values, credentialed URLs, or raw page HTML. The Phase 8 cookie-logging privacy scan (file-scoped taint) polices production sources — new log lines must pass it. Log `error` descriptions and stable descriptors only, matching Phase 9's FileClient precedent (fixed operation descriptors, never paths). |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive data in new OSLog lines | Information Disclosure | `.private` default OSLog redaction; never interpolate cookie/URL-credential values at `.public`; Phase 8 scan as gate |
| Out-of-bounds subscript trap (DoS/crash) | Denial of Service | the phase's own `unchecked_subscript_index_access` work: safe idioms + precondition-checked exceptions |
| Test seams leaking into production behavior | Tampering | D-12 seams default to current production paths; injection only overrides in tests (Phase 8 DataCache precedent) |

## Sources

### Primary (HIGH confidence — verified this session)
- Local SwiftLint 0.65.0 binary run over the full repo with all draft rules enabled (violation inventory, rule metadata via `swiftlint rules`, empirical `--fix` test)
- Repo files: `.swiftlint.yml` (root + 60 module stubs), `AppPackage/Package.swift`/`Package.resolved`, ParserFeature Group C sites, `AppAlertState.swift`, test helper/suite files, lifecycle-site grep, `xcodebuild -list`
- `.planning/phases/11-infra-refactor-lint-capstone/11-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`

### Secondary (MEDIUM confidence)
- Project memory precedents: inject-over-serialize, DataCache test pollution, no-overlapping-xcodebuild-test, test-target lint gap, standalone-swiftlint usage, Phase 9 per-site `try?` decisions

### Tertiary (LOW confidence)
- TCA `ifLet`/`forEach` auto-cancellation semantics (A1) — training knowledge + pfw skill patterns; verify with the first migrated site's TestStore test

## Metadata

**Confidence breakdown:**
- Violation inventory: HIGH — produced by the enforcement tool itself at the pinned version
- Resolution patterns: HIGH — grounded in locked decisions + in-repo precedents
- Test-parallelization diagnosis: MEDIUM — 39 DownloadsFeatureTests suites not individually diagnosed (explicitly Claude's discretion per CONTEXT)
- New-rule regex shapes: MEDIUM — starting shapes provided; iteration against the small site inventories is expected

**Research date:** 2026-07-20
**Valid until:** violation counts drift with every commit — re-run the sweep command at plan-execution start; patterns/decisions stable for the phase
