# Home pose screenshot review — 2026-11-01

The owner approved the corrected Live Text translation review and requested whole-Home screenshots,
including scrolled Frontpage and Toplists, for Duo and iPad Pro in each pose. The expanded request
adds Stage Manager, Split View and windows with portrait/landscape proportions.

## Capture matrix

- Duo: closed (0°), half-open (130°), open (180°), each portrait/landscape.
- iPad Pro 11-inch M5: full screen, Stage Manager, two-column tiled windows and free windows,
  each portrait/landscape. The free windows are 633×1029 and 939×487 points.
- Native iPad two-column Fill & Arrange supplies the requested Split View in Windowed Apps mode;
  Settings is the adjacent app. The final landscape capture retains the native divider. An earlier
  overlapping-window attempt is excluded from delivery.

Light appearance, English UI, Large text, 9:41 and battery discharging at 100%. Home uses selected
center gallery 3600779 in fixture `marketing-a6157bfafd6db913`, using the accepted Home build plus
the separately approved Debug translation-replay changes. No Home source changed for this request.

The sim-use observe/act/verify workflow checked capture readiness, blockers and unknown requests.
Native iPad framebuffers saved sideways are rotated upright, without cropping or retouching.
Duo capture explicitly selects the active cover/inner display because the default screenshot route
can capture its inactive panel. Full-resolution viewport captures preserve native system chrome;
Duo vertical system bars are expected on this runtime. Cards may span overlapping viewport images.
Overview contact sheets contain scaled copies; no stitched or generated app screens are presented.

Local delivery root:
`$HOME/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-poses/`.
`review/` contains named PNG sets, overviews, README and source/pixel-size manifest. Separate Duo
and iPad ZIPs avoid an HTML dependency. Raw capture JSON and superseded attempts remain outside
the curated delivery. This is review evidence, not final marketing generation or a baseline/pin update.

No additional source tests were warranted for screenshot capture. Existing Live Text validation
remains recorded in its own summary; this task does not claim a fresh test-suite run.

## Final delivery verification

Delivered 14 configurations and 120 curated native-resolution PNG frames. Both ZIP archives
passed CRC verification; all images decode, are nonblank and match the labeled orientation.
The corrected landscape tiled sequence reports 600×834-point Home geometry throughout.
Both task-owned simulators and only those simulators were removed after capture. Owner review
of these Home pose sets is pending.

## Refresh-fix recapture (R2) — 2026-11-01

Owner requested the same complete pose matrix after the native iPad Reload-row fix. Recaptured
all 14 configurations against `13a461c0c`, with the accepted Home adaptations now committed as
`ecdc11f68` and the approved translation replay as `252b3a8d5`. Fresh build-for-testing completed
without warnings or errors; the 52 Python fixture tests pass. This capture changes no app source.

R2 contains 111 curated native-resolution PNG frames: 51 Duo and 60 iPad. Light appearance,
standard text size, selected center 3600779, 9:41 and noncharging battery are retained. Whole Home
includes Frontpage, all four Toplists categories and Other; overlapping supplemental frames cover
the second Frontpage row in short windows. The selected frames collectively cover all three
vertical thirds of every Frontpage and Toplists card, with no missing coverage tokens.

The iPad viewports (portrait / landscape, points) are:

- Fullscreen: 834×1210 / 1210×834.
- Stage Manager: 714×1118 / 752×647.
- Native two-column Fill & Arrange: 412×1210 / 600×711, with Settings alongside Home and
  the native divider visible. Rotation restored the earlier floating layout, so the native
  two-column arrangement was reapplied in portrait before capture.
- Free windows: 714×1118 / 941×486.

Verified the merged top tab/Reload row in the expanded iPad layouts. Both overview PNGs were
visually inspected. All 111 frames decode, are nonblank and match their labeled orientation;
both ZIPs pass CRC checks, and their manifests reference only included files. Capture diagnostics
reported ready with no blockers or unknown requests. No process disappearance was observed.

Local delivery root:
`$HOME/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-poses-r2/`.
`review/duo-overview.png` and `review/ipad-overview.png` provide the pose overview; separate
Duo and iPad ZIPs contain the complete scrolled sets. R1 and raw evidence are preserved.
This remains owner review evidence, not approval of a marketing baseline or rendering pin.

Both R2 task-owned simulators were deleted after verification; the owner’s standard iPhone
review simulator remains booted. Other simulators were preserved.
