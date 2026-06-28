// swift-tools-version: 6.3.1

import PackageDescription

// MARK: Dependency
var dependencies: [PackageDescription.Package.Dependency] = [
    // Pinned to match the app's resolved version; 1.1.x deprecates ColorfulView.
    .package(url: "https://github.com/Co2333/Colorful", .upToNextMinor(from: "1.0.1")),
    .package(url: "https://github.com/EhPanda-Team/AlertKit", branch: "custom"),
    .package(url: "https://github.com/EhPanda-Team/DeprecatedAPI", branch: "main"),
    .package(url: "https://github.com/EhPanda-Team/TTProgressHUD", branch: "custom"),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "3.0.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageWebPCoder", from: "0.14.0"),
    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.0"),
    .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", from: "2.0.0"),
    .package(url: "https://github.com/ddddxxx/SwiftyOpenCC", exact: "2.0.0-beta"),
    .package(url: "https://github.com/fermoya/SwiftUIPager", from: "2.5.0"),
    .package(url: "https://github.com/gonzalezreal/SwiftCommonMark", from: "1.0.0"),
    .package(url: "https://github.com/jathu/UIImageColors", from: "2.2.0"),
    .package(url: "https://github.com/markrenaud/FilePicker", from: "1.0.0"),
    .package(url: "https://github.com/onevcat/Kingfisher", from: "8.0.0"),
    .package(url: "https://github.com/paololeonardi/WaterfallGrid", from: "1.0.0"),
    .package(
        url: "https://github.com/pointfreeco/swift-composable-architecture",
        from: "1.25.0"
    ),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.8.0"),
    .package(url: "https://github.com/tid-kijyun/Kanna", from: "6.0.0")
]

extension PackageDescription.Target.Dependency {
    static let alertKit: Self = .product(name: "AlertKit", package: "AlertKit")
    static let colorful: Self = .product(name: "Colorful", package: "Colorful")
    static let commonMark: Self = .product(name: "CommonMark", package: "SwiftCommonMark")
    static let composableArchitecture: Self = .product(
        name: "ComposableArchitecture",
        package: "swift-composable-architecture"
    )
    static let deprecatedAPI: Self = .product(name: "DeprecatedAPI", package: "DeprecatedAPI")
    static let filePicker: Self = .product(name: "FilePicker", package: "FilePicker")
    static let kanna: Self = .product(name: "Kanna", package: "Kanna")
    static let kingfisher: Self = .product(name: "Kingfisher", package: "Kingfisher")
    static let openCC: Self = .product(name: "OpenCC", package: "SwiftyOpenCC")
    static let sdWebImageSwiftUI: Self = .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI")
    static let sdWebImageWebPCoder: Self = .product(name: "SDWebImageWebPCoder", package: "SDWebImageWebPCoder")
    static let sfSafeSymbols: Self = .product(name: "SFSafeSymbols", package: "SFSafeSymbols")
    static let swiftUINavigation: Self = .product(name: "SwiftUINavigation", package: "swift-navigation")
    static let swiftUIPager: Self = .product(name: "SwiftUIPager", package: "SwiftUIPager")
    static let swiftyBeaver: Self = .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
    static let ttProgressHUD: Self = .product(name: "TTProgressHUD", package: "TTProgressHUD")
    static let uiImageColors: Self = .product(name: "UIImageColors", package: "UIImageColors")
    static let waterfallGrid: Self = .product(name: "WaterfallGrid", package: "WaterfallGrid")
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
    case alertKitExt = "AlertKitExt"
    case animatedImageFeature = "AnimatedImageFeature"
    case appComponents = "AppComponents"
    case appDelegateClient = "AppDelegateClient"
    case appFeature = "AppFeature"
    case appLaunchAutomationClient = "AppLaunchAutomationClient"
    case appModels = "AppModels"
    case authorizationClient = "AuthorizationClient"
    case backgroundProcessingClient = "BackgroundProcessingClient"
    case clipboardClient = "ClipboardClient"
    case composableArchitectureExt = "ComposableArchitectureExt"
    case cookieClient = "CookieClient"
    case dfClient = "DFClient"
    case databaseClient = "DatabaseClient"
    case dateSeekFeature = "DateSeekFeature"
    case detailFeature = "DetailFeature"
    case deviceClient = "DeviceClient"
    case downloadClient = "DownloadClient"
    case downloadsFeature = "DownloadsFeature"
    case favoritesFeature = "FavoritesFeature"
    case fileClient = "FileClient"
    case filtersFeature = "FiltersFeature"
    case foundationExt = "FoundationExt"
    case galleryListComponents = "GalleryListComponents"
    case hapticsClient = "HapticsClient"
    case homeFeature = "HomeFeature"
    case imageClient = "ImageClient"
    case libraryClient = "LibraryClient"
    case loggerClient = "LoggerClient"
    case migrationFeature = "MigrationFeature"
    case networkingFeature = "NetworkingFeature"
    case parserFeature = "ParserFeature"
    case quickSearchFeature = "QuickSearchFeature"
    case readingFeature = "ReadingFeature"
    case resources = "Resources"
    case searchFeature = "SearchFeature"
    case settingFeature = "SettingFeature"
    case swiftUINavigationExt = "SwiftUINavigationExt"
    case ttProgressHUDExt = "TTProgressHUDExt"
    case uiApplicationClient = "UIApplicationClient"
    case urlClient = "URLClient"
    case userDefaultsClient = "UserDefaultsClient"
    case utilities = "Utilities"

