# Equal spacing around Recently Seen — D127–D128

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Current spacing: D128 increases the shared inter-section gap to 32 points. The 24-point
measurements and screenshot below are historical D127 evidence.

Date: 2026-10-23. Implementation: `105950892dbe7b28e4b2e80ce85a447378f9f5a9`.

The owner observes unequal spacing above and below Recently Seen and asks for consistency.
D124 set the outer stack gap to 24 points, but keyword content still carried vertical padding
and an invisible last divider with its own gap. Those internal spaces increased only the gap
preceding Recently Seen; the outer stack setting alone did not resolve the visible discrepancy.

Remove keyword-stack vertical padding, retaining horizontal margins. Render dividers only between
rows, so the last row contributes no invisible footer. The common section container explicitly
uses 8 points between heading and content; the outer stack owns the 24-point inter-section gap.
Both keyword types retain their 44-point minimum control height, wrapping and existing row pitch.
Empty content keeps its 96-point minimum height and top-leading secondary text. Header actions,
confirmation behavior, persistence, native navigation/search and scroll-edge policy are unchanged.

## Native verification

The native iPad landscape screenshot (image removed from repository history) uses the same synthetic
14 recent searches, ten gallery records and 12 saved searches as the earlier review. Accessibility
rectangles from the running app give these measurements, in points:

| Measurement | Actual |
|---|---:|
| Last Recent Search control bottom → Recently Seen heading top | 24 |
| Gallery-strip bottom → Quick Search heading top | 24 |
| Recently Seen heading bottom → gallery-strip top | 8 |
| Quick Search heading bottom → first keyword-control top | 8 |
| Recent Search / Quick Search control height | 44 / 44 |

These are section/content bounds, not glyph-ink measurements; native font metrics and the controls'
minimum touch height remain intact. Pinned strict SwiftLint and whitespace checks pass. Both the
preview and restored normal builds pass with zero compiler/analyzer warnings or errors. No new
behavior tests or full accessibility/device matrix were run for this layout-only correction; D126's
16-test behavior evidence remains tied to its original implementation commit.

The temporary data-only seed is identical in purpose to the retained
[preview patch](actions-preview-seed.patch), and source restoration is verified byte-for-byte before
the normal build. No fixture setup remains in production source. The existing review iPad receives
the normal app and launches without seed flags (PID 60122), preserving its data and preferences.
The dedicated capture simulator is shut down and deleted. Evidence, commands, build diagnostics,
raw native rectangles and computed gaps are under `.build/library/search-equal-spacing-preview/`
and `.build/library/search-equal-spacing-final/`. A compact text-role selector did not match the
native StaticText role; the full raw snapshot supplied the exact rectangles for measurement.
Phase 17 owner gates are unchanged.


## Larger shared gap — D128

Implementation: `afeed90a362421da10d900a571af18d1e15eac0a`. The owner asks to increase spacing after D127
equalized it. Increase only the shared section stack gap from 24 to 32 points, keeping the
same gap above and below Recently Seen. Retain the 8-point heading/content gap, 44-point
minimum keyword controls and 96-point minimum empty-content height.

Pinned strict SwiftLint and whitespace checks pass. The generic Simulator build succeeds with
zero compiler/analyzer warnings or errors. The existing review iPad receives the normal build and
launches without seed flags (PID 84434), preserving its data and preferences. Evidence is under
`.build/library/search-section-spacing-32/`. No new screenshot, native geometry measurement or
behavior test run is claimed for this one-value layout change. The earlier screenshot and
24-point measurements remain tied to D127; D126's behavior tests retain their original source
boundary. Phase 17 gates are unchanged.
