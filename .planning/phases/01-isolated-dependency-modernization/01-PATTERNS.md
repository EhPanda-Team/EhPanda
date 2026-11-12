# Phase 01: isolated-dependency-modernization - Pattern Map

**Mapped:** 2026-07-10
**Files analyzed:** 28 files/module families
**Analogs found:** 25 / 28

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `AppPackage/Package.swift` | config | transform | `AppPackage/Package.swift` | exact |
| `AppPackage/Package.resolved` | config | transform | `AppPackage/Package.resolved` | exact |
| `AppPackage/Sources/SwiftyOpenCC/.swiftlint.yml` | config | transform | `AppPackage/Sources/SystemNotificationExt/.swiftlint.yml` | exact |
| `AppPackage/Sources/SwiftyOpenCC/**` | utility/module | transform, file-I/O | `AppPackage/Sources/OpenCCExt/TagTranslation+ChtConverted.swift` | partial |
| `AppPackage/Tests/SwiftyOpenCCTests/.swiftlint.yml` | config | transform | `AppPackage/Tests/NetworkingFeatureTests/.swiftlint.yml` | exact |
| `AppPackage/Tests/SwiftyOpenCCTests/**` | test | transform | `AppPackage/Tests/FileClientTests/FileClientTests.swift` | role-match |
| `AppPackage/Sources/OpenCCExt/TagTranslation+ChtConverted.swift` | utility | transform | same file | exact |
| `AppPackage/Sources/FileClient/FileClient.swift` | service/client | file-I/O, transform | same file | exact |
| `AppPackage/Sources/UIImageColors/.swiftlint.yml` | config | transform | `AppPackage/Sources/SystemNotificationExt/.swiftlint.yml` | exact |
| `AppPackage/Sources/UIImageColors/**` | utility/module | transform | `AppPackage/Sources/LibraryClient/LibraryClient.swift` | partial |
| `AppPackage/Tests/UIImageColorsTests/**` | test | transform | `AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingTests.swift` | role-match |
| `AppPackage/Sources/LibraryClient/LibraryClient.swift` | service/client | async transform | same file | exact |
| `AppPackage/Sources/MarkdownExt/.swiftlint.yml` | config | transform | `AppPackage/Sources/SystemNotificationExt/.swiftlint.yml` | exact |
| `AppPackage/Sources/MarkdownExt/MarkdownUtil.swift` | utility/module | transform | `AppPackage/Sources/CommonMarkExt/MarkdownUtil.swift` | role-match |
| `AppPackage/Sources/CommonMarkExt/MarkdownUtil.swift` | utility/module | transform | same file | exact |
| `AppPackage/Tests/MarkdownExtTests/**` | test | transform | `AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataDecodeTests.swift` | role-match |
| `AppPackage/Sources/TagTranslationFeature/TagTranslation+Markdown.swift` | utility | transform | same file | exact |
| `AppPackage/Tests/TagTranslationFeatureTests/**` | test | transform | `AppPackage/Tests/FileClientTests/FileClientTests.swift` | role-match |
| `AppPackage/Sources/DetailFeature/DetailView.swift` | component | request-response UI | same file | exact |
| `AppPackage/Sources/NetworkingFeature/DFExtensions.swift` | utility | request-response, streaming | same file | exact |
| `AppPackage/Sources/NetworkingFeature/DFRequest.swift` | service | streaming, request-response | same file | exact |
| `AppPackage/Sources/NetworkingFeature/DFStreamHandler.swift` | service | streaming, event-driven | same file | exact |
| `AppPackage/Sources/NetworkingFeature/DFURLProtocol.swift` | middleware | request-response, streaming | same file | exact |
| `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` | test | request-response | `AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataDecodeTests.swift` | role-match |
| `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` | component | event-driven UI | same file | exact |
| `AppPackage/Sources/HomeFeature/HomeReducer.swift` | store/reducer | event-driven | same file | exact |
| `AppPackage/Sources/HomeFeature/HomeReducer+Body.swift` | store/reducer | event-driven, async transform | same file | exact |
| `AppPackage/Tests/FeatureTests.xctestplan` | config | batch | same file | exact |

## Pattern Assignments

### `AppPackage/Package.swift` (config, transform)

**Analog:** `AppPackage/Package.swift`

**Dependency list pattern** (lines 5-27):
```swift
// MARK: Dependency
var dependencies: [PackageDescription.Package.Dependency] = [
    // Pinned to match the app's resolved version; 1.1.x deprecates ColorfulView.
    .package(url: "https://github.com/Co2333/Colorful", .upToNextMinor(from: "1.0.1")),
    .package(url: "https://github.com/EhPanda-Team/DeprecatedAPI", branch: "main"),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "3.0.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageWebPCoder", from: "0.14.0"),
    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.0"),
    .package(url: "https://github.com/ddddxxx/SwiftyOpenCC", exact: "2.0.0-beta"),
    .package(url: "https://github.com/fermoya/SwiftUIPager", from: "2.5.0"),
    .package(url: "https://github.com/gonzalezreal/SwiftCommonMark", from: "1.0.0"),
    .package(url: "https://github.com/jathu/UIImageColors", from: "2.2.0"),
    .package(url: "https://github.com/onevcat/Kingfisher", from: "8.0.0"),
    .package(url: "https://github.com/paololeonardi/WaterfallGrid", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.7.0"),
    .package(
        url: "https://github.com/pointfreeco/swift-composable-architecture",
        from: "1.25.0"
    ),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
    .package(url: "https://github.com/tid-kijyun/Kanna", from: "6.0.0")
]
```

**Target dependency helper pattern** (lines 29-48):
```swift
extension PackageDescription.Target.Dependency {
    static let casePaths: Self = .product(name: "CasePaths", package: "swift-case-paths")
    static let colorful: Self = .product(name: "Colorful", package: "Colorful")
    static let commonMark: Self = .product(name: "CommonMark", package: "SwiftCommonMark")
    static let composableArchitecture: Self = .product(
        name: "ComposableArchitecture",
        package: "swift-composable-architecture"
    )
    static let deprecatedAPI: Self = .product(name: "DeprecatedAPI", package: "DeprecatedAPI")
    static let kanna: Self = .product(name: "Kanna", package: "Kanna")
    static let kingfisher: Self = .product(name: "Kingfisher", package: "Kingfisher")
    static let openCC: Self = .product(name: "OpenCC", package: "SwiftyOpenCC")
    static let sdWebImageSwiftUI: Self = .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI")
    static let sdWebImageWebPCoder: Self = .product(name: "SDWebImageWebPCoder", package: "SDWebImageWebPCoder")
    static let sfSafeSymbols: Self = .product(name: "SFSafeSymbols", package: "SFSafeSymbols")
    static let sharing: Self = .product(name: "Sharing", package: "swift-sharing")
    static let swiftUIPager: Self = .product(name: "SwiftUIPager", package: "SwiftUIPager")
    static let uiImageColors: Self = .product(name: "UIImageColors", package: "UIImageColors")
    static let waterfallGrid: Self = .product(name: "WaterfallGrid", package: "WaterfallGrid")
}
```

