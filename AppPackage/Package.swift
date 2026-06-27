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
    case appFeature = "AppFeature"
    case appModels = "AppModels"
    case authorizationClient = "AuthorizationClient"
    case composableArchitectureExt = "ComposableArchitectureExt"
    case foundationExt = "FoundationExt"
    case hapticsClient = "HapticsClient"
    case loggerClient = "LoggerClient"
    case resources = "Resources"
    case swiftUINavigationExt = "SwiftUINavigationExt"
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
            .module(.appModels),
            .module(.authorizationClient),
            .module(.composableArchitectureExt),
            .module(.foundationExt),
            .module(.hapticsClient),
            .module(.loggerClient),
            .module(.resources),
            .module(.swiftUINavigationExt),
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
        resources: [.process(.resources)],
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
        module: .utilities,
        dependencies: [
            .module(.appModels)
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
        module: .hapticsClient,
        dependencies: [
            .module(.utilities),
            .targetDependency(.composableArchitecture)
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
            .module(.appFeature),
            .module(.appModels),
            .module(.foundationExt),
            .module(.hapticsClient),
            .module(.loggerClient),
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
