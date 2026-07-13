# Deferred Items

- `AppPackage/Sources/TestingSupport/HTMLFilename.swift`: the DownloadsFeatureTests build reports that
  `HTMLFilename` is not `Sendable` when used by the `Sendable` `TestError` enum. This warning predates
  Plan 05-02 and is unrelated to orientation-lock removal, so it remains out of scope.
