---
status: complete
quick_id: 261126-trf
date: 2026-11-26
commit: ad9050e94
---

# Quick 261126-trf summary: passive webtoon detection

## What changed

- `ReadingReducer+Webtoon.swift`: `pendingWebtoonVerdict` decides what to record after every action. The passive rule
  `mostKnownPagesAreExtremelyTall` (more than two thirds of the known pages at a ratio of at least 2.5, over at least
  three known pages) comes first and also overturns a recorded "not a webtoon"; otherwise an unchecked gallery takes
  the middle sample's verdict as before. A webtoon is final. The open-time middle-page fetch is unchanged and still
  asks only while the verdict is `nil`. `isExtremelyTall` is shared by both rules.
- Doc comments of `ReadingReducer.State.isWebtoon` and `GalleryHistoryEntry.isWebtoon` say that `false` is no longer
  final. No schema change.
- `WebtoonReadingTests`: the old "a recorded verdict is not checked again" case is replaced by "a recorded no-webtoon
  is turned by the pages read" and "a recorded webtoon is never turned back"; new cases cover more than, exactly and
  fewer than the threshold, a short middle page overturned page by page with the toast, and the option off.

## Verification

- `ReadingFeatureTests`: 347 passed, 0 failed, 0 warnings (FeatureTests plan, EhPanda iPhone Air (phase19)).
- SwiftLint `--strict` clean on the changed source and test trees.

## Owner device check

- With the option on, read a gallery whose middle pages include a short image: once more than two thirds of the
  known pages are tall, it turns vertical with the toast, and stays vertical when reopened.