**Module enum pattern** (lines 61-118):
```swift
// MARK: Module
enum Module: String {
    case animatedImageFeature = "AnimatedImageFeature"
    case appComponents = "AppComponents"
    case appDelegateClient = "AppDelegateClient"
    case appFeature = "AppFeature"
    case appLaunchAutomationClient = "AppLaunchAutomationClient"
    case appModels = "AppModels"
    case appTools = "AppTools"
    case applicationClient = "ApplicationClient"
    case authorizationClient = "AuthorizationClient"
    case backgroundProcessingClient = "BackgroundProcessingClient"
    case clipboardClient = "ClipboardClient"
    case commonMarkExt = "CommonMarkExt"
    ...
    // Test targets
    case parserFeatureTests = "ParserFeatureTests"
    case downloadsFeatureTests = "DownloadsFeatureTests"
    case fileClientTests = "FileClientTests"
    case settingFeatureTests = "SettingFeatureTests"
    case detailFeatureTests = "DetailFeatureTests"
    case networkingFeatureTests = "NetworkingFeatureTests"
    case appModelsTests = "AppModelsTests"
}
```

**Target helper pattern** (lines 181-244):
```swift
extension PackageDescription.Target {
    static func target(
        module: Module,
        dependencies: [Module.Dependency] = .init(),
        path: String? = nil,
        exclude: [Exclude] = .init(),
        sources: [String]? = nil,
        resources: [Resource]? = nil,
        publicHeadersPath: String? = nil,
        packageAccess: Bool = true,
        cSettings: [PackageDescription.CSetting]? = nil,
        cxxSettings: [PackageDescription.CXXSetting]? = nil,
        swiftSettings: [PackageDescription.SwiftSetting]? = sharedSwiftSettings,
        linkerSettings: [PackageDescription.LinkerSetting]? = nil,
        plugins: [PackageDescription.Target.PluginUsage]? = nil
    ) -> PackageDescription.Target {
        target(
            name: module.rawValue,
            dependencies: dependencies.map(\.targetDependency),
            path: path,
            exclude: exclude.map(\.name),
            sources: sources,
            resources: resources?.map(\.value),
            publicHeadersPath: publicHeadersPath,
            packageAccess: packageAccess,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings,
            plugins: plugins
        )
    }

    static func testTarget(
        module: Module,
        dependencies: [Module.Dependency] = .init(),
        path: String? = nil,
        exclude: [Exclude] = .init(),
        sources: [String]? = nil,
        resources: [Resource]? = nil,
        packageAccess: Bool = true,
        cSettings: [PackageDescription.CSetting]? = nil,
        cxxSettings: [PackageDescription.CXXSetting]? = nil,
        swiftSettings: [PackageDescription.SwiftSetting]? = sharedSwiftSettings,
        linkerSettings: [PackageDescription.LinkerSetting]? = nil,
        plugins: [PackageDescription.Target.PluginUsage]? = nil
    ) -> PackageDescription.Target {
        testTarget(
            name: module.rawValue,
            dependencies: dependencies.map(\.targetDependency),
            path: path,
            exclude: exclude.map(\.name),
            sources: sources,
            resources: resources?.map(\.value),
            packageAccess: packageAccess,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings,
            plugins: plugins
        )
    }
}
```

**Existing extension-module target pattern** (lines 491-513):
```swift
.target(
    module: .commonMarkExt,
    dependencies: [
        .targetDependency(.casePaths),
        .targetDependency(.commonMark)
    ],
    plugins: swiftLintPlugins
),
...
.target(
    module: .openCCExt,
    dependencies: [
        .module(.appModels),
        .targetDependency(.openCC)
    ],
    plugins: swiftLintPlugins
),
```

**Existing client dependency pattern** (lines 787-799):
```swift
.target(
    module: .libraryClient,
    dependencies: [
        .module(.appModels),
        .module(.animatedImageFeature),
        .module(.appTools),
        .targetDependency(.composableArchitecture),
        .targetDependency(.kingfisher),
        .targetDependency(.sdWebImageSwiftUI),
        .targetDependency(.sdWebImageWebPCoder),
        .targetDependency(.uiImageColors)
    ],
    plugins: swiftLintPlugins
),
```

**Test target pattern** (lines 895-934):
```swift
.testTarget(
    module: .fileClientTests,
    dependencies: [
        .module(.appModels),
        .module(.fileClient)
    ],
    plugins: swiftLintPlugins
),
...
.testTarget(
    module: .networkingFeatureTests,
    dependencies: [
        .module(.appModels),
        .module(.networkingFeature)
    ],
    plugins: swiftLintPlugins
),
```

**Planner note:** Add/remove package dependencies through `dependencies`, `Target.Dependency` helpers, `Module` cases, and target declarations. Do not add ad hoc string literals when the helper enums can express the relationship. New test targets also need `FeatureTests.xctestplan` entries.

---

### Local module `.swiftlint.yml` files (config, transform)

**Analog:** `AppPackage/Sources/SystemNotificationExt/.swiftlint.yml`

**Source module lint config** (line 1):
```yaml
parent_config: ../../../.swiftlint.yml
```

**Analog:** `AppPackage/Tests/NetworkingFeatureTests/.swiftlint.yml`

**Test module lint config** (line 1):
```yaml
parent_config: ../../../.swiftlint.yml
```

**Apply to:** `AppPackage/Sources/SwiftyOpenCC/.swiftlint.yml`, `AppPackage/Sources/UIImageColors/.swiftlint.yml`, `AppPackage/Sources/MarkdownExt/.swiftlint.yml`, and any new test target `.swiftlint.yml` under `AppPackage/Tests`.

---

