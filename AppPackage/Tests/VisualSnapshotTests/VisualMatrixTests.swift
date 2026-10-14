import AppComponents
import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import CryptoKit
import DeviceClient
import Foundation
@testable import HomeFeature
import Kingfisher
import SnapshotTesting
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// Each invocation receives one explicit coordinate from the complete Python matrix.
/// A fresh app process makes UIKit and SwiftUI share the selected language and system text size.
final class VisualMatrixTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testSelectedCoordinate() async throws {
        let encoded = try XCTUnwrap(ProcessInfo.processInfo.environment["EHPANDA_VISUAL_COORDINATE"])
        let data = Data(encoded.utf8)
        let configuration = try JSONDecoder().decode(MatrixConfiguration.self, from: data)
        let configurationJSON = try JSONSerialization.jsonObject(with: data)
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-matrix-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            let attachment = XCTAttachment(compressedContentsOfDirectory: directory)
            attachment.name = "phase17-matrix"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        do {
            try await capture(configuration, configurationJSON: configurationJSON, directory: directory)
        } catch {
            try JSONSerialization.data(withJSONObject: [
                "configuration": configurationJSON, "error": String(reflecting: error), "status": "failed"
            ], options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appending(path: "capture-error.json"), options: .atomic)
            throw error
        }
    }

    @MainActor
    private func capture(_ configuration: MatrixConfiguration, configurationJSON: Any, directory: URL) async throws {
        let coordinate = configuration.coordinate
        guard coordinate.scenario == "home-populated", ["candidate", "compare"].contains(configuration.mode),
              coordinate.key == configuration.key else { throw MatrixError.invalidConfiguration }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }))
        let family = scene.traitCollection.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        XCTAssertEqual(coordinate.family, family)
        let landscape = coordinate.orientation == "landscape"
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while scene.effectiveGeometry.interfaceOrientation.isLandscape != landscape && clock.now < deadline {
            try await clock.sleep(for: .milliseconds(50))
        }
        let bounds = scene.effectiveGeometry.coordinateSpace.bounds
        XCTAssertEqual(scene.effectiveGeometry.interfaceOrientation.isLandscape, landscape)
        XCTAssertEqual(bounds.width > bounds.height, landscape)
        let category = try XCTUnwrap(Self.contentSizes[coordinate.size])
        XCTAssertEqual(UIApplication.shared.preferredContentSizeCategory, category)
        XCTAssertEqual(scene.traitCollection.preferredContentSizeCategory, category)
        XCTAssertEqual(Locale.current.identifier, configuration.localeIdentifier)
        XCTAssertEqual(Locale.preferredLanguages.first, coordinate.locale)
        let style: UIUserInterfaceStyle = coordinate.theme == "dark" ? .dark : .light
        XCTAssertEqual(scene.traitCollection.userInterfaceStyle, style)
        XCTAssertEqual(UIAccessibility.isReduceMotionEnabled, configuration.geometry.reduceMotionEnabled)
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let originalTimeZone = NSTimeZone.default
        let animations = UIView.areAnimationsEnabled
        NSTimeZone.default = timeZone
        UIView.setAnimationsEnabled(false)
        defer {
            NSTimeZone.default = originalTimeZone
            UIView.setAnimationsEnabled(animations)
        }
        let fixtures = URL(filePath: configuration.fixtures, directoryHint: .isDirectory)
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: fixtures.appending(path: "manifest.json"))
        ) as? [String: Any])
        XCTAssertEqual(manifest["aggregateDigest"] as? String, configuration.fixtureDigest)
        XCTAssertEqual(manifest["fixtureVersion"] as? String, PublicVisualFixtures.fixtureVersion)
        let assets = try XCTUnwrap(manifest["assets"] as? [[String: Any]])
        for asset in assets {
            let path = try XCTUnwrap(asset["path"] as? String)
            guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
                throw MatrixError.invalidConfiguration
            }
            let bytes = try Data(contentsOf: fixtures.appending(path: path))
            XCTAssertEqual(bytes.count, asset["bytes"] as? Int)
            XCTAssertEqual(SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined(),
                           asset["sha256"] as? String)
        }
        let artwork = FixtureArtwork(
            traits: scene.traitCollection, displayScale: scene.screen.scale,
            readerPagePixelWidth: Int(bounds.width * scene.screen.scale)
        )
        let coordinateFixtures = directory.appending(path: "fixtures", directoryHint: .isDirectory)
        try artwork.export(
            to: coordinateFixtures, sourceDigest: configuration.fixtureDigest,
            scenarios: Data(contentsOf: fixtures.appending(path: "scenarios.json"))
        )
        try await withDependencies {
            $0.continuousClock = TestClock()
            $0.date.now = PublicVisualFixtures.fixedDate
            $0.defaultAppStorage = UserDefaults.inMemory
            $0.defaultInMemoryStorage = InMemoryStorage()
            $0.uuid = .incrementing
            $0.deviceClient = .live
        } operation: {
            let metadata = try JSONDecoder().decode(
                [PublicGalleryFixture].self, from: Data(contentsOf: fixtures.appending(path: "metadata/home.json"))
            )
            let galleries = try await Self.galleries(metadata, directory: coordinateFixtures)
            let expected = Array(galleries.prefix(6))
            let neighbors = Array(galleries.dropFirst(6))
            XCTAssertEqual(expected.map(\.gid), PublicVisualFixtures.homeGalleries.map(\.gid))
            XCTAssertEqual(neighbors.map(\.gid), PublicVisualFixtures.homeCarouselNeighbors.map(\.gid))
            var state = HomeReducer.State()
            // Distinct native carousel peeks remain outside the exact-once census, as in the carousel fixture contract.
            state.popularGalleries = [try XCTUnwrap(expected.first)] + neighbors
            state.cardPageIndex = 0
            state.currentCardID = try XCTUnwrap(expected.first).gid
            state.frontpageGalleries = Array(expected.dropFirst().prefix(2))
            state.toplistsGalleries = Dictionary(
                uniqueKeysWithValues: ToplistsType.allCases.map({ ($0.categoryIndex, []) })
            )
            let toplist = try XCTUnwrap(ToplistsType.allCases.first)
            state.toplistsGalleries[toplist.categoryIndex] = Array(expected.dropFirst(3))
            let locale = Locale(identifier: configuration.localeIdentifier)
            let root = HomeView(store: Store(initialState: state, reducer: HomeReducer.init))
                .environment(\.locale, locale)
                .environment(\.timeZone, timeZone)
                .environment(\.colorScheme, coordinate.theme == "dark" ? .dark : .light)
                .transaction {
                    $0.animation = nil
                    $0.disablesAnimations = true
                }
            let host = try await FullContentHost(
                rootView: root, sampling: VisibleViewportSampling(),
                samplingKey: \.visibleViewportSampling, frozen: \.isFrozen,
                contentSizeCategory: category, standardImageRange: true
            )
            defer { host.dismiss() }
            XCTAssertEqual([host.viewport.size.width, host.viewport.size.height], configuration.geometry.points)
            XCTAssertEqual(host.viewport.scale, configuration.geometry.scale)
            XCTAssertEqual(host.window.traitCollection.userInterfaceStyle, style)
            let insets = host.viewport.safeAreaInsets
            let measuredInsets = [insets.top, insets.left, insets.bottom, insets.right]
            XCTAssertEqual(measuredInsets, configuration.geometry.safeAreaInsets)
            XCTAssertEqual(host.viewport.traits.horizontalSizeClass.rawValue,
                           configuration.geometry.horizontalSizeClass)
            XCTAssertEqual(host.viewport.traits.verticalSizeClass.rawValue,
                           configuration.geometry.verticalSizeClass)
            var trailingResource: LocalizedStringResource = .other
            trailingResource.locale = locale
            let evidence = try await host.capture(
                expectedItems: expected.map({ .init(title: $0.title, marker: $0.gid, artworkAspectRatio: 8.0 / 11.0) }),
                trailingMarker: String(localized: trailingResource), outputDirectory: directory, record: .all,
                trailingMarkerLanguage: Locale.Language(identifier: coordinate.locale)
            )
            try artwork.assertNotResampled(evidence, fixtures: coordinateFixtures, output: directory)
            // Actuals always live in the run directory. Compare reads the separately approved references only.
            if configuration.mode == "compare" {
                for name in ["viewport", "frozen-viewport", "full-content"] {
                    let path = directory.appending(path: "capture.\(name).png")
                    let image = try XCTUnwrap(UIImage(contentsOfFile: path.path))
                    if let failure = verifySnapshot(
                        of: image, as: .image, named: name, record: .never,
                        snapshotDirectory: configuration.references, testName: "capture"
                    ) {
                        throw MatrixError.comparisonFailed(failure)
                    }
                }
            }
            XCTAssertFalse(evidence.finalItemClipped)
            try JSONSerialization.data(withJSONObject: [
                "configuration": configurationJSON, "status": "captured", "itemCensus": evidence.itemCensus,
                "deviceID": try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_UDID"]),
                "appCategory": UIApplication.shared.preferredContentSizeCategory.rawValue,
                "sceneCategory": scene.traitCollection.preferredContentSizeCategory.rawValue,
                "appearance": style.rawValue, "locale": Locale.current.identifier,
                "fixtureMarkerLanguage": "en", "trailingMarkerLanguage": coordinate.locale,
                "trailingMarker": String(localized: trailingResource)
            ], options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appending(path: "acceptance.json"), options: .atomic)
        }
    }

    @MainActor
    private static func galleries(_ fixtures: [PublicGalleryFixture], directory: URL) async throws -> [Gallery] {
        var result: [Gallery] = []
        for fixture in fixtures {
            let url = directory.appending(path: fixture.coverPath)
            let image = try XCTUnwrap(UIImage(data: Data(contentsOf: url)))
            try await ImageCache.default.store(image, forKey: url.absoluteString, toDisk: false)
            result.append(Gallery(
                gid: fixture.gid, token: fixture.token, title: fixture.title, rating: 4.5, tags: [],
                category: .doujinshi, uploader: "Visual Fixture", pageCount: fixture.pageCount,
                postedDate: PublicVisualFixtures.fixedDate, coverURL: url, galleryURL: nil
            ))
        }
        return result
    }

    private static let contentSizes: [String: UIContentSizeCategory] = [
        "xSmall": .extraSmall, "small": .small, "medium": .medium, "large": .large,
        "xLarge": .extraLarge, "xxLarge": .extraExtraLarge, "xxxLarge": .extraExtraExtraLarge,
        "accessibility1": .accessibilityMedium, "accessibility2": .accessibilityLarge,
        "accessibility3": .accessibilityExtraLarge, "accessibility4": .accessibilityExtraExtraLarge,
        "accessibility5": .accessibilityExtraExtraExtraLarge
    ]
}

private struct MatrixConfiguration: Decodable {
    let coordinate: MatrixCoordinate
    let key: String
    let mode: String
    let fixtures: String
    let references: String
    let pinSHA256: String
    let fixtureDigest: String
    let localeIdentifier: String
    let geometry: MatrixGeometry
}

private struct MatrixCoordinate: Decodable {
    let scenario: String
    let locale: String
    let size: String
    let orientation: String
    let family: String
    let theme: String

    var key: String { [scenario, locale, size, orientation, family, theme].joined(separator: "__") }
}

private struct MatrixGeometry: Decodable {
    let points: [CGFloat]
    let safeAreaInsets: [CGFloat]
    let scale: CGFloat
    let horizontalSizeClass: Int
    let verticalSizeClass: Int
    /// Pinned on: Reduce Motion is the only switch that freezes the dark Home card's Metal gradient.
    let reduceMotionEnabled: Bool
}

private enum MatrixError: Error {
    case comparisonFailed(String)
    case invalidConfiguration
}
