import AppComponents
import AppFeature
import CustomDump
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

final class GeometryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testPortraitGeometry() async throws {
        try await measure(landscape: false)
    }

    @MainActor
    func testLandscapeGeometry() async throws {
        try await measure(landscape: true)
    }

    /// The simulator is rotated externally before this process launches. A full-size real window, without
    /// navigation bars or content-height expansion, supplies the rendering contract for later capture runners.
    @MainActor
    private func measure(landscape: Bool) async throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
        XCTAssertEqual(scene.effectiveGeometry.interfaceOrientation.isLandscape, landscape)
        let environment = ProcessInfo.processInfo.environment
        let deviceID = try XCTUnwrap(environment["SIMULATOR_UDID"])
        let modelIdentifier = try XCTUnwrap(environment["SIMULATOR_MODEL_IDENTIFIER"])
        let isTablet = scene.traitCollection.userInterfaceIdiom == .pad
        XCTAssertTrue(isTablet || scene.traitCollection.userInterfaceIdiom == .phone)
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let originalTimeZone = NSTimeZone.default
        let animationsEnabled = UIView.areAnimationsEnabled
        NSTimeZone.default = timeZone
        UIView.setAnimationsEnabled(false)
        defer {
            NSTimeZone.default = originalTimeZone
            UIView.setAnimationsEnabled(animationsEnabled)
        }
        let sampling = VisibleViewportSampling()
        let host = try await FullContentHost(
            rootView: ScrollView {
                Color.clear.frame(height: 10_000)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.timeZone, timeZone)
            .preferredColorScheme(.light),
            sampling: sampling, samplingKey: \.visibleViewportSampling,
            frozen: \VisibleViewportSampling.isFrozen, contentSizeCategory: .large
        )
        defer { host.dismiss() }

        // Require three equal samples over separate layout opportunities. An unstable safe area or an
        // orientation transition fails the finite probe instead of becoming a partially settled pin.
        var previous: Data?
        var geometry: [String: Any]?
        var stableSamples = 0
        for _ in 1...12 {
            try await Task.sleep(for: .milliseconds(30))
            host.window.layoutIfNeeded()
            host.controller.view.layoutIfNeeded()
            let sample = Self.geometry(window: host.window, scene: scene)
            let bytes = try JSONSerialization.data(withJSONObject: sample, options: [.sortedKeys])
            stableSamples = bytes == previous ? stableSamples + 1 : 0
            previous = bytes
            geometry = sample
            if stableSamples >= 2 { break }
        }
        XCTAssertGreaterThanOrEqual(stableSamples, 2, "Native window geometry did not converge")
        XCTAssertTrue(host.isAttachedToActiveWindow)
        XCTAssertEqual(host.window.bounds.size, scene.effectiveGeometry.coordinateSpace.bounds.size)
        XCTAssertEqual(host.window.traitCollection.horizontalSizeClass, scene.traitCollection.horizontalSizeClass)
        XCTAssertEqual(host.window.traitCollection.verticalSizeClass, scene.traitCollection.verticalSizeClass)
        XCTAssertEqual(host.window.traitCollection.preferredContentSizeCategory, .large)
        XCTAssertEqual(UIApplication.shared.preferredContentSizeCategory, .large)
        XCTAssertEqual(Locale.current.identifier, "en_US")

        let size = host.window.bounds.size
        let scale = host.window.traitCollection.displayScale
        let pixels = [Int((size.width * scale).rounded()), Int((size.height * scale).rounded())]
        let portrait = isTablet ? [1668, 2420] : [1260, 2736]
        expectNoDifference(pixels, landscape ? Array(portrait.reversed()) : portrait)
        let settings: [String: Any] = [
            "locale": Locale.current.identifier, "timeZone": NSTimeZone.default.identifier,
            "fixedDateUnix": PublicVisualFixtures.fixedDate.timeIntervalSince1970,
            "textSize": "large", "fontDesign": "system", "animationsEnabled": UIView.areAnimationsEnabled
        ]
        let evidence: [String: Any] = [
            "family": isTablet ? "ipad" : "iphone", "orientation": landscape ? "landscape" : "portrait",
            "deviceID": deviceID, "modelIdentifier": modelIdentifier,
            "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
            "stableSamples": stableSamples, "windowIsAttached": host.isAttachedToActiveWindow,
            "settings": settings, "geometry": try XCTUnwrap(geometry)
        ]
        let bytes = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "phase17-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private static func geometry(window: UIWindow, scene: UIWindowScene) -> [String: Any] {
        let traits = window.traitCollection
        let size = window.bounds.size
        let insets = window.safeAreaInsets
        let styles: [(name: String, style: UIFont.TextStyle)] = [
            ("body", .body), ("caption1", .caption1), ("title1", .title1)
        ]
        let fonts = Dictionary(uniqueKeysWithValues: styles.map { item in
            let font = UIFont.preferredFont(forTextStyle: item.style, compatibleWith: traits)
            return (item.name, [
                "name": font.fontName, "pointSize": font.pointSize, "lineHeight": font.lineHeight
            ] as [String: Any])
        })
        return [
            "points": [size.width, size.height],
            "pixels": [Int((size.width * traits.displayScale).rounded()),
                       Int((size.height * traits.displayScale).rounded())],
            "safeAreaInsets": [insets.top, insets.left, insets.bottom, insets.right],
            "scale": traits.displayScale, "nativeScale": scene.screen.nativeScale,
            "horizontalSizeClass": traits.horizontalSizeClass.rawValue,
            "verticalSizeClass": traits.verticalSizeClass.rawValue,
            "contentSizeCategory": traits.preferredContentSizeCategory.rawValue,
            "appearance": traits.userInterfaceStyle.rawValue,
            "displayGamut": traits.displayGamut.rawValue,
            "boldTextEnabled": UIAccessibility.isBoldTextEnabled,
            "legibilityWeight": traits.legibilityWeight.rawValue, "fonts": fonts
        ]
    }
}
