# Website recapture delivered — 2026-11-04

Captured all ten requested iPhone Air images from EhPanda 3.0.0 (158), commit
`bc67ddf146fce546b03abc2a24db7ab70a62d0f4`, on iOS 27.2 (24B8117).
Four reader images show page 6 / 80, controls and the approved light/dark bottom fade.
Six light Live Text images show page 12, following the owner's relayed correction, with the
required source-gallery mapping and target-language overlays. All use the nonexplicit selection.

The source folder and ZIP are in the current chat's visualization output under
`ehpanda-screenshot-source-20261104`. The folder contains exactly ten PNGs, `manifest.json`
and `README.md`. Each PNG is 1260 × 2736, RGB without alpha, with the standard sRGB IEC61966-2.1
ICC profile. Ancillary screenshot metadata was removed without changing rendered pixels.
Every manifest SHA-256 and byte count was verified, and the twelve-file ZIP passed integrity checks.

## Capture and verification

- Native capture tests verified all ten accepted coordinates: correct gallery, page, app language,
  theme, control visibility, ready state, zero pending images, no unknown requests, and settled screenshots.
- The two successful light-reader configurations were retained from the first nonempty batch.
  Six Live Text configurations passed in a subsequent batch; both dark-reader configurations passed.
  Default test parallelism stayed enabled; capture configurations disabled automatic retries only.
- Visual inspection confirmed the four reader controls/fades and the six translated overlays.
  The central page pixels of each light/dark reader pair are identical.
- English/German use Japanese gallery 4217037; the other four locales use English gallery 4223235.
  The original page framing is preserved. Nothing adult-only appears.
- Live Text uses real Apple Translation records with the app's native rendering pipeline.
  German, Korean and both Chinese targets were newly recorded for the revised source mapping;
  English/Japanese retain their approved records. All screenshots are new captures from one build.
  This is rendered replay verification, not an end-to-end online translation test.

## Capture issues resolved

The normal UITests plan excludes MarketingCaptureUITests. The initial empty run produced no
images; capture-only configurations explicitly selected that class. No production test plan changed.

The old Live Text fixtures lacked later pages requested by the current lazy reader, producing
unknown-request failures. New immutable local versions include the full chapter range, reconstructed
entirely from the existing saved response archive. Approved fixtures and translation source images
remain unchanged. The failed Live Text images are excluded from delivery.

AirBuild commands were unavailable in this desktop session. The local Simulator build used native
`xcodebuild build-for-testing`; no source, signing configuration, bundle setting, dependency
declaration or production configuration was changed. Build succeeded.

Private capture scripts, source inputs, raw attachments, result bundles and detailed evidence remain
under ignored `.capture/website-recapture-20261104/`, separate from the delivery.
Only the task-created simulator and its testing clones were removed after verification.
No app-source changes, commits, website changes or publication.

## Revision 2 — English Live Text home indicator

The owner rejected `reading-live-text-en-light.png` because the home indicator was visible.
The reader now requests `.persistentSystemOverlays(store.showsPanel ? .automatic : .hidden)`
on its NavigationStack root. The native visibility preference follows reader controls and
preserves system navigation. Only this image was recaptured; the other nine PNGs remain
byte-identical. Concurrent reader edits were preserved.

The recapture build was the original base commit plus this one-line visibility change, uncommitted
at capture time. The build succeeded, strict no-cache SwiftLint reported zero violations in the
changed file, and the native capture test passed once, with correct page 12/gallery/language,
controls hidden, no unknown requests or blockers, zero pending images and a settled screenshot.

Visual inspection confirms the home indicator is absent. Exact RGB comparison with the rejected
image confines every changed pixel to `(405, 2697)–(855, 2712)`, its former home-indicator rectangle.
Everything else, including framing and translations, is identical. Screenshot pixels were not retouched.

The revised folder and ZIP are named `ehpanda-screenshot-source-20261104-r2`. The manifest checksum
and size were updated, the README records mixed-build provenance, all ten PNG/profile/checksum
checks pass, and the twelve-file ZIP passes integrity verification. The original package is superseded.
Private evidence is under `.capture/website-recapture-20261104/home-indicator-revision/`.
The revision's task-created simulator and testing clones were removed. No commit or publication.

## Revision 3 — no home indicator in any screenshot

The owner also rejected `reading-ja-light.png`, then clarified: no home indicator in any delivered
screenshot, including readers with visible controls. The capture root now installs a DEBUG-only
`captureSystemOverlayVisibility` environment preference and requests hidden persistent system
overlays. Presented readers honor that preference ahead of their normal control-dependent policy.
Ordinary launches, including Release, retain their existing behavior.

All ten coordinates were regenerated from source based on `33dbf648b` plus this capture policy.
The Simulator build passed and strict no-cache lint found zero violations in the changed Swift files.
All ten accepted native captures passed their content/readiness checks. Visual inspection of every
bottom edge confirms the indicator is absent, including `reading-ja-light.png` with controls shown.

The first dark English reader frame retained a transient indicator even though two consecutive
screenshots agreed. It was rejected. Native screenshot settlement now requires three consecutive
unchanged one-second intervals, allowing delayed system chrome to finish fading. A new build passed;
the replacement dark English capture passed and its bottom edge was inspected separately. Failed or
rejected frames are excluded from the delivery; raw evidence is preserved.

The six final Live Text images have identical RGB pixels to revision 2. Reader central page content
remains identical to the preceding captures and across light/dark pairs. The required fade remains
visible, every reader says 6 / 80, and Live Text stays on page 12. The source-gallery mapping is unchanged.

Delivery: `ehpanda-screenshot-source-20261104-r3/` and its ZIP in the current chat's visualization output.
Exactly ten 1260 × 2736 RGB PNGs, no alpha, standard sRGB IEC61966-2.1 profile, manifest and README.
All file sizes, SHA-256 checksums and ZIP integrity were verified. Metadata normalization preserves
every rendered RGB pixel. The original package and revision 2 are superseded, retained as history.

Private evidence is under `.capture/website-recapture-20261104/reader-indicator-revision/`, including
the rejected dark frame and its independently accepted replacement. The task-created simulator and
testing clones were removed after capture. No website publication.
