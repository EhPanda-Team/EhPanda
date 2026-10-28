# Release size optimization

Both release workflows archive with `-xcconfig Config/SizeOptimization.xcconfig`. That build-wide
override applies `-Osize` to the app, extension and source-built Swift packages, including third-party
packages. Its assignment is conditional on Release; Debug keeps `-Onone`.

The Xcode project and local package also select `-Osize` for their own Release targets. Those local
settings alone do not change third-party package compilation. Use the shared override for comparable
local archives:

```sh
xcodebuild archive \
  -project EhPanda.xcodeproj -scheme EhPanda -configuration Release \
  -xcconfig Config/SizeOptimization.xcconfig \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/EhPanda.xcarchive
```

For an unsigned size-only measurement, add `CODE_SIGNING_ALLOWED=NO`. An ordinary Archive action
inside Xcode does not supply this command-line override; use the command above when comparing the
full package graph. Do not place this configuration in application resources.

The measured 2026-10-28 unsigned arm64 payload is 29,793,340 bytes, compared with 33,989,732 bytes
before these changes. This is an unthinned archive measurement. A signed export's App Thinning Size
Report and a device installation answer different size questions. See the
[measurement and optional follow-ups](../.planning/quick/261028-hi0-adopt-native-bottom-bars-enforce-paralle/SIZE-REDUCTION.md).
