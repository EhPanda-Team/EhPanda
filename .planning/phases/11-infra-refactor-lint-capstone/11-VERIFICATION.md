---
phase: 11-infra-refactor-lint-capstone
verified: 2026-07-21T10:20:00Z
status: human_needed
score: 7/7 must-haves verified
behavior_unverified: 2
overrides_applied: 0
behavior_unverified_items:
  - truth: "The subscript/byte-parser refactors preserved runtime parity in AnimatedImageFeature"
    test: "Open a gallery with an animated GIF and one with an animated WebP; confirm both still animate rather than showing a first frame. Open a static JPEG/PNG gallery and confirm no regression."
    expected: "Animated images animate; static images unaffected."
    why_human: "11-17 rewrote 14 unchecked byte reads into a bounds-checked walker (endian conversions, added `offset >= 0` guard) and AnimatedImageFeature has NO test target. Byte-for-byte parity rests on argument + a green suite, but nothing tests that an animated GIF is still detected as animated. Grep cannot see this."
  - truth: "parseInfoPanel still parses a real gallery with zero favourites"
    test: "Open a gallery whose 'Favorited' row genuinely reads empty/zero and confirm the detail page loads."
    expected: "Detail parse succeeds and degrades the field, rather than rejecting the whole parse."
    why_human: "Parser+Detail.swift:275 throws AppError.parseFailed if any of 8 named fields is empty. Behaviour is unchanged from before the phase, but a real zero-favourites page would reject the whole detail parse. Requires a live gallery to confirm."
human_verification:
  - test: "Owner batch review of the 8 phase-created swiftlint:disable exceptions (11-EXCEPTIONS.md §2)"
    expected: "All 8 (6 lifecycle_modifiers, 2 unchecked_subscript_index_access) approved, or unapproved ones reworked. Decision points: narrow lifecycle_modifiers to exempt .task(id:) (§6.1, would collapse 3 of 6); whether the 2 subscript preconditions — both unfirable by construction — are acceptable (§2.2)."
    why_human: "The exception-review flow (D-01) is a by-design phase-end owner decision, not a programmatic check. 11-EXCEPTIONS.md is explicitly 'awaiting owner batch review'."
  - test: "Animated GIF/WebP detection UAT (see behavior_unverified_items)"
    expected: "Both animate; static images unaffected."
    why_human: "No test target for AnimatedImageFeature after a byte-parser rewrite."
  - test: "Zero-favourites gallery detail parse UAT (see behavior_unverified_items)"
    expected: "Detail parse succeeds."
    why_human: "Runtime behaviour against a real remote page."
---

# Phase 11: Infra Refactor & Lint Capstone Verification Report

**Phase Goal:** Resolve infra-level refactors (incl. test-isolation cleanup), then ratchet SwiftLint to the stricter ruleset at error; mechanical sweep last, refactor-gated rules flipped on.
**Verified:** 2026-07-21T10:20:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

