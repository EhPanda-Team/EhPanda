# Gallery rating display

Owner request (2026-11-02): fix the Gallery Info ratings, where an average of 4.5 read as 4. Tracing the value found
three separate faults, because fixing the display alone would still have shown the wrong average.

## Changes

| Where | Before | After | Commit |
| --- | --- | --- | --- |
| Detail parser | An unrated gallery took its average from the star image, which rounds to a half star, so the site's 4.74 became 4.5. | Takes the site's average label. The star image is the fallback only while it still shows the average. | `4e20599d6` |
| Gallery Info, Average Rating and My Rating | Truncated to a whole number. | Two decimals for the average, as on the Detail page, and one for the user's half-star rating. | `cc273e99e` |
| Rating control on Detail | A 3.5-star rating reopened as 3 stars. | Reopens as 3.5 stars. | `556b53a0c` |

The parser change also corrects the large rating on the Detail page, which read 4.50 for the same gallery. Lists, cards
and rows round to a half star themselves, so they look the same. A new capture of the Detail page will show the
fixture's 4.74 rather than 4.50.

## Verification

- `FeatureTests` without `VisualSnapshotTests`: 1,398 tests, 1,389 passed, 9 expected failures, 0 failed.
- New tests cover the average with and without a user rating, the fallback when the label is missing, and the half-star
  control. The fixture's Gallery Info row reads 4.74 in `testGalleryInfoAudit` on iPhone and iPad.
- SwiftLint reports no violations.

Not verified: the live site was not checked, so the label comes from the saved fixtures. No fixture has a user rating
that reaches the screen, so the My Rating row was not seen rendered with a half star.

One earlier full run had an unrelated timeout in
`DownloadContinuedSessionExpirationTests.testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession`, with the
machine's load average near 200. The test passed in the next full run and in 10 of 10 runs alone, so this reads as load,
but the cause was not proven.

## File size

The owner then asked for the File Size row on the same screen, which also truncated and had no space before its unit:
the fixture's 314.3 MiB read 314MiB. It now reads 314.3 MiB (`04fb7c986`).

Gallery Info and the Detail page's strip now share one format, to at most two decimals. The strip therefore also follows
the reader's number format, so German reads 314,3 rather than 314.3, and a whole size drops its `.0`.

- `FeatureTests` without `VisualSnapshotTests`, rerun with this change: 1,399 tests, 1,390 passed, 9 expected failures,
  0 failed, and no test passed only on a retry.
- `testGalleryInfoAudit` passes on iPhone and iPad and reads the row's VoiceOver value, 314.3 mebibytes.
- Gallery Info and the Detail strip were read on an iPhone Air screen in English and German: 314.3 MiB and 4.74, then
  314,3 MiB and 4,74.
