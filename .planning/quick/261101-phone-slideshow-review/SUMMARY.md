# iPhone slideshow review result

Implemented the owner's requested visual trial: single-pane iPhone Home now reuses the existing
iPad rich slideshow card and its 90%-viewport width. The split-pane choice remains unchanged.
Only HomeSectionsView.swift changes; no new layout component or dependency was introduced.

Verification: strict pinned SwiftLint reports zero violations; git diff --check passes. The fresh
Xcode 27.2 Debug simulator build succeeds without compiler warnings/errors. The existing build
folder failed on SwiftSyntax prebuilts compiled for a different macOS SDK; a fresh folder with
source-built package macros resolves that mismatch. The original enabled Xcode prebuilts preference
was restored after the capture build. Build evidence: /tmp/ehpanda-slideshow-fresh-build.log.

Native iPhone Air, iOS 27.2: offline fixture marketing-47696f0e633fea3e reports ready, 31 gallery IDs,
zero pending images, no blockers or unknown requests; English, light, default Large text. Captured
one 1260×2736 screenshot with 9:41 status bar. Its centered card is 378×274 points; the larger cover,
rating, page/category fields and tags render, while the long title truncates after two lines.
This is one standard-size visual trial, not full accessibility/rotation verification or owner approval.

Screenshot: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/iphone-ipad-slideshow.png
The task-owned simulator was removed after capture. Changes remain uncommitted for owner review;
Phase 17 acceptance and baseline gates are unchanged.

## Owner revision: compact height, smaller title, no tags

Compact rich cards now use the original 150-point hero cover and 20-point padding, a semantic
headline instead of title2.bold, and omit tags. Existing rich metadata and 90% card width remain.
The established GalleryViewport.isLarge policy retains the original large-window composition.

Strict pinned lint passes for all three additionally changed files, and git diff --check passes.
The revised Debug simulator build succeeds with no compiler warnings/errors; the temporary Xcode
prebuilts preference is restored successfully. Evidence: /tmp/ehpanda-slideshow-revised-build.log.
Native iPhone Air readiness passes again. The centered card measures exactly 378×190 points,
restoring its original default-size height. Visual inspection confirms no tags and readable rating,
page count and category. The title remains two lines. No iPad runtime or accessibility-size matrix
is claimed for this scoped review. Task simulator removed after capture.

Revised screenshot: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/iphone-slideshow-compact.png

## Owner revision: metadata row and smaller Frontpage covers

Compact slideshow title now uses subheadline.bold. A dedicated compact metadata view presents
Rating, Pages, Category in order; ViewThatFits measures the row's ideal width and drops Category
when it cannot fit. Language remains below when present. The Rating heading is visual only because
the rating control already supplies its accessible label. The new heading is translated in all six
Home locales. Compact-width Frontpage uses the existing standard cover role (120 points), below
the slideshow hero cover (150 points); regular-width Frontpage retains its existing cover role.

Native iPhone Air / English / light / Large: ready, no image blockers; centered card 378×190 points.
At AX1, the accessibility tree confirms Category is absent while Rating and Pages remain. The card
naturally grows with Dynamic Type (228 points), without font caps. Restored Large after this check.
The review screenshot shows the metadata columns and reduced Frontpage cover hierarchy. No full
localization, iPad runtime, or accessibility-size matrix is claimed.

Screenshot: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/iphone-slideshow-columns.png
Initial build and strict lint passed; final accessibility adjustment build evidence is
/tmp/ehpanda-slideshow-columns-final-build.log. Owner acceptance remains pending.
Final build passes without compiler warnings/errors. Final native readiness and 190-point card
height pass; Rating is announced once. Screenshot refreshed from that final build. The task-owned
simulator is removed; Xcode's original prebuilts preference is restored. Changes remain uncommitted.

## Owner revision: shared value baseline, plain rating and title region

Compact slideshow metadata now uses two shared Grid rows; the value row aligns text baselines,
and rating is a plain number without a star. The compact title removes its explicit line limit,
fills the remaining height above metadata, and aligns top-leading. The text column uses the scaled
hero-cover height, retaining the 190-point card at default text size. Compact Frontpage uses the
same hero cover and subheadline.bold title font. The iPad slideshow composition remains unchanged.

Strict lint and whitespace checks pass. Debug simulator build succeeds without compiler warnings
or errors (/tmp/ehpanda-slideshow-aligned-build.log). Native English/light/Large readiness passes;
the centered card remains 378×190 points. Visual inspection confirms aligned numeric/category
values, no rating star, a top-aligned four-line title, and matching 150-point cover heights.
This is a scoped standard-size review; no full Dynamic Type or iPad runtime matrix is claimed.

Screenshot: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/iphone-slideshow-aligned.png
The task simulator is removed after capture, original Xcode preference restored, and changes remain
uncommitted for continued owner review. Phase 17 acceptance gates remain unchanged.

## Owner revision: equal metadata typography and 10% larger covers

Both compact metadata rows inherit subheadline, with secondary color distinguishing labels.
Compact Frontpage titles now use footnote.bold. Slideshow and Frontpage share the new homeCompact
cover role: 165-point height, 10% larger than the prior 150 points, preserving the 0.707 proportion
and existing scaled metrics. Other hero and iPad cover roles remain unchanged.