### `AppPackage/Sources/SwiftyOpenCC/**` (utility/module, transform + file-I/O)

**Closest analog:** `AppPackage/Sources/OpenCCExt/TagTranslation+ChtConverted.swift`

**Current import and conversion seam** (lines 1-35):
```swift
import AppModels
import Foundation
import OpenCC

extension Dictionary where Value == TagTranslation {
    public var chtConverted: Self {
        func customConversion(text: String) -> String {
            switch text {
            case "full color":
                return "全彩"
            default:
                return text
            }
        }

        guard let preferredLanguage = Locale.preferredLanguages.first else { return self }

        var options: ChineseConverter.Options = [.traditionalize]
        if preferredLanguage.contains("HK") {
            options = [.traditionalize, .hkStandard]
        } else if preferredLanguage.contains("TW") {
            options = [.traditionalize, .twStandard, .twIdiom]
        }

        guard let converter = try? ChineseConverter(options: options) else { return self }
        var dictionary = self
        dictionary.forEach { (key, value) in
            dictionary[key] = TagTranslation(
                namespace: value.namespace, key: value.key,
                value: customConversion(text: converter.convert(value.value)),
                description: value.description, linksString: value.linksString
            )
        }
        return dictionary
    }
}
```

**Current FileClient integration** (lines 32-44):
```swift
// Decode raw DB JSON → flatten → OpenCC-convert for Traditional Chinese. `nil` if empty/undecodable.
private func decodeTranslations(
    _ data: Data, applyingChtFor language: TranslatableLanguage?
) -> [String: TagTranslation]? {
    guard var translations = try? JSONDecoder()
        .decode(EhTagTranslationDatabaseResponse.self, from: data).tagTranslations,
          !translations.isEmpty
    else { return nil }
    if language == .traditionalChinese {
        translations = translations.chtConverted
    }
    return translations
}
```

**Language selection support** (from `AppPackage/Sources/AppModels/Tags/TranslatableLanguage.swift`, lines 10-29):
```swift
extension TranslatableLanguage {
    public static var current: TranslatableLanguage? {
        guard let preferredLanguage = Locale.preferredLanguages.first,
              let translatableLanguage = TranslatableLanguage.allCases.compactMap({ lang in
                preferredLanguage.contains(lang.languageCode) ? lang : nil
              }).first else { return nil }
        return translatableLanguage
    }
    public var languageCode: String {
        switch self {
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }
}
```

**Tag translation value shape** (from `AppPackage/Sources/AppModels/Tags/TagTranslation.swift`, lines 3-21):
```swift
public struct TagTranslation: Codable, Equatable, Hashable, Sendable {
    public init(
        namespace: TagNamespace,
        key: String,
        value: String,
        description: String? = nil,
        linksString: String? = nil
    ) {
        self.namespace = namespace
        self.key = key
        self.value = value
        self.description = description
        self.linksString = linksString
    }
    public let namespace: TagNamespace
    public let key: String
    public let value: String
    public var description: String?
    public var linksString: String?
}
```

**Planner note:** The app needs the `ChineseConverter` behavior and options above, plus `"full color" -> "全彩"` parity. The local implementation internals have no strong first-party analog; keep the public app-facing seam narrow and test conversion through app fixtures before changing OpenCC dictionaries or internals.

---

### `AppPackage/Sources/FileClient/FileClient.swift` (service/client, file-I/O + transform)

**Analog:** `AppPackage/Sources/FileClient/FileClient.swift`

**Client shape and side-effect closures** (lines 6-19):
```swift
public struct FileClient: Sendable {
    public var createFile: @Sendable (String, Data?) -> Bool
    public var importTagTranslator: @Sendable (URL) async -> Result<TagTranslator, AppError>
    /// Decodes the raw downloaded DB JSON, applies OpenCC conversion for Traditional Chinese, caches
    /// the raw bytes for a launch-time rebuild, and returns the built translator (`nil` on decode
    /// failure). The raw file — not the converted dictionary — is what persists.
    public var cacheAndBuildRemoteTagTranslator: @Sendable (Data, TranslatableLanguage, Date) -> TagTranslator?
    /// Rebuilds the in-memory translator from the cached raw JSON described by `info` — Application
    /// Support for a custom import, Caches for a remote download. `nil` if the cache is missing.
    public var loadCachedTagTranslator: @Sendable (TagTranslatorInfo) -> TagTranslator?
    /// Deletes the imported custom-translations file from Application Support. That directory is not
    /// purgeable, so a removed import must be cleaned up explicitly rather than left on disk forever.
    public var removeCustomTranslations: @Sendable () -> Void
}
```

**Live file-cache pattern** (lines 84-107):
```swift
cacheAndBuildRemoteTagTranslator: { data, language, date in
    guard let translations = decodeTranslations(data, applyingChtFor: language) else { return nil }
    writeTranslations(data, to: remoteTranslationsURL(language))
    return TagTranslator(language: language, updatedDate: date, translations: translations)
},
loadCachedTagTranslator: { info in
    if info.hasCustomTranslations {
        guard let data = try? Data(contentsOf: customTranslationsURL),
              let translations = decodeTranslations(data, applyingChtFor: nil)
        else { return nil }
        return TagTranslator(hasCustomTranslations: true, translations: translations)
    }
    guard let language = info.language,
          let data = try? Data(contentsOf: remoteTranslationsURL(language)),
          let translations = decodeTranslations(data, applyingChtFor: language)
    else { return nil }
    return TagTranslator(
        language: language, updatedDate: info.updatedDate, translations: translations
    )
},
removeCustomTranslations: {
    try? FileManager.default.removeItem(at: customTranslationsURL)
}
```

**Dependency API/test fallback pattern** (lines 115-148):
```swift
public enum FileClientKey: DependencyKey {
    public static let liveValue = FileClient.live
    public static let previewValue = FileClient.noop
    public static let testValue = FileClient.unimplemented
}

extension DependencyValues {
    public var fileClient: FileClient {
        get { self[FileClientKey.self] }
        set { self[FileClientKey.self] = newValue }
    }
}

// MARK: Test
extension FileClient {
    public static let noop: Self = .init(
        createFile: { _, _ in false },
        importTagTranslator: { _ in .success(.init()) },
        cacheAndBuildRemoteTagTranslator: { _, _, _ in nil },
        loadCachedTagTranslator: { _ in nil },
        removeCustomTranslations: {}
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        createFile: IssueReporting.unimplemented(placeholder: placeholder()),
        importTagTranslator: IssueReporting.unimplemented(placeholder: placeholder()),
        cacheAndBuildRemoteTagTranslator: IssueReporting.unimplemented(placeholder: placeholder()),
        loadCachedTagTranslator: IssueReporting.unimplemented(placeholder: placeholder()),
        removeCustomTranslations: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
```

