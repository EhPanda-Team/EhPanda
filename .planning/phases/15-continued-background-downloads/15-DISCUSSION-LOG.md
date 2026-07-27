# Phase 15: Continued Background Downloads - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-28
**Phase:** 15-continued-background-downloads
**Areas discussed:** Tier topology — replace vs complement, Seam scope — download-only vs general, Task granularity & submission moments, System progress UI & cancel mapping

---

## Tier topology — replace vs complement

| Option | Description | Selected |
|--------|-------------|----------|
| Keep both (Recommended) | Discretionary scheduling stays unconditional at backgrounding; continued task is an additional user-initiated tier | |
| Fallback-only (replace) | Suppress discretionary scheduling while a session is live; schedule only on refusal/expiration | |
| You decide | Leave topology to researcher/planner | |

**User's choice:** Free text — "no, i want you to replace BGProcessingTask usage with BGContinuedProcessingTask, there will be no BGProcessingTask anywhere." Stronger than either presented option: full deletion of the discretionary path.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep assertion (Recommended) | BackgroundTaskClient stays; covers refused submissions and tap-less backgrounding | |
| Remove it too | Continued task becomes the only background mechanism; refusal means suspension within seconds | ✓ |

**User's choice:** Remove it too.

| Option | Description | Selected |
|--------|-------------|----------|
| .queue (Recommended) | Request waits in the system's queue if it can't start immediately | ✓ |
| .fail | Immediate, unambiguous refusal | |
| You decide | Research determines the better strategy | |

**User's choice:** .queue.
**Notes:** Consequence accepted explicitly: with no fallback tier, an ungranted session means downloads suspend with the process and resume on next foreground. SC3's "existing paths" wording is superseded; ROADMAP amendment due at planning.

---

## Seam scope — download-only vs general

| Option | Description | Selected |
|--------|-------------|----------|
| General shape (Recommended) | Domain-agnostic client: title/subtitle/progress parameters, self-finishing event stream | ✓ |
| Download-specific | Client hardcodes download identifier and strings | |
| You decide | Planner picks within SC4 | |

**User's choice:** General shape.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep BackgroundProcessingClient | Same module, rebuilt contents | ✓ |
| Rename (e.g. ContinuedProcessingClient) | Rename to reflect the module's one remaining job | |
| You decide | Planner picks | |

**User's choice:** Keep BackgroundProcessingClient.

| Option | Description | Selected |
|--------|-------------|----------|
| DownloadCoordinator (Recommended) | Client injected into the coordinator like BackgroundTaskClient was; single owner of submit/progress/complete | ✓ |
| Reducer-driven | Reducers start sessions and feed progress from observeDownloads | |
| You decide | Planner picks the owner | |

**User's choice:** DownloadCoordinator.

---

## Task granularity & submission moments

| Option | Description | Selected |
|--------|-------------|----------|
| Whole queue (Recommended) | One session covers all schedulable work; new galleries fold in | ✓ |
| Per-gallery, superseding | Each start tap supersedes with a gallery-scoped session | |
| You decide | Planner picks | |

**User's choice:** Whole queue.

| Option | Description | Selected |
|--------|-------------|----------|
| Every queue-mobilizing tap (Recommended) | Start, resume, retry, and update taps all ensure a session exists | ✓ |
| Start-download taps only | Only the initial download tap submits | |
| You decide | Planner enumerates sites | |

**User's choice:** Every queue-mobilizing tap.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep it running (Recommended) | Session lives until drain/expiration/cancel; survives foreground returns | ✓ |
| Complete on foreground | End the session when the app becomes active | |
| You decide | Planner decides after research | |

**User's choice:** Keep it running.

---

## System progress UI & cancel mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Neutral counts only (Recommended) | Static localized title + count subtitle; no gallery titles or tags | ✓ |
| Include current gallery title | Subtitle names the gallery being downloaded | |
| You decide | Claude picks strings; privacy stance chosen above | |

**User's choice:** Neutral counts only.

| Option | Description | Selected |
|--------|-------------|----------|
| Pages across the queue (Recommended) | completed pages / total pages over all schedulable galleries | ✓ |
| Galleries completed | completed galleries / total galleries | |
| You decide | Planner picks the unit | |

**User's choice:** Pages across the queue.

| Option | Description | Selected |
|--------|-------------|----------|
| Pause all schedulable work (Recommended) | Expiration pauses every active/queued download, like in-app pause on each | ✓ |
| Stop executing, stay active | State stays active so next foreground auto-continues | |
| You decide | Planner researches for a cancel-vs-reclaim signal | |

**User's choice:** Pause all schedulable work.
**Notes:** User cancel and system reclaim are indistinguishable (both arrive as expiration), so one policy covers both; the manual-resume cost after a reclaim was accepted.

---

## Claude's Discretion

- Exact card strings and localization placement (labeled numeric-format-argument rules apply).
- Event-stream vocabulary and client endpoint names within the general shape.
- Identifier naming under the bundle-ID prefix + wildcard plist entry; verify against docs.
- Whether `UIBackgroundModes: processing` survives the removal (research).
- Pause-all mechanics and progress-total recomputation against the system `Progress`.
- Fate of orphaned machinery (`runQueueUntilIdle`, `hasPendingWork`); dead code deleted.
- Concurrency design for the non-Sendable task object — main-actor confinement preferred;
  any `@unchecked Sendable` needs explicit owner permission first.

## Deferred Ideas

None — discussion stayed within phase scope.

## Reference material

Before the discussion, the owner pointed at a local reference project with a production
continued-processing client; its API-level findings were extracted name-free into
CONTEXT.md's `<code_context>` (AGENTS.md reference-privacy rule).
