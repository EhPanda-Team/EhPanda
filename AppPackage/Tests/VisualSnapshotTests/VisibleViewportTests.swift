import AppComponents
import AppFeature
import CustomDump
import Observation
import SwiftUI
import UIKit
import XCTest

final class VisibleViewportTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testUnfrozenMeasurementForwardsEverySizeChange() async throws {
        let host = try ViewportProbeHost()
        defer { host.dismiss() }
        try await host.settle()
        let initial = host.probe.size
        expectNoDifference(host.probe.forwardedSizes, [initial])

        let second = CGSize(width: 210, height: 130)
        await expectDifference(host.probe.forwardedSizes) {
            host.probe.size = second
            try await host.settle()
        } changes: {
            $0.append(second)
        }

        host.probe.size = initial
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [initial, second, initial])
    }

    @MainActor
    func testFrozenMeasurementDefersLatestSizeUntilThaw() async throws {
        let host = try ViewportProbeHost()
        defer { host.dismiss() }
        try await host.settle()
        let initial = host.probe.size

        host.probe.isFrozen = true
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [initial])
        for size in [CGSize(width: 220, height: 150), CGSize(width: 230, height: 180)] {
            host.probe.size = size
            try await host.settle()
            expectNoDifference(host.probe.forwardedSizes, [initial])
        }

        let latest = host.probe.size
        await expectDifference(host.probe.forwardedSizes) {
            host.probe.isFrozen = false
            try await host.settle()
        } changes: {
            $0.append(latest)
        }

        host.probe.isFrozen = true
        try await host.settle()
        host.probe.isFrozen = false
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [initial, latest])

        host.probe.size = initial
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [initial, latest, initial])
    }

    @MainActor
    func testInitiallyFrozenMeasurementEmitsCurrentSizeOnThaw() async throws {
        let host = try ViewportProbeHost(initiallyFrozen: true)
        defer { host.dismiss() }
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [])

        host.probe.size = CGSize(width: 250, height: 190)
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [])

        host.probe.isFrozen = false
        try await host.settle()
        expectNoDifference(host.probe.forwardedSizes, [host.probe.size])
    }
}

@MainActor
@Observable
private final class ViewportProbe {
    var size = CGSize(width: 200, height: 100)
    var isFrozen = false
    @ObservationIgnored var measuredSize: CGSize?
    @ObservationIgnored var renderedFrozen: Bool?
    @ObservationIgnored var forwardedSizes: [CGSize] = []
}

private struct ViewportProbeView: View {
    let probe: ViewportProbe

    var body: some View {
        Color.clear
            .frame(width: probe.size.width, height: probe.size.height)
            .onVisibleViewportChange { probe.forwardedSizes.append($0) }
            .onGeometryChange(for: CGSize.self, of: \.size) { probe.measuredSize = $0 }
            .onChange(of: probe.isFrozen, initial: true) {
                probe.renderedFrozen = probe.isFrozen
            }
            .environment(\.isVisibleViewportFrozen, probe.isFrozen)
    }
}

@MainActor
private final class ViewportProbeHost {
    let probe = ViewportProbe()
    private let window: UIWindow
    private let previousKeyWindow: UIWindow?

    init(initiallyFrozen: Bool = false) throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
        probe.isFrozen = initiallyFrozen
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: ViewportProbeView(probe: probe))
        window.makeKeyAndVisible()
    }

    func settle() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        repeat {
            try await clock.sleep(for: .milliseconds(20))
            window.layoutIfNeeded()
            if probe.measuredSize == probe.size, probe.renderedFrozen == probe.isFrozen { return }
        } while clock.now < deadline
        XCTFail("SwiftUI did not apply the requested geometry and freeze state")
        throw ViewportProbeError.layoutDidNotSettle
    }

    func dismiss() {
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
}

private enum ViewportProbeError: Error {
    case layoutDidNotSettle
}