**Planner note:** If OpenCC conversion moves out of `OpenCCExt`, update `FileClient` imports and `decodeTranslations` only enough to preserve the existing cache/raw-data semantics.

---

### `AppPackage/Tests/SwiftyOpenCCTests/**` and `AppPackage/Tests/TagTranslationFeatureTests/**` (test, transform)

**Analog:** `AppPackage/Tests/FileClientTests/FileClientTests.swift`

**Imports and serialized suite pattern** (lines 1-11):
```swift
import Testing
import Foundation
import AppModels
import FileClient

// Exercises the live importer's coordinated, security-scoped read (REV-1) against local files;
// the iCloud download that coordination triggers is system behavior, smoke-tested manually.
// Serialized: the tag-translation cache/import endpoints write fixed paths in the real Caches and
// Application Support directories, so parallel cases would race on the same files.
@Suite(.serialized)
struct FileClientTests {
```

**Fixture/file cleanup pattern** (lines 52-68):
```swift
@Test
func cachesRemoteTableAndRebuildsItFromMetadata() throws {
    let language = TranslatableLanguage.english
    let cacheURL = URL.cachesDirectory.appending(component: language.cachedTranslationsFilename)
    defer { try? FileManager.default.removeItem(at: cacheURL) }

    let built = try #require(
        FileClient.live.cacheAndBuildRemoteTagTranslator(try sampleResponseData(), language, .distantPast)
    )
    #expect(built.language == language)
    #expect(built.translations.count == 1)
    #expect(FileManager.default.fileExists(atPath: cacheURL.path))

    // A launch-time rebuild restores the same table from the cached file the metadata points at.
    let rebuilt = try #require(FileClient.live.loadCachedTagTranslator(TagTranslatorInfo(language: language)))
    #expect(rebuilt.language == language)
    #expect(rebuilt.translations.count == 1)
}
```

**Planner note:** Build fixtures around Traditional/HK/TW option selection, `full color`, and FileClient decode/cache behavior. Keep direct test target dependencies minimal: the test target should depend on the module under test and required app model/support modules, not transitive implementation packages.

---

### `AppPackage/Sources/UIImageColors/**` (utility/module, transform)

**Closest analog:** `AppPackage/Sources/LibraryClient/LibraryClient.swift`

**Current app-facing color API use** (lines 13-21):
```swift
public struct LibraryClient: Sendable {
    public let initializeWebImage: @Sendable () -> Void
    public let removeAllCachedImages: @Sendable () async -> Void
    public let cachedImage: @Sendable (String) async -> UIImage?
    public let cachedImageData: @Sendable (String) async -> Data?
    public let removeCachedImage: @Sendable (String) async -> Void
    public let isCached: @Sendable (String) -> Bool
    public let analyzeImageColors: @Sendable (UIImage) async -> [Color]?
    public let calculateWebImageDiskCacheSize: @Sendable () async -> UInt?
```

**Async wrapper around `getColors(quality:)`** (lines 107-121):
```swift
analyzeImageColors: { image in
    await withCheckedContinuation { continuation in
        image.getColors(quality: .lowest) { colors in
            continuation.resume(
                returning: colors.map {
                    [
                        $0.primary, $0.secondary,
                        $0.detail, $0.background
                    ]
                    .map(Color.init)
                }
            )
        }
    }
},
```

**Color serialization pattern for deterministic assertions** (from `AppPackage/Sources/AppTools/ColorCodable.swift`, lines 17-37):
```swift
struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

var colorComponents: RGBA? {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    #if os(macOS)
    SystemColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    #else
    guard SystemColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    #endif

    return RGBA(red: red, green: green, blue: blue, alpha: alpha)
}
```

**Planner note:** Preserve `UIImage.getColors(quality: .lowest)` behavior unless a narrower app-specific API is explicitly chosen. There is no first-party analog for the actual dominant-color algorithm; use the existing `LibraryClient` call site and deterministic fixture tests as the app boundary.

---

### `AppPackage/Tests/UIImageColorsTests/**` (test, transform)

**Analog:** `AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingTests.swift`

**Image/data fixture test pattern** (lines 12-31):
```swift
@Test
func testFileBasedQuotaImageMapsToQuotaExceeded() async throws {
    let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let manager = makeTestingDownloadCoordinator()
    let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
    let response = try makeResponse(
        url: quotaImageURL,
        contentType: "image/gif",
        contentLength: 28658
    )
    let error = await manager.detectResponseError(
        fileURL: fileURL,
        response: response,
        requestURL: quotaImageURL
    )

    #expect(error == .quotaExceeded)
}
```

**Generated temporary image/data pattern** (lines 57-80):
```swift
@Test
func testFileBasedBinaryKokomadeImageMapsToAuthenticationRequired() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("gif")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let imageData = try #require(Data(base64Encoded: "R0lGODlhAQABAIABAP///wAAACwAAAAAAQABAAACAkQBADs="))
    try imageData.write(to: fileURL, options: .atomic)

    let manager = makeTestingDownloadCoordinator()
    let kokomadeURL = try #require(URL(string: "https://exhentai.org/img/kokomade.jpg"))
    let response = try makeResponse(
        url: kokomadeURL,
        contentType: "image/gif",
        contentLength: imageData.count
    )
    let error = await manager.detectResponseError(
        fileURL: fileURL,
        response: response,
        requestURL: URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1")
    )

    #expect(error == .authenticationRequired)
}
```

**Planner note:** Use generated images plus fixed fixtures. Assert concrete RGBA component tuples for background/primary/secondary/detail. Automated tests prove deterministic technical parity only; final visual judgment stays in user verification.

---

### `AppPackage/Sources/MarkdownExt/MarkdownUtil.swift` (utility/module, transform)

**Analog:** `AppPackage/Sources/CommonMarkExt/MarkdownUtil.swift`

