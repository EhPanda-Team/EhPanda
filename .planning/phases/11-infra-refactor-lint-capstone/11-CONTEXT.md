# Phase 11: Infra Refactor & Lint Capstone - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve the infra-level refactors gating the stricter SwiftLint ruleset — including test-isolation cleanup — then ratchet SwiftLint to error: the mechanical rules (`sorted_imports`, `multiline_function_chains`, `single_line_trailing_closure`, new labeled-tuple-elements rule) as a final sweep, the refactor-gated rules (`optional_try`, `binding_initializer`, `lifecycle_modifiers`, `unchecked_subscript_index_access`) flipped to error, with every violation resolved at its root. `.serialized` and `@MainActor` removed from all tests except where genuinely required; full suite runs in parallel on any thread. Requirement: LINT-01.

**Scope correction discovered during discussion:** the roadmap's claim that the refactor-gated rules were "resolved at root during Phases 5–7/9" is not true at HEAD — ~127 `try?` sites, ~30 `Binding(` sites, and ~46 lifecycle-modifier sites remain in `AppPackage/Sources`. Resolving them is Phase 11 work.

</domain>

<decisions>
## Implementation Decisions

### optional_try (exception-gated ban)
- **D-01:** Every `try?` is a violation by default. An exception exists only when the code genuinely cannot be implemented without `try?`; each exception is requested, then individually reviewed and granted by the owner.
- **D-02:** Approved exceptions are expressed as `// reason: …` + `// swiftlint:disable:next optional_try` (the form the existing `swiftlint_disable_requires_reason` custom rule polices). Success criterion 3 is amended accordingly: "no **unapproved** disables" rather than "no disables".
- **D-03:** Refactored sites bring the error to the nearest surface — the owning reducer — which decides whether to present it to the user via the Phase 9 ErrorInfo/toast machinery.
- **D-04:** ParserFeature degradation sites split by group:
  - **Group A (per-row drops, 23 sites)** and **Group B (per-field defaults, 13 sites)**: converted to explicit `do/catch` that logs the swallowed failure via `OSLog.Logger` (file-top `private let logger` convention) while exactly mirroring current behavior — row skipped, field defaults to `nil`/`[]`. No `try?` survives.
  - **Group C (whole-parse collapses, 6 sites** — `Parser+List.swift:10–29` empty-list fallbacks, `Parser+Detail.swift:128`, `Parser+Shared.swift:38` static-regex compile**)**: propagate to the owning reducer as real errors. An unparseable page must no longer silently render as "no results".

### Refactor-gated rules (binding / lifecycle / subscript)
- **D-05:** `binding_initializer` is narrowed to ban only closure-based `Binding(get:set:)`. `Binding($x)` (Optional-unwrap / `@Shared`-projection, the canonical TCA+Sharing idiom, ~29 sites) stays legal. The one real `get:set:` site (`AppPackage/Sources/AppComponents/AppAlertState.swift:235`) is refactored or reviewed.
- **D-06:** `lifecycle_modifiers` is a blanket ban on `.onAppear`/`.onDisappear`/`.task` (~46 sites). All lifecycle work migrates into reducers. Self-contained store-less components that cannot be implemented without a lifecycle modifier may be owner-reviewed exceptions (same reason + disable:next form).
- **D-07:** Replacement mechanism is presentation-driven lifecycle: the reducer that presents a screen kicks off its lifecycle — setting `Destination`/`StackState` (or handling the navigation action) runs the child's former `onAppear` effect. Lifecycle becomes a state transition, not a view callback.
- **D-08:** `unchecked_subscript_index_access` violations resolve via inherently safe idioms (first/last, `prefix`, `indices.contains` guard, `zip`, `[validatedIndex]` local). Where indexing is genuinely required, adopt the checked-subscript idiom from a reference project: a `precondition(collection.indices.contains(index))` bounds check wrapping the single sanctioned `// reason:` + `swiftlint:disable:next unchecked_subscript_index_access`.
- **D-09:** Also adopt the reference project's stable preview-identity design: a PreviewSupport-style module holding a fixed table of stable UUID strings (count-asserted, `compactMap(UUID.init(uuidString:))`), exposed **only** through that checked static subscript, giving previews deterministic fixture identities instead of random `UUID()`.

### labeled-tuple-elements rule (new)
- **D-10:** The rule requires labels on every element of every multi-element tuple **type** — return types, properties, typealiases, and closure signatures (~27 current unlabeled sites). Construction literals (`return (a, b)`) are not policed.
- **D-11:** A small named struct is an equally valid root fix where labels are awkward or the compiler misbehaves (Phase 4 hit a compiler crash on a labeled-tuple expression in a task group), and is **required** whenever a tuple would break the built-in `large_tuple` rule (which stays enabled at its defaults).

