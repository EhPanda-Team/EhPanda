---
status: testing
phase: 15-continued-background-downloads
source: [15-VERIFICATION.md]
started: 2026-07-29T03:54:41Z
updated: 2026-07-29T03:54:41Z
---

## Current Test

number: 1
name: Backgrounded queue outlasts the old grace window
expected: |
  Pages keep landing while backgrounded, well past the old grace window; no page lost
  or duplicated.
awaiting: user response

## Tests

### 1. Backgrounded queue outlasts the old grace window

test: On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages,
start in the foreground, background the app for more than 60 seconds, then foreground and compare
persisted page counts against the queue.
expected: Pages keep landing while backgrounded, well past the old grace window; no page lost or duplicated.
why_human: The simulator neither grants continued-processing tasks nor suspends the process as a device does.
covers: SC1
result: [pending]

### 2. System progress card renders real progress and its cancel matches the in-app pause baseline

test: Observe the system progress card during that run, then cancel from the card, foreground, and
compare queue state against pausing each gallery by hand.
expected: One neutral card with real, monotonically advancing counts; card-cancel state matches the
in-app per-gallery pause baseline.
why_human: The card and its cancel affordance are system-owned and do not render or fire in the simulator.
covers: SC2
result: [pending]

### 3. Refusal, indefinite queuing, expiration and process death lose no work and show no error

test: Exercise a refused or indefinitely queued submission and a system expiration; force-quit
mid-session and relaunch.
expected: No crash, no visible error, no duplicated or lost pages, and persisted work resuming on foreground.
why_human: Real scheduler decisions and process death are not reproducible in unit tests.
covers: SC3
result: [pending]

### 4. Collected diagnostics carry no gallery title and no unmasked identifier

test: Take a sysdiagnose or collected log archive after a real download session and search it for
gallery titles and unmasked gallery identifiers.
expected: No gallery title and no unmasked identifier from the DownloadClient module appears in
collected diagnostics.
why_human: The invariant suite proves the source spellings; only a real collected archive proves
what the system actually persists.
covers: Privacy gate (gap C closure)
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
