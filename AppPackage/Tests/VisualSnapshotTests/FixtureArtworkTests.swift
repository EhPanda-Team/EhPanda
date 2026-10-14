import AppComponents
import AppFeature
import CustomDump
import Foundation
import SwiftUI
import UIKit
@testable import VisualSnapshotSupport
import XCTest

final class FixtureArtworkTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testExportRendersEveryRequestedArtworkAtItsPixelSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "phase17-artwork-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        let covers = PublicVisualFixtures.homeGalleries + PublicVisualFixtures.homeCarouselNeighbors
            + PublicVisualFixtures.downloadGalleries
        var sizes = Dictionary(uniqueKeysWithValues: covers.map({
            ($0.coverPath, CGSize(width: 218, height: 300))
        }))
        for page in 1...PublicVisualFixtures.readerPageMarkers.count {
            sizes["assets/reader/\(page).png"] = CGSize(width: 1260, height: 1733)
            sizes["assets/previews/\(page).png"] = CGSize(width: 80, height: 110)
        }
        let result = try PublicVisualFixtures.export(to: directory, artworkPixelSizes: sizes)
        for (path, size) in sizes {
            let imageURLPath = directory.appending(path: path).path(percentEncoded: false)
            let image = try XCTUnwrap(UIImage(contentsOfFile: imageURLPath)?.cgImage)
            XCTAssertEqual(CGSize(width: image.width, height: image.height), size, path)
        }
        let repeated = directory.appending(path: "repeat", directoryHint: .isDirectory)
        XCTAssertEqual(try PublicVisualFixtures.export(to: repeated, artworkPixelSizes: sizes).aggregateDigest,
                       result.aggregateDigest)
    }

    @MainActor
    func testExportRejectsUnknownOrNonIntegralArtworkSizesBeforeWriting() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "phase17-invalid-artwork-\(UUID().uuidString)", directoryHint: .isDirectory)
        let path = try XCTUnwrap(PublicVisualFixtures.downloadGalleries.last).coverPath
        for size in [CGSize.zero, CGSize(width: 218.5, height: 300), CGSize(width: 218, height: -1)] {
            XCTAssertThrowsError(try PublicVisualFixtures.export(to: directory, artworkPixelSizes: [path: size])) {
                XCTAssertEqual($0 as? PublicFixtureError, .invalidArtworkPixelSize(path))
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
        }
        XCTAssertThrowsError(try PublicVisualFixtures.export(
            to: directory, artworkPixelSizes: ["metadata/home.json": CGSize(width: 218, height: 300)]
        )) {
            XCTAssertEqual($0 as? PublicFixtureError, .missingAsset("metadata/home.json"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
    }

    @MainActor
    func testProductionClipExtentIncludesContinuousCurveAtBothNativeScales() throws {
        for displayScale: CGFloat in [2, 3] {
            for style: GalleryCoverStyle in [.compact, .standard, .hero] {
                for metric: CGFloat in [1, 1.25] {
                    let size = style.size(scale: metric, displayScale: displayScale)
                    expectNoDifference(
                        try FixtureArtwork.coverCornerExtentPixels(size: size, displayScale: displayScale),
                        displayScale == 2 ? 16 : 23
                    )
                }
            }
        }
    }

    @MainActor
    func testArtworkPixelComparisonExcludesOnlyTheFourCornerSquares() throws {
        let width = 40
        let height = 36
        let sourceBytes = Data(repeating: 255, count: width * height * 4)
        let source = try XCTUnwrap(CapturedRaster(width: width, height: height, pixels: sourceBytes)
            .comparisonImage(scale: 1).cgImage)
        var changed = sourceBytes
        for pixel in [0, width - 1, width * (height - 1), width * height - 1] {
            changed[pixel * 4] = 0
        }
        let corners = try XCTUnwrap(CapturedRaster(width: width, height: height, pixels: changed)
            .comparisonImage(scale: 1).cgImage)
        let masked = try FixtureArtwork.comparePixels(source: source, captured: corners, cornerExtentPixels: 3)
        expectNoDifference(masked.comparedPixels, 1404)
        expectNoDifference(masked.differingPixels, 0)

        changed[3 * 4] = 254
        let oneByte = try XCTUnwrap(CapturedRaster(width: width, height: height, pixels: changed)
            .comparisonImage(scale: 1).cgImage)
        let failure = try FixtureArtwork.comparePixels(source: source, captured: oneByte, cornerExtentPixels: 3)
        expectNoDifference(failure.differingPixels, 1)
        expectNoDifference(failure.maximumChannelDifference, 1)
        expectNoDifference(failure.firstDifference, CGPoint(x: 3, y: 0))
        let unmasked = try FixtureArtwork.comparePixels(source: source, captured: corners, cornerExtentPixels: 0)
        expectNoDifference(unmasked.comparedPixels, 1440)
        expectNoDifference(unmasked.differingPixels, 4)
    }

    @MainActor
    func testArtworkPixelComparisonDetectsShiftWithoutDimensionChanges() throws {
        let width = 80
        let height = 72
        let pixels: [UInt8] = (0..<width * height).flatMap({ pixel in
            [UInt8(pixel % width), UInt8(pixel / width), 0, 255]
        })
        let shifted: [UInt8] = (0..<width * height).flatMap({ pixel in
            [UInt8((pixel % width + 1) % width), UInt8(pixel / width), 0, 255]
        })
        let source = try XCTUnwrap(CapturedRaster(width: width, height: height, pixels: Data(pixels))
            .comparisonImage(scale: 1).cgImage)
        let captured = try XCTUnwrap(CapturedRaster(width: width, height: height, pixels: Data(shifted))
            .comparisonImage(scale: 1).cgImage)
        let cornerExtent = try FixtureArtwork.coverCornerExtentPixels(
            size: CGSize(width: CGFloat(width) / 3, height: CGFloat(height) / 3), displayScale: 3
        )
        let result = try FixtureArtwork.comparePixels(
            source: source, captured: captured, cornerExtentPixels: cornerExtent
        )
        expectNoDifference(result.differingPixels, result.comparedPixels)
        expectNoDifference(result.comparedPixels, 3644)
    }

    @MainActor
    func testCoverSizesUseIntegralPixelsAcrossAllCategoriesAndNativeScales() {
        let styles: [GalleryCoverStyle] = [.compact, .standard, .hero]
        for category in Self.contentSizes {
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let metric = UIFontMetrics(forTextStyle: .headline).scaledValue(for: 1, compatibleWith: traits)
            for displayScale: CGFloat in [2, 3] {
                for style in styles {
                    for maximumHeight: CGFloat? in [nil, 91.5, 56.25, 0] {
                        let size = style.size(
                            scale: metric, displayScale: displayScale, maximumHeight: maximumHeight
                        )
                        let width = size.width * displayScale
                        let height = size.height * displayScale
                        expectNoDifference(width, width.rounded())
                        expectNoDifference(height, height.rounded())
                        XCTAssertLessThanOrEqual(abs(width - height * 8 / 11), 0.5)
                        let nominal = style.baseHeight * min(max(metric, 1), 1.25)
                        XCTAssertLessThanOrEqual(abs(height - min(nominal, maximumHeight ?? nominal) * displayScale),
                                                0.5)
                    }
                }
            }
        }
        expectNoDifference(GalleryCoverStyle.compact.size(scale: 1.25, displayScale: 3),
                           CGSize(width: 82, height: 338.0 / 3))
    }

    @MainActor
    func testExportMetricsMatchProductionCoverMetricsAtEveryContentSize() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }))
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        for category in Self.contentSizes {
            var measured: [CGSize]?
            let window = UIWindow(windowScene: scene)
            window.traitOverrides.preferredContentSizeCategory = category
            window.rootViewController = UIHostingController(rootView: CoverMetricsProbe {
                measured = $0
            })
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true
                window.rootViewController = nil
                previousKeyWindow?.makeKey()
            }
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(3))
            while measured == nil && clock.now < deadline {
                window.layoutIfNeeded()
                try await clock.sleep(for: .milliseconds(20))
            }
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let styles: [GalleryCoverStyle] = [.compact, .standard, .hero]
            XCTAssertEqual(try XCTUnwrap(measured), styles.map({
                FixtureArtwork.coverPointSize($0, traits: traits, displayScale: scene.screen.scale)
            }), category.rawValue)
        }
    }

    private static let contentSizes: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge
    ]
}

private struct CoverMetricsProbe: View {
    @GalleryCoverMetrics(.compact) private var compact
    @GalleryCoverMetrics(.standard) private var standard
    @GalleryCoverMetrics(.hero) private var hero
    let report: ([CGSize]) -> Void

    var body: some View {
        Color.clear.onChange(of: [compact, standard, hero], initial: true) { _, sizes in
            report(sizes)
        }
    }
}
