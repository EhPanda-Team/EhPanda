// swift-tools-version: 6.4

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
    // TelemetryDeck's Swift SDK. The repository is named `SwiftSDK` while the product it vends is
    // named `TelemetryDeck`, so the `.product(name:package:)` alias below cannot use one name for
    // both. Pinned with an explicit `.upToNextMajor` range rather than a bare `from:`: 3.0.0 has
    // only pre-release tags, and a bare `from:` can resolve one of those.
    .package(url: "https://github.com/TelemetryDeck/SwiftSDK", .upToNextMajor(from: "2.14.1")),
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
    static let telemetryDeck: Self = .product(name: "TelemetryDeck", package: "SwiftSDK")
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
    case analyticsClient = "AnalyticsClient"
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
    case previewSupport = "PreviewSupport"
    case quickSearchFeature = "QuickSearchFeature"
    case readingFeature = "ReadingFeature"
    case readingSettingFeature = "ReadingSettingFeature"
    case resources = "Resources"
    case searchFeature = "SearchFeature"
    case settingFeature = "SettingFeature"
    case sfSafeSymbolsExt = "SFSafeSymbolsExt"
    case systemNotification = "SystemNotification"
    case tagTranslationFeature = "TagTranslationFeature"
    case userDefaultsClient = "UserDefaultsClient"

    // Test support
    case testingSupport = "TestingSupport"

    // Test targets
    case appFeatureTests = "AppFeatureTests"
    case appToolsTests = "AppToolsTests"
    case homeFeatureTests = "HomeFeatureTests"
    case parserFeatureTests = "ParserFeatureTests"
    case downloadsFeatureTests = "DownloadsFeatureTests"
    case fileClientTests = "FileClientTests"
    case settingFeatureTests = "SettingFeatureTests"
    case detailFeatureTests = "DetailFeatureTests"
    case networkingFeatureTests = "NetworkingFeatureTests"
    case appModelsTests = "AppModelsTests"
    case cookieClientTests = "CookieClientTests"
    case swiftyOpenCCTests = "SwiftyOpenCCTests"
    case imageClientTests = "ImageClientTests"
    case imageColorsTests = "ImageColorsTests"
    case markdownExtTests = "MarkdownExtTests"
    case tagTranslationFeatureTests = "TagTranslationFeatureTests"
    case galleryListComponentsTests = "GalleryListComponentsTests"
    case readingFeatureTests = "ReadingFeatureTests"
    case systemNotificationTests = "SystemNotificationTests"
    case analyticsClientTests = "AnalyticsClientTests"
    case searchFeatureTests = "SearchFeatureTests"
    case favoritesFeatureTests = "FavoritesFeatureTests"
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

// MARK: Helper methods
@MainActor
extension PackageDescription.Target {
    static func target(
        module: Module,
        dependencies: [Module.Dependency] = .init(),
        resources: [PackageDescription.Resource]? = nil,
        swiftSettings: [PackageDescription.SwiftSetting]? = sharedSwiftSettings,
        plugins: [PackageDescription.Target.PluginUsage] = swiftLintPlugins
    ) -> PackageDescription.Target {
        target(
            name: module.rawValue,
            dependencies: dependencies.map(\.targetDependency),
            resources: resources,
            swiftSettings: swiftSettings,
            plugins: plugins
        )
    }

    static func testTarget(
        module: Module,
        dependencies: [Module.Dependency] = .init(),
        resources: [PackageDescription.Resource]? = nil,
        swiftSettings: [PackageDescription.SwiftSetting]? = sharedSwiftSettings,
        plugins: [PackageDescription.Target.PluginUsage] = swiftLintPlugins
    ) -> PackageDescription.Target {
        testTarget(
            name: module.rawValue,
            dependencies: dependencies.map(\.targetDependency),
            resources: resources,
            swiftSettings: swiftSettings,
            plugins: plugins
        )
    }
}

