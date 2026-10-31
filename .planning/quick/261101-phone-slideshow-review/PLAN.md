# iPhone slideshow layout review

The owner requests applying the existing iPad slideshow card layout to iPhone and returning one
native screenshot for visual review. This extends the earlier D130 phone Home scope, which excluded
the slideshow. Owner acceptance and Phase 17 gates remain pending.

Reuse the rich single-pane slideshow composition and its existing card width, cover, metadata and
spacing. Remove only the large-viewport eligibility check; retain split-pane behavior and navigation.
Build with the existing Debug offline fixture, verify readiness and capture one iPhone Air screenshot
in English, light appearance, default Large text and a neutral 9:41 status bar. Inspect the actual
result without introducing a separate compact redesign. Record build/lint and screenshot evidence.

## Owner revision

Restore the original iPhone card height, omit tags on iPhone, and reduce its title font. Retain the
rich metadata and width from the trial. Use the existing large-viewport policy to preserve the iPad
composition; compact cards use the original hero cover, 20-point padding and a semantic headline.
Verify the normal-size card returns to 190 points and capture the updated home view.

## Owner revision: metadata columns and cover hierarchy

On compact slideshow cards, place Rating before Pages and Category in one row, dropping Category
when its ideal row width does not fit. Reduce the title to subheadline.bold. Preserve language
information separately. Use the standard cover role for compact Frontpage cards (120 points versus
150-point slideshow covers), retaining the existing large-window Frontpage size. Build/lint and
inspect one native home screenshot; check measured cover/card geometry and metadata ordering.

## Owner revision: aligned values, full title region and equal covers

Compact slideshow metadata uses a shared Grid value row with first-text-baseline alignment and a
plain numeric rating. The title has no explicit line limit and fills the region above metadata,
aligned to the top, within the original hero-cover height. Compact Frontpage now uses the same
hero cover role and already shares the subheadline.bold title font. Preserve the iPad slideshow.
Build/lint and capture the default-size native result for continued owner review.

## Owner revision: typography and slightly larger covers

Use subheadline for both compact slideshow metadata rows, footnote.bold for compact Frontpage
titles, and a shared homeCompact cover role of 165 points (10% above the prior 150-point covers).
Keep existing hero and iPad cover roles unchanged. Extend the existing cover-proportion matrix to
include the new role, run its focused test, build/lint and inspect a fresh native screenshot.

## Owner choice and light screenshot presentation

The owner selects gallery 3600779 (Utakata no Dilemma) for the center. Save a new selection/fixture
version with selectedIndex 2 while preserving previous versions. Remove language from compact
slideshow metadata, show one decimal place for compact slideshow and shared Home ratings (including
Toplists), and capture in light mode with a full discharging battery. Use the existing native
XCUIScreen screenshot test for pill-free system output; do not retouch the screenshot or alter
capture-environment pins. Keep normal test parallelism, remove retry policy from the generated
run configuration, and report the exact native test result.
