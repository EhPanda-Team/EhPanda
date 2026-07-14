// swift-tools-version: 6.3.1

import PackageDescription

// MARK: Dependency
var dependencies: [PackageDescription.Package.Dependency] = [
    // ColorfulX (Lakr233) — Metal-backed animated multicolor gradient, pinned exactly for
    // supply-chain hardening. Replaces the deprecated Colorful package (DEP-07b): Colorful
    // 1.1.x marked `ColorfulView` deprecated on non-watchOS ("This library hurts CPU alot")
    // and pointed here, so the Home gallery-card gradient now renders through ColorfulX.
    .package(url: "https://github.com/Lakr233/ColorfulX", exact: "6.1.0"),
    // App-owned fork of ddddxxx/SwiftyOpenCC, pinned exactly for DEP-01. It de-vendors the
    // OpenCC/marisa C++ engine (as a submodule) and carries the copencc shim fixes; its
    // `OpenCC` product replaces EhPanda's former app-owned SwiftyOpenCC + copencc modules.
    .package(url: "https://github.com/EhPanda-Team/SwiftyOpenCC", exact: "2.1.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "3.0.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageWebPCoder", from: "0.14.0"),
    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.64.1"),
    .package(url: "https://github.com/apple/swift-markdown", from: "0.8.0"),
    .package(url: "https://github.com/onevcat/Kingfisher", from: "8.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.7.0"),
    .package(
        url: "https://github.com/pointfreeco/swift-composable-architecture",
        from: "1.25.3",
        traits: [
            "ComposableArchitecture2Deprecations",
            "ComposableArchitecture2DeprecationOverloads"
        ]
    ),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
    .package(url: "https://github.com/tid-kijyun/Kanna", from: "6.0.0")
]

extension PackageDescription.Target.Dependency {
    static let casePaths: Self = .product(name: "CasePaths", package: "swift-case-paths")
    static let colorfulX: Self = .product(name: "ColorfulX", package: "ColorfulX")
    static let composableArchitecture: Self = .product(
        name: "ComposableArchitecture",
        package: "swift-composable-architecture"
    )
    static let kanna: Self = .product(name: "Kanna", package: "Kanna")
    static let kingfisher: Self = .product(name: "Kingfisher", package: "Kingfisher")
    static let markdown: Self = .product(name: "Markdown", package: "swift-markdown")
    static let openCC: Self = .product(name: "OpenCC", package: "SwiftyOpenCC")
    static let sdWebImageSwiftUI: Self = .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI")
    static let sdWebImageWebPCoder: Self = .product(name: "SDWebImageWebPCoder", package: "SDWebImageWebPCoder")
    static let sfSafeSymbols: Self = .product(name: "SFSafeSymbols", package: "SFSafeSymbols")
    static let sharing: Self = .product(name: "Sharing", package: "swift-sharing")
}

let swiftLintPlugins: [PackageDescription.Target.PluginUsage] = [
    .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
]

// Matches the app target's "Approachable Concurrency" (SWIFT_APPROACHABLE_CONCURRENCY)
// so code keeps compiling under the same concurrency posture after moving into the package.
let sharedSwiftSettings: [PackageDescription.SwiftSetting] = [
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

// MARK: Module
enum Module: String {
    case animatedImageFeature = "AnimatedImageFeature"
    case appComponents = "AppComponents"
    case appFeature = "AppFeature"
    case appLaunchAutomationClient = "AppLaunchAutomationClient"
    case appModels = "AppModels"
    case appTools = "AppTools"
    case applicationClient = "ApplicationClient"
    case backgroundProcessingClient = "BackgroundProcessingClient"
    case clipboardClient = "ClipboardClient"
    case cookieClient = "CookieClient"
    case dfClient = "DFClient"
    case dateSeekFeature = "DateSeekFeature"
    case detailFeature = "DetailFeature"
    case deviceClient = "DeviceClient"
    case downloadClient = "DownloadClient"
    case downloadsFeature = "DownloadsFeature"
    case favoritesFeature = "FavoritesFeature"
    case fileClient = "FileClient"
    case filtersFeature = "FiltersFeature"
    case galleryListComponents = "GalleryListComponents"
    case hapticsClient = "HapticsClient"
    case homeFeature = "HomeFeature"
    case imageClient = "ImageClient"
    case imageColors = "ImageColors"
    case legacyCFReadStream = "LegacyCFReadStream"
    case libraryClient = "LibraryClient"
    case logsClient = "LogsClient"
    case markdownExt = "MarkdownExt"
    case networkingFeature = "NetworkingFeature"
    case osLogExt = "OSLogExt"
    case parserFeature = "ParserFeature"
    case quickSearchFeature = "QuickSearchFeature"
    case readingFeature = "ReadingFeature"
    case readingSettingFeature = "ReadingSettingFeature"
    case resources = "Resources"
    case searchFeature = "SearchFeature"
    case settingFeature = "SettingFeature"
    case sfSafeSymbolsExt = "SFSafeSymbolsExt"
    case systemNotificationExt = "SystemNotificationExt"
    case tagTranslationFeature = "TagTranslationFeature"
    case urlClient = "URLClient"
    case userDefaultsClient = "UserDefaultsClient"

    // Test support
    case testingSupport = "TestingSupport"

    // Test targets
    case appFeatureTests = "AppFeatureTests"
    case parserFeatureTests = "ParserFeatureTests"
    case downloadsFeatureTests = "DownloadsFeatureTests"
    case fileClientTests = "FileClientTests"
    case settingFeatureTests = "SettingFeatureTests"
    case detailFeatureTests = "DetailFeatureTests"
    case networkingFeatureTests = "NetworkingFeatureTests"
    case appModelsTests = "AppModelsTests"
    case swiftyOpenCCTests = "SwiftyOpenCCTests"
    case imageClientTests = "ImageClientTests"
    case imageColorsTests = "ImageColorsTests"
    case markdownExtTests = "MarkdownExtTests"
    case tagTranslationFeatureTests = "TagTranslationFeatureTests"
    case galleryListComponentsTests = "GalleryListComponentsTests"
    case readingFeatureTests = "ReadingFeatureTests"
}

extension Module {
    enum Dependency {
        case module(Module)
        case literal(String)
        case targetDependency(PackageDescription.Target.Dependency)

        var targetDependency: PackageDescription.Target.Dependency {
            switch self {
            case .module(let module):
                return .init(stringLiteral: module.rawValue)

            case .literal(let stringLiteral):
                return .init(stringLiteral: stringLiteral)

            case .targetDependency(let dependency):
                return dependency
            }
        }
    }
}

// MARK: Exclude
enum Path: String {
    case resources = "Resources"
}

enum Exclude {
    case literal(String)
    case path(Path)

    var name: String {
        switch self {
        case .literal(let stringLiteral):
            return stringLiteral

        case .path(let path):
            return path.rawValue
        }
    }
}

// MARK: Resource
enum Resource {
    case copy(Path)
    case embedInCode(Path)
    case process(Path, PackageDescription.Resource.Localization? = nil)

    var value: PackageDescription.Resource {
        switch self {
        case .copy(let path):
            return .copy(path.rawValue)

        case .embedInCode(let path):
            return .embedInCode(path.rawValue)

        case .process(let path, let localization):
            return .process(path.rawValue, localization: localization)
        }
    }
}

// MARK: Helper methods
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

// MARK: Target
let targets: [PackageDescription.Target] = [
    .target(
        module: .appFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.appTools),
            .module(.applicationClient),
            .module(.backgroundProcessingClient),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.dfClient),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.downloadsFeature),
            .module(.favoritesFeature),
            .module(.fileClient),
            .module(.filtersFeature),
            .module(.hapticsClient),
            .module(.homeFeature),
            .module(.imageClient),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.osLogExt),
            .module(.parserFeature),
            .module(.quickSearchFeature),
            .module(.readingFeature),
            .module(.resources),
            .module(.searchFeature),
            .module(.animatedImageFeature),
            .module(.settingFeature),
            .module(.systemNotificationExt),
            .module(.urlClient),
            .module(.userDefaultsClient),
            .targetDependency(.colorfulX),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kanna),
            .targetDependency(.kingfisher),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sdWebImageWebPCoder),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appModels,
        dependencies: [
            .module(.appTools),
            .module(.resources),
            .module(.osLogExt),
            .targetDependency(.casePaths),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .resources,
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .deviceClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .downloadClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.osLogExt),
            .module(.parserFeature),
            .module(.resources),
            .module(.animatedImageFeature),
            .module(.urlClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kanna),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .fileClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture),
            .targetDependency(.openCC)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .systemNotificationExt,
        dependencies: [
            .module(.appComponents),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appTools,
        dependencies: [
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appLaunchAutomationClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .backgroundProcessingClient,
        dependencies: [
            .module(.appModels),
            .module(.osLogExt),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .clipboardClient,
        dependencies: [
            .module(.animatedImageFeature),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .cookieClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .dfClient,
        dependencies: [
            .module(.networkingFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .networkingFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.osLogExt),
            .module(.parserFeature),
            .targetDependency(.composableArchitecture),
            .module(.legacyCFReadStream),
            .targetDependency(.kanna)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .hapticsClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appComponents,
        dependencies: [
            .module(.sfSafeSymbolsExt),
            .module(.appModels),
            .module(.appTools),
            .module(.deviceClient),
            .module(.parserFeature),
            .module(.resources),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .galleryListComponents,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.tagTranslationFeature),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .animatedImageFeature,
        dependencies: [
            .targetDependency(.sdWebImageSwiftUI)
        ],
        plugins: swiftLintPlugins
    ),
    // App-owned markdown helper: the sole owner of the swift-markdown (`Markdown`) dependency,
    // keeping parser node types out of feature modules (D-08, D-09).
    .target(
        module: .markdownExt,
        dependencies: [
            .targetDependency(.markdown)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .sfSafeSymbolsExt,
        dependencies: [
            .targetDependency(.sfSafeSymbols)
        ],
        plugins: swiftLintPlugins
    ),
    // App-owned local dominant-color module. Clean-room reimplementation of the
    // app-needed dominant-color surface, replacing the external jathu/UIImageColors
    // package while preserving color-selection output (DEP-02, D-01/D-04/D-16).
    // Modernized I/O: a CGImage goes in and non-optional SwiftUI Colors come out.
    .target(
        module: .imageColors,
        plugins: swiftLintPlugins
    ),
    // Internal isolation module for the one deprecated CFNetwork call the app relies on
    // (`CFReadStreamCreateForHTTPRequest`, for domain fronting — DEP-06 / D-12/D-14). Compiled
    // with `-suppress-warnings` so the unavoidable deprecation notice is silenced at this single
    // documented boundary. Replaces the former external `DeprecatedAPI` package (inlined 01-09).
    // Kept out of `products` (below): it is an internal implementation detail, not a public library.
    .target(
        module: .legacyCFReadStream,
        swiftSettings: sharedSwiftSettings + [.unsafeFlags(["-suppress-warnings"])],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .osLogExt,
        dependencies: [
            .module(.appTools)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .logsClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.osLogExt),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .tagTranslationFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.markdownExt)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .filtersFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.resources),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .dateSeekFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.hapticsClient),
            .module(.resources),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .readingSettingFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.resources),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .quickSearchFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.resources),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .downloadsFeature,
        dependencies: [
            .module(.sfSafeSymbolsExt),
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.detailFeature),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.galleryListComponents),
            .module(.readingFeature),
            .module(.resources),
            .module(.systemNotificationExt),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .favoritesFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .settingFeature,
        dependencies: [
            .module(.sfSafeSymbolsExt),
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.applicationClient),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.dfClient),
            .module(.fileClient),
            .module(.hapticsClient),
            .module(.libraryClient),
            .module(.logsClient),
            .module(.networkingFeature),
            .module(.osLogExt),
            .module(.readingSettingFeature),
            .module(.resources),
            .module(.systemNotificationExt),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .searchFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.filtersFeature),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .homeFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.filtersFeature),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.tagTranslationFeature),
            .targetDependency(.colorfulX),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .detailFeature,
        dependencies: [
            .module(.sfSafeSymbolsExt),
            .module(.appComponents),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.appTools),
            .module(.applicationClient),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.downloadClient),
            .module(.fileClient),
            .module(.filtersFeature),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.readingFeature),
            .module(.resources),
            .module(.systemNotificationExt),
            .module(.tagTranslationFeature),
            .module(.urlClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .readingFeature,
        dependencies: [
            .module(.sfSafeSymbolsExt),
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.hapticsClient),
            .module(.imageClient),
            .module(.networkingFeature),
            .module(.osLogExt),
            .module(.readingSettingFeature),
            .module(.resources),
            .module(.animatedImageFeature),
            .module(.systemNotificationExt),
            .module(.urlClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .imageClient,
        dependencies: [
            .module(.appModels),
            .module(.animatedImageFeature),
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
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
            .module(.imageColors)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .parserFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.resources),
            .module(.osLogExt),
            .targetDependency(.kanna)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .applicationClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .urlClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .target(
        module: .userDefaultsClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),

    // MARK: Test Support
    .target(
        module: .testingSupport,
        dependencies: [
            .targetDependency(.kanna)
        ],
        resources: [.process(.resources)],
        plugins: swiftLintPlugins
    ),

    // MARK: Tests
    .testTarget(
        module: .appFeatureTests,
        dependencies: [
            .module(.appFeature)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .parserFeatureTests,
        dependencies: [
            .module(.testingSupport),
            .module(.animatedImageFeature),
            .module(.appFeature),
            .module(.appModels),
            .module(.appTools),
            .module(.networkingFeature),
            .module(.parserFeature),
            .module(.urlClient),
            .targetDependency(.kanna)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .downloadsFeatureTests,
        dependencies: [
            .module(.testingSupport),
            .module(.appFeature),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.appTools),
            .module(.applicationClient),
            .module(.backgroundProcessingClient),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.detailFeature),
            .module(.dfClient),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.downloadsFeature),
            .module(.fileClient),
            .module(.hapticsClient),
            .module(.imageClient),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.readingFeature),
            .module(.urlClient),
            .module(.userDefaultsClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .fileClientTests,
        dependencies: [
            .module(.appModels),
            .module(.fileClient)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .settingFeatureTests,
        dependencies: [
            .module(.appModels),
            .module(.cookieClient),
            .module(.fileClient),
            .module(.hapticsClient),
            .module(.logsClient),
            .module(.settingFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .detailFeatureTests,
        dependencies: [
            .module(.appModels),
            .module(.detailFeature),
            .module(.hapticsClient),
            .targetDependency(.composableArchitecture)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .networkingFeatureTests,
        dependencies: [
            .module(.appModels),
            .module(.networkingFeature)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .appModelsTests,
        dependencies: [
            .module(.appModels)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .swiftyOpenCCTests,
        dependencies: [
            .targetDependency(.openCC)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .imageClientTests,
        dependencies: [
            .module(.imageClient),
            .module(.appTools),
            .module(.appModels),
            .module(.testingSupport)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .imageColorsTests,
        dependencies: [
            .module(.imageColors)
        ],
        plugins: swiftLintPlugins
    ),
    // DEP-03 parity: exercises MarkdownExt.MarkdownUtil (swift-markdown-backed) against the
    // Wave 0 expected outputs originally locked on CommonMarkExt (D-09).
    .testTarget(
        module: .markdownExtTests,
        dependencies: [
            .module(.markdownExt)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .tagTranslationFeatureTests,
        dependencies: [
            .module(.appModels),
            .module(.tagTranslationFeature)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .galleryListComponentsTests,
        dependencies: [
            .module(.galleryListComponents)
        ],
        plugins: swiftLintPlugins
    ),
    .testTarget(
        module: .readingFeatureTests,
        dependencies: [
            .module(.testingSupport),
            .module(.appModels),
            .module(.appTools),
            .module(.readingFeature)
        ],
        plugins: swiftLintPlugins
    )
]

// MARK: Package
let package = Package(
    name: "AppPackage",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: targets
        .filter({
            !$0.isTest
                && $0.name != Module.testingSupport.rawValue
                && $0.name != Module.legacyCFReadStream.rawValue
        })
        .map(\.name)
        .map({ .library(name: $0, targets: [$0]) }),
    dependencies: dependencies,
    targets: targets,
    cxxLanguageStandard: .cxx14
)
