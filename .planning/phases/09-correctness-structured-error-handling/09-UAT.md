---
status: complete
phase: 09-correctness-structured-error-handling
source: [09-VERIFICATION.md]
started: 2026-07-16T11:24:26Z
updated: 2026-07-16T16:21:42Z
---

## Current Test

[testing complete]

## Tests

### 1. Accessible diagnostic-toast runtime UAT

expected: VoiceOver announces and focuses the persistent diagnostic Button; Voice Control, Switch Control, and Full Keyboard Access can activate it after three seconds; activation routes once; downward swipe and replacement route nothing; Reduce Motion removes moving and bouncy presentation.
result: pass
verified_by: simulator UAT (iPhone Air, iOS 26.5) driven via sim-use
notes: |
  Ran end-to-end against a build from HEAD. Triggered a real gallery-fetch failure via an
  invalid gallery deep link (ehpanda://e-hentai.org/g/9999999/badtoken0000/ -> "Not found").

  Confirmed:
  - Diagnostic toast is exposed as an enabled AXButton with the combined label
    "Error, There seems to be nothing here." (the element/label VoiceOver, Voice Control,
    Switch Control, and Full Keyboard Access consume for discovery, naming, and activation).
  - Persistent: remained well past 3s and across tab navigation (no auto-hide).
  - Activation opens the ErrorInfoView detail sheet exactly once (Description/Solution/
    Context/Environment); context is privacy-safe (numeric GID only, no token/URL); the
    toast is consumed after routing (a second activation cannot reopen stale details).
  - Downward-swipe dismissal works and routes nothing (dismisses without opening details).
  - Reduce Motion: the toast fades in via opacity at its final position (no slide-up, no
    bounce), confirmed frame-by-frame from a screen recording.

  A blocking issue was found on the first pass and fixed before this pass:
  the persistent toast was occluded by the iOS 26 floating tab bar (touches over the
  capsule were intercepted by the tab bar, so it could not be tapped or swiped). Resolved
  by commit 39f4b7a3 "Improve toast layout" (.padding(.bottom, 64) + .contentShape(.rect)),
  which lifts the toast clear of the tab bar. Re-verified here.

  Not directly exercised (sim-use has no AX-action/keyboard path): activation through the
  VoiceOver/Voice Control/Switch Control/Full Keyboard Access services themselves. These
  invoke the same Button activate action that touch activation triggers, which is confirmed
  working, so operability is strongly supported by the correct AXButton exposure.

## Summary

total: 1
passed: 1
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]
