---
status: testing
phase: 05-adaptive-layout-universal-orientation
source: [05-VERIFICATION.md]
started: 2026-07-13T10:29:32Z
updated: 2026-07-13T10:29:32Z
---

## Current Test

number: 1
name: Universal rotation and reader state
expected: |
  Home, detail, grid, settings, and reader screens rotate without snap-back. Single-page,
  dual-page, RTL, current-page, and resumed-landscape state all remain correct.
awaiting: user response

## Tests

### 1. Universal rotation and reader state

expected: Home, detail, grid, settings, and reader screens rotate without snap-back; single-page, dual-page, RTL, current-page, and resumed-landscape state all remain correct.
result: [pending]

### 2. About metadata in landscape

expected: Version, build, copyright, and related metadata remain visible in the leading form content on a landscape phone.
result: [pending]

### 3. Reader placeholders

expected: Slow or unavailable pages in portrait/landscape and single/dual-page modes occupy the usable page footprint instead of collapsing to narrow slivers.
result: [pending]

### 4. Home carousel sizing

expected: Phone and pad in portrait/landscape show stable card width and pitch, a centered focused card, and the intended neighboring-card peek.
result: [pending]

### 5. Range fields and reusable sheet cancellation

expected: Filters range fields show no duplicate visible title while retaining a useful VoiceOver label; Filters, Quick Search, and Date Seek each expose an untitled Cancel control that dismisses the sheet.
result: [pending]

### 6. Favorites category, feature menu, and date seek

expected: Category selection is directly reachable; sorting, date seek, and quick search are available from the features menu; date seek is disabled before metadata arrives and opens after it arrives.
result: [pending]

### 7. iPad freeform reader controls

expected: Reader upper controls clear the window traffic-light region in freeform windows, while full-screen pad and phone spacing remain unchanged.
result: [pending]

### 8. Home card contrast

expected: Home cards remain distinguishable in normal and freeform windows in light mode, dark mode, and Increase Contrast.
result: [pending]

### 9. Single-window behavior

expected: System app and window menus expose no New Window or multi-scene affordance.
result: [pending]

### 10. Gallery-route host matrix

expected: On phone, Home carousel/cover/top lists and nested lists, Search root/nested lists, Favorites, Downloads, Comments, and detail-search onward routes push; equivalent in-app pad hosts present; external deep links remain deliberately modal on both.
result: [pending]

### 11. Representative adaptive-layout matrix

expected: Compact/regular widths and split view keep category/grid layouts, previews, archives, and settings readable, centered, and unclipped in portrait/landscape. Maximum Dynamic Type is deferred to Phase 10.
result: [pending]

## Summary

total: 11
passed: 0
issues: 0
pending: 11
skipped: 0
blocked: 0

## Gaps

[none yet]

## Previous Gap Closure

- G-05-1 was resolved by executed Plans 05-11 through 05-15; this session retests the six corrected runtime behaviors.
- G-05-4 source fixes were resolved by executed Plans 05-16 and 05-17. Plan 05-18 found no routing bypass, so the live gallery-host matrix remains a human confirmation.
- Comprehensive maximum Dynamic Type support remains deferred to Phase 10 and is not a Phase 5 acceptance blocker.
