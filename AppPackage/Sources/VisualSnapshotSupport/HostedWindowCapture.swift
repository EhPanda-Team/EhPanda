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
    /// The first attempt's picture and difference when that attempt differed or timed out, so a flaky picture can
    /// be read afterwards.
    public var firstAttempt: (png: Data?, difference: Data?)?
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

    /// The last motion the latest ``settle(_:)`` read (a view or layer class and animation key, never page text),
    /// for a timeout's reason.
    public private(set) static var lastMotion: String?

    /// Reads the window at 1x every ``sampleInterval`` until the reads stay identical across at least
    /// ``stableSpan`` while the window is at rest (``motion(in:)`` is `nil`), or gives up after ``maximumSamples``
    /// reads.
    ///
    /// A read is the picture as the comparison sees it (``comparedBytes(_:)``), not the 16-bit capture: Liquid
    /// Glass moves the capture's low bits below what the comparison reads, so a byte-exact read of the capture
    /// could keep a window that is still for the comparison from settling.
    ///
    /// Identical reads alone are not rest: a scroll indicator that a scroll view flashes when it appears holds still
    /// for longer than ``stableSpan`` before it fades, and a list can hold an offset between two steps of an
    /// animation. On a loaded host either could be read as settled in one run and not in the next (run
    /// 42455556948), so reads count only once nothing in the window moves.
    public static func settle(_ window: UIWindow) async -> SettleResult {
        let clock = ContinuousClock()
        let start = clock.now
        var runStart = clock.now
        var previous: [UInt8]?
        lastMotion = nil
        for sample in 1...maximumSamples {
            let moving = motion(in: window)
            lastMotion = moving ?? lastMotion
            let data = moving == nil ? comparedBytes(capture(window)) : nil
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

    /// What still moves in `window`, or `nil` when it is at rest: a scroll view that is tracked, dragged or
    /// decelerating, a scroll indicator that is showing, or a finite layer animation that has not ended.
    ///
    /// A layer whose `speed` is 0 is frozen on purpose (a scenario that holds an indeterminate indicator or a caret
    /// still), so it and its sublayers are not read. An animation that repeats forever (an
    /// indicator's spin, a caret's blink) never ends and is the scenario's own state, not motion.
    public static func motion(in window: UIWindow) -> String? {
        if let view = movingView(in: window) { return view }
        return runningAnimation(in: window.layer, now: CACurrentMediaTime())
    }

    private static func movingView(in view: UIView) -> String? {
        if view.isHidden || view.alpha < 0.01 { return nil }
        if let scrollView = view as? UIScrollView,
           scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
            return "scrolling:\(String(describing: type(of: scrollView)))"
        }
        // UIKit's scroll indicators are private subviews of their scroll view; a visible one fades out on a timer.
        if view.superview is UIScrollView, String(describing: type(of: view)).contains("ScrollIndicator") {
            return "scroll-indicator"
        }
        for subview in view.subviews {
            if let moving = movingView(in: subview) { return moving }
        }
        return nil
    }

    /// An animation longer than this repeats for as long as its view shows.
    private static let forever: CFTimeInterval = 3600

    /// Whether `animation` repeats for as long as its view shows (an indicator's spin, a caret's blink): the
    /// scenario's own state, not motion that ends.
    public static func repeatsForever(_ animation: CAAnimation) -> Bool {
        let length = length(of: animation)
        // UIKit writes "forever" as a huge finite count (an animated image view repeats 2^31 times).
        return !length.isFinite || length > forever
    }

    private static func length(of animation: CAAnimation) -> CFTimeInterval {
        let cycles = Double(max(animation.repeatCount, 1)) * (animation.autoreverses ? 2 : 1)
        let rate = Double(max(animation.speed, 0.0001))
        return max(animation.repeatDuration, animation.duration * cycles) / rate
    }

    private static func runningAnimation(in layer: CALayer, now: CFTimeInterval) -> String? {
        if layer.speed == 0 { return nil }
        // A caret blinks on a timer of its own for as long as its field is focused.
        if let delegate = layer.delegate, String(describing: type(of: delegate)).contains("Cursor") { return nil }
        let local = layer.convertTime(now, from: nil)
        let owner = layer.delegate.map({ String(describing: type(of: $0)) }) ?? String(describing: type(of: layer))
        for key in layer.animationKeys() ?? [] {
            guard let animation = layer.animation(forKey: key) else { continue }
            // Not yet committed: it starts at the next commit.
            if animation.beginTime == 0 { return "animation:\(owner):\(key)" }
            if repeatsForever(animation) { continue }
            if animation.beginTime + length(of: animation) > local { return "animation:\(owner):\(key)" }
        }
        for sublayer in layer.sublayers ?? [] {
            if let running = runningAnimation(in: sublayer, now: now) { return running }
        }
        return nil
    }

    /// The image's pixels as the library's image comparison reads them: 8-bit sRGB, premultiplied RGBA.
    public static func comparedBytes(_ image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bytesPerRow = cgImage.width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * cgImage.height)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return true
        }
        return drawn ? bytes : nil
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
        let referenceImage = diffing.fromData(data)
        guard diffing.diffV2(referenceImage, image) != nil else { return .passed }
        return .changed(difference: differencePNG(referenceImage, image))
    }

    /// A difference picture read the way the comparison reads both pictures (``comparedBytes(_:)``): a pixel that
    /// differs is white, brighter the larger its largest channel difference; an equal pixel is the actual picture at
    /// an eighth of its brightness, for orientation. `nil` when the sizes differ.
    ///
    /// The library's own difference picture is not used: it reads the raw bytes of both images as 8-bit RGBA, but a
    /// capture is 16-bit RGB (48 bits a pixel), so its picture is the first two thirds of the bytes laid out at the
    /// wrong stride, and nothing in the bottom third of a picture ever shows in it (run 42455556948).
    public static func differencePNG(_ reference: UIImage, _ actual: UIImage) -> Data? {
        guard let old = comparedBytes(reference), let new = comparedBytes(actual), old.count == new.count,
              let width = actual.cgImage?.width, let height = actual.cgImage?.height,
              old.count == width * height * 4 else { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(old.count)
        for start in stride(from: 0, to: old.count, by: 4) {
            let channels = start..<(start + 3)
            let largest = channels.map({ abs(Int(old[$0]) - Int(new[$0])) }).max() ?? 0
            out += channels.map({ largest == 0 ? new[$0] / 8 : UInt8(min(255, 128 + largest * 4)) })
            out.append(255)
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let cgImage = out.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        return cgImage.flatMap({ UIImage(cgImage: $0, scale: 1, orientation: .up).pngData() })
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
            var outcome = CaptureOutcome(
                status: result.status, attempts: attempt,
                flaky: firstFailed && (result.status == .passed || result.status == .recorded),
                seconds: elapsed, settleSamples: result.settleSamples, png: result.png,
                difference: result.difference, reason: result.reason
            )
            if attempt == 2, let first = last { outcome.firstAttempt = (first.png, first.difference) }
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
                           reason: lastMotion.map({ "settle-timeout:\($0)" }) ?? "settle-timeout")
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
