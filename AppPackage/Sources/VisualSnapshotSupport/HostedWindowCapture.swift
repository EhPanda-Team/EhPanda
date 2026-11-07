public import Foundation
public import SnapshotTesting
public import SwiftUI
public import UIKit

/// How a matrix run treats its pictures.
public enum SnapshotMode: String, Sendable {
    /// Compares every picture with the approved reference, which is only ever read.
    case compare
    /// Writes every picture into the run's output directory as a candidate for approval. Never touches a reference.
    case candidate
}

/// The outcome of waiting for a hosted window to stop changing.
public enum SettleResult: Equatable, Sendable {
    /// Consecutive 1x reads stayed identical across at least ``HostedWindowCapture/stableSpan``.
    case settled(samples: Int, seconds: Double)
    /// ``HostedWindowCapture/maximumSamples`` reads never stayed identical for long enough.
    case timeout(samples: Int, seconds: Double)

    public var samples: Int {
        switch self {
        case .settled(let samples, _), .timeout(let samples, _): samples
        }
    }

    public var seconds: Double {
        switch self {
        case .settled(_, let seconds), .timeout(_, let seconds): seconds
        }
    }
}

/// One comparison of a captured picture with its reference.
public enum ComparisonOutcome: Equatable, Sendable {
    case passed
    /// The picture differs beyond the tolerance; `difference` is the library's difference image as PNG.
    case changed(difference: Data?)
    case missingBaseline
    /// The reference exists but is not a readable image.
    case unreadableBaseline
}

/// The status vocabulary shared with the Python aggregate (19-RESEARCH §9).
public enum SnapshotStatus: String, Codable, Sendable {
    case passed
    case changed
    case missingBaseline = "missing-baseline"
    case recorded
    case timeout
    case error
    case notApplicable
}

/// What ``HostedWindowCapture/captureAndCompare(make:window:style:reference:candidate:mode:)`` produced.
public struct CaptureOutcome: Sendable {
    public let status: SnapshotStatus
    public let attempts: Int
    /// A first attempt that differed or timed out and a second attempt that passed.
    public let flaky: Bool
    public let seconds: Double
    public let settleSamples: Int
    /// The PNG of the last attempt's picture.
    public let png: Data?
    /// The library's difference image of the last failed comparison.
    public let difference: Data?
    /// A fixed reason code for a non-passing outcome, never page text.
    public let reason: String?
}

/// A SwiftUI root installed as the root view controller of a real window.
@MainActor
public final class HostedRoot {
    public let controller: UIHostingController<AnyView>
    private let window: UIWindow
    private let previousRoot: UIViewController?
    private let previousStyle: UIUserInterfaceStyle
    private var isDisposed = false

    init(controller: UIHostingController<AnyView>, window: UIWindow, previousRoot: UIViewController?,
         previousStyle: UIUserInterfaceStyle) {
        self.controller = controller
        self.window = window
        self.previousRoot = previousRoot
        self.previousStyle = previousStyle
    }

    /// Dismisses anything the root presented, waits until the dismissal finishes, then restores the window.
    ///
    /// Restoring the root while a presentation (an alert) is still being torn down leaves its transition view in the
    /// window in place of the restored root, which then refuses every orientation but the current one.
    public func disposeAfterDismissal() async {
        guard !isDisposed else { return }
        if controller.presentedViewController != nil {
            await withCheckedContinuation { continuation in
                controller.dismiss(animated: false) {
                    continuation.resume()
                }
            }
        }
        dispose()
    }

    /// Dismisses anything the root presented and restores the window's previous root and appearance.
    public func dispose() {
        guard !isDisposed else { return }
        isDisposed = true
        controller.dismiss(animated: false)
        window.rootViewController = previousRoot
        window.overrideUserInterfaceStyle = previousStyle
        window.layoutIfNeeded()
    }
}

