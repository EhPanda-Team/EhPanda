# Website reader and Live Text recapture

The owner requests capturing and delivering the images specified by the 2026-11-04 recapture
requirements. This is a local screenshot delivery; website intake and publication remain separate.

- Capture from `bc67ddf146fce546b03abc2a24db7ab70a62d0f4`, which includes the approved reader bottom fade.
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