    // Test targets
    case appFeatureTests = "AppFeatureTests"
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
        swiftSettings: [PackageDescription.SwiftSetting]? = nil,
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
        swiftSettings: [PackageDescription.SwiftSetting]? = nil,
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
            .module(.appDelegateClient),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.authorizationClient),
            .module(.backgroundProcessingClient),
            .module(.clipboardClient),
            .module(.composableArchitectureExt),
            .module(.cookieClient),
            .module(.databaseClient),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.dfClient),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.downloadsFeature),
            .module(.favoritesFeature),
            .module(.fileClient),
            .module(.filtersFeature),
            .module(.foundationExt),
            .module(.hapticsClient),
            .module(.homeFeature),
            .module(.imageClient),
            .module(.libraryClient),
            .module(.loggerClient),
            .module(.migrationFeature),
            .module(.networkingFeature),
            .module(.parserFeature),
            .module(.quickSearchFeature),
            .module(.readingFeature),
            .module(.resources),
            .module(.searchFeature),
            .module(.animatedImageFeature),
            .module(.settingFeature),
            .module(.swiftUINavigationExt),
            .module(.ttProgressHUDExt),
            .module(.uiApplicationClient),
            .module(.urlClient),
            .module(.userDefaultsClient),
            .module(.utilities),
            .targetDependency(.alertKit),
            .targetDependency(.colorful),
            .targetDependency(.commonMark),
            .targetDependency(.composableArchitecture),
            .targetDependency(.deprecatedAPI),
            .targetDependency(.filePicker),
            .targetDependency(.kanna),
            .targetDependency(.kingfisher),
            .targetDependency(.openCC),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sdWebImageWebPCoder),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.swiftUINavigation),
            .targetDependency(.swiftUIPager),
            .targetDependency(.swiftyBeaver),
            .targetDependency(.ttProgressHUD),
            .targetDependency(.uiImageColors),
            .targetDependency(.waterfallGrid)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appModels,
        dependencies: [
            .module(.resources),
            .targetDependency(.commonMark),
            .targetDependency(.composableArchitecture),
            .targetDependency(.openCC),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.swiftyBeaver)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .resources,
        resources: [.process(.resources)],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .composableArchitectureExt,
        dependencies: [
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .deviceClient,
        dependencies: [
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .downloadClient,
        dependencies: [
            .module(.appModels),
            .module(.databaseClient),
            .module(.foundationExt),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.parserFeature),
            .module(.resources),
            .module(.animatedImageFeature),
            .module(.urlClient),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kanna)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .fileClient,
        dependencies: [
            .module(.appModels),
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .foundationExt,
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .swiftUINavigationExt,
        dependencies: [
            .targetDependency(.swiftUINavigation)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .ttProgressHUDExt,
        dependencies: [
            .module(.resources),
            .module(.swiftUINavigationExt),
            .targetDependency(.swiftUINavigation),
            .targetDependency(.ttProgressHUD)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .utilities,
        dependencies: [
            .module(.appModels)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appDelegateClient,
        dependencies: [
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appLaunchAutomationClient,
        dependencies: [
            .module(.appModels),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .authorizationClient,
        dependencies: [
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .backgroundProcessingClient,
        dependencies: [
            .module(.appModels),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .clipboardClient,
        dependencies: [
            .module(.animatedImageFeature),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .cookieClient,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .module(.resources),
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .dfClient,
        dependencies: [
            .module(.networkingFeature),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .networkingFeature,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .module(.parserFeature),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.deprecatedAPI),
            .targetDependency(.kanna)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .databaseClient,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        resources: [.process(.resources)],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .hapticsClient,
        dependencies: [
            .module(.swiftUINavigationExt),
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .appComponents,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .module(.parserFeature),
            .module(.resources),
            .module(.utilities),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .galleryListComponents,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.resources),
            .module(.utilities),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.waterfallGrid)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .animatedImageFeature,
        dependencies: [
            .targetDependency(.sdWebImageSwiftUI)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .alertKitExt,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.resources),
            .targetDependency(.alertKit)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .migrationFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.databaseClient),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .filtersFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.databaseClient),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .dateSeekFeature,
        dependencies: [
            .module(.appModels),
            .module(.hapticsClient),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .quickSearchFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.databaseClient),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .downloadsFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.composableArchitectureExt),
            .module(.detailFeature),
            .module(.downloadClient),
            .module(.foundationExt),
            .module(.galleryListComponents),
            .module(.readingFeature),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .module(.ttProgressHUDExt),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.sfSafeSymbols)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .favoritesFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.composableArchitectureExt),
            .module(.databaseClient),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.downloadClient),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .module(.utilities),
            .targetDependency(.alertKit),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .settingFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appDelegateClient),
            .module(.appModels),
            .module(.authorizationClient),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.databaseClient),
            .module(.deviceClient),
            .module(.dfClient),
            .module(.fileClient),
            .module(.foundationExt),
            .module(.hapticsClient),
            .module(.libraryClient),
            .module(.loggerClient),
            .module(.networkingFeature),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .module(.ttProgressHUDExt),
            .module(.uiApplicationClient),
            .module(.userDefaultsClient),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.filePicker),
            .targetDependency(.sfSafeSymbols)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .searchFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appModels),
            .module(.composableArchitectureExt),
            .module(.databaseClient),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.downloadClient),
            .module(.filtersFeature),
            .module(.foundationExt),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .homeFeature,
        dependencies: [
            .module(.alertKitExt),
            .module(.appComponents),
            .module(.appModels),
            .module(.composableArchitectureExt),
            .module(.databaseClient),
            .module(.dateSeekFeature),
            .module(.detailFeature),
            .module(.downloadClient),
            .module(.filtersFeature),
            .module(.foundationExt),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.libraryClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .module(.utilities),
            .targetDependency(.alertKit),
            .targetDependency(.colorful),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.swiftUIPager),
            .targetDependency(.uiImageColors)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .detailFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.clipboardClient),
            .module(.composableArchitectureExt),
            .module(.cookieClient),
            .module(.databaseClient),
            .module(.downloadClient),
            .module(.fileClient),
            .module(.filtersFeature),
            .module(.foundationExt),
            .module(.galleryListComponents),
            .module(.hapticsClient),
            .module(.networkingFeature),
            .module(.quickSearchFeature),
            .module(.readingFeature),
            .module(.resources),
            .module(.swiftUINavigationExt),
            .module(.ttProgressHUDExt),
            .module(.uiApplicationClient),
            .module(.urlClient),
            .module(.utilities),
            .targetDependency(.commonMark),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .readingFeature,
        dependencies: [
            .module(.appComponents),
            .module(.appDelegateClient),
            .module(.appModels),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.databaseClient),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.foundationExt),
            .module(.hapticsClient),
            .module(.imageClient),
            .module(.networkingFeature),
            .module(.resources),
            .module(.animatedImageFeature),
            .module(.swiftUINavigationExt),
            .module(.ttProgressHUDExt),
            .module(.urlClient),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sfSafeSymbols),
            .targetDependency(.swiftUIPager),
            .targetDependency(.ttProgressHUD)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .imageClient,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .module(.animatedImageFeature),
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .libraryClient,
        dependencies: [
            .module(.appModels),
            .module(.animatedImageFeature),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kingfisher),
            .targetDependency(.sdWebImageSwiftUI),
            .targetDependency(.sdWebImageWebPCoder),
            .targetDependency(.swiftyBeaver),
            .targetDependency(.uiImageColors)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .loggerClient,
        dependencies: [
            .module(.appModels),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .parserFeature,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .module(.resources),
            .module(.utilities),
            .targetDependency(.kanna)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .uiApplicationClient,
        dependencies: [
            .module(.foundationExt),
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .urlClient,
        dependencies: [
            .module(.appModels),
            .module(.foundationExt),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),
    .target(
        module: .userDefaultsClient,
        dependencies: [
            .module(.utilities),
            .targetDependency(.composableArchitecture)
        ],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    ),

    // MARK: Tests
    .testTarget(
        module: .appFeatureTests,
        dependencies: [
            .module(.appDelegateClient),
            .module(.appFeature),
            .module(.appLaunchAutomationClient),
            .module(.appModels),
            .module(.backgroundProcessingClient),
            .module(.clipboardClient),
            .module(.cookieClient),
            .module(.databaseClient),
            .module(.detailFeature),
            .module(.dfClient),
            .module(.deviceClient),
            .module(.downloadClient),
            .module(.downloadsFeature),
            .module(.fileClient),
            .module(.foundationExt),
            .module(.hapticsClient),
            .module(.imageClient),
            .module(.libraryClient),
            .module(.loggerClient),
            .module(.networkingFeature),
            .module(.parserFeature),
            .module(.readingFeature),
            .module(.animatedImageFeature),
            .module(.uiApplicationClient),
            .module(.urlClient),
            .module(.userDefaultsClient),
            .module(.utilities),
            .targetDependency(.composableArchitecture),
            .targetDependency(.kanna),
            .targetDependency(.kingfisher),
            .targetDependency(.sfSafeSymbols)
        ],
        resources: [.process(.resources)],
        swiftSettings: sharedSwiftSettings,
        plugins: swiftLintPlugins
    )
]

// MARK: Package
let package = Package(
    name: "AppPackage",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: targets
        .filter({ !$0.isTest })
        .map(\.name)
        .map({ .library(name: $0, targets: [$0]) }),
    dependencies: dependencies,
    targets: targets
)
