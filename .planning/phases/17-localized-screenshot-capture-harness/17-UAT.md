---
status: complete
phase: 17-localized-screenshot-capture-harness
source: 17-01-SUMMARY.md, 17-02-SUMMARY.md, 17-03-SUMMARY.md, 17-04-SUMMARY.md, 17-05-SUMMARY.md, 17-06-SUMMARY.md, 17-14-SUMMARY.md, 17-16-SUMMARY.md, 17-17-SUMMARY.md, 17-18-SUMMARY.md, 17-19-SUMMARY.md, 17-23-SUMMARY.md, 17-24-SUMMARY.md
started: 2026-11-04T17:22:17Z
updated: 2026-11-05T00:57:22.293Z
---

## Current Test

[testing complete]

## Tests

### 1. Reload All Images while reading
expected: On an iPhone and on an iPad, open any gallery in the reader with Direction set to Left-to-right (in Reading Settings, with Match Screen Orientation off) and go to about page 5. Tap the right edge to turn a page and, straight away, choose Reload All Images from the reader's ••• menu. When the images are back, the reader shows the page you were on or the one you were turning to, and the page number in the controls names that page. Then turn pages by tapping the edges, by dragging the slider to another page, and with Auto-Play. Every time, the page number matches the page on screen, each tap moves exactly one page, the slider lands on the page you picked, Auto-Play steps forward one page at a time, and nothing jumps back or gets stuck. (The page may follow the slider while you are still dragging; that is a known limit.)
result: pass
source: agent
evidence: "Agent-run (owner rule msg 1652), throwaway XCUITest at 891103afa source on iPhone Air and iPad Pro 11 sims, offline fixtures. iPhone run D: edge tap 5->6, Reload All Images, settles on 6; edge taps +/-1, slider lands as picked, Auto-Play steps by one (video-confirmed). iPad run B: lands on 6, slider and Auto-Play correct. Menu reached 2.7 s and Reload 4.8-5.0 s after the edge tap (XCUITest idles between taps)."
addendum 2026-11-05: rebuild-during-turn condition exercised separately, see 17-WR01-MIDTURN.md

### 2. Switch from Vertical to Left-to-right while reading
expected: On an iPhone and on an iPad, read a gallery with Direction set to Vertical and scroll partway into a page around page 5. Open Reading Settings from the ••• menu, change Direction to Left-to-right and close the settings. The reader shows a page and the page number names that same page. Then turn pages by tapping the edges, by the slider and with Auto-Play: every turn moves the page, the page number always matches the page on screen, and nothing jumps or gets stuck.
result: pass
source: agent
evidence: "Agent-run. iPhone run A: page 6 before, page 5 after the switch, indicator matches; taps, slider and Auto-Play fine. iPad run B: pass."
addendum 2026-11-05: rebuild-during-turn condition exercised separately, see 17-WR01-MIDTURN.md

### 3. Switch from Left-to-right to Right-to-left while reading
expected: On an iPhone and on an iPad, while reading around page 5 in Left-to-right, change Direction to Right-to-left in Reading Settings and close the settings. The same page stays on screen with the matching page number. Tapping the left edge now goes to the next page and the right edge to the previous one, and the slider and Auto-Play also move the pages in the right-to-left order. The page number always matches the page on screen, and turning keeps working.
result: pass
source: agent
evidence: "Agent-run. iPhone run C: left taps go forward (5->8), right taps back; slider left quarter -> 106, right quarter -> 42 (reversed as RTL); Auto-Play forward. iPad run B: slider 109/45, pass. Run A's failure was a harness fault (accessibility slider value is not screen position under the RTL rotation)."
addendum 2026-11-05: rebuild-during-turn condition exercised separately, see 17-WR01-MIDTURN.md

### 4. Reader reopens on the right page and keeps up with quick turns
expected: Close the reader on a later page (for example page 8) and open the gallery's reader again, once in Vertical and once in Left-to-right: it opens on that page and the page number says so. In Left-to-right, tap an edge several times quickly: the reader ends up as many pages forward as you tapped, and the page number matches the page shown. On an iPhone, open the Vertical reader in portrait and turn the phone to landscape: it stays on the page you were reading. (One quick self-correction of the page right after a rotation is a known limit.)
result: pass
source: agent
evidence: "Agent-run. iPhone run A: reopens on page 8 in LTR and Vertical; 5 quick taps 8->13, back to 10; landscape rotation holds page 10. iPad run B: pass (rotation part iPhone-only). A separate 0.25 s tap-burst check was a harness fault (taps never delivered; 0.25 s spacing is a double-tap) and is not part of this test."

### 5. Reader edges and home indicator
expected: In the reader, tap the middle of the page to show the controls: the page fades softly under the top navigation bar and also under the lower control panel at the bottom. Tap again to hide the controls: on a device with a home indicator, the home indicator bar fades away while the controls are hidden, and it is back when you show the controls or leave the reader.
result: pass
source: agent
evidence: "Agent-run. Page fades under the top bar and the lower panel: pass on iPhone (run C) and iPad (run B); status bar hides and shows with the controls. The home-indicator clause cannot be captured in simulator screenshots or video; code path ReadingView persistentSystemOverlays(showsPanel ? .automatic : .hidden). Owner accepted that clause as code-checked (msg 1663)."

