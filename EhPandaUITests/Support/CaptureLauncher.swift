import XCTest

/// One marketing capture coordinate (D-16): the screen, selection set and rendering axes a single
/// capture shows, decoded from `EHPANDA_CAPTURE_COORDINATE`. The text size and orientation are
/// fixed for every marketing capture, so no coordinate names them.
struct CaptureCoordinate: Equatable, Sendable {
    enum Screen: String, Decodable, Sendable {
        case home
        case detail
        case comments
        case filters
        case reading
        case readingLiveText = "reading-live-text"
        case downloads
        case laboratory
    }

    enum Locale: String, Decodable, Sendable {
        case english = "en"
        case german = "de"
        case japanese = "ja"
        case korean = "ko"
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"

        /// The formatting locale a capture launches with, as the regression runner launches it.
        var launchLocale: String {
            switch self {
            case .english:
                "en_US"
            case .german:
                "de_DE"
            case .japanese:
                "ja_JP"
            case .korean:
                "ko_KR"
            case .simplifiedChinese:
                "zh_CN"
            case .traditionalChinese:
                "zh_TW"
            }
        }
    }

    enum Theme: String, Decodable, Sendable {
        case light
        case dark
    }

    enum Family: String, Decodable, Sendable {
        case iphone
        case ipad
    }

    static let environmentKey = "EHPANDA_CAPTURE_COORDINATE"

    let screen: Screen
    /// The selection set, such as `nonexplicit`.
    let set: String
    let locale: Locale
    let theme: Theme
    let family: Family

    /// The coordinate's name in attachments and evidence.
    var key: String {
        [set, screen.rawValue, family.rawValue, locale.rawValue, theme.rawValue].joined(separator: "__")
    }

    /// The coordinate the runner names through `TEST_RUNNER_EHPANDA_CAPTURE_COORDINATE`. Without one
    /// the capture fails rather than pick a default, so no run can stand in for a coordinate it was
    /// not given.
    static func fromEnvironment() throws -> Self {
        let json = try XCTUnwrap(
            ProcessInfo.processInfo.environment[environmentKey],
            "Run with TEST_RUNNER_EHPANDA_CAPTURE_COORDINATE naming one coordinate as JSON."
        )
        do {
            return try JSONDecoder().decode(Self.self, from: Data(json.utf8))
        } catch {
            XCTFail("The capture coordinate is malformed: \(json)")
            throw error
        }
    }
}

extension CaptureCoordinate: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case screen
        case set
        case locale
        case theme
        case family
    }

    /// Decodes a coordinate with exactly its five keys and a set named like a selection set.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = Set(container.allKeys.map(\.stringValue))
        guard keys == Set(CodingKeys.allCases.map(\.stringValue)) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "a coordinate has exactly \(CodingKeys.allCases)")
            )
        }
        screen = try container.decode(Screen.self, forKey: .screen)
        set = try container.decode(String.self, forKey: .set)
        guard set.wholeMatch(of: /[a-z][a-z0-9-]*/) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .set, in: container, debugDescription: "not a set ID")
        }
        locale = try container.decode(Locale.self, forKey: .locale)
        theme = try container.decode(Theme.self, forKey: .theme)
        family = try container.decode(Family.self, forKey: .family)
    }
}

/// A copy of the runner-named marketing fixture version in the test's own temporary directory.
///
/// The fixture holds real gallery content, so it never enters the repository. The runner names a
/// local fixture version directory through `TEST_RUNNER_EHPANDA_CAPTURE_SOURCE` (for example
/// `.capture/marketing/current`); the copy is what the app reads, so a capture never reads
/// `.capture/` directly. Without that input the capture fails rather than skip.
struct CaptureFixtureCopy: Sendable {
    static let sourceKey = "EHPANDA_CAPTURE_SOURCE"

    /// The temporary directory this copy created; ``remove()`` deletes it.
    let root: URL
    let version: URL
    let fixtureVersion: String
    let selection: CaptureFixtureSelection

    static func make() throws -> Self {
        let sourcePath = try XCTUnwrap(
            ProcessInfo.processInfo.environment[sourceKey],
            "Run with TEST_RUNNER_EHPANDA_CAPTURE_SOURCE naming a marketing fixture version directory."
        )
        // A `current` link is resolved once, so the copy is one fixed version.
        let source = URL(filePath: sourcePath, directoryHint: .isDirectory).resolvingSymlinksInPath()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "Capture-\(UUID().uuidString)", directoryHint: .isDirectory)
        let version = root.appending(path: source.lastPathComponent, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: version)

