# Website reader and Live Text recapture

The owner requests capturing and delivering the images specified by the 2026-11-04 recapture
requirements. This is a local screenshot delivery; website intake and publication remain separate.

- Capture from `90d6a6339683ce43dbeacd4068a8b00b975069f9`, which includes the approved reader bottom fade.
- Use iPhone Air portrait, 1260 × 2736 RGB PNGs in sRGB, with 9:41, full Wi-Fi and battery.
- Capture four vertical-reader images at page 6 of 80, with controls and bottom fade visible.
  Both source galleries use English app language and light/dark appearances.
- Capture six light Live Text images using recorded Apple translations and the app's native renderer.
  The owner relayed the planning agent's correction: Live Text stays on page 12, matching the
  original framing; page 6 applies only to reader images.
- English/German use Japanese gallery 4217037. Korean/Japanese/Simplified Chinese/Traditional
  Chinese use English gallery 4223235. All captures use the nonexplicit set.
- Preserve approved fixtures; create new local content-addressed versions for changed translations.
- Verify native readiness, source/gallery/page/language, settled screenshots, dimensions, color,
  alpha absence and checksums. Keep default test parallelism and reject empty runs and retries.
- Deliver ten images, manifest and README outside the website repository, excluding capture
  diagnostics and machine-specific metadata. Retain diagnostics separately in ignored local output.
- Remove only task-created simulators after verification. No app-source changes or publication.

## Owner rejection: English Live Text home indicator

The owner rejected `reading-live-text-en-light.png` because its home indicator is visible.
Use the native persistent-system-overlay visibility preference when reader controls are hidden,
then recapture only that image. Preserve the other nine delivery images. Update the manifest,
README and ZIP with the replacement and its precise build provenance. This continuation supersedes
the original no-app-source-change scope only for this native reader visibility correction.

## Owner clarification: no home indicator in any screenshot

After rejecting `reading-ja-light.png`, the owner clarified that the home indicator must be absent
from all delivered screenshots, including readers whose controls are visible. This is a capture
requirement. Install a DEBUG-only system-overlay visibility preference for capture launches and
propagate it through presented readers. Ordinary launches retain their existing visibility policy.
Regenerate all ten coordinates consistently, verify the indicator is absent in every PNG, and
deliver a new revision with updated checksums and build provenance. Keep the preceding packages
as historical outputs. Commit the completed capture change and records after verification.

## Seven older Filters and adult-mode Detail images

The owner identified remaining home indicators in five Filters screenshots (English light/dark,
German light, Simplified Chinese light/dark) and two adult-mode Detail screenshots (English light,
Korean light). These belong to the original general website corpus rather than the reader/Live Text
replacement matrix. Use the approved default fixtures and hash-pinned tag translations from that
corpus, the current capture-only chrome policy and native sustained settlement. Recapture exactly
these seven coordinates, inspect every bottom edge, validate PNGs and checksums, and deliver them
as a separate replacement package. Preserve the reader/Live Text revision and the original corpus.
No website modification or publication.

Visual inspection of the first replacement German Filters image still found a home indicator.
Filters owns a separately presented NavigationStack, so apply the existing DEBUG-only capture
overlay preference directly to that presentation root, then recapture German Filters. Preserve
the six replacement images whose bottom edges already passed inspection. Ordinary launches and
Release remain unchanged.