**Current parse API and behavior** (lines 1-45):
```swift
import CasePaths
import CommonMark
import Foundation

public struct MarkdownUtil {
    public static func parseTexts(markdown: String) -> [String] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap({ $0[case: \.paragraph] })
            .flatMap(\.text)
            .compactMap({ $0[case: \.text] })
            ?? []
    }
    public static func parseLinks(markdown: String) -> [URL] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap({ $0[case: \.paragraph] })
            .flatMap(\.text)
            .compactMap({ $0[case: \.link] })
            .compactMap(\.url)
            ?? []
    }
    public static func parseImages(markdown: String) -> [URL] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap({ $0[case: \.paragraph] })
            .flatMap(\.text)
            .compactMap({ $0[case: \.image] })
            .compactMap { image in
                if let absoluteString = image.url?.absoluteString, isValidURL(absoluteString) {
                    return image.url
                } else if let title = image.title, isValidURL(title) {
                    return .init(string: title)
                }
                return nil
            }
            ?? []
    }

    private static func isValidURL(_ string: String) -> Bool {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ), let match = detector.firstMatch(
            in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)
        ) else { return false }
        return match.range.length == string.utf16.count
    }
}
```

**Planner note:** New `MarkdownExt` should keep `MarkdownUtil.parseTexts/parseLinks/parseImages` as the app-facing boundary unless there is a clear reason to narrow it. Preserve paragraph-only traversal unless fixtures explicitly document an intended bug fix. Avoid exposing `Markdown.Document` nodes to `DetailFeature` or `TagTranslationFeature`.

---

### `AppPackage/Sources/TagTranslationFeature/TagTranslation+Markdown.swift` (utility, transform)

**Analog:** same file