Strict lint and git diff --check pass. Debug build succeeds without compiler warnings/errors
(/tmp/ehpanda-slideshow-larger-build.log). The expanded existing cover-layout suite passes all
8 test declarations / 23 device test executions, with zero failures or runtime warnings
(/tmp/ehpanda-slideshow-cover-suite.xcresult). The earlier individual-test filter selected zero
tests and is not credited as validation. Two preceding test invocations rejected an unsupported
single-iteration flag and an existing result path before executing tests.

Native English/light/Large readiness passes with 31 gallery IDs and no image blockers. The centered
card measures 378×205 points; both covers are 165 points tall. Visual inspection confirms matching
metadata font sizes, smaller Frontpage titles, and the retained shared value baseline.
Screenshot: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/iphone-slideshow-larger.png
Original Xcode preference restored; task simulator removed after verification. Changes remain
uncommitted for owner review. Phase 17 gates remain unchanged.

## Typography clarification

The owner clarifies that values should shrink to the original label size, rather than enlarging
labels. Compact slideshow metadata Grid now explicitly uses caption for both rows. Language text
retains its existing subheadline style. Cover sizes and Frontpage titles are unchanged. Strict lint
and whitespace checks pass. This is a font-only correction; no new native screenshot or build run.

## Dark-mode slideshow review

Built the latest source, including the caption-size metadata correction, successfully without
compiler warnings/errors (/tmp/ehpanda-slideshow-dark-build.log). Captured all three galleries in
the current slideshow: 1892938, 4157689, 3600779. Each was centered, allowed eight seconds for the
ColorfulX transition, and verified ready in dark appearance with no blockers. The app's readiness
check requires current-cover color analysis in dark mode. Visual inspection confirms the colored
gradient is rendered for all three; these covers produce muted beige/purple/gray palettes.
No palette, animation, fixture-selection or production appearance code was changed for capture.

Evidence directory: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/
Files: dark-01-1892938.png, dark-02-4157689.png, dark-03-3600779.png; matching JSON UI snapshots.
English, default Large text, 9:41 status bar; each card remains 378×205 points. Task simulator
removed after capture; Xcode preference restored. Owner slideshow-center selection remains pending.

## Selected center and native light capture attempt

Owner selected 3600779 (Utakata no Dilemma) as the center. Saved selection-owner-20261101-home-center.json
with selectedIndex 2 and exported immutable fixture marketing-15926cafc2d6cc30. Local fixture commit
1d6c38b is signed (G) with +0800 offset; no push. Previous selections/versions are preserved.

Removed language from compact slideshow metadata and formatted its numeric rating with one
fraction digit. Shared HomeGalleryRating now uses the same format, including Toplists. Strict lint
passes and native UI test build succeeds without compiler warnings/errors (/tmp/ehpanda-center-build.log).

For the requested light screenshot without Dynamic Island, invoked existing
MarketingCaptureUITests/testCaptureCoordinate (XCUIScreen.main screenshot), with a generated
xctestrun containing the new fixture and light/en/iphone/home coordinate, retry policy removed,
and normal test parallelism preserved. Base simulator status bar was set to discharging / 100% / 9:41.
The test reported app.ehpanda.fixture crashed on launch, before capture diagnostics existed.
No valid requested screenshot was produced. Stopped the test; did not relaunch or bypass the failure,
per the sim-use skill's explicit crash checkpoint. Crash evidence is /tmp/ehpanda-center-capture.xcresult
and /tmp/ehpanda-center-capture.log. Task simulator retained for investigation while awaiting owner
instructions; UDID 2F479964-4E34-40F1-8B6B-25576800D2EC. Xcode preference restored after build.
Phase 17 remains unapproved and no screenshot baseline is promoted.

## Retry resolved: fixture center-slot contract

The owner authorized retrying. Exported diagnostics identify the prior crash as a deliberate
capture-launch rejection: selectedIndex must equal Home's starting index 1. The previous fixture
incorrectly set it to 2. Reordered hero galleries to [1892938, 3600779, 4157689] and selectedIndex 1,
preserving the owner's choice without changing or bypassing the app contract. New immutable fixture
marketing-a6157bfafd6db913 is current; signed local fixture commit 83f9adb (G, +0800), no push.
The unchanged retry was interrupted after identifying this cause; it is not credited as verification.

The corrected MarketingCaptureUITests/testCaptureCoordinate passes: 1/1 tests, zero failures,
zero runtime warnings, normal parallel execution and no retry policy. Evidence:
/tmp/ehpanda-center-corrected.xcresult and /tmp/ehpanda-center-corrected.log.
Native screenshot diagnostics report ready, light/en/iphone/Large, new fixture version, all 31 IDs,
zero pending images, blockers or unknown requests. Visual inspection confirms selected 3600779,
5.0 rating, no slideshow language, full non-charging battery and no Dynamic Island capsule.
The PNG is the untouched XCUIScreen attachment, not a retouched framebuffer.

Delivered screenshot: ~/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/home-review/selected-center-light.png
Task simulator removed after delivery preparation. Source changes remain uncommitted for owner
review; the owner-selected fixture change is committed. Phase 17 gates remain unchanged.

## Owner acceptance and next step

The owner accepts the final Home screenshot and requests committing the completed changes.
Final strict lint passes across all seven changed Swift source/test files; whitespace checks pass.
Earlier intermediate screenshots and failed fixture attempts remain historical evidence, superseded
by the successful final native capture above. Acceptance covers this Home design and selected center,
not a full accessibility matrix or completion of Phase 17.

Next is Live Text screenshot review. Book 4217037 is present in the current fixture; book 4223235
is the other final owner-selected Live Text book and still needs its review composition established.
The generation-run rendering-pin decision and website publication remain pending.
