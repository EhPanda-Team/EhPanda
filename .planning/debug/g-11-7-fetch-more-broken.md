---
status: investigating
trigger: "frontpage list (probably all lists) fetch more feature is broken, it just reach the end and won't fetch more"
created: 2026-07-21
updated: 2026-07-21
---

## Current Focus

status: diagnosed (diagnose-only mode — no fix applied)

reasoning_checkpoint:
  hypothesis: "Commit ebc99f5e deleted DetailList's last-cell `.onAppear` fetch-more trigger and replaced it with `AutoLoadNextPage`, a scroll-geometry heuristic that was designed and device-validated (Phase 2 / D-36) only for ThumbnailList's structurally different layout. Because `listDisplayMode` defaults to `.detail`, every gallery list lost its working pagination trigger."
  confirming_evidence:
    - "git show ebc99f5e: the `.onAppear { if gallery == galleries.last { fetchMoreAction?() } }` block is deleted from DetailList; `.autoLoadNextPage(...)` added."
    - "Setting.swift:91 — `listDisplayMode: ListDisplayMode = .detail` is the default, so DetailList is the code path users actually see."
    - "02-CONTEXT.md D-36 states the guards were built for the masonry layout and that a STANDALONE SIBLING footer row breaks the geometry accounting — which is exactly DetailList's structure (FetchMoreFooter is a sibling row inside the ForEach)."
    - "D-36 explicitly scoped itself: 'Detail mode's own pagination (DetailList, last-cell onAppear) is unchanged.' 11-11 violated that scoping."
    - "All 7 list surfaces (Frontpage, Watched, Favorites, Search, Toplists, History, DetailSearch) route through GalleryList -> DetailList."
  falsification_test: "Switch Appearance -> list display mode to `thumbnail` and scroll a multi-page list. If pagination works there but not in `detail`, the layout-structural mismatch is confirmed. If BOTH fail, the defect is in AutoLoadNextPage's guard set generally."
  fix_rationale: "Restore an edge-triggered 'trailing cell reached' signal using `.onScrollTargetVisibilityChange(idType:)` — the semantic equivalent of the deleted `.onAppear`, already used in-repo at PreviewsView.swift:65, and not matched by the `lifecycle_modifiers` regex. Re-entrancy is already covered by the reducer's own `footerLoadingState != .loading` + `hasNextPage()` guards, so no view-local latch is needed."
  blind_spots: "Cannot run the app; have not empirically confirmed WHICH guard fails to fire (the one-shot `lastAutoFetchCount` latch vs. never satisfying the geometry predicate). Have not confirmed thumbnail mode still works at HEAD."

## Symptoms

## Symptoms

expected: Scrolling a gallery list to the bottom fetches the next page and appends more galleries.
actual: List renders first page, reaches end, never appends more.
errors: none reported
reproduction: Open front page, scroll to bottom.
started: after phase 11 (infra refactor + SwiftLint lifecycle_modifiers sweep)

## Eliminated

## Evidence

- checked: AppPackage/Sources/GalleryListComponents/GalleryList.swift
  found: fetch-more is driven by AutoLoadNextPage ViewModifier using .onScrollPhaseChange + .onScrollGeometryChange, NOT .onAppear on trailing cell. Applied to both DetailList and ThumbnailList.
  implication: The sweep DID replace the lifecycle trigger with a scroll-geometry trigger (a legitimate per-scroll mechanism). Bug is likely in the guard logic, not in a presentation-time action.

## Resolution

root_cause:
fix:
verification:
files_changed: []
