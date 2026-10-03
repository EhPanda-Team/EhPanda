import AppComponents
import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import Foundation
import HomeFeature
import Kingfisher
import SnapshotTesting
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

final class VisualTracerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Dependencies clears prepared values before each XCTest case. UIKit callbacks outlive
        // a task-local override, so restore the opt-in host defaults before this case renders.
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testActiveAppHost() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            if UIApplication.shared.connectedScenes.contains(where: { $0.activationState == .foregroundActive }) {
                break
            }
            try await clock.sleep(for: .milliseconds(20))
        }
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
        XCTAssertTrue(Bundle.main.bundlePath.hasSuffix("/EhPanda.app"))
        XCTAssertTrue(scene.windows.contains(where: { !$0.isHidden }))
        XCTAssertGreaterThan(scene.effectiveGeometry.coordinateSpace.bounds.width, 0)
        XCTAssertGreaterThan(scene.effectiveGeometry.coordinateSpace.bounds.height, 0)
    }

    @MainActor
    func testSnapshotTestingCustomHeightPreservesHomeLayout() async throws {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        let galleries = try Self.homeGalleries()
        try await Self.cacheCoverImages(galleries)
        let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appending(component: "ehpanda-phase17-library-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer {
            let attachment = XCTAttachment(compressedContentsOfDirectory: outputDirectory)
            attachment.name = "phase17-library-custom-height"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()
        try await withDependencies {
            $0.continuousClock = TestClock()
            $0.date.now = Self.fixedDate
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = inMemoryStorage
            $0.uuid = .incrementing
            $0.deviceClient = .live
        } operation: {
            var images: [UIImage] = []
            var diagnostics: [[String: Any]] = []
            var nativeSize: CGSize?
            var requestedFullHeight: CGFloat?
            for name in ["viewport", "custom-height"] {
                let measurement = LibraryLayoutMeasurement()
                let rootView = try Self.homeRoot(galleries: galleries)
                    .onGeometryChange(for: CGSize.self, of: \.size) {
                        measurement.rootSizes.append($0)
                    }
                let host = try await FullContentHost(
                    rootView: rootView, visibleViewportFrozenKey: \.isVisibleViewportFrozen
                )
                let originalWindowFrame = host.window.frame
                let originalAutoresizingMask = host.controller.view.autoresizingMask
                defer {
                    host.window.frame = originalWindowFrame
                    host.controller.view.autoresizingMask = originalAutoresizingMask
                    host.dismiss()
                }
                XCTAssertTrue(host.isAttachedToActiveWindow)
                let scrollHost = try XCTUnwrap(
                    Self.descendants(of: host.controller.view)
                        .compactMap({ $0 as? UIScrollView })
                        .filter({ $0.contentSize.height > $0.bounds.height })
                        .max(by: { $0.contentSize.height < $1.contentSize.height })
                )
                let initialContentHeight = scrollHost.contentSize.height
                if nativeSize == nil {
                    nativeSize = host.viewport.size
                    let insets = scrollHost.adjustedContentInset
                    requestedFullHeight = ceil(
                        (host.viewport.size.height + scrollHost.contentSize.height + insets.top
                         + insets.bottom - scrollHost.bounds.height) * host.viewport.scale
                    ) / host.viewport.scale
                }
                let viewport = try XCTUnwrap(nativeSize)
                let height: CGFloat
                if name == "viewport" {
                    height = viewport.height
                } else {
                    height = try XCTUnwrap(requestedFullHeight)
                }
                let requestedSize = CGSize(width: viewport.width, height: height)
                // SnapshotTesting explicitly sets the root frame and window size. Disable the
                // second frame writer while it owns sizing, keeping the prepared root attached.
                host.controller.view.autoresizingMask = []
                let strategy: Snapshotting<UIViewController, UIImage> = .image(
                    on: ViewImageConfig(
                        safeArea: host.viewport.safeAreaInsets, size: requestedSize, traits: host.viewport.traits
                    ),
                    drawHierarchyInKeyWindow: true,
                    size: requestedSize,
                    traits: host.viewport.traits
                )
                // Exercise the library's capture strategy itself, then encode disposable evidence.
                let image: UIImage = await withCheckedContinuation { continuation in
                    strategy.snapshot(host.controller).run { continuation.resume(returning: $0) }
                }
                try strategy.diffing.toData(image)
                    .write(to: outputDirectory.appending(path: "library.\(name).png"), options: .atomic)
                images.append(image)
                diagnostics.append([
                    "name": name,
                    "requestedSize": [requestedSize.width, requestedSize.height],
                    "imageSize": [image.size.width, image.size.height],
                    "imageScale": image.scale,
                    "nativeViewport": [viewport.width, viewport.height],
                    "rootSizes": measurement.rootSizes.map({ [$0.width, $0.height] }),
                    "windowBoundsAfterSnapshot": NSCoder.string(for: host.window.bounds),
                    "initialContentHeight": initialContentHeight,
                    "contentHeightAfterSnapshot": scrollHost.contentSize.height
                ])
                XCTAssertEqual(image.size, requestedSize)
                XCTAssertEqual(image.scale, host.viewport.scale)
            }
            try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
                .write(to: outputDirectory.appending(path: "library.geometry.json"), options: .atomic)
            let normal = try XCTUnwrap(images.first)
            let full = try XCTUnwrap(images.last)
            let normalCG = try XCTUnwrap(normal.cgImage)
            let fullCG = try XCTUnwrap(full.cgImage)
            let croppedCG = try XCTUnwrap(fullCG.cropping(to: CGRect(
                x: 0, y: 0, width: normalCG.width, height: normalCG.height
            )))
            let cropped = UIImage(cgImage: croppedCG, scale: normal.scale, orientation: .up)
            let imageStrategy: Snapshotting<UIImage, UIImage> = .image
            try imageStrategy.diffing.toData(cropped)
                .write(to: outputDirectory.appending(path: "library.custom-height-viewport.png"), options: .atomic)
            if let difference = imageStrategy.diffing.diffV2(normal, cropped) {
                XCTFail("Library custom-height capture changes native Home viewport pixels: \(difference.0)")
            }
        }
    }

    @MainActor
    func testHomeFullContentTracer() async throws {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        let galleries = try Self.homeGalleries()
        try await Self.cacheCoverImages(galleries)
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()
        let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appending(component: "ehpanda-phase17-tracer-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            if FileManager.default.fileExists(atPath: outputDirectory.path) {
                let attachment = XCTAttachment(compressedContentsOfDirectory: outputDirectory)
                attachment.name = "phase17-home-tracer"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }

        let evidence: FullContentCaptureEvidence
        do {
            evidence = try await withDependencies {
                $0.continuousClock = TestClock()
                $0.date.now = Self.fixedDate
                $0.defaultAppStorage = appStorage
                $0.defaultInMemoryStorage = inMemoryStorage
                $0.uuid = .incrementing
                $0.deviceClient = .live
            } operation: {
                let rootView = try Self.homeRoot(galleries: galleries)
                let host = try await FullContentHost(
                    rootView: rootView, visibleViewportFrozenKey: \.isVisibleViewportFrozen
                )
                defer { host.dismiss() }
                let evidence = try await host.capture(
                    expectedItems: galleries.map({
                        CaptureItemExpectation(title: $0.title, marker: $0.gid, artworkAspectRatio: 8.0 / 11.0)
                    }),
                    trailingMarker: "Other",
                    outputDirectory: outputDirectory,
                    record: .all
                )
                XCTAssertTrue(host.isAttachedToActiveWindow)
                return evidence
            }
        } catch {
            XCTFail("Home completeness failed (\(String(reflecting: type(of: error)))): \(error)")
            return
        }

        XCTAssertEqual(evidence.viewport.traits.userInterfaceIdiom, UIUserInterfaceIdiom.phone)
        XCTAssertGreaterThan(evidence.viewport.size.width, 0)
        XCTAssertGreaterThan(evidence.viewport.size.height, 0)
        XCTAssertGreaterThan(evidence.viewport.scale, 0)
        XCTAssertGreaterThan(evidence.contentHeight, evidence.viewport.size.height)
        XCTAssertEqual(evidence.itemCensus.count, galleries.count)
        XCTAssertTrue(evidence.itemCensus.values.allSatisfy({ $0 == 1 }))
        XCTAssertFalse(evidence.finalItemClipped)
        XCTAssertGreaterThan(evidence.normalImageByteCount, 0)
        XCTAssertGreaterThan(evidence.fullImageByteCount, 0)
        XCTAssertEqual(evidence.outputSize.width, evidence.viewport.size.width)
        XCTAssertGreaterThanOrEqual(evidence.outputSize.height, evidence.contentHeight)
        XCTAssertGreaterThanOrEqual(evidence.stableIterations, 2)
        XCTAssertTrue(evidence.windowIsAttached)
        XCTAssertEqual(evidence.windowBounds.size, evidence.viewport.size)
        XCTAssertEqual(evidence.sceneBounds.size, evidence.viewport.size)
        XCTAssertTrue(evidence.testHostPath.contains("EhPanda.app"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: evidence.normalImageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: evidence.fullImageURL.path))
    }
}

