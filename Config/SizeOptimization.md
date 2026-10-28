# Release optimization policy

The owner prioritizes runtime speed. The build-wide `-Osize` change has been dropped from the
branch; `SizeOptimization.xcconfig` no longer exists. Project Release settings and both deployment
workflows use `-O`. The local package has no custom optimization override, so it uses the normal
Release optimization. Debug retains `-Onone`; whole-module Release compilation remains enabled.

Preview-only helpers and their frozen identifiers remain excluded from Release. No runtime feature
or asset was removed. For a comparable local unsigned archive:

```sh
xcodebuild archive \
  -project EhPanda.xcodeproj -scheme EhPanda -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/EhPanda.xcarchive \
  SWIFT_OPTIMIZATION_LEVEL=-O CODE_SIGNING_ALLOWED=NO
```

The earlier 29,793,340-byte payload used the withdrawn `-Osize` configuration. The current `-O` plus
preview-cleanup payload has not been remeasured. Archive payload, installed-device footprint and
App Store download size remain separate measurements. See the
[decision and verification](../.planning/quick/261028-hi0-adopt-native-bottom-bars-enforce-paralle/SPEED-PRIORITY.md)
and [historical measurements](../.planning/quick/261028-hi0-adopt-native-bottom-bars-enforce-paralle/SIZE-REDUCTION.md).