        let manifest = try JSONDecoder().decode(
            CaptureFixtureManifest.self,
            from: Data(contentsOf: version.appending(path: "manifest.json"))
        )
        let selection = try JSONDecoder().decode(
            CaptureFixtureSelection.self,
            from: Data(contentsOf: version.appending(path: "selection.json"))
        )
        return Self(root: root, version: version, fixtureVersion: manifest.fixtureVersion, selection: selection)
    }

    func remove() throws {
        try FileManager.default.removeItem(at: root)
    }
}

private struct CaptureFixtureManifest: Decodable {
    let fixtureVersion: String
}

/// The parts of `selection.json` a capture verifies its screens against.
struct CaptureFixtureSelection: Decodable, Sendable {
    struct Scene: Decodable, Sendable {
        let home: Home
        let flow: Flow
        let downloads: [Download]
    }

    struct Home: Decodable, Sendable {
        let hero: Hero
        let frontpage: [String]
        let toplists: [String: [String]]
    }

    struct Hero: Decodable, Sendable {
        let galleries: [String]
    }

    struct Flow: Decodable, Sendable {
        let gallery: String
        let readerPage: Int
        let liveTextPage: Int
    }

    struct Download: Decodable, Sendable {
        let gallery: String
    }

    let selectionID: String
    let scenes: [String: Scene]

    func scene(_ set: String) throws -> Scene {
        try XCTUnwrap(scenes[set], "The selection has no \(set) scene.")
    }
}

extension CaptureFixtureSelection.Home {
    /// Home's galleries in display order: the cards, the front page, then each Toplists period.
    func galleryIDs() throws -> [String] {
        let toplists = try ["yesterday", "pastMonth", "pastYear", "allTime"].flatMap { period in
            try XCTUnwrap(toplists[period], "The selection has no \(period) Toplists.")
        }
        return hero.galleries + frontpage + toplists
    }
}

/// The app's capture diagnostics, as the accessibility value of `capture_diagnostics` carries them.
struct CaptureLaunchDiagnostics: Decodable, Equatable {
    struct Rendering: Decodable, Equatable {
        let language: String
        let locale: String
        let appearance: String
        let textSize: String
        let family: String
    }

    let screenID: String?
    let selectionID: String
    let setID: String
    let fixtureVersion: String
    let galleryIDs: [String]
    let page: Int?
    let readiness: String
    let pendingImages: Int
    let unknownRequests: [String]
    let blockers: [String]
    let rendering: Rendering
}

/// Launches the actual app on one marketing coordinate and verifies the screen it settles on.
///
/// The launcher sets the coordinate's appearance and portrait orientation on the simulator and
/// its language and formatting locale on the launch. The text size stays the simulator's own and
/// is verified instead of set: a text size the app overrides for its window, while the system
/// setting differs, renders some toolbar glyphs at the system's size.
struct CaptureLauncher: Sendable {
    /// The text size of every marketing capture (D-16 has no Dynamic Type axis).
    static let textSize = "large"

    let coordinate: CaptureCoordinate
    let fixture: CaptureFixtureCopy
    private let restoredAppearance: XCUIDevice.Appearance
    private let restoredOrientation: UIDeviceOrientation