### 6. Gallery and Settings on wide and narrow windows
expected: On an iPad at full width, tapping a gallery in Home or Library opens it as a centered sheet over the screen, and tapping Settings opens Settings as a sheet; the tabs sit at the top, Home shows no title, and Library has a category sidebar. In a narrow iPad window (a Stage Manager window dragged to its narrowest) and on an iPhone in landscape, the same gallery tap pushes the gallery full screen with a Back button and the bottom tab bar, and Settings opens as its own tab; Home shows its title, and Library shows a single list with a title menu. Galleries opened from Search and Downloads follow the same rule.
result: pass
source: agent
evidence: "Agent-run. iPhone landscape and portrait run C: pass. iPad full width run F3: pass. iPad narrow window (Stage Manager 375 pt) run F5: pass. Correction to the expected text: in a narrow iPad window Library shows the collapsed split view (Favorites with a back button to the category list), not a title menu. That is the kept behaviour (17-LAYOUT-AUDIT row 2, owner msg 1409); the title menu applies to iPhone. Search and Downloads push with Back and the bottom tab bar."

### 7. Home slideshow colors with and without Reduce Motion
expected: On Home, the slideshow card in focus is tinted with colors from its cover, and the same gallery gets the same colors every time you come back to it. With Reduce Motion on (iOS Settings, Accessibility, Motion), the tint stands still and a tint that arrives after the cover loads appears at once, without fading in. With Reduce Motion off, the tint moves gently, as before.
result: pass
source: agent
evidence: "Agent-run. Same colours on return (distance 1.0 off / 0.0 on; different cards 38-52 apart); Reduce Motion off: tint drifts; on: holds still (0.00 change per frame), iPhone run G and iPad run H. The late-tint-appears-at-once clause cannot be separated in offline fixtures (cover, text and tint fade in together); owner accepted it as code-checked (msg 1663)."

### 8. Website screenshots
expected: On the EhPanda website, the screenshots show the current app on iPhone for all eight screens (Home, gallery details, comments, filters, the reader, the reader with Live Text, Downloads and Laboratory), in all six languages, in light and dark, and for both content sets. Each image is sharp and complete, every cover and page is loaded with no placeholder, the status bar shows 9:41 with full signal and a full battery, and the Live Text image shows Live Text over the page's text.
result: pass
source: agent
evidence: "Agent-run. All 192 coordinates map to the 118 files in ehpanda-website main c17d230 (public/image/); 118/118 SHA-256 match the d4393bd provenance. All 118 viewed: right screen, locale, theme, sharp, no placeholders; 112 status bars 9:41/full (6 Live Text hide it by design); Live Text overlay on all 6. Live site is behind Cloudflare Access by design; Leto (msg 1656) checked the deployed c17d230 build: every referenced image present, no broken images; black corner pixels in 46 light files are hidden by the frame clip. Minor app-content notes (not capture faults): untranslated 'artbook' tag chip, a truncated comment date (ja), Laboratory title style differs de dark vs light."

### 9. Accept the reduced Phase 17 result
expected: You agree that Phase 17 closes with: the screenshot capture tooling, the approved 192-image website set, the size-class layout that already landed together with the five device-specific behaviors you chose to keep, and a clean check that the Release app ships no capture or test code. You agree that these move to Phase 18 and are not done here: the visual-regression snapshots and baselines, the CI snapshot check, the preview tooling, the 384-image marketing export and final gallery choice, the AltStore promotional images, the reader page-tracking rework with its UI tests, and the two deferred code-review clean-ups. You accept the known limits: the reader page-sync stress test ran 5 times per device instead of 20; it does not cover right-to-left reading or iPad two-page spreads; the slider seeks live during a drag; and a rotation or a two-page spread can cause one quick page correction.
result: pass
source: owner
evidence: "Owner accepted the reduced Phase 17 with the moved work and known limits (msg 1663, card 1662; scope listed in msg 1661)."

### 10. Genuine app-hosted capture preserves native viewport pixels and captures all finite content on 32 coordinates.
expected: Genuine app-hosted capture preserves native viewport pixels and captures all finite content on 32 coordinates.
result: pass
source: automated
coverage_id: D1

### 11. Missing or duplicated rendered markers remain detectable after two-scale OCR merging.
expected: Missing or duplicated rendered markers remain detectable after two-scale OCR merging.
result: pass
source: automated
coverage_id: D2

### 12. Public fixture v2 exports repeatable complete bytes with validated source and asset provenance.
expected: Public fixture v2 exports repeatable complete bytes with validated source and asset provenance.
result: pass
source: automated
coverage_id: D3

