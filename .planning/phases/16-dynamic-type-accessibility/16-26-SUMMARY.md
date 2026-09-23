---
phase: 16-dynamic-type-accessibility
plan: 26
subsystem: accessibility
tags: [swiftui, dynamic-type, voiceover, voice-control, contrast, ios-27]

requires:
  - phase: 16-dynamic-type-accessibility
    provides: round-1 Dynamic Type sign-off and round-2 walkthrough, audit, and contrast evidence
provides:
  - D-25 rendered-scope re-sweep and closure record
  - current iOS 27 phase-close gate evidence
  - owner-approved round-2 sign-off and A11Y traceability
affects: [phase-16-verification, accessibility, ios-27]

actuals:
  tasks: 4
  commits: 1
plan_head_before: 30f54fe93729ebd8885dbea488b5a1445eaa9453

tech-stack:
  added: []
  patterns: [bounded iPhone portrait re-sweep, first-try gate evidence, owner-signed best-effort closure]

key-files:
  created:
    - .planning/phases/16-dynamic-type-accessibility/16-26-SUMMARY.md
  modified:
    - .planning/phases/16-dynamic-type-accessibility/16-SWEEP.md
    - .planning/config.json
    - EhPandaUITests/AccessibilityAuditUITests.swift
    - EhPandaUITests/Support/ReaderPageProbe.swift
    - EhPandaUITests/ReaderPageSyncUITests.swift

key-decisions:
  - "The effective D-25 rendered scope is Search root, Favorites, and Watched only; the historical Activity Logs, Laboratory, and Gallery Detail rows are withdrawn after owner reversal cc05aca6."
  - "Round 2 closes as best-effort owner-approved evidence; the 2026-09-15 owner decision supersedes the Nutrition Label deliverable."
  - "W-38 is accepted on the native VoiceOver page 1-to-41 recording without changing reader index logic."

patterns-established:
  - "Record simulator identity, baseline restoration, evidence paths, and current-versus-retired identifiers in the sweep ledger."
  - "Treat a retried green test as a gate failure by checking xcresult Repetition nodes, not only the summary status."

requirements-completed: [A11Y-01, A11Y-02]

coverage:
  - id: D1
    description: "D-25 re-sweep of the nine rendered iPhone portrait cells at XXL, AX3, and AX5."
    requirement: A11Y-02
    verification:
      - kind: manual_procedural
        ref: "16-SWEEP.md § D-25 re-sweep › Re-sweep cells (16-26) and Re-sweep closure"
        status: pass
    human_judgment: true
    rationale: "The cell verdicts and accepted native-search finding require visual and owner review."
  - id: D2
    description: "First-try FeatureTests and full iPhone/iPad UI gates with strict lint and phase-range media checks."
    requirement: A11Y-02
    verification:
      - kind: automated_ui
        ref: "$HOME/Library/Caches/ehpanda-phase16/round2/close/20260923/featuretests-iphone.xcresult"
        status: pass
      - kind: automated_ui
        ref: "$HOME/Library/Caches/ehpanda-phase16/round2/close/20260923/uitests-iphone-final.xcresult"
        status: pass
      - kind: automated_ui
        ref: "$HOME/Library/Caches/ehpanda-phase16/round2/close/20260923/uitests-ipad-final.xcresult"
        status: pass
      - kind: other
        ref: "swiftlint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests"
        status: pass
    human_judgment: false
  - id: D3
    description: "Owner approval of the round-2 closure and its explicit evidence limits."
    requirement: A11Y-02
    verification:
      - kind: manual_procedural
        ref: "16-SWEEP.md § Owner sign-off (round 2); commit a4cc3754"
        status: pass
    human_judgment: true
    rationale: "The owner must decide whether accepted, deferred, carried, and unmeasured items close the round."

commits: 1
duration: continuation documentation session
completed: 2026-09-23
status: complete
---

# Phase 16 Plan 26: Dynamic Type Accessibility Summary

The D-25 rendered re-sweep, current iOS 27 gate runs, and owner-approved round-2 sign-off are recorded with explicit best-effort limits and no Nutrition Label claim.

## Performance

- **Duration:** continuation documentation session
- **Started:** 2026-09-23T06:35:48Z (owner sign-off observation)
- **Completed:** 2026-09-23
- **Tasks:** 4
- **Recorded file scope:** sweep documentation, three UI-test files, this summary, and the ignored local workflow command. Review and tracking documents are maintained by the orchestrator.
- **Token usage:** unavailable; no estimate is reported.

