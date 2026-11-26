---
date: "2026-11-26T09:00:00Z"
promoted: true
promoted_to: ".planning/quick/261126-iq9-fix-the-findings-and-release-a-new-beta-/"
---

# Webtoon detection samples the middle pages: done in quick 261126-iq9

Source: owner, 2026-11-26. Owner direction: record the recommended fix option. Implemented 2026-11-26 in quick 261126-iq9.

## Problem

With "Always read webtoons vertically" on, https://e-hentai.org/g/4354007/62c2a4692c/ (26 pages) opened at page 1
is not detected as a webtoon. The reader samples pages 1, 2 and 3 (D-04 in quick task 261122-317), and the cover,
page 1, is 797 x 1895 (ratio 2.38), below the 2.5 threshold (D-05). Pages 2 onwards are 5 to 25 times as tall as
wide. The negative verdict is then recorded in the browsing history (D-07), so the gallery is never checked again.

The rule is what fails: it judges a gallery by the pages next to where the reader happens to be, so a cover, a
title page or an end-credits page decides the verdict.

## Recorded fix (the recommended option)

1. **Sample the middle of the gallery, not the current page.** The three sampled pages are the middle three:
   `m-1, m, m+1` with `m = (pageCount + 1) / 2` (for 26 pages: 12, 13, 14, ratios 23.0, 15.8 and 24.0). The
   threshold (2.5) and the all-three rule (D-05) stay. Galleries with fewer than three pages are still never
   detected.
2. **Fetch the middle three pages' addresses when the gallery opens.** At page 1 the reader has not fetched the
   middle pages, so their sizes are unknown. The reader requests those three pages' image addresses when it opens
   a gallery that has no recorded verdict. The sizes come from the served URL's file identifier, the same
   known-size source the reader already uses (`KnownPageSize` / `State.pageSizes`); no new size source. The fetched
   addresses are kept, so those pages are ready if the user reads that far. This supersedes D-04 and the
   "no extra fetching" part of D-06 when implemented; D-06's switch-with-a-toast still applies when the verdict
   arrives after the gallery is already showing.
3. **Re-check verdicts saved under the old rule.** A "not a webtoon" verdict recorded by the current-page rule is
   checked again once with the middle-page rule, so galleries like 4354007 recover without clearing the history.
   Positive verdicts stay.

## Rejected alternatives

- Middle pages only when their sizes are already known (multi-page viewer sizes), otherwise wait until the user
  reaches the middle: no extra requests, but most galleries would switch late or halfway through.
- Keep sampling near the current page but leave page 1 out: no extra requests, but it fixes covers only, not
  title or end pages elsewhere.

## Where

- `AppPackage/Sources/ReadingFeature/ReadingReducer+Webtoon.swift` (`webtoonSamplePages(around:pageCount:)`,
  `webtoonVerdictFromKnownSizes`)
- Decisions D-04 to D-07: `.planning/quick/261122-317-port-462-item-9-always-read-webtoons-ver/261122-317-CONTEXT.md`

## Open for planning

- How an old-rule negative verdict is told apart from a new one (the stored field is an optional `Bool` on
  `GalleryHistoryEntry` today).
- What happens when the address fetch fails (retry policy, and whether a failure records no verdict).