/// Path B of the Phase 19 snapshot spike (19-CONTEXT D-08): the real view is hosted in the app-hosted test's real
/// key window, the test waits until the window stops changing, draws the window at 1x, and compares the picture with
/// the library's image diffing.
///
/// The spike measured this path at 0 mismatches in 75 exact 1x compares, and showed that it renders Liquid Glass,
/// materials, menus, alerts, sheets, confirmation dialogs and the soft scroll edge (D-09). Comparison uses precision
/// 0.9999 and perceptual precision 1 everywhere (D-10); a deliberate 1-point layout shift still fails it.
@MainActor
public enum HostedWindowCapture {
    /// The shortest span of identical consecutive reads that counts as settled.
    public static let stableSpan: Duration = .milliseconds(500)
    public static let sampleInterval: Duration = .milliseconds(100)
    public static let maximumSamples = 40
    public static let precision: Float = 0.9999
    public static let perceptualPrecision: Float = 1

    /// The library's image diffing at the matrix tolerance; references are stored at scale 1.
    public static var diffing: Diffing<UIImage> {
        .image(precision: 0.9999, perceptualPrecision: 1, scale: 1)
    }

    /// The key window of the foreground scene.
    public static func keyWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .filter({ $0.activationState == .foregroundActive })
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    /// Installs `root` as the window's root view controller with animations disabled.
    public static func host(_ root: some View, in window: UIWindow, style: UIUserInterfaceStyle) -> HostedRoot {
        let previousRoot = window.rootViewController
        let previousStyle = window.overrideUserInterfaceStyle
        window.overrideUserInterfaceStyle = style
        let controller = UIHostingController(rootView: AnyView(root.transaction {
            $0.disablesAnimations = true
            $0.animation = nil
        }))
        controller.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return HostedRoot(
            controller: controller, window: window, previousRoot: previousRoot, previousStyle: previousStyle
        )
    }

    /// Reads the window at 1x every ``sampleInterval`` until the reads stay identical across at least
    /// ``stableSpan``, or gives up after ``maximumSamples`` reads.
    public static func settle(_ window: UIWindow) async -> SettleResult {
        let clock = ContinuousClock()
        let start = clock.now
        var runStart = clock.now
        var previous: Data?
        for sample in 1...maximumSamples {
            let data = capture(window).pngData()
            if let data, data == previous {
                if runStart.duration(to: clock.now) >= stableSpan {
                    return .settled(samples: sample, seconds: seconds(start.duration(to: clock.now)))
                }
            } else {
                runStart = clock.now
            }
            previous = data
            do {
                try await clock.sleep(for: sampleInterval)
            } catch {
                // Cancellation ends the wait; the reads so far did not settle.
                return .timeout(samples: sample, seconds: seconds(start.duration(to: clock.now)))
            }
        }
        return .timeout(samples: maximumSamples, seconds: seconds(start.duration(to: clock.now)))
    }

