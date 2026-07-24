---
phase: 14-analytics-instrumentation
plan: 14
completed: 2026-07-25
tasks_completed: 2
tasks_total: 2
requirements-completed: []
---

# 14-14 Summary: ReadingFeature instrumentation

**One reader-session signal, emitted at the dismissal seam, carrying a bucketed distinct-page count and a bucketed duration — with the pages-read metric proven immune to slider scrubbing and the duration proven deterministic across four bucket boundaries.**

## What shipped

| Site | Behavior |
|------|----------|
| `.onPresented` | Records the session start instant, seeds the visited set with the opening page. **Emits nothing.** |
| `.syncReadingProgress` | One `Set.insert`. No effect, no send, no allocation. |
| `.onPerformDismiss` | Emits exactly one `readingSessionEnded(pagesRead:duration:)`, after the existing progress flush. |

New transient state on `ReadingReducer.State`: `visitedPages: Set<Int>` and `sessionStartDate: Date?`. Neither is persisted, so no stored model or schema version is affected. The date property is a noun form rather than an `...At` suffix, per the repository's error-severity `date_property_at_suffix` rule.

## Discretionary decisions made here

**One end-of-session signal, not a start/end pair.** A start without a matching end is unanalyzable, the vendor bills per signal, and the synchronous dismissal case is the one place both the page count and the elapsed time are still known. Recorded inline at the emission site so a later reader does not add a start signal for symmetry.

**Duration is bucketed in the reducer, not delegated to the SDK.** TelemetryDeck's duration-signal pair transmits an exact rounded second count, which D-08 forbids. The opt-out is asserted by grep: `startDurationSignal` and `stopAndSendDurationSignal` appear nowhere in `AppPackage/Sources`.

**A never-presented teardown emits nothing.** Guarded on the start instant being present, rather than reporting a zero-duration session that never happened.

**Pages read is a set, not a counter.** Scrubbing the slider back and forth revisits pages; a counter would report fidgeting as reading.

**Reading direction and dual-page mode are absent from the signal.** D-11 puts the settings snapshot on every signal at emission time, so this signal already carries them; adding them here would duplicate.

## Tests

`ReadingFeatureTests` → **TEST SUCCEEDED**, 24 tests in the target (up from 20).

- The date dependency is driven from a `LockIsolated<Date>` box via `DateGenerator`, not `.constant`, so the elapsed interval is both controllable and deterministic. A wall-clock read is the classic way this kind of assertion becomes flaky.
- Four duration-boundary arguments: 9s/10s and 59s/60s, pinning both sides of two edges.
- Two empty-recorded-sequence assertions: presenting, and dismissing without presenting.
- The scrub case drives `1,2,3` and `1,2,3,2,1` through the same helper and requires **identical** recorded output, so the two sequences are compared like with like rather than each against a hand-written expectation.
- `continuousClock` is a `TestClock` that is never advanced, so the page-change debounce never fires and cannot interleave with the assertions.

## Deviations from plan

None material. The plan's task 1 anticipated that adding state fields might break an existing full-state assertion in this target; it did not — the existing suite passed unchanged, so no assertion was touched.

## Notes

- The existing reading-progress flush ordering in `.onPerformDismiss` is unchanged: the flush still runs first, synchronously, before the emission effect is merged in. That ordering is what makes a normal close not lose the last page swiped to.
- `ANALYTICS-01` remains `[ ]` — it spans the phase and 14-17 closes it out.