// MARK: Target
let targets: [PackageDescription.Target] = [
    .target(
        module: .appFeature,
        dependencies: [
            .module(.analyticsClient),
            .module(.appComponents),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.appTools),
            .module(.applicationClient),
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
            .module(.systemNotification),
            .module(.userDefaultsClient),
            .targetDependency(.colorfulX),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kanna),
            .targetDependency(.kingfisher),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sdWebImageWebPCoder),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process("Resources")]
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
        resources: [.process("Resources")]
    ),
    .target(
        module: .resources,
        resources: [.process("Resources")]
    ),
    .target(
        module: .deviceClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .downloadClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.backgroundProcessingClient),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.osLogExt),
            .module(.parserFeature),
            .module(.resources),
            .module(.animatedImageFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kanna),
            .targetDependency(.sharing)
        ]
    ),
    .target(
        module: .fileClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture),
            .targetDependency(.openCC)
        ]
    ),
    .target(
        module: .systemNotification,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ]
    ),
    .target(
        module: .appTools,
        dependencies: [
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .appLaunchAutomationClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .backgroundProcessingClient,
        dependencies: [
            .module(.osLogExt),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .clipboardClient,
        dependencies: [
            .module(.animatedImageFeature),
            .targetDependency(.composableArchitecture)
        ]
    ),
    // The sole owner of the TelemetryDeck SDK: no other module may import it, so every payload
    // that leaves the app is minted through this module's closed signal vocabulary. The
    // `.cookieClient` edge exists because the per-signal login-state snapshot reads
    // `@SharedReader(.didLogin)`, whose key is declared there. The `.deviceClient` edge exists
    // because the orientation enricher reads the window scene through it rather than reaching for
    // UIKit from this module.
    .target(
        module: .analyticsClient,
        dependencies: [
            .module(.appModels),
            .module(.cookieClient),
            .module(.deviceClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing),
            .targetDependency(.telemetryDeck)
        ]
    ),
    .target(
        module: .cookieClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .dfClient,
        dependencies: [
            .module(.networkingFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher)
        ]
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
        ]
    ),
    .target(
        module: .hapticsClient,
        dependencies: [
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .appComponents,
        dependencies: [
            .module(.sfSafeSymbolsExt),
            .module(.appModels),
            .module(.appTools),
            .module(.deviceClient),
            .module(.hapticsClient),
            .module(.parserFeature),
            .module(.resources),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .galleryListComponents,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.previewSupport),
            .module(.tagTranslationFeature),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .animatedImageFeature,
        dependencies: [
            .targetDependency(.sdWebImageSwiftUI)
        ]
    ),
    // Preview-only support: a frozen table of stable fixture identities. Foundation-only and
    // depended on by feature modules purely so their `#Preview` fixtures stop minting random
    // UUIDs; nothing in a production code path may reference it.
    .target(
        module: .previewSupport
    ),
    // App-owned markdown helper: the sole owner of the swift-markdown (`Markdown`) dependency,
    // keeping parser node types out of feature modules (D-08, D-09).
    .target(
        module: .markdownExt,
        dependencies: [
            .targetDependency(.markdown)
        ]
    ),
    .target(
        module: .sfSafeSymbolsExt,
        dependencies: [
            .targetDependency(.sfSafeSymbols)
        ]
    ),
    // App-owned local dominant-color module. Clean-room reimplementation of the
    // app-needed dominant-color surface, replacing the external jathu/UIImageColors
    // package while preserving color-selection output (DEP-02, D-01/D-04/D-16).
    // Modernized I/O: a CGImage goes in and non-optional SwiftUI Colors come out.
    .target(
        module: .imageColors
    ),
    // Internal isolation module for the one deprecated CFNetwork call the app relies on
    // (`CFReadStreamCreateForHTTPRequest`, for domain fronting — DEP-06 / D-12/D-14). Compiled
    // with `-suppress-warnings` so the unavoidable deprecation notice is silenced at this single
    // documented boundary. Replaces the former external `DeprecatedAPI` package (inlined 01-09).
    // Kept out of `products` (below): it is an internal implementation detail, not a public library.
    .target(
        module: .legacyCFReadStream,
        swiftSettings: sharedSwiftSettings + [.unsafeFlags(["-suppress-warnings"])]
    ),
    .target(
        module: .osLogExt,
        dependencies: [
            .module(.appTools)
        ]
    ),
    .target(
        module: .logsClient,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.osLogExt),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .tagTranslationFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.markdownExt)
        ]
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
        resources: [.process("Resources")]
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
        resources: [.process("Resources")]
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
        resources: [.process("Resources")]
    ),
    .target(
        module: .quickSearchFeature,
        dependencies: [
            .module(.analyticsClient),
            .module(.appComponents),
            .module(.appModels),
            .module(.resources),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .downloadsFeature,
        dependencies: [
            .module(.analyticsClient),
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
            .module(.systemNotification),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .favoritesFeature,
        dependencies: [
            .module(.analyticsClient),
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.cookieClient),
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
        resources: [.process("Resources")]
    ),
    .target(
        module: .settingFeature,
        dependencies: [
            .module(.analyticsClient),
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
            .module(.systemNotification),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .searchFeature,
        dependencies: [
            .module(.analyticsClient),
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
            .module(.previewSupport),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.sfSafeSymbolsExt),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .homeFeature,
        dependencies: [
            .module(.analyticsClient),
            .module(.appComponents),
            .module(.appModels),
            .module(.appTools),
            .module(.cookieClient),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.filtersFeature),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.previewSupport),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.tagTranslationFeature),
            .targetDependency(.colorfulX),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .detailFeature,
        dependencies: [
            .module(.analyticsClient),
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
            .module(.systemNotification),
            .module(.tagTranslationFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.sharing)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .readingFeature,
        dependencies: [
            .module(.analyticsClient),
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
            .module(.systemNotification),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process("Resources")]
    ),
    .target(
        module: .imageClient,
        dependencies: [
            .module(.appModels),
            .module(.animatedImageFeature),
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ]
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
        ]
    ),
    .target(
        module: .parserFeature,
        dependencies: [
            .module(.appModels),
            .module(.appTools),
            .module(.resources),
            .module(.osLogExt),
            .targetDependency(.kanna)
        ]
    ),
    .target(
        module: .applicationClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .target(
        module: .userDefaultsClient,
        dependencies: [
            .module(.appTools),
            .targetDependency(.composableArchitecture)
        ]
    ),

    // MARK: Test Support
    .target(
        module: .testingSupport,
        dependencies: [
            .targetDependency(.kanna)
        ],
        resources: [.process("Resources")]
    ),

    // MARK: Tests
    .testTarget(
        module: .appFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.appFeature)
        ]
    ),
    .testTarget(
        module: .appToolsTests,
        dependencies: [
            .module(.appTools)
        ]
    ),
    .testTarget(
        module: .homeFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.homeFeature)
        ]
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
            .targetDependency(.kanna)
        ]
    ),
    .testTarget(
        module: .downloadsFeatureTests,
        dependencies: [
            .module(.analyticsClient),
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
            .module(.userDefaultsClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols)
        ]
    ),
    .testTarget(
        module: .fileClientTests,
        dependencies: [
            .module(.appModels),
            .module(.fileClient)
        ]
    ),
    .testTarget(
        module: .settingFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.appModels),
            .module(.cookieClient),
            .module(.fileClient),
            .module(.hapticsClient),
            .module(.logsClient),
            .module(.settingFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing)
        ]
    ),
    .testTarget(
        module: .detailFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.appModels),
            .module(.detailFeature),
            .module(.hapticsClient),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .testTarget(
        module: .networkingFeatureTests,
        dependencies: [
            .module(.appModels),
            .module(.networkingFeature)
        ]
    ),
    .testTarget(
        module: .appModelsTests,
        dependencies: [
            .module(.appModels)
        ]
    ),
    .testTarget(
        module: .cookieClientTests,
        dependencies: [
            .module(.cookieClient),
            .module(.appModels),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .testTarget(
        module: .swiftyOpenCCTests,
        dependencies: [
            .targetDependency(.openCC)
        ]
    ),
    .testTarget(
        module: .imageClientTests,
        dependencies: [
            .module(.imageClient),
            .module(.appTools),
            .module(.appModels),
            .module(.testingSupport)
        ]
    ),
    .testTarget(
        module: .imageColorsTests,
        dependencies: [
            .module(.imageColors)
        ]
    ),
    // DEP-03 parity: exercises MarkdownExt.MarkdownUtil (swift-markdown-backed) against the
    // Wave 0 expected outputs originally locked on CommonMarkExt (D-09).
    .testTarget(
        module: .markdownExtTests,
        dependencies: [
            .module(.markdownExt)
        ]
    ),
    .testTarget(
        module: .tagTranslationFeatureTests,
        dependencies: [
            .module(.appModels),
            .module(.tagTranslationFeature)
        ]
    ),
    .testTarget(
        module: .galleryListComponentsTests,
        dependencies: [
            .module(.galleryListComponents)
        ]
    ),
    .testTarget(
        module: .readingFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .targetDependency(.composableArchitecture),
            .module(.testingSupport),
            .module(.appModels),
            .module(.appTools),
            .module(.cookieClient),
            .module(.readingFeature)
        ]
    ),
    .testTarget(
        module: .systemNotificationTests,
        dependencies: [
            .module(.systemNotification)
        ]
    ),
    .testTarget(
        module: .analyticsClientTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.appModels),
            .module(.cookieClient),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sharing)
        ]
    ),
    .testTarget(
        module: .searchFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.appModels),
            // For building a GalleriesResult fixture: the success arm of the performed-search
            // signal buckets `response.galleries.count`, and the response type lives there.
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.searchFeature),
            .targetDependency(.composableArchitecture)
        ]
    ),
    .testTarget(
        module: .favoritesFeatureTests,
        dependencies: [
            .module(.analyticsClient),
            .module(.appModels),
            .module(.favoritesFeature),
            .targetDependency(.composableArchitecture)
        ]
    )
]

// MARK: Package
let package = Package(
    name: "AppPackage",
    defaultLocalization: "en",
    platforms: [.iOS(.v27)],
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