The central, falsifiable claim of this phase — the stricter SwiftLint ruleset is genuinely live at error with all violations root-fixed — is **verified by direct inspection of the tree**, not by trusting the 30 SUMMARY files. All seven observable truths hold. The status is `human_needed` (not `passed`) because two refactor parities lack test coverage and the 8 exceptions await the by-design owner batch review — none of which blocks the phase goal.

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | All 8 rules live at error, `optional_try` has no Tests exclusion | ✓ VERIFIED | `.swiftlint.yml`: `lifecycle_modifiers` (138), `binding_initializer` (58), `unchecked_subscript_index_access` (249), `labeled_tuple_elements` (112), `optional_try` (185), `single_line_trailing_closure` (217) all `severity: error`; `sorted_imports` (29) + `multiline_function_chains` (24) opt-in at error. `optional_try` block carries only `excluded_match_kinds`, no `excluded:` path (D-15 honored). |
| 2 | Zero remaining `try?` in production + test code | ✓ VERIFIED | `grep -rn "try? " AppPackage/Sources AppPackage/Tests App ShareExtension \| grep -v "//"` → **0**. Total raw `try?` in tree = 1, and it is explanatory doc-comment prose (`Parser+Shared.swift:14`). |
| 3 | Exception accounting is honest (8 phase-created: 6 lifecycle, 2 subscript) | ✓ VERIFIED | Enumerated 8 phase `swiftlint:disable:next` directives matching 11-EXCEPTIONS.md §2 exactly: 6 `lifecycle_modifiers` (View+Toast:80, ReadingView:122, ReadingViewComponents:142/340, AppAlertState:251, PreviewImageView:97), 2 `unchecked_subscript_index_access` (GalleryHistory+Operations:43, PreviewIdentifiers:1046). Subscript sites carry literal `// reason:`; lifecycle sites carry multi-line prose whose last line is a comment (the documented `swiftlint_disable_requires_reason` code-preceded gap, candidly disclosed in §3.1). |
| 4 | Violations root-fixed; no unapproved suppressions; rules actually fire | ✓ VERIFIED | Every `excluded_match_kinds` uses the correct `doccomment` spelling — the only `doc_comment` strings in the file are the warning comments themselves. This is the §8.1 trap that would silently disable a rule; its absence is the structural proof the rules are not inert. (Battery-reported 0 violations / 452 files + negative-control probes accepted per no-xcodebuild constraint.) |
| 5 | Test-isolation cleanup: `.serialized` gone, suite parallel, plan covers all targets | ✓ VERIFIED | `grep -rn '\.serialized' AppPackage/Tests` → 1 hit, prose only (DidLoginKeyTests:20). 18 test-target dirs; `FeatureTests.xctestplan` covers all 18 (set-diff both directions empty; wave-23 3-target omission repaired). 565-test / 18-target count established (not re-run per constraint). |
| 6 | Shortfalls candidly recorded, not buried | ✓ VERIFIED | REQUIREMENTS.md LINT-01 has explicit "**Fell short:**" clause (D-13 17/186, D-09 half-done AppModels `UUID()`, 11-02 inert, no network seam). ROADMAP.md §Phase 11 marks criteria MET-with-scope-correction and has a "**Not achieved as originally written**" section stating the same. Wording is plain and specific. |
| 7 | IN-01 code-review finding resolved | ✓ VERIFIED | `Parser+Shared.swift:26` — `degrading` helper logs `\(error, privacy: .private)`. Commit `1dd35b2e` "fix(11): redact degrading error in logs". |

**Score:** 7/7 truths verified (2 refactor-parity behaviors additionally flagged for UAT — see below)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.swiftlint.yml` | 8 rules at error, correct `doccomment` spelling, no `optional_try` Tests exclusion | ✓ VERIFIED | All 8 present; spelling correct; D-15 honored. Only `unchecked_subscript_index_access` carries a Tests path exclusion (deliberate, §8.2). |
| `AppPackage/Tests/FeatureTests.xctestplan` | Lists all 18 test-target dirs | ✓ VERIFIED | 18/18, no drift. |
| `11-EXCEPTIONS.md` | Honest inventory separating phase-created (8) from pre-existing (20) | ✓ VERIFIED | Matches tree; boundary case (PreviewIdentifiers file_length) disclosed; §3.1 gap in `swiftlint_disable_requires_reason` disclosed. |
| `Parser+Shared.swift` `degrading` | Logs caught error at `privacy: .private` | ✓ VERIFIED | Line 26. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No surviving `try?`, no `.serialized`, no `@MainActor` on a suite type | ℹ️ Info | Clean. The 8 phase disables are all reason-annotated and inventoried. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| LINT-01 | 11-01…11-29 | Enable stricter SwiftLint ruleset at error | ✓ SATISFIED | 8 rules at error, 0 `try?`, exceptions inventoried, shortfalls recorded. REQUIREMENTS.md line 75 `[x]`, traceability line 123 Complete. |

### Human Verification Required

1. **Owner batch review of the 8 exceptions** — the phase-end review is by design (D-01); 11-EXCEPTIONS.md is "awaiting owner batch review". Two live decision points: narrow `lifecycle_modifiers` to exempt `.task(id:)` (§6.1, collapses 3 of 6); acceptability of the 2 unfirable subscript preconditions (§2.2).
2. **Animated GIF/WebP detection** — 11-17 rewrote the byte parser; AnimatedImageFeature has no test target. Confirm animated images still animate.
3. **Zero-favourites gallery detail parse** — confirm a real zero-favourites page loads rather than failing the whole detail parse.

### Gaps Summary

No gaps block the phase goal. The lint ratchet is genuinely enforced at error and root-fixed — verified structurally, with the `doccomment`-spelling guard confirming the rules are not silently inert. The four "not achieved as written" items (11-02 inert must-have, D-09 half-done, D-13's 17-case yield, no network seam) are honestly recorded in both REQUIREMENTS.md and ROADMAP.md and are side goals of the infra-refactor half, not LINT-01's core deliverable; they are correctly carried as documented deviations rather than silent failures. The remaining human items are (a) the by-design exception batch review and (b) two refactor-parity behaviors that no test exercises.

---

_Verified: 2026-07-21T10:20:00Z_
_Verifier: Claude (gsd-verifier)_
