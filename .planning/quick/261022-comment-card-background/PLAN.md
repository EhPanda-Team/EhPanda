# Detail comment-card background investigation — 2026-10-22

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner report (D110)

A comment preview in the horizontal Detail Comments strip sometimes has a narrower, square-cornered
background while adjacent cards remain rounded. Investigate and correct the cause without changing
the established card sizes, text budgets, header reflow, navigation or full Comments list.

## Hypothesis and plan

The preview paints its background before assigning the fixed card width. A short body with a header
that falls back to two lines can retain a narrower intrinsic width; the outer clipping shape then
clips the allocated card bounds rather than the visible background edges. Reproduce with native
SwiftUI rendering and neutral short/long comment fixtures before editing production code.

Check both light and dark, at Large, AX1, AX3 and AX5. Assert that the background reaches every
straight edge of the allocated card and all four corners are transparent. Retain before/after native
render attachments. If confirmed, let the content fill its available width with leading alignment,
then paint the background after the final card frame and apply the existing rounded clip.

Run strict lint and the focused native rendering regressions. Build/launch the review iPad in place
with its account/data preserved. Record the actual code SHA, results and any verification limits
in SUMMARY.md and the session decision ledger. No screenshot-baseline promotion or Phase 17 gate
completion is implied.
