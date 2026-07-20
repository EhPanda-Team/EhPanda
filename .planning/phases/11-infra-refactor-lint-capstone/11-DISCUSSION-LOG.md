# Phase 11: Infra Refactor & Lint Capstone - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-20
**Phase:** 11-infra-refactor-lint-capstone
**Areas discussed:** optional_try vs Phase 9 audit, Remaining gated-rule violations, labeled-tuple-elements rule, Test parallelization strategy

---

## optional_try vs Phase 9 audit

| Option | Description | Selected |
|--------|-------------|----------|
| Reason-comment gate | try? legal only when annotated with a fallback rationale | |
| Rewrite all sites | Blanket ban; convert every blessed try? | |
| Drop the rule | Phase 9 already did the real job | |
| *(free text)* | Every try? is an exception; request one only when it genuinely cannot be implemented without try?, reviewed by the owner per site | ✓ |

**User's choice:** Exception-gated ban with per-site owner review.

| Option | Description | Selected |
|--------|-------------|----------|
| Reason + disable:next | `// reason:` + `// swiftlint:disable:next optional_try`; criterion 3 amended to "no unapproved disables" | ✓ |
| Regex carve-out in the rule | Marker the regex skips (e.g. named wrapper) | |
| Central excluded-paths list | File-level exclusions in .swiftlint.yml | |

**User's choice:** Reason + disable:next.

| Option | Description | Selected |
|--------|-------------|----------|
| Propagate or log | Throw where possible; log fire-and-forget | |
| Propagate or exception | No log-and-swallow middle tier | |
| Case-by-case in planning | Planner proposes per-category treatments | |
| *(free text)* | Always bring the error to the nearest surface (its owning reducer), which decides whether to present it to the user | ✓ |

**User's choice:** Propagate to the owning reducer; reducer decides presentation.

| Option | Description | Selected |
|--------|-------------|----------|
| Split by group | Group C propagates; A/B keep skipping but collect errors | ✓ (amended) |
| All collect-and-report | All groups collect swallowed failures for the reducer | |
| A/B are exceptions, C propagates | Per-row/per-field sites keep try? via review | |

**User's choice:** Split by group, then amended after an interrupt: Groups A/B convert to explicit do/catch logging via OSLog.Logger while exactly mirroring current behavior (no try? survives, no error collection into the parse result); Group C propagates to the reducer.
**Notes:** User first asked for the full classified list of the 42 ParserFeature sites (A: 23 per-row drops, B: 13 per-field defaults, C: 6 whole-parse collapses) before deciding.

---

## Remaining gated-rule violations

| Option | Description | Selected |
|--------|-------------|----------|
| Ban get:set: only | Narrow regex to closure-based Binding(get:set:) | ✓ |
| Ban all, exceptions for $-forms | Broad regex with $-argument carve-out | |
| Original intent stands | Ban Binding($x) too | |

**User's choice:** Ban get:set: only.

| Option | Description | Selected |
|--------|-------------|----------|
| Ban inline logic only | Lifecycle closure may contain exactly one store.send | |
| Ban onAppear, allow task | Push toward .task-based lifecycles | |
| Blanket ban with exceptions | Full ban; every site needs review | |
| *(free text)* | Ban onAppear/onDisappear/task — every lifecycle modifier as the rule required; migrate to reducer actions only; self-contained components that must use lifecycle modifiers can be exceptions | ✓ |

**User's choice:** Blanket ban; migrate to reducer actions; store-less self-contained components may be reviewed exceptions.

| Option | Description | Selected |
|--------|-------------|----------|
| Presentation-driven | Presenting reducer's state transition runs the child's former onAppear effect | ✓ |
| Store/reducer lifecycle API | Library-level lifecycle seam | |
| Decide in research | Researcher compares patterns | |

**User's choice:** Presentation-driven.

| Option | Description | Selected |
|--------|-------------|----------|
| Safe-access idiom | first/last, indices.contains guard, validatedIndex; keep drafted heuristic | ✓ (plus reference design) |
| Collection extension helper | collection[safe:] Optional helper | |
| Review sites first | Violation list reviewed before locking a convention | |

**User's choice:** Safe-access idioms plus a reference project's stable-preview-UUID + checked-subscript design (both parts adopted: the precondition-wrapped sanctioned disable idiom for must-index sites, and a PreviewSupport-style stable fixture-ID table for previews).

---

## labeled-tuple-elements rule

| Option | Description | Selected |
|--------|-------------|----------|
| All multi-element tuple types | Returns, properties, typealiases, closure signatures | ✓ |
| Return types only | Closure-type params stay legal | |
| Prefer structs over tuples | Public-signature tuples become structs | |

**User's choice:** All multi-element tuple types.

| Option | Description | Selected |
|--------|-------------|----------|
| Types only | Construction literals not policed | ✓ |
| Types + returns of tuples | Also require labels at return construction | |
| You decide | Claude picks enforceable scope | |

**User's choice:** Types only.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, struct allowed | Struct is an equally valid root fix | ✓ (amended) |
| Labels only | Struct conversion is scope creep | |
| Struct preferred | Structs at public API boundaries | |

**User's choice:** Struct allowed, and required whenever the tuple breaks the built-in large_tuple rule.

---

## Test parallelization strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add seams | Production seam changes are the sanctioned root fix | ✓ |
| Tests-only changes | Fixed-path suites stay serialized exceptions | |
| Case-by-case review | Each seam proposal approved first | |

**User's choice:** Yes, add seams.

| Option | Description | Selected |
|--------|-------------|----------|
| Compiler-forced only | Keep @MainActor only where compilation forces it | |
| Compiler-forced + UI types | Pre-approve UIKit/SwiftUI-touching tests | |
| Zero tolerance | Restructure until every test is nonisolated | |
| *(free text)* | Keep when the test actually requires main actor, or becomes meaningless without it | ✓ |

**User's choice:** Genuine-need criterion (required, or meaningless without).

| Option | Description | Selected |
|--------|-------------|----------|
| Accept + in-file rationale | DidLoginKeyTests stays; exceptions carry in-file comments | |
| Try to fix it too | Attempt isolation of the Sharing ref-cache problem | |
| You decide | Claude judges per suite | |
| *(free text)* | "does it become meaningless without .serialized?" — the criterion itself becomes the policy | ✓ |

**User's choice:** The meaningless-without-it criterion governs all retained serialization; DidLoginKeyTests qualifies (process-global Sharing ref cache keyed by constant key id; per-test key ids would stop testing the production .didLogin key) and stays a single sequential test with its in-file rationale.

---

## Claude's Discretion

- Enforceable regex shape for the labeled-tuple-elements rule (types-only scope).
- Per-suite diagnosis of the shared state behind the 39 serialized DownloadsFeatureTests suites and the matching injection design.
- Mechanical-rule configs without decision points (sorted_imports ordering, multiline_function_chains threshold).

## Deferred Ideas

None — discussion stayed within phase scope.
