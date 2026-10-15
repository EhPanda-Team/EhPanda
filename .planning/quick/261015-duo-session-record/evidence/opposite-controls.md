> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/opposite-controls`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Opposite-side reader controls

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Verified on 2026-10-15.

- The move button is centered in the half opposite the slider and matches the slider row's height (at least 44 points).
- Slider and iPad lower Close move together with a 0.35-second smooth animation. The lower Close remains centered above the slider. Duo landscape retains only its side-toolbar Close; existing portrait and closed-cover behavior is unchanged.
- Physical positioning is independent of interface text direction; content keeps its inherited direction. Stable slider identity preserves its gesture state.
- Warning-free build-for-testing completed in 24.362 seconds (`build.log`). SwiftLint and `git diff --check` passed.
- Four focused UI tests passed: Duo posture transitions (44.843 seconds), Duo RTL (19.337 seconds), Duo move/rotation (39.095 seconds), and iPad move/rotation with lower Close assertions (42.248 seconds).
- `ipad-animation.mp4` records the actual transition at 60 fps. The intermediate frame at 0.85 seconds shows the slider and Close between their starting and final positions. Synthetic placeholder pages are intentional.
- The iPad initially had Reduce Motion enabled. The first recording confirmed immediate repositioning. It was temporarily disabled to record the animation, then restored. App accessibility inspection was also restored to its original disabled preference.
- Both simulators were relaunched without EHPANDA test environment flags. iPad remains in landscape; Duo was returned to closed portrait. No Device Hub was used for this change.

The UI checks cover geometry, reachability, labels, button height, rotation retention and close-button placement. A complete manual VoiceOver audit was not performed.
