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
    func testHomeFullContentTracer() async throws {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        let galleries = try Self.homeGalleries()
        for (index, gallery) in galleries.enumerated() {
            let url = try XCTUnwrap(gallery.coverURL)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 220), format: format)
                .image { context in
                    UIColor(hue: CGFloat(index) / 6, saturation: 0.5, brightness: 0.85, alpha: 1).setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 160, height: 220))
                    UIColor.white.setFill()
                    context.fill(CGRect(x: 24, y: 32, width: 112, height: 16))
                    context.fill(CGRect(x: 24, y: 72, width: 72, height: 8))
                }
            try await ImageCache.default.store(image, forKey: url.absoluteString, toDisk: false)
            XCTAssertNotNil(ImageCache.default.retrieveImageInMemoryCache(forKey: url.absoluteString))
        }
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
                let host = try await FullContentHost(rootView: rootView)
                defer { host.dismiss() }
                let evidence = try await host.capture(
                    expectedItemTitles: galleries.map(\.title),
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
    static let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)

    static func homeGalleries() throws -> [Gallery] {
        try (0..<6).map { index in
            Gallery(
                gid: "visual-home-\(index)",
                token: "visual-token-\(index)",
                title: "Visual Home Gallery \(index + 1)",
                rating: 4.5,
                tags: [],
                category: .doujinshi,
                uploader: "Visual Fixture",
                pageCount: 24 + index,
                postedDate: fixedDate,
                coverURL: try XCTUnwrap(URL(string: "https://visual-fixture.invalid/home/\(index).png")),
                galleryURL: nil
            )
        }
    }
}
