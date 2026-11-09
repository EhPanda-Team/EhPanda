import AppFeature
import ComposableArchitecture
import CookieClient
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The base class of every matrix scenario class (19-CONTEXT D-04, D-08, D-11).
///
/// Language and text size come from the process: each configuration of `SnapshotMatrix.xctestplan` launches the app
/// with its `-AppleLanguages`, `-AppleLocale` and `-UIPreferredContentSizeCategoryName`, so UIKit and SwiftUI agree on
/// both. Appearance changes in process, and so does orientation on iPhone: each scenario method captures its four
/// coordinates (portrait and landscape × light and dark) through ``HostedWindowCapture``. iPadOS refuses programmatic
/// orientation changes ("the current windowing mode does not allow" them, Full Screen Apps included), so an iPad
/// process captures the one orientation its device was turned to before launch, named by
/// `EHPANDA_SNAPSHOT_ORIENTATIONS`; the window must still match the pinned geometry.
///
/// Capture is serial within each simulator clone, by the owner's approval for the screenshot runs only (D-11; owner
/// msgs 1949, 2252): XCTest's parallel testing hands whole classes to clones, each clone runs one class at a time,
/// and several clones and CI jobs run at once. No serial trait or single-worker cap is involved, and every
/// other test stays parallel (AGENTS.md test parallelism).
class SnapshotMatrixCase: XCTestCase {
    override func setUp() {
        super.setUp()
        // Dependencies clears prepared values before each XCTest case; restore the opt-in host defaults.
        UITestAutomation.prepareIfNeeded()
    }

    /// Captures, or compares, the four in-process coordinates of `id` in this process's configuration.
    ///
    /// - Parameters:
    ///   - id: The scenario ID in `scenarios.json`.
    ///   - factory: The scenario's real view and store, signed-in state and user step. `make` is called inside the
    ///     scenario's dependencies, once per attempt, so every attempt starts from the scenario's initial state.
    @MainActor
    func capture(scenario id: String, factory: ScenarioFactory) async throws {
        let run = SnapshotRunEnvironment.current
        guard let mode = run.mode, let output = run.output else {
            throw XCTSkip("Matrix scenarios run only with EHPANDA_SNAPSHOT_MODE and EHPANDA_SNAPSHOT_OUTPUT")
        }
        if let only = run.only, !only.contains(id) {
            throw XCTSkip("Not selected by EHPANDA_SNAPSHOT_ONLY")
        }
        let writer = SnapshotResultWriter(output: output)
        let scene = try await Self.foregroundScene()
        let family = scene.traitCollection.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let pins = try SnapshotPins.load()
        let inventory = try ScenarioInventory.load()
        guard let configuration = run.configuration else {
            XCTFail("EHPANDA_SNAPSHOT_CONFIGURATION is missing")
            return
        }
        let coordinates = Self.coordinates(scenario: id, family: family, configuration: configuration)
            .filter({ run.orientations.contains($0.orientation) })
        // A shard's re-run (Scripts/visual/run-shard.sh) runs a class again in every configuration of the
        // invocation; a scenario that already wrote every line of this configuration keeps them (run 42577585956
        // re-captured, then dropped, whole configurations a crash had left finished).
        // Captured coordinates count, as in Scripts/visual/snapshot_shard.py's `pending`; a scenario with none
        // counts its not-applicable lines.
        if run.keepCaptured {
            let recorded = try writer.recordedKeys()
            let captured = coordinates.filter({ inventory.notApplicableReason(for: $0, pins: pins) == nil })
            let needed = captured.isEmpty ? coordinates : captured
            if !needed.isEmpty, needed.allSatisfy({ recorded.contains($0.key) }) {
                throw XCTSkip("Captured before this re-run (EHPANDA_SNAPSHOT_KEEP_CAPTURED)")
            }
        }
        if let failure = configuration.failedCheck() {
            for coordinate in coordinates {
                try writer.append(.failure(coordinate.key, reason: "configuration-\(failure)"))
            }
            XCTFail("Configuration check failed: \(failure)")
            return
        }
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let originalTimeZone = NSTimeZone.default
        let animations = UIView.areAnimationsEnabled
        NSTimeZone.default = timeZone
        UIView.setAnimationsEnabled(false)
        defer {
            NSTimeZone.default = originalTimeZone
            UIView.setAnimationsEnabled(animations)
        }
        for orientation in run.orientations {
            let wanted = coordinates.filter({ $0.orientation == orientation })
            let rules = wanted.map({ inventory.notApplicableReason(for: $0, pins: pins) })
            guard rules.contains(where: { $0 == nil }) else {
                for (coordinate, reason) in zip(wanted, rules) {
                    try writer.append(.notApplicable(coordinate.key, reason: reason ?? ""))
                }
                continue
            }
            let pin = try XCTUnwrap(pins.geometry(family: family, orientation: orientation))
            guard await Self.rotate(scene: scene, window: window, to: orientation, pin: pin) else {
                for coordinate in wanted {
                    try writer.append(.failure(coordinate.key, reason: "geometry"))
                }
                let insets = window.safeAreaInsets
                let traits = window.traitCollection
                XCTFail("""
                    \(family) \(orientation): the window did not reach the pinned geometry; it is \
                    \(window.bounds.size), insets \(insets.top),\(insets.left),\(insets.bottom),\(insets.right), \
                    size classes \(traits.horizontalSizeClass.rawValue),\(traits.verticalSizeClass.rawValue); \
                    request \(Self.lastGeometryError ?? "accepted"); \
                    window subviews \(window.subviews.map({ String(describing: type(of: $0)) }))
                    """)
                continue
            }
            for (coordinate, reason) in zip(wanted, rules) {
                if let reason {
                    try writer.append(.notApplicable(coordinate.key, reason: reason))
                    continue
                }
                try await captureCoordinate(
                    coordinate, factory: factory,
                    context: .init(window: window, mode: mode, run: run, writer: writer)
                )
            }
        }
        if run.orientations.count > 1 {
            _ = await Self.rotate(scene: scene, window: window, to: "portrait", pin: nil)
        }
    }

