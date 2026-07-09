# Technology Stack

**Analysis Date:** 2026-07-09

## Languages

**Primary:**
- Swift (Swift 6 mode, tools version 6.3.1) - All app and package code across `App/`, `AppPackage/Sources/`, and `ShareExtension/`

**Secondary:**
- C/C++/Objective-C - Only transitively via dependencies (SwiftyOpenCC, Kanna); no first-party C code detected
- HTML/CSS parsing targets - E-Hentai pages parsed via Kanna in `AppPackage/Sources/ParserFeature`

## Runtime

**Environment:**
- iOS / iPadOS 26.0 minimum (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, package `platforms: [.iOS(.v26)]`)
- App marketing version: 3.0.0 (`MARKETING_VERSION` in `EhPanda.xcodeproj/project.pbxproj`)

**Package Manager:**
- Swift Package Manager (local package `AppPackage`, declared as `XCLocalSwiftPackageReference` in the Xcode project)
- Lockfile: `AppPackage/Package.resolved` (present; `swift package resolve` regenerates it)
- All third-party dependencies are declared in `AppPackage/Package.swift`, never in the Xcode project
- Note: root `package.json` / `package-lock.json` / `node_modules/` exist but are tooling-only (agent skills), not part of the app build

## Frameworks

**Core:**
- ComposableArchitecture (TCA) `1.25.0+` - App architecture / reducers (`swift-composable-architecture`)
- swift-case-paths `1.7.0+` - Enum ergonomics for TCA (`CasePaths`)
- swift-sharing `2.0.0+` - `@Shared` / `@SharedReader` persistence layer (replaces former Core Data)
- SwiftUI / UIKit - Apple UI frameworks (implicit, not in Package.swift)

**Testing:**
- Swift Testing - Test framework used across `AppPackage/Tests/*` (see TESTING.md)
- Test plan: `AppPackage/Tests/FeatureTests.xctestplan`

**Build/Dev:**
- SwiftLintPlugins `0.63.0+` (`SimplyDanny/SwiftLintPlugins`) - Build-tool plugin attached to every target; root config `.swiftlint.yml`
- Xcode project `EhPanda.xcodeproj` with `AppPackage-Package` scheme for tests

## Key Dependencies

**Critical:**
- Kingfisher `8.0.0+` - Primary async image loading/caching (`onevcat/Kingfisher`)
- SDWebImageSwiftUI `3.0.0+` + SDWebImageWebPCoder `0.14.0+` - Animated image rendering + WebP decode; paired with Kingfisher (dual image stack is deliberate: KF primary, SD renders animated)
- Kanna `6.0.0+` - HTML/XML parsing of E-Hentai pages (`tid-kijyun/Kanna`)
- DeprecatedAPI (`EhPanda-Team/DeprecatedAPI`, `main` branch) - First-party shim for deprecated Apple APIs still needed

**Infrastructure / UI:**
- SwiftUIPager `2.5.0+` - Paged reading view (`fermoya/SwiftUIPager`)
- WaterfallGrid `1.0.0+` - Gallery grid layout (`paololeonardi/WaterfallGrid`)
- SwiftyOpenCC `2.0.0-beta` (exact pin) - Simplified/Traditional Chinese conversion for tag translation (`ddddxxx/SwiftyOpenCC`)
- SwiftCommonMark `1.0.0+` - Markdown rendering (`gonzalezreal/SwiftCommonMark`)
- SFSafeSymbols `7.0.0+` - Type-safe SF Symbols (`SFSafeSymbols/SFSafeSymbols`)
- UIImageColors `2.2.0+` - Dominant-color extraction for gallery theming (`jathu/UIImageColors`)
- Colorful `1.0.1` (upToNextMinor pin; 1.1.x deprecates ColorfulView) - Animated gradient backgrounds (`Co2333/Colorful`)

## Configuration

**Environment:**
- No `.env` files present; app uses no server-side secret config
- Session state (login) is stored via `HTTPCookie` handling in `AppPackage/Sources/CookieClient/CookieClient.swift`
- Light data persisted through swift-sharing `@Shared` (no `fileStorage`, no database) per the persistence refactor
- Background task identifier declared in `App/Info.plist`: `app.ehpanda.downloads.processing` under `BGTaskSchedulerPermittedIdentifiers`

**Build:**
- `AppPackage/Package.swift` - Single source of truth for modules, dependencies, resources
- `.swiftlint.yml` (root) + per-module `.swiftlint.yml` (`parent_config` chained)
- Swift upcoming features enabled package-wide: `InferIsolatedConformances`, `NonisolatedNonsendingByDefault` (matches app target's Approachable Concurrency)
- App entitlements: `App/EhPanda.entitlements` (currently empty dict)

## Platform Requirements

**Development:**
- Xcode toolchain supporting Swift 6.3.1 tools version and iOS 26 SDK
- Build/test via Xcode only (`xcodebuild`); bare `swift build` fails for this project
- SwiftLint runs as a build-tool plugin (no separate PATH install needed for builds)

**Production:**
- Distributed as sideloaded `.ipa` (AltStore); not on the App Store. See `AltStore.json` and README.
- Requires iOS / iPadOS 26.0 or later on device

---

*Stack analysis: 2026-07-09*
