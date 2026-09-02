# Slideshow viewport cap and real screenshot review

> Superseded by [REVISION.md](REVISION.md): owner clarified small 70%/80% and large 50%/40% limits.
Status: implementation complete; owner visual review pending.

Commit: `ec3bff98`.

Home measures its actual scroll viewport. The slideshow ceiling is 50% of viewport height when the viewport is portrait, and 80% when landscape. The ceiling propagates through the equatable carousel when the window changes size. A constrained layout proposes the ceiling without stretching a shorter card to fill it. Cards that do not fit use a compact arrangement with bounded artwork and a shorter title preview, keeping system Dynamic Type sizes.

Validation: four SwiftUI layout tests passed, including parameterized Large/AX5 height budgets and a regression test that prevents expansion to the ceiling. The normal simulator app built successfully. SwiftLint and git diff whitespace checks passed. Actual Home AX5 card bounds measured 228 pt on iPhone and 360 pt on the full-size iPad configurations.

The real review now contains 114 PNGs across 19 views, each with iPhone portrait, iPad portrait and iPad landscape at Large and AX5. PNG chunk checksums and compressed image data were verified; every manifest row has all six configurations. HTML JavaScript syntax was checked. Browser automation refused reloading the existing file URL, so automated browser interaction validation was not completed.

Capture limitations remain explicit in the local review: both simulators are signed out, downloads are empty and no download inspector can be opened. These are actual recorded states, not populated-cover verification. Additional resized iPad windows were not captured; constrained height budgets have automated layout coverage. Popular initially returned Not Found on iPad; a later reload succeeded and all six populated detail-list captures plus six thumbnail captures replaced that limitation. Home, Frontpage and Popular use real Non-H filtered data. No fixture data or PDF was used for this follow-up.

Temporary category and display settings were restored and checked against persisted preferences. Both simulators returned to Large, and iPad returned to portrait.

Local artifact directory: `$HOME/.codex/visualizations/2026/09/07/01a07ac6-2537-7ac2-9d9e-27cf7712377a/real-cover-review/`.
