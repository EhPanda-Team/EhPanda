# Live Text translation overlay: deferred items

## JA0-D1: Intermittent first translation request stalls

- **Status:** Deferred, unresolved. Owner approved deferral on 2026-10-14; this item does not block visual acceptance or Task 9 cleanup.
- **Task closure:** The owner accepted the feature and closed the current task on 2026-10-14, explicitly reserving deferred items for a later visit. Task 9 completion is recorded in [261013-ja0-SUMMARY.md](261013-ja0-SUMMARY.md); JA0-D1 remains open.
- **Area:** Live Text translation session lifecycle.
- **Affected code:** `AppPackage/Sources/LiveTextTranslation/LiveTextTranslations.swift` and `LiveTextTranslator.swift` in the same module.

### Observed behavior

On the authorized iPad mini 6, run 83's first English (US) to Japanese batch returned neither a response nor an error for 138.829617 seconds before Live Text was turned off. Availability initially reported `supported` for models that had translated previously. Turning Live Text off and on created a new session and completed all 18 text-bearing pages; the original native call still had not returned. That recovery is not a successful uninterrupted launch.

The root cause remains unknown. Native logs alone do not establish a framework defect, a model-readiness race, or a SwiftUI lifecycle cause. Do not describe this item as fixed merely because it does not reproduce in later runs.

### Current implementation and subsequent evidence

- `270676f55` moved preparation and translation into one SwiftUI-owned session, preserving nearest-page serial scheduling and stale session/batch guards.
- `45fe4c34f` removed redundant preparation after focused device comparisons showed that preparation could return successfully after the person dismissed its download prompt, then the subsequent batch failed internally. The batch call now owns download prompting, waiting, translation and public cancellation handling.
- With that final flow, runs 99, 100 and 101 each completed all 18 text-bearing pages on independent cold launches without a translation error or stalled batch. Page 20 layout became ready 4.091512, 3.753084 and 3.982138 seconds after the automation's tap completion. These are layout-readiness timings, not captured first frames.
- Two consecutive same-reader download cancellations and reactivations succeeded, followed by successful download-to-translation continuation. All 77 translation and 62 reader tests passed; clean Release and simulator builds and strict SwiftLint passed.
- These results support the current implementation but do not explain or erase run 83.

### Evidence retained locally

The following files are ignored scratch artifacts, not portable repository dependencies. The essential findings are preserved above so the item remains useful if scratch files are removed.

- `build/ja0/logs/83-initial-ipad-console.log`
- `build/ja0/logs/83-stall.json`
- `build/ja0/logs/83-reactivated-summary.json`
- `build/ja0/logs/99-session-summary.json`
- `build/ja0/logs/100-session-summary.json`
- `build/ja0/logs/101-session-summary.json`
- `build/ja0/drafts/SESSION-INVESTIGATION.md`
- `build/ja0/drafts/REOPEN-INVESTIGATION.md`

### Reopen conditions and investigation direction

Reopen if a first-request stall recurs during ordinary use or when validating a relevant OS/SDK update. Preserve the initial failed activation before attempting recovery. Record the OS/SDK version, language pair, availability result, session/batch identities, request duration, prompt visibility and cancellation state. Compare a minimal public-API sample with the reader before changing session ownership or UI lifetime.

No speculative timeout, automatic retry, fixed delay, private error-code matching or concurrency suppression is approved by this deferral. A proposed mitigation requires evidence and the owner's design decision. Completed visual acceptance and Task 9 cleanup do not resolve this deferred investigation.