    /// Draws the window's hierarchy into an opaque image at scale 1, so its pixel size is the window's point size.
    public static func capture(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    /// Compares `image` with the reference file. The reference is only read, never written.
    public static func compare(_ image: UIImage, reference: URL) -> ComparisonOutcome {
        let data: Data
        do {
            data = try Data(contentsOf: reference)
        } catch {
            return .missingBaseline
        }
        // The library's `fromData` force-unwraps, so a damaged reference is rejected here first.
        guard UIImage(data: data) != nil else { return .unreadableBaseline }
        let diffing = Self.diffing
        guard let (_, attachments) = diffing.diffV2(diffing.fromData(data), image) else { return .passed }
        let difference = attachments.lazy.compactMap { attachment -> Data? in
            if case .data(let bytes, let name) = attachment, name == "difference.png" { return bytes }
            return nil
        }.first
        return .changed(difference: difference)
    }

    /// The PNG bytes the library would store for `image`.
    public static func pngData(_ image: UIImage) -> Data {
        diffing.toData(image)
    }

    /// Hosts, settles, captures and compares (or records) one picture, retrying a difference or a timeout once.
    ///
    /// The retry re-hosts a fresh root from `make`, settles and captures again (owner msg 2263): a second pass that
    /// passes is `passed` with `flaky`; otherwise the second pass decides (`changed` or `timeout`). In candidate
    /// mode the picture is returned for the caller to write into the run's output; `reference` is never touched.
    ///
    /// `interact`, when given, runs after hosting and before the settle wait: the user step that brings a scenario
    /// to its state where no store state can (a moderation alert that its row presents after the row's own action).
    public static func captureAndCompare(
        make: () throws -> AnyView, window: UIWindow, style: UIUserInterfaceStyle, reference: URL?,
        mode: SnapshotMode, interact: (@MainActor (UIWindow) async throws -> Void)? = nil
    ) async -> CaptureOutcome {
        let clock = ContinuousClock()
        let start = clock.now
        var firstFailed = false
        var last: CaptureOutcome?
        for attempt in 1...2 {
            let result = await attemptOnce(
                make: make, window: window,
                request: .init(style: style, reference: reference, mode: mode, interact: interact)
            )
            let elapsed = seconds(start.duration(to: clock.now))
            let outcome = CaptureOutcome(
                status: result.status, attempts: attempt,
                flaky: firstFailed && (result.status == .passed || result.status == .recorded),
                seconds: elapsed, settleSamples: result.settleSamples, png: result.png,
                difference: result.difference, reason: result.reason
            )
            switch result.status {
            case .changed, .timeout:
                firstFailed = true
                last = outcome
                continue
            default:
                return outcome
            }
        }
        // Both attempts failed; `last` always holds the second.
        return last ?? CaptureOutcome(
            status: .error, attempts: 2, flaky: false, seconds: seconds(start.duration(to: clock.now)),
            settleSamples: 0, png: nil, difference: nil, reason: "no-attempt"
        )
    }

    private struct Request {
        let style: UIUserInterfaceStyle
        let reference: URL?
        let mode: SnapshotMode
        let interact: (@MainActor (UIWindow) async throws -> Void)?
    }

    private struct Attempt {
        let status: SnapshotStatus
        let settleSamples: Int
        let png: Data?
        let difference: Data?
        let reason: String?
    }

    private static func attemptOnce(make: () throws -> AnyView, window: UIWindow, request: Request) async -> Attempt {
        let root: AnyView
        do {
            root = try make()
        } catch {
            return Attempt(status: .error, settleSamples: 0, png: nil, difference: nil, reason: "factory")
        }
        let hosted = host(root, in: window, style: request.style)
        let attempt = await attemptHosted(window: window, request: request)
        await hosted.disposeAfterDismissal()
        return attempt
    }

    private static func attemptHosted(window: UIWindow, request: Request) async -> Attempt {
        if let interact = request.interact {
            do {
                try await interact(window)
            } catch {
                return Attempt(status: .error, settleSamples: 0, png: nil, difference: nil, reason: "interaction")
            }
        }
        let settled = await settle(window)
        let image = capture(window)
        let png = pngData(image)
        if case .timeout = settled {
            return Attempt(status: .timeout, settleSamples: settled.samples, png: png, difference: nil,
                           reason: "settle-timeout")
        }
        switch request.mode {
        case .candidate:
            return Attempt(status: .recorded, settleSamples: settled.samples, png: png, difference: nil, reason: nil)
        case .compare:
            guard let reference = request.reference else {
                return Attempt(status: .missingBaseline, settleSamples: settled.samples, png: png, difference: nil,
                               reason: "no-reference-directory")
            }
            switch compare(image, reference: reference) {
            case .passed:
                return Attempt(status: .passed, settleSamples: settled.samples, png: png, difference: nil,
                               reason: nil)
            case .changed(let difference):
                return Attempt(status: .changed, settleSamples: settled.samples, png: png, difference: difference,
                               reason: "pixels")
            case .missingBaseline:
                return Attempt(status: .missingBaseline, settleSamples: settled.samples, png: png,
                               difference: nil, reason: "missing-reference")
            case .unreadableBaseline:
                return Attempt(status: .error, settleSamples: settled.samples, png: png, difference: nil,
                               reason: "unreadable-reference")
            }
        }
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