## Accomplishments

- Re-pointed infrastructure preserves the historical round-1 simulator rows while recording current `LOGIN_UDID` `C9C8B01B-1FBC-466E-A4F8-C46B13E1D07D`, hermetic `WALK_UDID` `CAE8CEE9-7C40-48D3-BE75-F0940B403DA8`, and historical iOS/iPadOS 26.5 gate IDs `73E148DA-26E4-4892-8C8A-7EDC6725D0E7` and `B6679864-3783-4A3B-89B5-B0B010588C13`. Retired `ADE09605…`, `8250D97E…`, and `E2BF974E…` remain history only. The local ignored `workflow.test_command` was subsequently pointed at the current iOS 27 iPhone gate `8E3EA338-4F93-40A7-BE4F-1F6E7C855F32`.
- D-25 is defined by rendered layout/frame changes, not file or symbol mapping. The effective set is Search root #9, Favorites #8, and Watched #5: nine iPhone portrait cells at XXL, AX3, and AX5. Eight cells pass; Favorites AX5 is finding #39 (the native Search drawer is a blank capsule missing its magnifier and placeholder while title, metadata, and tail remain reachable), routed to the owner and left unfixed. There are no blocked cells. Historical Gallery Detail, Activity Logs #32, and Laboratory #36 candidates are withdrawn after `cc05aca6`.
- The 15 `fix(16-25)` commits classify as one rendered layout/frame commit (`7edfb1a7`, the three W-22 screens) plus fourteen excluded semantics-only or test/audit-only commits: `26625a78`, `962f60c9`, `a8cb5d53`, `6b7ef86a`, `464d1584`, `772e8f85`, `f811bf5e`, `700db090`, `a12b9903`, `a90750a7`, `c30fbe08`, `aa3d9947`, `24f5847a`, and `b01add4c`. Count: `fix(16-25) commits: 15 = layout-changing 1 + semantics-only 14`. The three separate test commits were `50e8412d`, `5c210835`, and `a0a2cbb3`.
- Final current-source gates ran against source `7675a7ac77301de9464a8e924c9fc8c70f691849` plus the unchanged pre-existing `EhPanda.xcodeproj/project.pbxproj` serialization edit. All 809 source/config hashes stayed stable. FeatureTests reported 1,066 tests (1,055 passed, 11 expected failures, 0 failed/skipped, Repetition 0); iPhone UI reported 56 tests (54 passed, 2 expected iPad-only skips, Repetition 0); iPad UI reported 56 passed, 0 skipped, Repetition 0. Strict no-cache SwiftLint reported 0 violations in 586 files, all six phase rules were present at error severity, and phase-range added media was 0.
- The walkthrough closure retains 38 hidden, 2 not-an-element, 15 unreached, and 0 pending hide rows; E-1 is retired with `testReadingControlPanelAudit` as the standing regression. Accepted findings are `VO-3b`, `VO-4`, `W-7`, `W-11`, `W-32`, and `W-31`; W-21 and W-24 remain deferred. W-8 and W-35 are accepted with their recorded evidence; VO-3 and W-13 Comments retain their Apple-bug dispositions; W-33 and W-34 both have bounded owner phonetic verification. W-38 is accepted on the native VoiceOver page 1-to-41 recording without a reader-source change. Voice Control spoken commands, 15 unreached sites, and VoiceOver double-tap activation outside the bounded W-38 reveal remain unmeasured.

## Evidence and Traceability

The immutable gate packet is `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260923/`; it retains the original failed/diagnostic bundles and the final bundles. No evidence media entered the repository. The owner sign-off covers the D-25 closure, the 16-25 walkthrough closure, accepted/carried/deferred items, E-1, listening results, and the final gates.

The owner’s reply is recorded verbatim:

> approved

It was delivered in the main Codex task and observed at `2026-09-23T06:35:48Z` UTC over repository HEAD `30f54fe93729ebd8885dbea488b5a1445eaa9453`. The sign-off records `Status: signed off` in `16-SWEEP.md`. The unrelated project-file serialization edit remains unchanged and uncommitted as provenance.

Requirement and roadmap traceability:

