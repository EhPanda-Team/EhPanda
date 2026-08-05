---
phase: 15-continued-background-downloads
plan: 27
subsystem: downloads
tags: [continued-processing, background-downloads, test-double-fidelity, tdd, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "BackgroundProcessingClientSpy and its refuseNextStart() control (15-08), its suspension gates (15-23), and the identity suite the regression joins"
provides:
  - "G-15-10: the spy's one-shot refusal arm has exactly one consumer — the refusal it arms; a single-session-guard refusal leaves an armed refusal held"
  - "The split start guard: the currentSessionID branch refuses without touching refusesNextStart; only the armed-refusal branch resets it"
  - "testASessionGuardRefusalLeavesAnArmedRefusalHeld — the race pinned against the spy's own client endpoints, observed failing against the pre-fix spy"
  - "A recorded audit of every refuseNextStart() caller against the changed consumption rule"
affects: [continued-processing-session, background-downloads, downloads-test-doubles]

tech-stack:
  added: []
  patterns:
    - "A test double's control state may be consumed only by the event it models: two distinct refusal causes get two distinct guards, and only the arm's own branch spends the arm"
    - "When the subject under test is the double itself, the double's own client endpoints are the seam — no coordinator fixture participates"

key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift

key-decisions:
  - "The single-session guard and the one-shot arm are separate refusal causes with separate guards; a refusal caused by a live session must leave the arm held for the start it was armed against"
  - "The regression drives spy.client.start directly rather than through a coordinator fixture: the double is the subject, so a coordinator would only add choreography that cannot discriminate the defect"
  - "The plan's `refusesNextStart = false` count-of-1 criterion was imprecise (it also matches the State struct's declaration default, which reads 2 both before and after); the substantive invariant is proven with the assignment-scoped grep `$0.refusesNextStart = false`, which is exactly 1"

metrics:
  duration: 26min
  completed: 2026-08-05
  tasks: 1
  files: 2

status: complete
---

# Phase 15 Plan 27: Split the Client Spy's Refusal Guard Summary

The `BackgroundProcessingClientSpy`'s one-shot `refuseNextStart()` arm is now consumed only by the
refusal it arms — a start refused by the spy's single-session guard leaves the arm held — closing
G-15-10, the double-fidelity blocker one layer up from the non-suspending `updateProgress` that let
G-15-3 ship green.

## What Was Built

**The guard split** (`DownloadFeatureTestSupportTypes.swift`). The combined guard

```swift
guard $0.currentSessionID == nil, !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
return false
```

became two guards, with the reset reachable from exactly one of them:

```swift
// The single-session guard and the one-shot arm are separate refusal causes,
// and only the arm's own branch may consume it (G-15-10): a refusal caused by
// a live session must leave an armed refusal held for the start it was armed
// against.
guard $0.currentSessionID == nil else { return true }
guard !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
return false
```

**The regression** (`DownloadContinuedSessionIdentityTests.swift`):
`testASessionGuardRefusalLeavesAnArmedRefusalHeld` stages the race against the spy's own client
endpoints — start #1 mints a session, `refuseNextStart()` arms while that session is live, start #2
is refused by the single-session guard, `expire()` releases the identity, start #3 is refused by the
armed refusal (the refusal it caused), and start #4 mints a session because the arm was one-shot.
It closes on `startCount == 4`, `startSessionIDs.count == 2`, and an `expectNoDifference` pinning
those two IDs to starts #1 and #4.

No production source, no new types, no renames.

## Falsifiability: the RED reading (verbatim, pre-fix)

Taken from the targeted run made after the regression was written and before the guard split landed
(`Test-EhPanda-2026.08.05_08-53-08-+0900.xcresult`, `** TEST FAILED **`, 5 tests / 1 suite / 2
issues, the other four identity cases green):

```
DownloadContinuedSessionIdentityTests.swift:244: Expectation failed: (armedRefusal → BackgroundProcessingSession(id: 1F211409-438E-45D0-B7CB-1309C21721D9, events: Swift.AsyncStream<BackgroundProcessingClient.BackgroundProcessingEvent>(context: Swift.AsyncStream<BackgroundProcessingClient.BackgroundProcessingEvent>._Context))) == nil
DownloadContinuedSessionIdentityTests.swift:247: Expectation failed: await client.start("Arm spent", "0 / 4 pages", 0, 4) → nil
```

This is the derived defect exactly: start #3 **minted a session** where `nil` was derived, because
start #2's single-session refusal had already burned the arm. The second failure is its consequence
— start #3 having succeeded, the spy still held an identity, so start #4 was refused by the
single-session guard and the `#require` found `nil`.

## Caller audit (`git grep -n "refuseNextStart()" -- AppPackage/Tests`, run at execution time)

| Site | Kind | Which branch consumes its arm | Disposition |
|------|------|------------------------------|-------------|
| `DownloadContinuedSessionIdentityTests.swift:155` — `testARefusedStartRollsBookkeepingBackAndTheNextTapStartsARealSession` | caller | The **armed-refusal** branch. The arm is set before any session exists (`currentSessionID == nil`, no prior `ensureContinuedSession`), so the first guard passes and the second consumes. | Unchanged before and after the split; the case is green and unedited. Its follow-on assertions (`startCount == 2`, a real session on the second tap) depended on the arm being one-shot, never on it being burned by an overlapping start. |
| `DownloadFeatureTestSupportTypes.swift:224` — `func refuseNextStart()` | the declaration | n/a | Not a caller; the arming control itself, unchanged. |
| `DownloadFeatureTestSupportTypes.swift:75` | doc-comment prose | n/a | Not a caller; still accurate — the control remains available for explicit refusal coverage. |
| `DownloadContinuedSessionIdentityTests.swift:216`, `:234` | the new case (doc comment + call) | The **armed-refusal** branch, deliberately after `expire()` clears the identity. | Added by this plan; this is the case that proves the new rule. |

The inventory is complete: at execution time the tree holds exactly one pre-existing caller, and no
case silently depended on the arm being burned by an overlapping start.

## Verification

| Check | Result |
|-------|--------|
| Targeted identity suite (`-only-testing:DownloadsFeatureTests/DownloadContinuedSessionIdentityTests`), single invocation, no other xcodebuild active | `** TEST SUCCEEDED **` — 5 tests / 1 suite passed |
| Full `FeatureTests` plan, single invocation | `** TEST SUCCEEDED **` — 841 tests, 836 passed, 0 failed, 0 skipped, 5 pre-existing expected failures |
| SwiftLint (`--strict`, root config) on both modified files | 0 violations, 0 serious |
| `grep -c 'guard \$0\.currentSessionID == nil else'` | `1` (was `0`) |
| `grep -c 'currentSessionID == nil, !\$0\.refusesNextStart'` | `0` (was `1`) — the combined guard is gone, not supplemented |
| `grep -c '\$0\.refusesNextStart = false'` | `1` — one consumer (see the criterion note below) |
| `grep -c 'testASessionGuardRefusalLeavesAnArmedRefusalHeld'` | `1` |
| Case body (`sed -n '/func testASessionGuardRefusalLeavesAnArmedRefusalHeld/,/^    }$/p'`) | contains `refuseNextStart()` (1), `expire()` (1), `client.start` (4) |
| `wc -l` | `DownloadFeatureTestSupportTypes.swift` 586, `DownloadContinuedSessionIdentityTests.swift` 253 — both below 1000 |
| `git diff --stat` for the task commit | exactly the two listed files (47 insertions, 1 deletion) |

**Acceptance-criterion note.** The plan asked for `grep -c 'refusesNextStart = false'` to output `1`.
That pattern also matches the `State` struct's declaration `var refusesNextStart = false`
(`:164`), so it reads `2` both before and after the fix — the criterion as literally written was
never satisfiable and does not discriminate the fix. The invariant it was written to prove ("the arm
has exactly one consumer") is proven instead by the assignment-scoped
`grep -c '\$0\.refusesNextStart = false'`, which outputs `1`, at `:270`, inside the armed-refusal
branch. Recorded as a deviation below rather than silently substituted.

## Assumption delta

Recorded no-change, carried forward from the plan verbatim: the round-11 scan reported
`detected: true` with three signals, all prose artifacts of existing phase documents (pluralization
hits on "fallback" and "second", the spelling "parameterised" in a prior plan). None names a
data-shape, storage, or architectural assumption this round moves. The recorded phase contracts —
no fallback tier, one queue-wide session, best-effort submission — stand exactly as written.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The `refusesNextStart = false` count criterion could not be satisfied as written**
- **Found during:** Task 1, acceptance-criteria verification
- **Issue:** The criterion's grep matches the `State` declaration default as well as the reset, so it reads `2` in both the pre-fix and post-fix trees; taken literally it would fail a correct fix.
- **Fix:** Verified the substantive invariant with the assignment-scoped pattern `\$0\.refusesNextStart = false` (exactly `1`, in the armed-refusal branch) and quoted the split hunk above, as the same criterion also required. No source change was made to satisfy a grep.
- **Files modified:** none
- **Commit:** n/a (verification-only)

No other deviations. No authentication gates. No architectural changes.

## Threat Flags

None. This plan changed test-target code only; no production trust boundary moved. T-15-27-01
(evidence fidelity) is discharged by the guard split plus the RED-first regression.

## Known Stubs

None.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `dc9ca42e` | `test(15-27): split the client spy's refusal guard` |

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift` — FOUND
- Commit `dc9ca42e` — FOUND in `git log`