    @MainActor
    private func captureCoordinate(
        _ coordinate: SnapshotCoordinate, factory: ScenarioFactory, context: CaptureContext
    ) async throws {
        let (window, mode, run, writer) = (context.window, context.mode, context.run, context.writer)
        let style: UIUserInterfaceStyle = coordinate.theme == "dark" ? .dark : .light
        let reference = run.references?.appending(path: coordinate.baselinePath)
        let shift = run.shift == coordinate.scenario
        let appStorage = UserDefaults.inMemory
        let outcome = await withDependencies {
            $0.context = .preview
            $0.cookieClient = factory.signedIn ? .previewLoggedIn : .noop
            $0.date.now = PublicVisualFixtures.fixedDate
            $0.uuid = .incrementing
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            await HostedWindowCapture.captureAndCompare(
                make: {
                    let view = try factory.make()
                    // The controlled 1-point shift of 19-01 Task 3; read only by the tracer's own variable.
                    return shift ? AnyView(view.padding(.top, 1)) : view
                },
                window: window, style: style, reference: reference, mode: mode, interact: factory.interact,
                minimumReads: factory.minimumReads
            )
        }
        let digest = outcome.png.map({ SHA256.hash(data: $0).map({ String(format: "%02x", $0) }).joined() })
        try writer.append(SnapshotResultLine(
            key: coordinate.key, status: outcome.status, attempts: outcome.attempts, flaky: outcome.flaky,
            seconds: outcome.seconds, settleSamples: outcome.settleSamples, bytes: outcome.png?.count ?? 0,
            sha256: digest, reason: outcome.reason
        ))
        // A first attempt that differed or timed out, kept beside the result so a flaky picture can be read.
        if let first = outcome.firstAttempt {
            if let png = first.png {
                try writer.writePicture(png, kind: "first-actual", relativePath: coordinate.baselinePath)
            }
            if let difference = first.difference {
                try writer.writePicture(difference, kind: "first-difference", relativePath: coordinate.baselinePath)
            }
        }
        switch outcome.status {
        case .recorded:
            if let png = outcome.png {
                try writer.writePicture(png, kind: nil, relativePath: coordinate.baselinePath)
            }
        case .passed, .notApplicable:
            break
        case .changed, .missingBaseline, .timeout, .error:
            if let png = outcome.png {
                try writer.writePicture(png, kind: "actual", relativePath: coordinate.baselinePath)
            }
            if let difference = outcome.difference {
                try writer.writePicture(difference, kind: "difference", relativePath: coordinate.baselinePath)
            }
            // A fixed message: the key names synthetic coordinates only.
            XCTFail("\(coordinate.key): \(outcome.status.rawValue)")
        }
    }