    @MainActor
    init(coordinate: CaptureCoordinate) throws {
        let family: CaptureCoordinate.Family? = switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            .iphone
        case .pad:
            .ipad
        default:
            nil
        }
        guard family == coordinate.family else {
            XCTFail("The \(coordinate.family.rawValue) coordinate cannot run on this \(UIDevice.current.model).")
            throw CaptureLaunchError.wrongFamily
        }
        self.coordinate = coordinate
        fixture = try CaptureFixtureCopy.make()
        restoredAppearance = XCUIDevice.shared.appearance
        restoredOrientation = XCUIDevice.shared.orientation
    }

    /// Puts the simulator's appearance and orientation back as they were and removes the copy.
    @MainActor
    func tearDown() throws {
        XCUIDevice.shared.appearance = restoredAppearance
        XCUIDevice.shared.orientation = restoredOrientation
        try fixture.remove()
    }

    /// Launches `app` on the coordinate and returns its diagnostics once the screen is ready,
    /// failing unless they show exactly the coordinate's screen, selection and rendering.
    @MainActor
    func launch(_ app: XCUIApplication) throws -> (json: String, diagnostics: CaptureLaunchDiagnostics) {
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = switch coordinate.theme {
        case .light:
            .light
        case .dark:
            .dark
        }
        let configuration = CaptureConfiguration(
            purpose: "marketingReal",
            scenarioID: coordinate.screen.rawValue,
            fixtureID: coordinate.set
        )
        app.launchArguments = [
            "-AppleLanguages", "(\(coordinate.locale.rawValue))",
            "-AppleLocale", coordinate.locale.launchLocale
        ]
        app.launchEnvironment = [
            "EHPANDA_CAPTURE_CONFIGURATION": try configuration.json(),
            "EHPANDA_CAPTURE_FIXTURES": fixture.version.path(percentEncoded: false),
            // Dates render in one time zone on every host (D-10).
            "TZ": "UTC"
        ]
        app.launch()

        let settled = try app.settledCaptureDiagnostics(as: CaptureLaunchDiagnostics.self, during: coordinate.key)
        let orientation = XCUIDevice.shared.orientation
        let expected = try expectedDiagnostics()
        XCTAssertEqual(orientation, .portrait, "The \(coordinate.key) capture left portrait.")
        XCTAssertEqual(settled.diagnostics, expected, "The \(coordinate.key) capture differs.")
        return settled
    }

    private func expectedDiagnostics() throws -> CaptureLaunchDiagnostics {
        let scene = try fixture.selection.scene(coordinate.set)
        let galleryIDs: [String] = switch coordinate.screen {
        case .home:
            try scene.home.galleryIDs()
        case .detail, .comments, .reading, .readingLiveText:
            [scene.flow.gallery]
        case .downloads:
            scene.downloads.map(\.gallery)
        case .filters, .laboratory:
            []
        }
        let page: Int? = switch coordinate.screen {
        case .reading:
            scene.flow.readerPage
        case .readingLiveText:
            scene.flow.liveTextPage
        case .home, .detail, .comments, .filters, .downloads, .laboratory:
            nil
        }
        return CaptureLaunchDiagnostics(
            screenID: coordinate.screen.rawValue,
            selectionID: fixture.selection.selectionID,
            setID: coordinate.set,
            fixtureVersion: fixture.fixtureVersion,
            galleryIDs: galleryIDs,
            page: page,
            readiness: "ready",
            pendingImages: 0,
            unknownRequests: [],
            blockers: [],
            rendering: .init(
                language: coordinate.locale.rawValue,
                locale: coordinate.locale.launchLocale,
                appearance: coordinate.theme.rawValue,
                textSize: Self.textSize,
                family: coordinate.family.rawValue
            )
        )
    }
}

enum CaptureLaunchError: Error {
    case wrongFamily
}

/// The capture configuration a launch passes in `EHPANDA_CAPTURE_CONFIGURATION`.
private struct CaptureConfiguration: Encodable {
    let purpose: String
    let scenarioID: String
    let fixtureID: String

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let json = String(bytes: try encoder.encode(self), encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "not UTF-8"))
        }
        return json
    }
}

@MainActor
extension XCUIApplication {
    /// Waits until the capture reports its screen ready or failed, then reads the diagnostics, both
    /// as the app wrote them and decoded.
    func settledCaptureDiagnostics<Diagnostics: Decodable>(
        as type: Diagnostics.Type,
        during launch: String
    ) throws -> (json: String, diagnostics: Diagnostics) {
        let element = descendants(matching: .any).matching(identifier: "capture_diagnostics").firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 30), "The \(launch) did not start a capture.")
        let settles = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@ OR value CONTAINS %@",
                #""readiness":"ready""#,
                #""readiness":"failed""#
            ),
            object: element
        )
        let outcome = XCTWaiter.wait(for: [settles], timeout: 60)
        let value = try XCTUnwrap(element.value as? String, "The capture diagnostics have no value.")
        XCTAssertEqual(outcome, .completed, "The \(launch) never finished loading: \(value)")
        do {
            return (value, try JSONDecoder().decode(type, from: Data(value.utf8)))
        } catch {
            XCTFail("The capture diagnostics are not readable on the \(launch): \(value)")
            throw error
        }
    }
}

extension XCUIScreen {
    /// How many screenshots a capture takes, a second apart, waiting for two in a row to agree.
    private static let settleAttempts = 10

    /// The screen as the system renders a screenshot, once two renders a second apart are
    /// byte-identical; when they never agree, the last render with `isSettled` false.
    ///
    /// The system renders a screenshot whole, so one screen gives the same bytes on every launch.
    /// The display's framebuffer, which `simctl io screenshot` reads, keeps Liquid Glass as it last
    /// composed it, so one screen's glass can differ by a level between cold launches.
    @MainActor
    func settledScreenshot() -> (png: Data, isSettled: Bool) {
        var previous = screenshot().pngRepresentation
        for _ in 1..<Self.settleAttempts {
            Thread.sleep(forTimeInterval: 1)
            let current = screenshot().pngRepresentation
            if current == previous {
                return (current, true)
            }
            previous = current
        }
        return (previous, false)
    }
}