- **A11Y-01:** round-1 owner sign-off (2026-09-11, `d5afe78f`) plus the D-25 closure confirms that the round-1 layout remains current where round 2 touched it.
- **A11Y-02 / criterion 7, VoiceOver:** plans 16-16 through 16-19, the 16-25 walkthrough closure, and `AccessibilityAuditUITests`; W-38’s approved native recording is bounded to the reader panel reveal.
- **Criterion 8, Voice Control:** plans 16-17 through 16-19 and the 16-25 native-label proxy evidence; spoken commands were not exercised.
- **Criterion 9, Reduce Motion:** plans 16-20 and 16-21, `ReduceMotionGatingSourceTests`, and the 16-25 display-settings pass.
- **Criterion 10, contrast:** the 16-15 and 16-23 measurements are historical. Owner reversal `cc05aca6` removed the adaptive contrast helper and `ColorContrastTests`, retaining white category labels, category colorset pins and Increase Contrast backgrounds. Current `CategoryColorsetInvariantTests` verify those pins; they do not guarantee text contrast. The owner-approved scope remains best effort.
- **Criterion 11, Differentiate Without Color:** the 16-22 audit is historical; owner reversal `cc05aca6` withdrew its added visible glyphs. Retained accessibility semantics and the bounded 16-25 grayscale evidence support the approved scope; this summary does not credit the reverted glyphs as current code.
- **Criterion 12 and the original A11Y-02 Nutrition Label wording:** superseded by the owner decision of 2026-09-15: “比較穩定的測試可以留下來，不穩定擋路的刪掉，因為本來就是 best effort 沒有要保證可以”. No Nutrition Label document or App Store claim is produced; the round closes through the walkthrough, gates, D-25 re-sweep, and sign-off.

## Task Commits

1. **Task 1: Re-point infrastructure and start D-25 re-sweep** — `353eb115` (`docs(16): re-point infra and start D-25 re-sweep`)
2. **Task 2: D-25 targeted re-sweep and gate evidence** — `182a5b0c` (`docs(16): D-25 targeted re-sweep`), with bounded test corrections `9ea2f359` and `7675a7ac`, and closing-gate/review record `30f54fe9` (`docs(16): record phase-close gates and final review`)
3. **Task 3: Owner decision** — `approved`, recorded in the Task 4 sign-off commit
4. **Task 4: Record round-2 sign-off** — `a4cc3754` (`docs(16): record round-2 sign-off`)

**Continuation-only plan ledger:** base `30f54fe93729ebd8885dbea488b5a1445eaa9453`; measured commits at summary creation: `1` (`a4cc3754`). Root owns the subsequent summary/state metadata commit.

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — current infrastructure, D-25 scope/cells/closure, gate evidence, walkthrough limits, and owner sign-off.
- `.planning/config.json` — ignored local `workflow.test_command` destination for the current iOS 27 iPhone gate.
- `EhPandaUITests/AccessibilityAuditUITests.swift` — bounded obsolete Search-route test correction.
- `EhPandaUITests/Support/ReaderPageProbe.swift` — geometrically paired page-number/Reload center measurement, valid half-viewport gesture, and autoplay-menu dismissal postcondition.
- `EhPandaUITests/ReaderPageSyncUITests.swift` — W-38 evidence comment; existing page-agreement assertions are retained.

## Deviations from Plan

The approved plan amendments are recorded in `16-26-PLAN.md`: the obsolete Search `More` lookup was removed from the test route; reader-page geometry now pairs each numeric label with its nearest Reload button and crosses a valid page boundary; and autoplay requires the selected menu option to disappear before continuing. These are test-only corrections; production reader logic, retry policy, timeouts, and audit assertions remain unchanged. No unapproved deviation was introduced.

## Issues Encountered

The first iPhone UI run exposed the obsolete Search route, and the first iPad run exposed the reader helper’s number-only center measurement plus an autoplay menu postcondition. The original failures and diagnostics remain preserved; corrected full gates pass with zero Repetition nodes. The pre-existing project-file diff was preserved and excluded from task-owned changes.

## Next Phase Readiness

Both requirements are recorded as completed for this plan. The whole-phase goal verifier remains root-owned and must validate the assembled phase record; this summary does not make a blanket accessibility guarantee or claim completion of unmeasured Voice Control spoken commands, unreached sites, or general VoiceOver activation.

## Self-Check: PASSED

- Summary file exists at the required path.
- Owner sign-off commit `a4cc3754` exists and the plan ledger measures one commit after `30f54fe9`.
- The summary contains no expanded contributor home path; evidence paths use `$HOME`.
- The pre-existing `EhPanda.xcodeproj/project.pbxproj` edit remains the only dirty file outside this new summary.

---
*Phase: 16-dynamic-type-accessibility*
*Plan: 26*
*Completed: 2026-09-23*