    private static func coordinates(
        scenario: String, family: String, configuration: SnapshotConfiguration
    ) -> [SnapshotCoordinate] {
        SnapshotCoordinate.orientations.flatMap { orientation in
            SnapshotCoordinate.themes.map { theme in
                SnapshotCoordinate(
                    scenario: scenario, locale: configuration.locale, size: configuration.size,
                    orientation: orientation, family: family, theme: theme
                )
            }
        }
    }

    @MainActor
    static func foregroundScene() async throws -> UIWindowScene {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                return scene
            }
            try await clock.sleep(for: .milliseconds(20))
        }
        throw SnapshotMatrixError.noForegroundScene
    }

    /// The scene's refusal of the last orientation request, for the geometry failure message.
    @MainActor static var lastGeometryError: String?

    /// How long one orientation request may take to reach the pinned geometry. A loaded host (several simulator
    /// clones, a hosted runner) took longer than the first fixed 5 s wait (run 42455556948), so the wait polls until
    /// the window matches and only gives up after this long.
    static let rotationWait: Duration = .seconds(20)

    /// Requests `orientation` and waits until the window matches `pin` (points, safe area, size classes), polling up
    /// to ``rotationWait``; a request that has not arrived by then is made once more, with the same wait.
    @MainActor
    static func rotate(
        scene: UIWindowScene, window: UIWindow, to orientation: String, pin: SnapshotPins.Geometry?
    ) async -> Bool {
        if await requestOrientation(scene: scene, window: window, to: orientation, pin: pin) { return true }
        return await requestOrientation(scene: scene, window: window, to: orientation, pin: pin)
    }

    @MainActor
    private static func requestOrientation(
        scene: UIWindowScene, window: UIWindow, to orientation: String, pin: SnapshotPins.Geometry?
    ) async -> Bool {
        let landscape = orientation == "landscape"
        let mask: UIInterfaceOrientationMask = landscape ? .landscapeRight : .portrait
        window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        lastGeometryError = nil
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            // A refused request leaves the scene where it was, which the geometry wait below reports.
            Task { @MainActor in lastGeometryError = String(describing: error) }
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: rotationWait)
        var stable = 0
        while clock.now < deadline {
            window.layoutIfNeeded()
            let matches = pin.map({ $0.matches(window) })
                ?? (scene.effectiveGeometry.interfaceOrientation.isLandscape == landscape)
            stable = matches ? stable + 1 : 0
            // Two matching reads 50 ms apart: the rotation has finished, not merely passed through the pin.
            if stable >= 2 { return true }
            do {
                try await clock.sleep(for: .milliseconds(50))
            } catch {
                return false
            }
        }
        return false
    }
}

/// What every coordinate of one scenario call shares.
struct CaptureContext {
    let window: UIWindow
    let mode: SnapshotMode
    let run: SnapshotRunEnvironment
    let writer: SnapshotResultWriter
}

enum SnapshotMatrixError: Error {
    case noForegroundScene
    case missingResource(String)
}

extension SnapshotResultLine {
    static func notApplicable(_ key: String, reason: String) -> Self {
        .init(key: key, status: .notApplicable, attempts: 0, flaky: false, seconds: 0, settleSamples: 0, bytes: 0,
              sha256: nil, reason: reason)
    }

