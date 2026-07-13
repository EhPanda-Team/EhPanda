# Deferred Items

- `AppPackage/Sources/TestingSupport/HTMLFilename.swift`: the DownloadsFeatureTests build reports that
  `HTMLFilename` is not `Sendable` when used by the `Sendable` `TestError` enum. This warning predates
  Plan 05-02 and is unrelated to orientation-lock removal, so it remains out of scope.
- `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift`: `DownloadButton` is implemented as
  `Text` with tap and long-press gestures instead of a native `Button`, so it does not expose button or
  disabled semantics to assistive technologies. This predates Plan 05-05's size-class-only edit and is
  deferred to a behavior-scoped accessibility change.