private extension VisualTracerTests {
    static let fixedDate = PublicVisualFixtures.fixedDate

    @MainActor
    static func cacheCoverImages(_ galleries: [Gallery]) async throws {
        for (index, gallery) in galleries.enumerated() {
            let url = try XCTUnwrap(gallery.coverURL)
            let image = PublicVisualFixtures.artwork(marker: gallery.gid, colorIndex: index)
            try await ImageCache.default.store(image, forKey: url.absoluteString, toDisk: false)
            XCTAssertNotNil(ImageCache.default.retrieveImageInMemoryCache(forKey: url.absoluteString))
        }
    }

    @MainActor
    static func homeRoot(galleries: [Gallery]) throws -> some View {
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
        let rootView = HomeView(store: Store(initialState: state, reducer: HomeReducer.init))
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, .large)
            .transaction {
                $0.animation = nil
                $0.disablesAnimations = true
            }
        return rootView
    }

    @MainActor
    static func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap({ [$0] + descendants(of: $0) })
    }

    static func homeGalleries() throws -> [Gallery] {
        try PublicVisualFixtures.homeGalleries.enumerated().map { index, fixture in
            Gallery(
                gid: fixture.gid,
                token: fixture.token,
                title: fixture.title,
                rating: 4.5,
                tags: [],
                category: .doujinshi,
                uploader: "Visual Fixture",
                pageCount: fixture.pageCount,
                postedDate: fixedDate,
                coverURL: try XCTUnwrap(URL(string: "https://visual-fixture.invalid/home/\(index).png")),
                galleryURL: nil
            )
        }
    }
}

@MainActor
private final class LibraryLayoutMeasurement {
    var rootSizes: [CGSize] = []
}