    static func failure(_ key: String, reason: String) -> Self {
        .init(key: key, status: .error, attempts: 0, flaky: false, seconds: 0, settleSamples: 0, bytes: 0,
              sha256: nil, reason: reason)
    }
}

// MARK: Run environment

/// The variables a matrix run passes to the test host (`TEST_RUNNER_`-prefixed on the `xcodebuild` process).
struct SnapshotRunEnvironment {
    let mode: SnapshotMode?
    let references: URL?
    let output: URL?
    let only: Set<String>?
    let configuration: SnapshotConfiguration?
    /// The tracer's controlled 1-point shift (19-01 Task 3): the one scenario ID whose root is offset.
    let shift: String?
    /// The orientations this process captures, `portrait,landscape` unless `EHPANDA_SNAPSHOT_ORIENTATIONS` names one.
    /// iPadOS refuses programmatic orientation changes, so an iPad process captures the orientation its device was
    /// turned to before launch.
    let orientations: [String]
    /// The shard's re-run: a scenario whose lines of this configuration are all written already is skipped.
    var keepCaptured = false

    static var current: Self {
        let environment = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? {
            environment[key].map({ $0.trimmingCharacters(in: .whitespaces) }).flatMap({ $0.isEmpty ? nil : $0 })
        }
        return Self(
            mode: value("EHPANDA_SNAPSHOT_MODE").flatMap(SnapshotMode.init(rawValue:)),
            references: value("EHPANDA_SNAPSHOT_REFERENCES").map({ URL(filePath: $0, directoryHint: .isDirectory) }),
            output: value("EHPANDA_SNAPSHOT_OUTPUT").map({ URL(filePath: $0, directoryHint: .isDirectory) }),
            only: value("EHPANDA_SNAPSHOT_ONLY").map({ Set($0.split(separator: ",").map(String.init)) }),
            configuration: value("EHPANDA_SNAPSHOT_CONFIGURATION").flatMap(SnapshotConfiguration.init(name:)),
            shift: value("EHPANDA_SNAPSHOT_SHIFT"),
            orientations: value("EHPANDA_SNAPSHOT_ORIENTATIONS").map { names in
                let wanted = Set(names.split(separator: ",").map(String.init))
                return SnapshotCoordinate.orientations.filter(wanted.contains)
            } ?? SnapshotCoordinate.orientations,
            keepCaptured: value("EHPANDA_SNAPSHOT_KEEP_CAPTURED") == "1"
        )
    }
}

/// One `<locale>-<size>` configuration of `SnapshotMatrix.xctestplan`.
struct SnapshotConfiguration {
    static let contentSizes: [String: UIContentSizeCategory] = [
        "xSmall": .extraSmall, "large": .large, "accessibility5": .accessibilityExtraExtraExtraLarge
    ]

    let locale: String
    let size: String

    init?(name: String) {
        guard let size = Self.contentSizes.keys.first(where: { name.hasSuffix("-\($0)") }) else { return nil }
        let locale = String(name.dropLast(size.count + 1))
        guard SnapshotCoordinate.locales.contains(locale) else { return nil }
        self.locale = locale
        self.size = size
    }

    /// The first process setting that differs from this configuration, or `nil` when all hold (D-15 pins).
    @MainActor
    func failedCheck() -> String? {
        if Locale.preferredLanguages.first != locale { return "language" }
        if UIApplication.shared.preferredContentSizeCategory != Self.contentSizes[size] { return "text-size" }
        if !UIAccessibility.isReduceMotionEnabled { return "reduce-motion" }
        // Scenarios that reach their state through a row's own accessibility action need the app's accessibility
        // runtime (`ApplicationAccessibilityEnabled`); without it a label reports no accessibility label. A UI test
        // run turns the setting off again, so the runner sets it before every matrix process.
        let probe = UILabel()
        probe.text = "probe"
        if probe.accessibilityLabel == nil { return "accessibility-runtime" }
        @Dependency(\.date) var date
        let fixed = withDependencies {
            $0.date.now = PublicVisualFixtures.fixedDate
        } operation: {
            date.now
        }
        if fixed != PublicVisualFixtures.fixedDate { return "date" }
        return nil
    }
}