**Current helper call-site pattern** (lines 1-33):
```swift
import AppModels
import CommonMarkExt
import Foundation

extension TagTranslation {
    public var displayValue: String {
        valuePlainText ?? value
    }

    public var valuePlainText: String? {
        MarkdownUtil.parseTexts(markdown: value).first
    }
    public var valueImageURL: URL? {
        MarkdownUtil.parseImages(markdown: value).first
    }
    public var descriptionPlainText: String? {
        if let description = description {
            return MarkdownUtil.parseTexts(markdown: description.replacingOccurrences(of: "`", with: " ")).joined()
        }
        return nil
    }
    public var descriptionImageURLs: [URL] {
        if let description = description {
            return MarkdownUtil.parseImages(markdown: description)
        }
        return .init()
    }
    public var links: [URL] {
        if let linksString = linksString {
            return MarkdownUtil.parseLinks(markdown: linksString)
        }
        return .init()
    }
}
```

**Planner note:** Swap `CommonMarkExt` to `MarkdownExt` here and keep the computed-property surface stable. Fixture-lock `displayValue`, `valuePlainText`, `valueImageURL`, `descriptionPlainText`, `descriptionImageURLs`, and `links`.

---

### `AppPackage/Sources/DetailFeature/DetailView.swift` (component, request-response UI)

**Analog:** same file

**Current imports showing stray direct markdown dependency** (lines 1-10):
```swift
import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import Kingfisher
import ComposableArchitecture
import CommonMark
import AppTools
import AppComponents
import ReadingFeature
```

**Planner note:** Remove the direct `CommonMark` import if unused. If Detail still needs markdown behavior, route it through `MarkdownExt` or `TagTranslationFeature`; do not import `Markdown` directly into `DetailFeature`.

---

### `AppPackage/Tests/MarkdownExtTests/**` (test, transform)

**Analog:** `AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataDecodeTests.swift`

**Focused parser fixture test pattern** (lines 1-12):
```swift
import Foundation
import Testing
import AppModels
@testable import NetworkingFeature

// REV-2: the `gdata` API returns bare `{ gid, error }` objects for expunged/removed gids (and can omit
// `token`). Decoding the whole `[GalleryMetadata]` array must tolerate those per-entry — one bad gid
// must never fail the batch and blank the entire History screen. A *resolved* entry missing a required
// display field is dropped rather than defaulted, matching the HTML list parser's row policy.
@Suite
struct GalleriesMetadataDecodeTests {
```

**Inline fixture and assertion pattern** (lines 14-40):
```swift
let json = """
{
  "gmetadata": [
    {
      "gid": 100, "token": "aaa", "title": "First &amp; Title",
      "category": "Doujinshi", "thumb": "https://example.com/1.jpg",
      "uploader": "u1", "posted": "1600000000", "filecount": "20",
      "rating": "4.5", "tags": ["language:japanese", "artist:someone"]
    },
    { "gid": 999, "error": "Key missing, or incorrect key." },
    {
      "gid": 200, "token": "bbb", "title": "Second Title",
      "category": "Manga", "thumb": "https://example.com/2.jpg",
      "uploader": "u2", "posted": "1600000100", "filecount": "30",
      "rating": "3.0", "tags": ["language:english"]
    }
  ]
}
"""

let galleries = try GalleriesMetadataRequest.galleries(fromResponseData: Data(json.utf8))

#expect(galleries.count == 2)
#expect(galleries.map(\.id) == ["100", "200"])
#expect(galleries.first?.token == "aaa")
#expect(galleries.first?.title == "First & Title")
```

**Planner note:** Use small inline markdown strings for `parseTexts`, `parseLinks`, and `parseImages`. Include current edge cases and any intentionally fixed behavior in test names/comments.

---

### Domain-fronting files (streaming/request-response)

**Analogs:** `DFExtensions.swift`, `DFRequest.swift`, `DFStreamHandler.swift`, `DFURLProtocol.swift`, `DFClient.swift`

**URL replacement and Host header semantics** (from `DFExtensions.swift`, lines 68-108):
```swift
extension URLRequest {
    public var isHTTPS: Bool { url?.scheme == "https" }
    public var hasHostField: Bool { hostKey?.count ?? 0 > 0 }
    public var hostKey: Dictionary<String, String>.Keys.Element? {
        allHTTPHeaderFields?.keys.first(where: { $0.lowercased() == "host" })
    }
    public var domain: String? {
        var domain: String? = url?.host

        if let allFields = allHTTPHeaderFields, let hostKey = hostKey {
            domain = allFields[hostKey]
        }

        return domain
    }
    public var domainWithScheme: String? {
        if let scheme = url?.scheme, let domain = domain {
            return scheme + "://" + domain
        } else {
            return nil
        }
    }
    public func domainIPReplaced() -> URLRequest {
        var request: URLRequest = self

        guard let domain = domain,
              let resolvedIP = DomainResolver
                .resolve(domain: domain),
              let url = request.url?.replaceHost(
                to: resolvedIP
              )
        else { return request }

        request.url = url

        if hasHostField == false {
            request.addValue(domain, forHTTPHeaderField: "Host")
        }
        return request
    }
}
```

**Body preservation pattern** (from `DFExtensions.swift`, lines 109-144):
```swift
public func HTTPBody() -> Data? {
    if httpMethod != "POST" ||
        httpBody != nil { return httpBody }

    guard let stream = httpBodyStream
    else { return nil }

    stream.open()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>
        .allocate(capacity: bufferSize)
    defer {
        stream.close()
        buffer.deallocate()
        buffer.deinitialize(count: bufferSize)
    }

    var body = Data()
    var readSize = 0
    repeat {
        if stream.hasBytesAvailable == false { break }

        readSize = stream.read(buffer, maxLength: bufferSize)
        if readSize > 0 {
            body.append(buffer, count: readSize)
        } else if readSize == 0 {
            logger.debug("HTTPBodyStream read EOF.")
        } else {
            if let error = stream.streamError as Error? {
                logger.error("HTTPBodyStream read Error: \(error, privacy: .public)")
            }
        }
    } while readSize > 0

    return body
}
```

**Current stream creation seam** (from `DFExtensions.swift`, lines 180-228):
```swift
public static func create(from request: URLRequest) -> Result<InputStream, CreateStreamError> {
    guard let method = request.httpMethod as CFString? else {
        return .failure(.methodNotFound(
            msg: "HTTPMethod not found: \(request.httpMethod ?? "nil")."
        ))
    }
    guard let url = request.url as CFURL? else {
        return .failure(.urlNotFound(
            msg: "URL not found: \(request.url?.absoluteString ?? "nil")."
        ))
    }

    let message = CFHTTPMessageCreateRequest(
        kCFAllocatorDefault, method,
        url, kCFHTTPVersion1_1
    )
    .autorelease()
    .takeUnretainedValue()

    request.allHTTPHeaderFields?.forEach { field, value in
        CFHTTPMessageSetHeaderFieldValue(
            message, field as CFString,
            value as CFString
        )
    }

    if request.hasHostField == false {
        CFHTTPMessageSetHeaderFieldValue(
            message, "host" as CFString,
            request.domain as CFString?
        )
    }

    if let body = request.HTTPBody() as CFData? {
        CFHTTPMessageSetBody(message, body)
    }

    guard let stream = DeprecatedAPI.getCFReadStream(
        kCFAllocatorDefault, message
    )
    .autorelease()
    .takeUnretainedValue() as InputStream? else {
        return .failure(.createStream(msg: "Create Stream error."))
    }

    let key = "kCFStreamPropertyHTTPAttemptPersistentConnection" as CFString
    stream.setProperty(true, forKey: key as Stream.PropertyKey)

    return .success(stream)
}
```

**Request construction and cookies** (from `DFRequest.swift`, lines 14-41):
```swift
public init?(
    _ req: URLRequest,
    delegate: DFRequestDelegate? = nil
) {
    self.delegate = delegate
    request = req.domainIPReplaced()

    if let url = req.url,
       let cookies = HTTPCookieStorage
        .shared.cookies(for: url) {
        request.allHTTPHeaderFields = HTTPCookie
            .requestHeaderFields(with: cookies)
    }

    switch InputStream.create(from: request) {
    case .success(let stream):
        self.stream = stream
    case .failure(let error):
        delegate?.dfRequest(
            request, didFailWithError: error
        )
        return nil
    }

    if request.isHTTPS, let host = request.domain {
        stream.invalidatesCertChain(for: host)
    }
}
```

**Trust and response handling** (from `DFStreamHandler.swift`, lines 19-86):
```swift
func readIfHasBytesAvailable(_ stream: InputStream) {
    let message = stream.httpMessage()
    guard message?.isCompleted == true else { return }

    if request.request.isHTTPS, hasEvaluated == false {
        let domain = request.request.domain
        if evaluate(stream.trust, domain: domain) {
            hasEvaluated = true
        } else {
            let err = NSError(
                domain: "CFNetwork SSLHandshake failed",
                code: -9870, userInfo: nil
            )
            request.delegate?.dfRequest(
                request.request,
                didFailWithError: err
            )
        }
    }

    if receivedResponse == false,
       let resp = message?.httpResponse() {
        receivedResponse = true
        request.delegate?.dfRequest(
            request, didReceive: resp,
            cacheStoragePolicy: .notAllowed
        )
    }

    guard stream.hasBytesAvailable else { return }
    let data = readData(from: stream)

    request.delegate?.dfRequest(request, didLoad: data)
}
```

**Redirect propagation pattern** (from `DFStreamHandler.swift`, lines 122-179):
```swift
func endEncountered(_ stream: InputStream) {
    if !request.request.urlContainsImageURL {
        let urlString = request.request.url?.absoluteString ?? ""
        logger.debug("Stream end off for: \(urlString).")
    }

    let message = stream.httpMessage()

    let finish = {
        if stream.streamError != nil {
            self.errorOccurred(stream)
        } else {
            if !self.request.request.urlContainsImageURL {
                let urlString = self.request.request.url?.absoluteString ?? ""
                logger.debug("Request loading finished for: \(urlString).")
            }
            self.request.delegate?.dfRequestDidFinishLoading(self.request)
        }
    }

    guard let resp = message?.httpResponse() else {
        finish()
        return
    }
    let statusCode = resp.statusCode

    if statusCode >= 300 && statusCode < 400 {
        guard let headerFields = message?.allHeaderFields,
              let hostKey = headerFields.keys
                .first(where: { $0.lowercased() == "location" }),
              let loction = headerFields[hostKey],
              var url = URL(string: loction)
        else {
            finish()
            return
        }

        if ["/", "/popular", "/watched"].contains(url.absoluteString)
            || ["/?f_search"].contains(where: url.absoluteString.contains),
           let domain = request.request.domainWithScheme,
           let originalURL = URL(string: domain) {
            url = originalURL.appendingPathComponent(url.absoluteString)
        }

        logger.warning("Request redirected to: \(url.absoluteString).")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        request.delegate?.dfRequest(
            request,
            wasRedirectedTo: req,
            redirectResponse: resp
        )
    } else {
        finish()
    }
}
```

**URLProtocol bridge pattern** (from `DFURLProtocol.swift`, lines 12-40):
```swift
public override class func canonicalRequest(
    for request: URLRequest) -> URLRequest { request }
public override class func canInit(with request: URLRequest) -> Bool {
    if property(forKey: requestIdentifier, in: request) != nil {
        logger.error("URLRequest has been initialized.")
        return false
    }
    if !["http", "https"].contains(request.url?.scheme) {
        let scheme = request.url?.scheme ?? "nil"
        logger.error("URL scheme \"\(scheme, privacy: .public)\" is not supported.")
        return false
    }
    return true
}

public override func startLoading() {
    dfRequest = DFRequest(request, delegate: self)
    let request = request as? NSMutableURLRequest
    DFURLProtocol.setProperty(
        true, forKey: DFURLProtocol.requestIdentifier,
        in: request.forceUnwrapped
    )

    dfRequest?.resume()
}

public override func stopLoading() {
    dfRequest?.stop()
    dfRequest = nil
}
```

**DF activation client pattern** (from `DFClient.swift`, lines 11-22):
```swift
public static let live: Self = .init(
    setActive: { newValue in
        if newValue {
            URLProtocol.registerClass(DFURLProtocol.self)
        } else {
            URLProtocol.unregisterClass(DFURLProtocol.self)
        }
        // Kingfisher
        let config = KingfisherManager.shared.downloader.sessionConfiguration
        config.protocolClasses = newValue ? [DFURLProtocol.self] : nil
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }
)
```

**Planner note:** DEP-06 must preserve these exact semantics: IP host replacement, original `Host`, original-URL cookies, body preservation, response/redirect propagation, and trust evaluation against the original domain. If a warning-free non-deprecated replacement cannot preserve those semantics, keep the dependency and document the D-12/D-13 skip evidence.

---

### `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` (test, request-response)

**Analog:** `AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataDecodeTests.swift`

**Networking test imports** (lines 1-4):
```swift
import Foundation
import Testing
import AppModels
@testable import NetworkingFeature
```

**Domain resolver behavior to fixture-lock** (from `AppPackage/Sources/NetworkingFeature/DomainResolver.swift`, lines 1-19):
```swift
public struct DomainResolver {
    public static func resolve(domain: String) -> String? {
        ResolvableDomain(rawValue: domain)?.ipPool.randomElement()
    }
}

public enum ResolvableDomain: String {
    case ehgt = "ehgt.org"
    case ehgt0 = "gt0.ehgt.org"
    case ehgt1 = "gt1.ehgt.org"
    case ehgt2 = "gt2.ehgt.org"
    case ehgt3 = "gt3.ehgt.org"
    case ehgtul = "ul.ehgt.org"
    case ehentai = "e-hentai.org"
    case exhentai = "exhentai.org"
    case repo = "repo.e-hentai.org"
    case forums = "forums.e-hentai.org"
    case github = "raw.githubusercontent.com"
}
```

**Planner note:** Tests can assert stable invariants without pinning the exact random IP: replaced host is in the expected pool, `Host` header equals the original domain when absent, existing `Host` header casing/value is preserved, POST body survives, cookies are derived from the original URL, and redirect URLs are reconstructed against `domainWithScheme`.

---

### `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` (component, event-driven UI)

**Analog:** same file

**Animated gradient integration** (lines 43-65):
```swift
public var body: some View {
    ZStack {
        Color.gray.opacity(0.2)
        ColorfulView(animated: animated, animation: animation, colors: colors)
            .id(currentID + animated.description)
        HStack {
            KFImage(gallery.coverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                .onSuccess(webImageSuccessAction).defaultModifier().scaledToFill()
                .frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)
                .cornerRadius(5)
            VStack(alignment: .leading) {
                Text(title).font(.title3.bold()).lineLimit(4)
                Spacer()
                RatingView(rating: gallery.rating).foregroundColor(.yellow)
            }
            .padding(.leading, 15)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    .frame(width: Defaults.FrameSize.cardCellWidth).cornerRadius(15)
}
```

**Preview default colors** (lines 68-77):
```swift
struct GalleryCardCell_Previews: PreviewProvider {
    static var previews: some View {
        let gallery = Gallery.preview
        GalleryCardCell(
            gallery: gallery, currentID: gallery.gid,
            colors: ColorfulView.defaultColorList,
            webImageSuccessAction: { _ in }
        )
        .previewLayout(.fixed(width: 300, height: 206)).padding()
    }
}
```

**Planner note:** If latest `ColorfulView` compiles cleanly, keep this integration shape. If deprecation warnings block the clean-build standard, replace only the gradient surface while preserving `animated`, `animation`, `colors`, `.id(currentID + animated.description)`, and the same fallback/visual concept.

---

### `AppPackage/Sources/HomeFeature/HomeReducer.swift` and `HomeReducer+Body.swift` (store/reducer, event-driven + async transform)

**Analogs:** same files

**State/action/dependency color flow** (from `HomeReducer.swift`, lines 20-25 and 67-82):
```swift
public var currentCardID = ""
public var allowsCardHitTesting = true
public var rawCardColors = [String: [Color]]()
var cardColors: [Color] {
    rawCardColors[currentCardID] ?? [.clear]
}
...
case analyzeImageColors(String, RetrieveImageResult)
case analyzeImageColorsDone(String, [Color]?)
...
@Dependency(\.libraryClient) var libraryClient
```

**Effect flow** (from `HomeReducer+Body.swift`, lines 170-179):
```swift
case .analyzeImageColors(let gid, let result):
    guard !state.rawCardColors.keys.contains(gid) else { return .none }
    return .run { send in
        let colors = await libraryClient.analyzeImageColors(result.image)
        await send(.analyzeImageColorsDone(gid, colors))
    }

case .analyzeImageColorsDone(let gid, let colors):
    state.rawCardColors[gid] = colors
    return .none
```

**Planner note:** Do not move color extraction into `GalleryCardCell`; the reducer/client flow already keeps image analysis off the view. Keep `rawCardColors` keyed by `gid` and fallback to `[.clear]`.

---

### `AppPackage/Tests/FeatureTests.xctestplan` (config, batch)

**Analog:** same file

**Existing test-plan target entries** (lines 14-64):
```json
"testTargets" : [
  {
    "target" : {
      "containerPath" : "container:AppPackage",
      "identifier" : "AppModelsTests",
      "name" : "AppModelsTests"
    }
  },
  ...
  {
    "target" : {
      "containerPath" : "container:AppPackage",
      "identifier" : "NetworkingFeatureTests",
      "name" : "NetworkingFeatureTests"
    }
  },
  {
    "target" : {
      "containerPath" : "container:AppPackage",
      "identifier" : "ParserFeatureTests",
      "name" : "ParserFeatureTests"
    }
  },
  {
    "target" : {
      "containerPath" : "container:AppPackage",
      "identifier" : "SettingFeatureTests",
      "name" : "SettingFeatureTests"
    }
  }
]
```

**Planner note:** Add new `SwiftyOpenCCTests`, `UIImageColorsTests`, `MarkdownExtTests`, and any `TagTranslationFeatureTests` entries here after adding Package.swift test targets.

## Shared Patterns

### AppPackage Module Registration

**Source:** `AppPackage/Package.swift`
**Apply to:** all new modules/test targets

Use the existing flow:
1. Add `Module` enum case.
2. Add `Target.Dependency` helper only for external products.
3. Add `.target(module:..., dependencies:..., plugins: swiftLintPlugins)`.
4. Add `.testTarget(module:..., dependencies:..., plugins: swiftLintPlugins)`.
5. Let `products` auto-generate from `targets` unless the target is a test or `TestingSupport`.

Do not bypass the helper enums with scattered string literals.

### SwiftLint Coverage

**Source:** `AppPackage/Sources/SystemNotificationExt/.swiftlint.yml`
**Apply to:** every new module under `AppPackage/Sources` and `AppPackage/Tests`

```yaml
parent_config: ../../../.swiftlint.yml
```

Root `.swiftlint.yml` has error-level `force_try`, `force_unwrapping`, line length 120, and custom bans on `NSLock`, `@preconcurrency`, `@unchecked Sendable`, unreasoned `swiftlint:disable`, and `systemName`/`systemImage` parameters. Imported package code must be modernized to pass these rules at the root, not suppressed.

### Swift Testing

**Source:** `AppPackage/Tests/FileClientTests/FileClientTests.swift`
**Apply to:** all new parity tests

```swift
import Testing
import Foundation
import AppModels
import FileClient

@Suite(.serialized)
struct FileClientTests {
    @Test
    func cachesRemoteTableAndRebuildsItFromMetadata() throws {
        let built = try #require(
            FileClient.live.cacheAndBuildRemoteTagTranslator(try sampleResponseData(), language, .distantPast)
        )
        #expect(built.language == language)
    }
}
```

Use `.serialized` only when tests touch fixed paths or shared caches. Otherwise use plain `@Suite`. Prefer `#require` for fixture construction and optional unwraps.

### Dependency Injection Clients

**Source:** `AppPackage/Sources/LibraryClient/LibraryClient.swift`, `AppPackage/Sources/FileClient/FileClient.swift`
**Apply to:** app-facing async/side-effect seams

Client structs are `Sendable`, expose closure properties, provide `.live`, `DependencyKey`, `DependencyValues`, `.noop`, and `.unimplemented`. Pure parser/converter modules do not need a client wrapper unless they own side effects or need injection.

### Logging And Error Handling

**Source:** `AppPackage/Sources/NetworkingFeature/DFExtensions.swift`, `DFStreamHandler.swift`
**Apply to:** NetworkingFeature changes

Use per-file `private let logger = Logger(category: ...)` and propagate failures through delegate/client callbacks. Preserve existing error propagation; do not hide warnings or failures to satisfy DEP-06.

### Domain-Fronting Preservation

**Source:** `AppPackage/Sources/NetworkingFeature/DFExtensions.swift`, `DFRequest.swift`, `DFStreamHandler.swift`, `DFURLProtocol.swift`
**Apply to:** DEP-06

Required invariants:
- Replace URL host with a resolved IP while preserving the original domain in `Host`.
- Merge cookies using the original request URL.
- Preserve headers and POST body.
- Evaluate TLS trust against the original domain.
- Forward response, data, redirects, failure, and finish events to `URLProtocolClient`.
- Keep Kingfisher routed through `DFURLProtocol` when DF is active.

### Markdown Boundary

**Source:** `AppPackage/Sources/CommonMarkExt/MarkdownUtil.swift`, `TagTranslationFeature/TagTranslation+Markdown.swift`
**Apply to:** DEP-03

`TagTranslationFeature` consumes `MarkdownUtil`, not parser node types. `DetailFeature` should not import `Markdown` directly. New `MarkdownExt` owns the `swift-markdown` import and adapter behavior.

### Color Flow

**Source:** `AppPackage/Sources/LibraryClient/LibraryClient.swift`, `HomeReducer.swift`, `HomeReducer+Body.swift`, `GalleryCardCell.swift`
**Apply to:** DEP-02 and DEP-07

`LibraryClient.analyzeImageColors` maps `UIImageColors` output to `[Color]`; `HomeReducer` stores it by `gid`; `GalleryCardCell` renders the passed `colors`. Preserve that flow.

## No Analog Found

| File/Module Family | Role | Data Flow | Reason |
|--------------------|------|-----------|--------|
| `AppPackage/Sources/SwiftyOpenCC/**` internal converter/dictionary implementation | utility/module | transform, file-I/O | Existing code only has the app seam using external `OpenCC`; no first-party OpenCC dictionary/C++ implementation exists. |
| `AppPackage/Sources/UIImageColors/**` dominant-color algorithm internals | utility/module | transform | Existing code only calls external `UIImage.getColors`; no first-party color clustering implementation exists. |
| Non-deprecated DEP-06 replacement for `DeprecatedAPI.getCFReadStream` | service/middleware | streaming, request-response | Current first-party analog is the deprecated CFStream path. A replacement must be spike-validated, or D-12 skip evidence must be documented. |

## Incidental Scope Notes

`AppPackage/Sources/SettingFeature/Components/AboutView.swift` currently lists acknowledgements for `SwiftyOpenCC`, `UIImageColors`, and `SwiftCommonMark` (lines 169-188). The phase docs do not require acknowledgement updates, so planners should treat this as a follow-up check only if dependency attribution policy demands it. If resource keys are changed, follow AGENTS.md `.xcstrings` locale-fill rules.

## Metadata

**Analog search scope:** `AppPackage/Package.swift`, `AppPackage/Sources`, `AppPackage/Tests`, `.planning/codebase`, root SwiftLint/project docs.
**Files scanned:** 150+ source/test/config paths from `find`/`rg`.
**Pattern extraction date:** 2026-07-10