### 13. The runner requests exactly 576 canonical coordinates per scenario, validates the pin before capture and accounts for every requested row, including interruption.
expected: The runner requests exactly 576 canonical coordinates per scenario, validates the pin before capture and accounts for every requested row, including interruption.
result: pass
source: automated
coverage_id: D1

### 14. The complete hosted tracer captures all 576 coordinates on both families with the tracked pin and leaves references untouched.
expected: The complete hosted tracer captures all 576 coordinates on both families with the tracked pin and leaves references untouched.
result: pass
source: automated
coverage_id: D2

### 15. Acquisition mirrors the app's requests, refuses disallowed hosts, redirects and account sessions, scrubs access values, and publishes only a verified version through a single writer.
expected: Acquisition mirrors the app's requests, refuses disallowed hosts, redirects and account sessions, scrubs access values, and publishes only a verified version through a single writer.
result: pass
source: automated
coverage_id: D1

### 16. Validation rejects tampering, including resealed semantic edits, malformed entries, symbolic links, traversal, extra or missing files and renamed versions.
expected: Validation rejects tampering, including resealed semantic edits, malformed entries, symbolic links, traversal, extra or missing files and renamed versions.
result: pass
source: automated
coverage_id: D2

### 17. The review traces every gallery occurrence, page and comment to the active selection, checks the proposed composition, keeps configured order and approves nothing.
expected: The review traces every gallery occurrence, page and comment to the active selection, checks the proposed composition, keeps configured order and approves nothing.
result: pass
source: automated
coverage_id: D3

### 18. A capture launch validates configuration and fixture completely (exact file set, lengths, SHA-256, canonical paths, links, media types, selection identity, aggregate digest and version) and refuses malformed or mismatched input before any state exists.
expected: A capture launch validates configuration and fixture completely (exact file set, lengths, SHA-256, canonical paths, links, media types, selection identity, aggregate digest and version) and refuses malformed or mismatched input before any state exists.
result: pass
source: automated
coverage_id: D1

### 19. Capture state cannot reach personal settings, caches or downloads, and unknown requests fail the capture.
expected: Capture state cannot reach personal settings, caches or downloads, and unknown requests fail the capture.
result: pass
source: automated
coverage_id: D3

### 20. The Release app ships no capture fixture, test asset, SnapshotTesting or XCTest linkage, and no DEBUG or instrumented compile.
expected: The Release app ships no capture fixture, test asset, SnapshotTesting or XCTest linkage, and no DEBUG or instrumented compile.
result: pass
source: automated
coverage_id: D1

### 21. No environment flag activates capture in a launched Release build.
expected: No environment flag activates capture in a launched Release build.
result: pass
source: automated
coverage_id: D2

### 22. The scanner rejects a seeded bad payload.
expected: The scanner rejects a seeded bad payload.
result: pass
source: automated
coverage_id: D3

### 23. FeatureTests and UITests pass on phone then tablet, and strict no-cache lint passes, without suppression.
expected: FeatureTests and UITests pass on phone then tablet, and strict no-cache lint passes, without suppression.
result: pass
source: automated
coverage_id: D4

### 24. The five view-layout sites read size classes, suggestion placement or container fitting at HEAD, with no idiom read.
expected: The five view-layout sites read size classes, suggestion placement or container fitting at HEAD, with no idiom read.
result: pass
source: automated
coverage_id: D1

### 25. The existing Home and Search behavioral tests pass on phone and tablet.
expected: The existing Home and Search behavioral tests pass on phone and tablet.
result: pass
source: automated
coverage_id: D2

### 26. Home and Library (Favorites) gallery taps open Detail as a sheet only when both window size classes are regular, decided once at the app root.
expected: Home and Library (Favorites) gallery taps open Detail as a sheet only when both window size classes are regular, decided once at the app root.
result: pass
source: automated
coverage_id: D1

### 27. Search and Downloads gallery taps follow the app-root window-size-class rule, and routeGalleryDetail no longer exists.
expected: Search and Downloads gallery taps follow the app-root window-size-class rule, and routeGalleryDetail no longer exists.
result: pass
source: automated
coverage_id: D1

### 28. Download manifest SSOT, the same-run deletion invariant and row-anchored confirmation dialogs are unchanged by the routing migration.
expected: Download manifest SSOT, the same-run deletion invariant and row-anchored confirmation dialogs are unchanged by the routing migration.
result: pass
source: automated
coverage_id: D2

### 29. Settings is a sheet only when both window size classes are regular and the Settings tab is not already selected, and inline otherwise.
expected: Settings is a sheet only when both window size classes are regular and the Settings tab is not already selected, and inline otherwise.
result: pass
source: automated
coverage_id: D1

### 30. Both device families and orientations have actual-window geometry and rendering metadata.
expected: Both device families and orientations have actual-window geometry and rendering metadata.
result: pass
source: automated
coverage_id: D1

### 31. An immutable tracked rendering pin resolves fresh devices and rejects rendering drift before capture.
expected: An immutable tracked rendering pin resolves fresh devices and rejects rendering drift before capture.
result: pass
source: automated
coverage_id: D2

## Summary

total: 31
passed: 31
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
