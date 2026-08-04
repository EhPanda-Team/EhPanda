# API Coverage — Apple `BackgroundTasks` continued-processing surface (iOS 26)

> Full coverage by default. Opt-outs are explicit, reasoned decisions.

Scope: the capability surface this phase integrates is the SDK family verified in
`15-RESEARCH.md` § Verified API Surface (`BGContinuedProcessingTaskRequest`,
`BGContinuedProcessingTask`, and the `BGTaskScheduler` verbs that serve them). The matrix is
the subtraction record against that surface; every row was decided, none was left undecided.

| capability | decision | reason |
|---|---|---|
| request `title` | INTEGRATE | |
| request `subtitle` | INTEGRATE | |
| request `strategy` `.queue` | INTEGRATE | |
| request `strategy` `.fail` | OPT-OUT | D-03 locked `.queue`; with no fallback tier, immediate refusal would discard work the system would otherwise have run |
| request `requiredResources` `.default` | INTEGRATE | |
| request `requiredResources` `.gpu` | OPT-OUT | needs the continued-processing GPU entitlement; page downloads are network and disk only |
| `BGTaskScheduler.supportedResources` | OPT-OUT | only meaningful for the `.gpu` resource class, which is opted out above |
| inherited `earliestBeginDate` | OPT-OUT | the header states the scheduler ignores it outright for this request type |
| `register(forTaskWithIdentifier:using:launchHandler:)` | INTEGRATE | |
| `submit(_:)` | INTEGRATE | |
| `cancel(taskRequestWithIdentifier:)` | INTEGRATE | |
| `cancelAllTaskRequests()` | INTEGRATE | |
| task `progress` (`NSProgressReporting`) | INTEGRATE | |
| task `progress` child-progress composition | OPT-OUT | one queue-wide session reports one summed fraction (D-06/D-10); a child tree would add no reader-visible detail |
| task `updateTitle(_:subtitle:)` | INTEGRATE | |
| task `title` (read) | INTEGRATE | |
| task `subtitle` (read) | OPT-OUT | the coordinator owns the subtitle it last pushed; reading the system copy back would add a second source of truth |
| task `identifier` (read) | OPT-OUT | the store already holds the identifier it registered and submitted; the system copy adds nothing |
| task `expirationHandler` | INTEGRATE | |
| task `setTaskCompleted(success:)` | INTEGRATE | |
| `BGTaskScheduler.Error.Code` per-case branching | OPT-OUT | SC3/D-01/D-02 make every submission failure the same silent outcome — one `unavailable` event, no user-visible error, no fallback tier — so branching could only produce behavior the phase forbids |

## Decision provenance

- `.queue` over `.fail`: CONTEXT.md D-03.
- No error-code branching, no second tier: CONTEXT.md D-01/D-02, ROADMAP SC3.
- One queue-wide session and one summed fraction: CONTEXT.md D-06/D-10.
- `.gpu` and `supportedResources`: `15-RESEARCH.md` § Verified API Surface (entitlement-gated).
