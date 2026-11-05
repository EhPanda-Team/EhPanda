---
phase: 18
step: regression_gate
recorded: 2026-11-05T18:05:00Z
result: passed
evidence_commit: e3c95a3bf
head: 26fec4b67
code_changed_since_evidence: false
rerun: false
---

# Phase 18: Regression gate

The regression gate of `execute-phase` (`steps/regression-gate.md`) runs the earlier phases' tests before the
verifier. In this repo every earlier phase's unit tests are in the `FeatureTests` test plan and its UI tests in
`UITests`. The project's `workflow.test_command` runs `FeatureTests` alone, on a simulator other than the two this
phase uses, so the phase's own gate on both devices is the stronger check.

## Evidence reused, not rerun

The 18-12 phase gate ran both full test plans on both devices at `e3c95a3bf`, the last commit that changes code
(18-12-SUMMARY.md, "Gate"). Every later commit changes planning documents only:

```
git diff --stat e3c95a3bf..HEAD -- . ':!.planning'   # empty
```

The code review (`18-REVIEW.md`, 26fec4b67) found no Critical or Warning item and changed no code. So the 18-12
results still describe the code at HEAD and were reused, as the gate brief allows. Nothing was rerun.

| Suite | Device | Result at `e3c95a3bf` |
|-------|--------|-----------------------|
| FeatureTests | phone (`FFE7E686`) | 1743 passed, 0 failed, 10 expected failures, 0 Repetition nodes |
| FeatureTests | pad (`B470DB46`) | 1744 passed, 0 failed, 9 expected failures, 0 Repetition nodes (run 2; run 1 had the known environmental `ReaderListPositionTests` `XCTUnwrap UIWindowScene` failure, 18-12 deviation 7) |
| UITests | phone | 100 passed, 0 failed, 20 skipped, 0 Repetition nodes |
| UITests | pad | 103 passed, 0 failed, 17 skipped, 0 Repetition nodes |
| SwiftLint `--strict --no-cache` | (AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests) | 0 violations in 805 files |
| `verify-release.py` Release scan | phone | PASS, 0 findings |

The skipped UI tests are the opt-in Duo suites and the other idiom's device-only cases; none is from Phase 18.

**Result:** ✓ Regression gate: the earlier phases' FeatureTests and UITests passed on both devices at the code under
verification. No regression found.
