---
quick_id: 260923-shl
mode: quick
description: Restore vertical centering in gallery detail cells while preserving Dynamic Type layouts
recorded_after_execution: true
---

# Restore gallery cell vertical centering

This record captures the scope approved and executed in the conversation. The owner requested
GSD documentation and commits after the implementation and visual verification were complete.

## Approved scope

- Restore the pre-Dynamic-Type vertical centering of the side-by-side cover and text column.
- Remove the previous uncommitted spacer, minimum-height constraint, and supporting grouping.
- Preserve horizontal spacing, shared cover sizing, adaptive metadata pairs, text wrapping,
  and the narrow accessibility layout that stacks the cover above the text.
- Limit production changes to
  `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift`.

## Execution and acceptance

1. Inspect the layout immediately before commit `59fb2eb9`, including the cell's renamed history.
   Establish whether the old design used a vertical spacer or native stack centering.
2. Restore native centering with the smallest change supported by that evidence.
3. Build the normal app and run strict uncached lint on the changed source.
4. Capture and inspect the real component on iPhone and iPad at Large, AX1, AX3, and AX5.
   Check live size changes, cold AX5 entry, and long-title rows with tags and a download badge.
5. Remove the temporary capture entry point, restore simulator settings, record results in
   the summary and STATE.md, and commit the fix and its GSD records.

Acceptance: short text centers beside the cover; taller text can grow naturally; the narrow
accessibility layout remains readable and scrollable; build and lint pass without suppression.
