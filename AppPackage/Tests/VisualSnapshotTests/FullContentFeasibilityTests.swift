import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import CryptoKit
@testable import DetailFeature
import DownloadsFeature
import Foundation
import HomeFeature
import Kingfisher
import ReadingFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

final class FullContentFeasibilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testExportPublicFixtures() throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = environment["EHPANDA_PUBLIC_FIXTURE_EXPORT_DIRECTORY"].map({
            URL(fileURLWithPath: $0, isDirectory: true)
        }) ?? FileManager.default.temporaryDirectory
            .appending(component: "phase17-public-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        let secondDirectory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-public-repeat-\(UUID().uuidString)", directoryHint: .isDirectory)
        let scenarios = try environment["EHPANDA_VISUAL_SCENARIOS"].map({
            try Data(contentsOf: URL(fileURLWithPath: $0))
        })
        do {
            let first = try PublicVisualFixtures.export(to: directory, scenarios: scenarios)
            let second = try PublicVisualFixtures.export(to: secondDirectory, scenarios: scenarios)
            XCTAssertEqual(first.aggregateDigest, second.aggregateDigest)
            XCTAssertEqual(try Data(contentsOf: first.manifestURL), try Data(contentsOf: second.manifestURL))
            XCTAssertFalse(first.aggregateDigest.isEmpty)
            let manifest = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: first.manifestURL)) as? [String: Any]
            )
            XCTAssertEqual(manifest["fixtureVersion"] as? String, PublicVisualFixtures.fixtureVersion)
            let entries = try XCTUnwrap(manifest["assets"] as? [[String: Any]])
            XCTAssertGreaterThan(entries.count, 30)
            for entry in entries {
                let path = try XCTUnwrap(entry["path"] as? String)
                let bytes = try Data(contentsOf: directory.appending(path: path))
                XCTAssertEqual(bytes.count, entry["bytes"] as? Int)
                XCTAssertEqual(SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined(),
                               entry["sha256"] as? String)
                XCTAssertFalse(path.hasPrefix("/"))
            }
            let attachment = XCTAttachment(compressedContentsOfDirectory: directory)
            attachment.name = "phase17-public-fixtures"
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            XCTFail("Committed fixtures must export complete repeatable bytes into empty directories: \(error)")
        }
    }

    @MainActor
    func testExportRejectsMissingFixtureAssetAndRoute() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-invalid-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        let catalogs: [(scenario: [String: Any], expected: PublicFixtureError)] = [
            (["fixtureID": "absent"], .unknownFixture("absent")),
            (["fixtureID": "home-finite", "assets": ["absent.png"]], .missingAsset("absent.png")),
            (["fixtureID": "home-finite", "routes": ["absent"]], .missingRoute("absent"))
        ]
        for catalog in catalogs {
            let data = try JSONSerialization.data(withJSONObject: [catalog.scenario])
            XCTAssertThrowsError(try PublicVisualFixtures.export(to: directory, scenarios: data)) { error in
                XCTAssertEqual(error as? PublicFixtureError, catalog.expected)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @MainActor
    func testCommentsNativeLibraryStrategy() async throws {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = timeZone
        defer { NSTimeZone.default = originalTimeZone }
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-comments-library-native-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fixtures = directory.appending(path: "fixtures", directoryHint: .isDirectory)
        _ = try PublicVisualFixtures.export(to: fixtures)
        defer {
            let attachment = XCTAttachment(compressedContentsOfDirectory: directory)
            attachment.name = "phase17-comments-library-native"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        try await withDependencies {
            $0.continuousClock = TestClock()
            $0.date.now = PublicVisualFixtures.fixedDate
            $0.defaultAppStorage = UserDefaults.inMemory
            $0.defaultInMemoryStorage = InMemoryStorage()
            $0.uuid = .incrementing
            $0.deviceClient = .live
        } operation: {
            let input = try await Self.screen(.comments, fixtureDirectory: fixtures)
            let root = input.view
                .environment(\.colorScheme, .light)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, timeZone)
                .environment(\.dynamicTypeSize, .large)
                .transaction {
                    $0.animation = nil
                    $0.disablesAnimations = true
                }
            let host = try await FullContentHost(
                rootView: root, contentSizeCategory: .large, standardImageRange: true, useSwiftUIStrategy: true
            )
            defer { host.dismiss() }
            do {
                let evidence = try await host.capture(
                    expectedItems: input.expectedItems, trailingMarker: input.trailingMarker,
                    outputDirectory: directory.appending(path: "capture", directoryHint: .isDirectory), record: .all
                )
                XCTAssertEqual(evidence.itemCensus.count, 12)
                XCTAssertFalse(evidence.finalItemClipped)
            } catch {
                try JSONSerialization.data(withJSONObject: [
                    "type": String(reflecting: type(of: error)), "description": String(describing: error),
                    "debugDescription": String(reflecting: error)
                ], options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appending(path: "capture-error.json"), options: .atomic)
                XCTFail("Native Comments capture failed: \(error)")
            }
        }
    }

    @MainActor
    func testActualFullContentMatrix() async throws {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = timeZone
        defer { NSTimeZone.default = originalTimeZone }
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-feasibility-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            let attachment = XCTAttachment(compressedContentsOfDirectory: directory)
            attachment.name = "phase17-full-content-matrix"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let fixtureDirectory = directory.appending(path: "fixtures", directoryHint: .isDirectory)
        _ = try PublicVisualFixtures.export(to: fixtureDirectory)
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
        let family = scene.traitCollection.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let originalOrientation = scene.effectiveGeometry.interfaceOrientation
        let coordinates = [false, true].flatMap { landscape in
            [false, true].flatMap { accessibility in
                FeasibilityShape.allCases.map({
                    FeasibilityCoordinate(shape: $0, landscape: landscape, accessibility: accessibility)
                })
            }
        }
        var outcomes = coordinates.map({ ["coordinate": $0.key(family: family), "status": "pending"] })
        for (index, coordinate) in coordinates.enumerated() {
            let output = directory.appending(path: coordinate.key(family: family), directoryHint: .isDirectory)
            do {
                try await Self.setOrientation(landscape: coordinate.landscape, scene: scene)
                let appStorage = UserDefaults.inMemory
                let inMemoryStorage = InMemoryStorage()
                try await withDependencies {
                    $0.continuousClock = TestClock()
                    $0.date.now = PublicVisualFixtures.fixedDate
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.uuid = .incrementing
                    $0.deviceClient = .live
                    $0.imageClient = .noop
                } operation: {
                    @Shared(.setting) var setting: Setting
                    $setting.withLock {
                        $0 = Setting(readingDirection: .vertical, prefetchLimit: 0)
                    }
                    let input = try await Self.screen(coordinate.shape, fixtureDirectory: fixtureDirectory)
                    let root = input.view
                        .environment(\.colorScheme, .light)
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .environment(\.timeZone, timeZone)
                        .environment(\.dynamicTypeSize, coordinate.accessibility ? .accessibility5 : .large)
                        .transaction {
                            $0.animation = nil
                            $0.disablesAnimations = true
                        }
                    let category: UIContentSizeCategory = coordinate.accessibility
                        ? .accessibilityExtraExtraExtraLarge : .large
                    let host = try await FullContentHost(
                        rootView: root, contentSizeCategory: category, isViewportReady: input.viewportIsReady
                    )
                    defer { host.dismiss() }
                    XCTAssertEqual(host.viewport.traits.preferredContentSizeCategory, category)
                    XCTAssertEqual(host.viewport.size.width > host.viewport.size.height, coordinate.landscape)
                    let evidence = try await host.capture(
                        expectedItems: input.expectedItems, trailingMarker: input.trailingMarker,
                        outputDirectory: output, record: .all, isContentReady: input.contentIsReady
                    )
                    XCTAssertEqual(evidence.itemCensus.count, input.expectedItems.count)
                    XCTAssertTrue(evidence.itemCensus.values.allSatisfy({ $0 == 1 }))
                    XCTAssertFalse(evidence.finalItemClipped)
                    XCTAssertGreaterThan(evidence.contentHeight, evidence.viewport.size.height)
                    XCTAssertGreaterThanOrEqual(evidence.stableIterations, 2)
                    XCTAssertTrue(evidence.windowIsAttached)
                    XCTAssertEqual(evidence.viewport.size, scene.effectiveGeometry.coordinateSpace.bounds.size)
                    if let readerStore = input.readerStore {
                        XCTAssertEqual(readerStore.setting.readingDirection, .vertical)
                        XCTAssertFalse(readerStore.setting.enableDualPageMode)
                    }
                    let details: [String: Any] = [
                        "coordinate": coordinate.key(family: family), "status": "captured",
                        "viewport": [evidence.viewport.size.width, evidence.viewport.size.height],
                        "output": [evidence.outputSize.width, evidence.outputSize.height],
                        "itemFrames": evidence.itemFrames.mapValues(NSCoder.string(for:)),
                        "trailingMarker": NSCoder.string(for: evidence.trailingMarkerFrame),
                        "census": evidence.itemCensus, "stableIterations": evidence.stableIterations,
                        "windowIsAttached": evidence.windowIsAttached,
                        "orientation": scene.effectiveGeometry.interfaceOrientation.rawValue
                    ]
                    try JSONSerialization.data(withJSONObject: details, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appending(path: "acceptance.json"), options: .atomic)
                }
                outcomes[index]["status"] = "captured"
            } catch {
                outcomes[index]["status"] = "failed"
                outcomes[index]["reason"] = String(describing: error)
                try Self.writeOutcomes(outcomes, directory: directory)
                XCTFail("Actual full-content gate failed at \(coordinate.key(family: family)): \(error)")
                return
            }
            try Self.writeOutcomes(outcomes, directory: directory)
        }
        try await Self.setOrientation(landscape: originalOrientation.isLandscape, scene: scene)
        XCTAssertEqual(outcomes.count, 16)
        XCTAssertTrue(outcomes.allSatisfy({ $0["status"] == "captured" }))
    }
}

private enum FeasibilityShape: String, CaseIterable {
    case home, comments, downloads, reader
}

private struct FeasibilityCoordinate {
    let shape: FeasibilityShape
    let landscape: Bool
    let accessibility: Bool

    func key(family: String) -> String {
        "\(family)-\(landscape ? "landscape" : "portrait")-\(accessibility ? "AX5" : "large")-\(shape.rawValue)"
    }
}

@MainActor
private struct FeasibilityScreen {
    let view: AnyView
    let expectedItems: [CaptureItemExpectation]
    let trailingMarker: String
    var readerStore: StoreOf<ReadingReducer>?
    var viewportIsReady: @MainActor () -> Bool = { true }
    var contentIsReady: @MainActor () -> Bool = { true }
}

private extension FullContentFeasibilityTests {
    @MainActor
    static func setOrientation(landscape: Bool, scene: UIWindowScene) async throws {
        var geometryError: (any Error)?
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscapeLeft : .portrait)) {
            geometryError = $0
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            if let geometryError { throw geometryError }
            let bounds = scene.effectiveGeometry.coordinateSpace.bounds
            if scene.effectiveGeometry.interfaceOrientation.isLandscape == landscape,
               (bounds.width > bounds.height) == landscape {
                try await clock.sleep(for: .milliseconds(150))
                return
            }
            try await clock.sleep(for: .milliseconds(20))
        }
        throw FeasibilityError.orientationUnavailable
    }

    static func writeOutcomes(_ outcomes: [[String: String]], directory: URL) throws {
        try JSONSerialization.data(withJSONObject: outcomes, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: "outcomes.json"), options: .atomic)
    }

    @MainActor
    static func screen(_ shape: FeasibilityShape, fixtureDirectory: URL) async throws -> FeasibilityScreen {
        switch shape {
        case .home:
            let galleries = try await galleries(PublicVisualFixtures.homeGalleries, directory: fixtureDirectory)
            var state = HomeReducer.State()
            state.popularGalleries = Array(galleries.prefix(1))
            state.cardPageIndex = 0
            state.currentCardID = try XCTUnwrap(galleries.first).gid
            state.frontpageGalleries = Array(galleries.dropFirst().prefix(2))
            state.toplistsGalleries = Dictionary(
                uniqueKeysWithValues: ToplistsType.allCases.map({ ($0.categoryIndex, []) })
            )
            let toplist = try XCTUnwrap(ToplistsType.allCases.first)
            state.toplistsGalleries[toplist.categoryIndex] = Array(galleries.dropFirst(3))
            return FeasibilityScreen(
                view: AnyView(HomeView(store: Store(initialState: state, reducer: HomeReducer.init))),
                expectedItems: expectations(galleries), trailingMarker: "Other"
            )
        case .comments:
            let comments = try PublicVisualFixtures.commentIDs.enumerated().map { index, identifier in
                GalleryComment(
                    votedUp: false, votedDown: false, votable: false, editable: false,
                    author: "Public Author", contents: [CommentContent(
                        id: try XCTUnwrap(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))),
                        type: .plainText, text: PublicVisualFixtures.commentText(index: index)
                    )], commentID: identifier, commentDate: PublicVisualFixtures.fixedDate
                )
            }
            let galleryURL = try XCTUnwrap(URL(string: "https://visual-fixture.invalid/g/comments/token"))
            let store = Store(
                initialState: CommentsReducer.State(galleryURL: galleryURL, comments: comments),
                reducer: CommentsReducer.init
            )
            return FeasibilityScreen(
                view: AnyView(NavigationStack {
                    CommentsView(store: store, gid: "VC", token: "public-token", apiKey: "",
                                 galleryURL: galleryURL, comments: comments)
                }),
                expectedItems: PublicVisualFixtures.commentIDs.map({ .init(title: $0, marker: $0) }),
                trailingMarker: "VCEND"
            )
        case .downloads:
            let galleries = try await galleries(PublicVisualFixtures.downloadGalleries, directory: fixtureDirectory)
            var state = DownloadsReducer.State()
            state.loadingState = .idle
            state.hasLoadedInitialDownloads = true
            state.downloads = galleries.map({ download($0, folder: fixtureDirectory) })
            return FeasibilityScreen(
                view: AnyView(DownloadsView(store: Store(initialState: state, reducer: DownloadsReducer.init))),
                expectedItems: expectations(galleries), trailingMarker: try XCTUnwrap(galleries.last).gid
            )
        case .reader:
            let readerGalleries = try await galleries(
                Array(PublicVisualFixtures.downloadGalleries.prefix(1)), directory: fixtureDirectory
            )
            let gallery = try XCTUnwrap(readerGalleries.first)
            XCTAssertEqual(gallery.pageCount, PublicVisualFixtures.readerPageMarkers.count)
            let pages = Dictionary(uniqueKeysWithValues: (1...gallery.pageCount).map({
                ($0, fixtureDirectory.appending(path: "assets/reader/\($0).png"))
            }))
            let local = download(gallery, folder: fixtureDirectory, pageURLs: pages)
            let store = Store(
                initialState: ReadingReducer.State(
                    gallery: gallery, contentSource: .local(download: local, manifest: local.manifest)
                ), reducer: ReadingReducer.init
            )
            let bounds = try XCTUnwrap(UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }))
                .effectiveGeometry.coordinateSpace.bounds
            let visibleCount = min(gallery.pageCount, Int(ceil(bounds.height / (bounds.width * 11.0 / 8.0))))
            let visiblePages = Set(1...visibleCount)
            let allPages = Set(1...gallery.pageCount)
            return FeasibilityScreen(
                view: AnyView(ReadingView(store: store)),
                expectedItems: PublicVisualFixtures.readerPageMarkers.map({
                    .init(title: $0, marker: $0, artworkAspectRatio: 8.0 / 11.0, requiresInsetArtwork: false)
                }), trailingMarker: try XCTUnwrap(PublicVisualFixtures.readerPageMarkers.last), readerStore: store,
                viewportIsReady: { visiblePages.isSubset(of: store.webImageLoadSuccessIndices) },
                contentIsReady: { allPages.isSubset(of: store.webImageLoadSuccessIndices) }
            )
        }
    }

    @MainActor
    static func galleries(_ fixtures: [PublicGalleryFixture], directory: URL) async throws -> [Gallery] {
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

    static func expectations(_ galleries: [Gallery]) -> [CaptureItemExpectation] {
        galleries.map({ .init(title: $0.title, marker: $0.gid, artworkAspectRatio: 8.0 / 11.0) })
    }

    static func download(_ gallery: Gallery, folder: URL, pageURLs: [Int: URL] = [:]) -> DownloadedGallery {
        let manifest = DownloadManifest(
            gid: gallery.gid, host: .ehentai, token: gallery.token, title: gallery.title, jpnTitle: nil,
            category: gallery.category, language: .english, remoteCoverURL: gallery.coverURL,
            uploader: gallery.uploader, tags: gallery.tags, postedDate: gallery.postedDate, rating: gallery.rating,
            pages: Dictionary(uniqueKeysWithValues: (1...gallery.pageCount).map({ ($0, "public-page-hash-\($0)") }))
        )
        return DownloadedGallery(
            manifest: manifest, folderURL: folder, folderName: "Public Fixtures", localCoverURL: gallery.coverURL,
            localPageURLs: pageURLs, modificationDate: PublicVisualFixtures.fixedDate, displayStatus: .completed
        )
    }
}

private enum FeasibilityError: Error {
    case orientationUnavailable
}