### Test parallelization
- **D-12:** Production seam changes are in scope as the sanctioned root fix for serialization: wherever a fixed global path or singleton forces `.serialized` (e.g. FileClient's live importer writing fixed real Caches/Application Support paths), add an injectable seam (directory root, dependency) — the Phase 8 DataCache-injection precedent.
- **D-13:** `@MainActor` survives on a test only when the test actually requires the main actor or becomes meaningless without it; every other occurrence is removed.
- **D-14:** Governing criterion for retained serialization: it survives only where the test becomes meaningless (or incorrect) without it, documented by an in-file rationale comment. `DidLoginKeyTests` qualifies and stays a deliberately single sequential test: Sharing's reference cache is a process-global weak table keyed by the key's constant id, and per-test key ids would stop testing the production `.didLogin` key.

### Post-research scope decisions (owner-answered 2026-07-20, after RESEARCH.md)
- **D-15:** `optional_try` is enforced in **test code too** — no Tests path exclusion. All 316 sites (127 Sources + 189 Tests, per RESEARCH.md inventory) are root-fixed or owner-reviewed. In Swift Testing, test functions are `throws`, so most test `try?` sites become plain `try`.
- **D-16:** ImageColors' 27 `unchecked_subscript_index_access` sites are **refactored to the checked idiom** (D-08 safe idioms / precondition-checked subscripts) — no module-level exception. The 3 parity fixtures must still pass unchanged after the refactor; they are the proof the algorithm's behavior survived.
- **Exception-review flow (applies D-01):** per the owner's standing instruction to defer confirmations to after-implementation, executors do not pause mid-execution for exception approval. Candidate exceptions are written in the D-02 form (`// reason: …` + `// swiftlint:disable:next`) as they arise and the owner reviews the full batch at phase-end verification — unapproved ones get reworked, not shipped.

### Claude's Discretion
- Enforceable regex shape for the new labeled-tuple-elements rule while implementing D-10 (chosen scope: type positions only).
- Per-suite diagnosis of what shared state forces each of the 39 DownloadsFeatureTests suites (helpers already use UUID-scoped roots; Kingfisher's shared disk cache appears in two suites) and the matching injection design, within the D-12/D-14 policy.
- Mechanical-rule configs without decision points (`sorted_imports` ordering, `multiline_function_chains` threshold) follow SwiftLint defaults/conventions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Lint configuration
- `.swiftlint.yml` — root config; the 5 commented-out rule drafts to enable (with the D-05/D-06/D-08 redefinitions), the `swiftlint_disable_requires_reason` rule that shapes the exception mechanism, and the per-module `parent_config` convention.

### Requirement & prior-phase constraints
- `.planning/REQUIREMENTS.md` §LINT-01 — the locked requirement wording.
- `.planning/ROADMAP.md` §Phase 11 — goal and success criteria (criterion 3 amended per D-02).
- `.planning/phases/09-correctness-structured-error-handling/09-CONTEXT.md` — Phase 9's error-surface conventions (AppError/ErrorInfo, toast presentation) that D-03/D-04 build on.

### Test-isolation precedents (in-file rationale comments)
- `AppPackage/Tests/CookieClientTests/DidLoginKeyTests.swift` — the accepted single-sequential exception and its rationale (D-14).
- `AppPackage/Tests/FileClientTests/FileClientTests.swift` — the fixed-path serialization rationale that D-12's FileClient seam removes.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` — existing UUID-scoped-root pattern for coordinators.

Note: the checked-subscript + stable-preview-UUID design (D-08/D-09) was extracted from a local reference project and is reproduced fully in this document; downstream agents need no access to the source.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 9 error machinery (AppError context, ErrorInfo, error toasts): the destination surface for D-03/D-04 Group C propagation.
- `swiftlint_disable_requires_reason` custom rule: already enforces the reason-comment form D-02 standardizes on.
- Phase 8 injection precedents (DataCache per-test instances, injectable `rootURL` in `DownloadClient`/`DownloadStore`): the model for D-12 seams.
- OSLog `Logger` convention (`Logger+.swift` init-only; file-top `private let logger`): the logging channel for D-04 Groups A/B.

### Established Patterns
- Reducers named with `Feature` suffix; `Scope(...child: Reducer.init)`; `Delegate` enum as sibling of `Action` (existing custom rules enforce these — new refactors must conform).
- Lint-as-error culture: all existing custom rules are `severity: error`; the phase extends this, it doesn't introduce it.

### Integration Points
- ~127 `try?` sites across ParserFeature (42), DownloadClient, DataCache, clients, and utilities — each either refactored per D-03/D-04 or exception-reviewed per D-01.
- ~46 lifecycle-modifier sites across DetailFeature (10), HomeFeature (7), SettingFeature (4), ReadingFeature (4), and 7 other modules — migrate per D-07.
- 41 `.serialized` suites (39 DownloadsFeatureTests, FileClientTests, ImageClientTests) + ~45 test files with `@MainActor` — resolve per D-12..D-14.
- Preview fixtures across modules — candidates for the D-09 stable-identity table.

</code_context>

<specifics>
## Specific Ideas

- The checked-subscript design (D-08/D-09), extracted name-free from a reference project: a `public enum` holding 1,000 stable UUID strings, `compactMap(UUID.init(uuidString:))`, an `assertionFailure` if the count deviates, and a `public static subscript(index: Int) -> UUID` whose body is `precondition(all.indices.contains(index), …)` followed by the single sanctioned reason + `swiftlint:disable:next unchecked_subscript_index_access` indexed access. The table file itself carries reason-annotated `file_length`/`type_body_length` disables.
- Owner's framing for exceptions, applied uniformly to lint disables, `@MainActor`, and serialization alike: *does it become meaningless (or impossible) without it?* If not, fix it at root.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-Infra Refactor & Lint Capstone*
*Context gathered: 2026-07-20*