// MARK: Pins

/// The rendering pin `Scripts/visual/regression-environment.json`: geometry per device and orientation.
struct SnapshotPins: Decodable {
    struct Geometry: Decodable {
        let points: [CGFloat]
        let safeAreaInsets: [CGFloat]
        let horizontalSizeClass: Int
        let verticalSizeClass: Int

        @MainActor
        func matches(_ window: UIWindow) -> Bool {
            let insets = window.safeAreaInsets
            return [window.bounds.width, window.bounds.height] == points
                && [insets.top, insets.left, insets.bottom, insets.right] == safeAreaInsets
                && window.traitCollection.horizontalSizeClass.rawValue == horizontalSizeClass
                && window.traitCollection.verticalSizeClass.rawValue == verticalSizeClass
        }
    }

    struct Device: Decodable {
        let model: String
        let orientations: [String: Geometry]
    }

    let devices: [String: Device]

    func geometry(family: String, orientation: String) -> Geometry? {
        devices[family]?.orientations[orientation]
    }

    /// `compact` or `regular`, from the pinned horizontal size class.
    func widthClass(family: String, orientation: String) -> String? {
        geometry(family: family, orientation: orientation).map({ $0.horizontalSizeClass == 1 ? "compact" : "regular" })
    }

    /// The repository's pin, or the file named by `EHPANDA_SNAPSHOT_ENVIRONMENT`.
    static func load() throws -> Self {
        let url = ProcessInfo.processInfo.environment["EHPANDA_SNAPSHOT_ENVIRONMENT"]
            .map({ URL(filePath: $0) })
            ?? repositoryRoot.appending(path: "Scripts/visual/regression-environment.json")
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    /// The repository root, four levels above this file (`AppPackage/Tests/VisualSnapshotTests/Matrix`).
    static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

// MARK: Inventory

/// `scenarios.json`: the scenario inventory and its not-applicable rules (19-RESEARCH §9).
struct ScenarioInventory: Decodable {
    struct Rule: Decodable {
        let when: [String: String]
        let reason: String
    }

    struct Scenario: Decodable {
        let id: String
        let group: String?
        let plan: String?
        let fixtureID: String?
        let state: String?
        let signedIn: Bool?
        let notApplicable: [Rule]?
    }

    let schema: Int
    let scenarios: [Scenario]

    init(from decoder: any Decoder) throws {
        // Schema 1 was a bare array of scenarios without rules (Phase 17); schema 2 wraps them with rules.
        do {
            scenarios = try decoder.singleValueContainer().decode([Scenario].self)
            schema = 1
            return
        } catch DecodingError.typeMismatch {
            // Not a bare array: schema 2 or later.
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(Int.self, forKey: .schema)
        scenarios = try container.decode([Scenario].self, forKey: .scenarios)
    }

    private enum CodingKeys: String, CodingKey {
        case schema, scenarios
    }

    static func load() throws -> Self {
        guard let url = Bundle(for: SnapshotMatrixCase.self).url(forResource: "scenarios", withExtension: "json")
        else { throw SnapshotMatrixError.missingResource("scenarios.json") }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    /// The reason of the first rule that matches `coordinate`, or `nil` when the coordinate is captured.
    func notApplicableReason(for coordinate: SnapshotCoordinate, pins: SnapshotPins) -> String? {
        guard let scenario = scenarios.first(where: { $0.id == coordinate.scenario }) else { return nil }
        let axes = [
            "family": coordinate.family, "orientation": coordinate.orientation, "locale": coordinate.locale,
            "size": coordinate.size, "theme": coordinate.theme,
            "widthClass": pins.widthClass(family: coordinate.family, orientation: coordinate.orientation) ?? ""
        ]
        return scenario.notApplicable?.first(where: { rule in
            rule.when.allSatisfy({ axes[$0.key] == $0.value })
        })?.reason
    }
}
