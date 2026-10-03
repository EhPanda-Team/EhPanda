import Foundation
import Observation
import SnapshotTesting
import SwiftUI
import UIKit
import Vision

public struct FullContentCaptureEvidence {
    public let contentHeight: CGFloat
    public let finalItemClipped: Bool
    public let fullImageByteCount: Int
    public let fullImageURL: URL
    public let hostBundlePath: String
    public let itemCensus: [String: Int]
    public let itemFrames: [String: CGRect]
    public let normalImageByteCount: Int
    public let normalImageURL: URL
    public let outputSize: CGSize
    public let pinnedViewportSize: CGSize
    public let renderSettleSamples: Int
    public let renderSliceCount: Int
    public let sceneBounds: CGRect
    public let stableIterations: Int
    public let statusBarHidden: Bool
    public let testHostPath: String
    public let trailingMarkerFrame: CGRect
    public let viewport: MeasuredViewport
    public let windowBounds: CGRect
    public let windowIsAttached: Bool
}

public struct MeasuredViewport {
    public let safeAreaInsets: UIEdgeInsets
    public let scale: CGFloat
    public let size: CGSize
    public let traits: UITraitCollection
}

public struct CaptureItemExpectation: Sendable {
    public let title: String
    public let marker: String
    public let artworkAspectRatio: CGFloat?
    public let requiresInsetArtwork: Bool

    public init(
        title: String, marker: String, artworkAspectRatio: CGFloat? = nil, requiresInsetArtwork: Bool = true
    ) {
        self.title = title
        self.marker = marker
        self.artworkAspectRatio = artworkAspectRatio
        self.requiresInsetArtwork = requiresInsetArtwork
    }
}

/// Measures native device geometry, then captures the whole scrollable content as one image.
///
/// The window is grown to the full content height so the hierarchy is laid out once and nothing moves. The long
/// image is that one laid-out hierarchy read back from the render server in slices of at most
/// ``RenderServerCapture/maximumSnapshotDimension`` screen pixels (the Simulator render server refuses any larger
/// single snapshot), composed into a single image, with the overlapping seam bands proven byte-identical. These are
/// not scrolled viewport images: every slice is a rect of the same committed frame. The top of the long image is
/// then checked against a native viewport capture. SnapshotTesting is still used to record, verify and diff images.
@MainActor
public final class FullContentHost<Content: View> {
    public let controller: UIHostingController<AnyView>
    public let scene: UIWindowScene
    public let window: UIWindow
    public let viewport: MeasuredViewport

    private let previousKeyWindow: UIWindow?
    private let standardImageRange: Bool
    private let viewportPin = VisibleViewportPin()
    private var verticalScrollHost: UIScrollView
    /// The full-screen window that owns the status bar while ``window`` is taller than the screen. See
    /// ``StatusBarAppearanceController``.
    private var companionWindow: UIWindow?

    public init(
        rootView: Content, visibleViewportKey: WritableKeyPath<EnvironmentValues, CGSize?>,
        contentSizeCategory: UIContentSizeCategory? = nil,
        standardImageRange: Bool = false,
        isViewportReady: @MainActor () -> Bool = { true }
    ) async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw FullContentHostError.noForegroundActiveScene
        }
        self.scene = scene
        self.standardImageRange = standardImageRange
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        if standardImageRange {
            window.traitOverrides.displayGamut = .SRGB
            window.traitOverrides.imageDynamicRange = .standard
        }
        if let contentSizeCategory {
            window.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        }
        controller = UIHostingController(rootView: AnyView(
            ViewportPinnedContent(content: rootView, pin: viewportPin, key: visibleViewportKey)
        ))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        let size = window.bounds.size
        guard size.width > 0, size.height > 0 else {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            throw FullContentHostError.invalidViewport(size)
        }
        viewport = MeasuredViewport(
            safeAreaInsets: window.safeAreaInsets,
            scale: window.traitCollection.displayScale,
            size: size,
            traits: window.traitCollection
        )
        controller.view.frame = window.bounds
        var resolvedScrollHost: UIScrollView?
        do {
            for _ in 1...12 {
                try Task.checkCancellation()
                await LayoutFrame.wait()
                controller.view.layoutIfNeeded()
                resolvedScrollHost = Self.descendants(of: controller.view)
                    .compactMap({ $0 as? UIScrollView })
                    .filter({ $0.contentSize.height > $0.bounds.height && $0.bounds.width > 0 })
                    .max(by: { $0.contentSize.height < $1.contentSize.height })
                if resolvedScrollHost != nil && isViewportReady() { break }
            }
        } catch {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            throw error
        }
        guard let scrollHost = resolvedScrollHost, isViewportReady() else {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            throw FullContentHostError.missingVerticalScrollHost
        }
        verticalScrollHost = scrollHost
    }

    public var isAttachedToActiveWindow: Bool {
        window.windowScene?.activationState == .foregroundActive && controller.view.window === window
    }

    public func dismiss() {
        viewportPin.size = nil
        removeStatusBarCompanion()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }

    public func capture(
        expectedItems: [CaptureItemExpectation],
        trailingMarker: String,
        outputDirectory: URL,
        record: SnapshotTestingConfiguration.Record = .never,
        isContentReady: @MainActor () -> Bool = { true }
    ) async throws -> FullContentCaptureEvidence {
        guard isAttachedToActiveWindow else { throw FullContentHostError.inactiveWindow }
        guard record == .never || record == .all else { throw FullContentHostError.invalidRecordMode }
        guard !expectedItems.isEmpty,
              Set(expectedItems.map(\.title)).count == expectedItems.count,
              Set(expectedItems.map(\.marker)).count == expectedItems.count else {
            throw FullContentHostError.duplicateExpectedItems
        }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let originalWindowFrame = window.frame
        let originalRootBounds = controller.view.bounds
        let originalOffset = verticalScrollHost.contentOffset
        let originalInsets = verticalScrollHost.adjustedContentInset
        let originalScrollHeight = verticalScrollHost.bounds.height
        let originalSceneBounds = scene.effectiveGeometry.coordinateSpace.bounds
        let originalOrientation = scene.effectiveGeometry.interfaceOrientation
        let scrollGeometry = Self.descendants(of: controller.view)
            .compactMap({ $0 as? UIScrollView })
            .filter({ $0 !== verticalScrollHost })
            .map({ $0.convert($0.bounds, to: controller.view) })
        defer {
            viewportPin.size = nil
            window.frame = originalWindowFrame
            controller.view.frame = window.bounds
            removeStatusBarCompanion()
            verticalScrollHost.setContentOffset(originalOffset, animated: false)
            controller.view.layoutIfNeeded()
        }
        let settled = try await settledViewportRendering(directory: outputDirectory)
        let normalImage = settled.rendering.image
        let normalURL = outputDirectory.appending(path: "capture.viewport.png")
        try store(normalImage, at: normalURL, name: "viewport", directory: outputDirectory, record: record)

        let pinnedViewportSize = verticalScrollHost.bounds.size
        viewportPin.size = pinnedViewportSize
        await LayoutFrame.wait()
        controller.view.layoutIfNeeded()
        let pinned = try await settledViewportRendering(directory: outputDirectory)
        let pinnedURL = outputDirectory.appending(path: "capture.pinned-viewport.png")
        try store(
            pinned.rendering.image, at: pinnedURL, name: "pinned-viewport", directory: outputDirectory, record: record
        )
        guard let referenceCG = normalImage.cgImage, let pinnedCG = pinned.rendering.image.cgImage else {
            throw FullContentHostError.emptyImage
        }
        let referencePixels = try CapturedRaster(image: referenceCG).pixels
        let pinnedPixels = try CapturedRaster(image: pinnedCG).pixels
        let pinMatches = referenceCG.width == pinnedCG.width && referenceCG.height == pinnedCG.height
            && referencePixels == pinnedPixels
        try JSONSerialization.data(withJSONObject: [
            "comparison": "byte-identical 8-bit sRGB RGBA before growth", "matched": pinMatches,
            "visibleViewport": [pinnedViewportSize.width, pinnedViewportSize.height],
            "windowViewport": [viewport.size.width, viewport.size.height],
            "unpinnedSettleSamples": settled.samples, "pinnedSettleSamples": pinned.samples
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: outputDirectory.appending(path: "visible-viewport-pin-parity.json"), options: .atomic)
        guard pinMatches else { throw FullContentHostError.visibleViewportPinChangedPixels }

        // UIKit lets only a window that covers the whole screen drive the status bar. Once the key window grows
        // past the screen it loses that role and the status bar reappears (measured 2026-10-03: hidden -> visible,
        // status bar frame 54 pt on the phone / 32 pt on the iPad, iPad safe-area top 0 -> 32), and the soft
        // scroll-edge effect renders under it. A full-screen companion window therefore owns the status bar state
        // while the capture window is tall, so that window keeps the viewport's status bar, safe area and edge
        // effect. It mirrors the state measured at viewport size rather than hard-coding hidden, which keeps
        // screens with a visible status bar unchanged.
        let statusBarHidden = scene.statusBarManager?.isStatusBarHidden ?? false
        let companion = UIWindow(windowScene: scene)
        companion.rootViewController = StatusBarAppearanceController(hidesStatusBar: statusBarHidden)
        // At `.normal`, created after the capture window, so it is the topmost full-screen window: the host app's
        // own full-screen main window is also at `.normal` with a visible status bar, and a companion below it
        // (`.normal - 1`) never takes over the status bar (measured 2026-10-03). It is never made key; the capture
        // window stays key, and a clear, non-key companion in front of it does not affect the replicant reads,
        // which draw the captured hierarchy itself.
        companion.windowLevel = .normal
        companion.isHidden = false
        companionWindow = companion

        var previousHeight: CGFloat?
        var previousOutputHeight: CGFloat?
        var stableIterations = 0
        var contentHeight = verticalScrollHost.contentSize.height
        var outputSize = viewport.size
        for _ in 1...12 {
            try Task.checkCancellation()
            guard isAttachedToActiveWindow else { throw FullContentHostError.inactiveWindow }
            outputSize.height = ceil(
                (viewport.size.height + contentHeight + originalInsets.top + originalInsets.bottom
                 - originalScrollHeight) * viewport.scale
            ) / viewport.scale
            // The composite bitmap memory budget (about 165 MB at 1260 px wide, 4 bytes per pixel), NOT a render
            // limit: slicing renders any height. Per-slice admissibility is
            // `RenderServerCapture.maximumSnapshotDimension`.
            guard outputSize.height * viewport.scale <= 32_768 else {
                throw FullContentHostError.contentHeightExceeded(outputSize.height * viewport.scale)
            }
            guard outputSize.height > viewport.size.height else {
                throw FullContentHostError.contentDoesNotExceedViewport(contentHeight)
            }
            window.frame.size = outputSize
            controller.view.frame = window.bounds
            window.layoutIfNeeded()
            verticalScrollHost.setContentOffset(CGPoint(x: originalOffset.x, y: -originalInsets.top), animated: false)
            await LayoutFrame.wait()
            // Verified rather than assumed: the companion must keep the status bar state the viewport had.
            guard scene.statusBarManager?.isStatusBarHidden == statusBarHidden else {
                throw FullContentHostError.statusBarStateChanged(expectedHidden: statusBarHidden)
            }
            controller.view.layoutIfNeeded()
            let currentHeight = verticalScrollHost.contentSize.height
            let isStable = previousHeight.map({ abs(currentHeight - $0) * viewport.scale <= 1 }) == true
                && previousOutputHeight.map({ abs(outputSize.height - $0) * viewport.scale <= 1 }) == true
                && isContentReady()
            stableIterations = isStable ? stableIterations + 1 : 0
            previousHeight = currentHeight
            previousOutputHeight = outputSize.height
            contentHeight = currentHeight
            if stableIterations >= 2 { break }
        }
        guard stableIterations >= 2 else { throw FullContentHostError.didNotConverge }
        let measurement = CaptureMeasurement(
            contentHeight: contentHeight, outputSize: outputSize, stableIterations: stableIterations,
            renderSettleSamples: settled.samples,
            renderSettleMilliseconds: Int((settled.settledDuration / .milliseconds(1)).rounded()),
            statusBarHidden: statusBarHidden
        )
        let rendering = try render(size: outputSize, directory: outputDirectory)
        let fullImage = rendering.image
        let fullURL = outputDirectory.appending(path: "capture.full-content.png")
        try store(fullImage, at: fullURL, name: "full-content", directory: outputDirectory, record: record)
        try writeDiagnostics(
            elements: [], census: [:],
            measurement: measurement, rendering: rendering, directory: outputDirectory
        )
        guard let normalCG = normalImage.cgImage, let fullCG = fullImage.cgImage,
              let viewportCG = fullCG.cropping(to: CGRect(
                x: 0, y: 0, width: normalCG.width, height: normalCG.height
              )) else { throw FullContentHostError.emptyImage }
        let fullViewport = UIImage(cgImage: viewportCG, scale: viewport.scale, orientation: .up)
        let imageStrategy: Snapshotting<UIImage, UIImage> = .image
        try imageStrategy.diffing.toData(fullViewport)
            .write(to: outputDirectory.appending(path: "capture.full-content-viewport.png"), options: .atomic)
        // The library compares 8-bit sRGB pixels, but its difference attachment reads
        // four raw bytes per pixel. Give both inputs that same explicit pixel format.
        let comparableNormal = try CapturedRaster(image: normalCG).comparisonImage(scale: viewport.scale)
        let comparableViewport = try CapturedRaster(image: viewportCG).comparisonImage(scale: viewport.scale)
        try JSONSerialization.data(withJSONObject: [
            "stage": "entering-strict-image-comparison",
            "normalBitsPerPixel": normalCG.bitsPerPixel, "fullBitsPerPixel": viewportCG.bitsPerPixel,
            "comparisonBitsPerPixel": comparableNormal.cgImage?.bitsPerPixel ?? 0
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: outputDirectory.appending(path: "capture-progress.json"), options: .atomic)
        let difference = imageStrategy.diffing.diffV2(comparableNormal, comparableViewport)
        try JSONSerialization.data(withJSONObject: [
            "comparison": "SnapshotTesting strict sRGB image diff", "matched": difference == nil,
            "viewportPixels": [normalCG.width, normalCG.height]
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: outputDirectory.appending(path: "native-viewport-parity.json"), options: .atomic)
        if let difference {
            for (sliceIndex, slice) in rendering.slices.enumerated() {
                guard let data = slice.image.pngData() else { throw FullContentHostError.emptyImage }
                try data.write(
                    to: outputDirectory.appending(path: "capture.render-slice-\(sliceIndex).png"), options: .atomic
                )
            }
            throw FullContentHostError.nativeViewportPixelsChanged(difference.0)
        }
        let elements = try await RenderedContentInspection.text(
            in: fullCG, size: outputSize, bandHeight: viewport.size.height,
            overlap: RenderedContentInspection.bandOverlap, words: expectedItems.map(\.marker) + [trailingMarker]
        )
        let census = Dictionary(uniqueKeysWithValues: expectedItems.map { item in
            (item.title, elements.filter({ $0.label == item.marker }).count)
        })
        try writeDiagnostics(
            elements: elements, census: census,
            measurement: measurement, rendering: rendering, directory: outputDirectory
        )
        guard census.values.allSatisfy({ $0 == 1 }) else { throw FullContentHostError.itemCensus(census) }
        let outputBounds = CGRect(origin: .zero, size: outputSize)
        let raster = try CapturedRaster(image: fullCG)
        var itemFrames: [String: CGRect] = [:]
        for item in expectedItems {
            guard let element = elements.first(where: { $0.label == item.marker }),
                  outputBounds.contains(element.frame), element.frame.height > 0 else {
                throw FullContentHostError.clippedItem(item.title)
            }
            let frame: CGRect
            if let aspectRatio = item.artworkAspectRatio {
                frame = try raster.artworkFrame(around: element.frame, scale: viewport.scale)
                let isInset = frame.minX > 0 && frame.minY > 0
                    && frame.maxX < outputSize.width && frame.maxY < outputSize.height
                guard abs(frame.width - aspectRatio * frame.height) <= 2 / viewport.scale,
                      outputBounds.contains(frame), !item.requiresInsetArtwork || isInset else {
                    throw FullContentHostError.clippedItem(item.title)
                }
            } else {
                frame = element.frame
            }
            itemFrames[item.title] = frame
        }
        guard let marker = elements.first(where: { $0.label == trailingMarker }) else {
            throw FullContentHostError.missingTrailingMarker(trailingMarker)
        }
        let requiredHeight = viewport.size.height + contentHeight + originalInsets.top + originalInsets.bottom
            - originalScrollHeight
        guard outputBounds.contains(marker.frame), marker.frame.height > 0,
              requiredHeight <= outputSize.height + 1 / viewport.scale else {
            throw FullContentHostError.clippedItem(trailingMarker)
        }
        try await restoreNativeHost(frame: originalWindowFrame)
        verticalScrollHost.setContentOffset(originalOffset, animated: false)
        let restoredScrollGeometry = Self.descendants(of: controller.view)
            .compactMap({ $0 as? UIScrollView })
            .filter({ $0 !== verticalScrollHost })
            .map({ $0.convert($0.bounds, to: controller.view) })
        let tolerance = 1 / viewport.scale
        let scrollFramesMatch = scrollGeometry.count == restoredScrollGeometry.count
            && zip(scrollGeometry, restoredScrollGeometry).allSatisfy { pair in
                let previous = pair.0
                let current = pair.1
                return abs(current.minX - previous.minX) <= tolerance
                    && abs(current.minY - previous.minY) <= tolerance
                    && abs(current.width - previous.width) <= tolerance
                    && abs(current.height - previous.height) <= tolerance
            }
        guard isAttachedToActiveWindow, window.bounds.size == viewport.size,
              controller.view.bounds == originalRootBounds,
              scene.effectiveGeometry.coordinateSpace.bounds == originalSceneBounds,
              scene.effectiveGeometry.interfaceOrientation == originalOrientation,
              scrollFramesMatch else {
            throw FullContentHostError.logicalViewportChanged
        }
        guard let normalData = normalImage.pngData(), let fullData = fullImage.pngData(),
              !normalData.isEmpty, !fullData.isEmpty,
              let executable = Bundle.main.executableURL else { throw FullContentHostError.emptyImage }
        return FullContentCaptureEvidence(
            contentHeight: contentHeight,
            finalItemClipped: false,
            fullImageByteCount: fullData.count,
            fullImageURL: fullURL,
            hostBundlePath: Bundle.main.bundlePath,
            itemCensus: census,
            itemFrames: itemFrames,
            normalImageByteCount: normalData.count,
            normalImageURL: normalURL,
            outputSize: fullImage.size,
            pinnedViewportSize: pinnedViewportSize,
            renderSettleSamples: measurement.renderSettleSamples,
            renderSliceCount: rendering.slices.count,
            sceneBounds: scene.effectiveGeometry.coordinateSpace.bounds,
            stableIterations: stableIterations,
            statusBarHidden: measurement.statusBarHidden,
            testHostPath: executable.path,
            trailingMarkerFrame: marker.frame,
            viewport: viewport,
            windowBounds: window.bounds,
            windowIsAttached: isAttachedToActiveWindow
        )
    }

    /// One format for the viewport and the long image, so the parity check compares like with like.
    private func rendererFormat() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat(for: viewport.traits)
        format.scale = viewport.scale
        format.opaque = true
        // Quantize viewport and slice reads to the same 8-bit range before CPU composition. An extended-range
        // composite otherwise rounds glass pixels again and changes strict viewport comparisons by one byte.
        format.preferredRange = .standard
        return format
    }

    private func restoreNativeHost(frame: CGRect) async throws {
        viewportPin.size = nil
        window.frame = frame
        controller.view.frame = window.bounds
        window.layoutIfNeeded()
        // Back at viewport size the capture window covers the screen and drives the status bar again.
        removeStatusBarCompanion()
        var previousHeight: CGFloat?
        var stableIterations = 0
        for _ in 1...12 {
            try Task.checkCancellation()
            await LayoutFrame.wait()
            controller.view.layoutIfNeeded()
            guard let scrollHost = Self.descendants(of: controller.view)
                .compactMap({ $0 as? UIScrollView })
                .filter({ $0.contentSize.height > $0.bounds.height && $0.bounds.width > 0 })
                .max(by: { $0.contentSize.height < $1.contentSize.height }) else { continue }
            verticalScrollHost = scrollHost
            let height = scrollHost.contentSize.height
            let isStable = previousHeight.map({ abs(height - $0) * viewport.scale <= 1 }) == true
            stableIterations = isStable ? stableIterations + 1 : 0
            previousHeight = height
            if stableIterations >= 2 { return }
        }
        throw FullContentHostError.didNotConverge
    }

    private func removeStatusBarCompanion() {
        companionWindow?.isHidden = true
        companionWindow?.rootViewController = nil
        companionWindow = nil
    }

    /// Samples the viewport rendering until it holds byte-identical for longer than the measured settle delay.
    ///
    /// Layout convergence is not render convergence: the glass toolbar material steps once, about 0.45 s after its
    /// window appears (measured 2026-10-03: captures at t <= 0.38 s differ from the final one by +-1-2 inside the
    /// glass disc, captures at t >= 0.52 s are identical on both devices), and is byte-stable afterwards. A
    /// reference taken earlier fails the strict parity check against the later full image. The reference is
    /// therefore accepted only once consecutive samples, compared on the same 8-bit sRGB basis as the parity
    /// check, stay identical for a run spanning at least 500 ms, which is longer than that delay. This is the
    /// same stable-iterations idea the layout loop uses, applied to pixels; no fixed sleep stands in for it.
    private func settledViewportRendering(directory: URL) async throws -> SettledRendering {
        let clock = ContinuousClock()
        var runStart = clock.now
        var previousPixels: [UInt8]?
        for sample in 1...40 {
            try Task.checkCancellation()
            let rendering = try render(size: viewport.size, directory: directory)
            let now = clock.now
            guard let image = rendering.image.cgImage else { throw FullContentHostError.emptyImage }
            let pixels = try CapturedRaster(image: image).pixels
            if previousPixels == pixels {
                let duration = runStart.duration(to: now)
                if duration >= .milliseconds(500) {
                    return SettledRendering(rendering: rendering, samples: sample, settledDuration: duration)
                }
            } else {
                runStart = now
            }
            previousPixels = pixels
            await LayoutFrame.wait()
            try await clock.sleep(for: .milliseconds(100))
        }
        throw FullContentHostError.renderDidNotSettle
    }

    /// Reads the full-height hierarchy back in render-server slices. The window already has the full content
    /// height, so the hierarchy is never resized or re-hosted for the capture.
    private func render(size: CGSize, directory: URL) throws -> RenderServerCapture.Result {
        let rendering = try RenderServerCapture.image(
            of: controller.view, format: rendererFormat(), diagnosticsDirectory: directory
        )
        guard rendering.image.size == size, rendering.image.scale == viewport.scale else {
            throw FullContentHostError.renderFailed
        }
        return rendering
    }

    private func store(
        _ image: UIImage,
        at url: URL,
        name: String,
        directory: URL,
        record: SnapshotTestingConfiguration.Record
    ) throws {
        let strategy: Snapshotting<UIImage, UIImage> = .image
        guard let png = image.pngData(), !png.isEmpty else { throw FullContentHostError.emptyImage }
        if record == .all {
            try strategy.diffing.toData(image).write(to: url, options: .atomic)
        } else if let failure = verifySnapshot(
            of: image, as: strategy, named: name, record: .never,
            snapshotDirectory: directory.path, testName: "capture"
        ) {
            throw FullContentHostError.snapshotFailed(failure)
        }
    }

    private func writeDiagnostics(
        elements: [RenderedText],
        census: [String: Int],
        measurement: CaptureMeasurement,
        rendering: RenderServerCapture.Result,
        directory: URL
    ) throws {
        let diagnostics: [String: Any] = [
            "renderer": "render-server slices via resizableSnapshotView",
            "renderSliceMaximumHeight": rendering.maximumSliceHeight,
            "renderSliceOverlap": rendering.overlap,
            "renderSliceEdgePadding": rendering.edgePadding,
            "renderSlices": rendering.slices.map({
                ["frame": NSCoder.string(for: $0.frame), "readFrame": NSCoder.string(for: $0.readFrame)]
            }),
            "standardImageRange": standardImageRange,
            "censusBasis": "OCR of actual rendered fixture markers; artwork bounds from captured pixels",
            "censusBandHeight": viewport.size.height,
            "censusBandOverlap": RenderedContentInspection.bandOverlap,
            "contentHeight": measurement.contentHeight,
            "displayScale": viewport.scale,
            "census": census,
            "logicalViewport": [viewport.size.width, viewport.size.height],
            "rootBounds": NSCoder.string(for: controller.view.bounds),
            "scrollBounds": NSCoder.string(for: verticalScrollHost.bounds),
            "outputSize": [measurement.outputSize.width, measurement.outputSize.height],
            "stableIterations": measurement.stableIterations,
            "renderSettleSamples": measurement.renderSettleSamples,
            "renderSettleMilliseconds": measurement.renderSettleMilliseconds,
            "statusBarHidden": measurement.statusBarHidden,
            "elements": elements.map({ ["label": $0.label, "frame": NSCoder.string(for: $0.frame)] })
        ]
        try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: "geometry.json"), options: .atomic)
    }

    private static func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap({ [$0] + descendants(of: $0) })
    }
}

private enum RenderedContentInspection {
    /// The points consecutive OCR bands share. Ownership hands each band half of it (64 pt) on each side of a seam,
    /// so the band owning a marker's midpoint has seen its whole glyph line as long as that line is under 128 pt
    /// tall. A single-line marker at AX5 is roughly 64 pt, which leaves a 2x allowance; the AX5 matrix coordinates
    /// are what confirm it.
    static let bandOverlap: CGFloat = 128

    /// Recognizes text in `image` band by band and returns every frame in full-image point coordinates.
    ///
    /// Vision is reliable on viewport-shaped inputs but misreads markers in a single very tall image (it scales
    /// the input down), so the full capture is read as `bandHeight`-tall bands instead. This changes only how the
    /// same pixels are read; the census stays exactly as strict.
    ///
    /// Bands cover `0..<size.height` with stride `bandHeight - overlap`, each `min(bandHeight, remaining)` tall,
    /// and a single band when the image fits. Each band owns the half-open range from its start (plus
    /// `overlap / 2` unless it is the first band) to its end (minus `overlap / 2` unless it is the last band).
    /// Those ranges tile the image exactly once, and an observation is kept only by the band owning its `midY`,
    /// so text visible in two overlapping bands is counted once.
    @concurrent
    static func text(
        in image: CGImage, size: CGSize, bandHeight: CGFloat, overlap: CGFloat, words: [String]
    ) async throws -> [RenderedText] {
        precondition(overlap > 0 && overlap < bandHeight, "OCR band overlap must leave a positive stride")
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "en")]
        request.usesLanguageCorrection = false
        request.customWords = words
        let scale = CGFloat(image.width) / size.width
        var elements: [RenderedText] = []
        var bandStart: CGFloat = 0
        while true {
            let bandEnd = min(bandStart + bandHeight, size.height)
            let isFirst = bandStart == 0
            let isLast = bandEnd >= size.height
            let pixelTop = (bandStart * scale).rounded()
            let pixelBottom = (bandEnd * scale).rounded()
            guard let band = image.cropping(to: CGRect(
                x: 0, y: pixelTop, width: CGFloat(image.width), height: pixelBottom - pixelTop
            )) else {
                throw FullContentHostError.renderedTextInspectionFailed("Band \(bandStart)..<\(bandEnd) is empty")
            }
            let bandOrigin = pixelTop / scale
            let bandPointSize = CGSize(width: size.width, height: (pixelBottom - pixelTop) / scale)
            let owned = (isFirst ? bandStart : bandStart + overlap / 2)..<(isLast ? bandEnd : bandEnd - overlap / 2)
            let observations: [RecognizedTextObservation]
            do {
                observations = try await ImageRequestHandler(band).perform(request)
            } catch {
                throw FullContentHostError.renderedTextInspectionFailed(String(describing: error))
            }
            try Task.checkCancellation()
            elements += observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.8 else {
                    return nil
                }
                let frame = observation.boundingBox
                    .toImageCoordinates(bandPointSize, origin: .upperLeft)
                    .offsetBy(dx: 0, dy: bandOrigin)
                guard owned.contains(frame.midY) else { return nil }
                return RenderedText(label: candidate.string, frame: frame)
            }
            if isLast { return elements }
            bandStart += bandHeight - overlap
        }
    }
}

private struct RenderedText: Sendable {
    let label: String
    let frame: CGRect
}

/// The converged layout, the viewport reference's render settle, and the status bar state the capture held the
/// tall window to.
private struct CaptureMeasurement {
    let contentHeight: CGFloat
    let outputSize: CGSize
    let stableIterations: Int
    let renderSettleSamples: Int
    let renderSettleMilliseconds: Int
    let statusBarHidden: Bool
}

private struct SettledRendering {
    let rendering: RenderServerCapture.Result
    /// Renders taken, including the accepted one.
    let samples: Int
    /// The span of the identical run the accepted rendering closed.
    let settledDuration: Duration
}

/// Root of the status bar companion window: it exists only to state the status bar visibility measured while
/// the capture window was viewport-sized.
///
/// UIKit lets only a window covering the whole screen drive the status bar, so a capture window grown past the
/// screen cannot keep it hidden (measured 2026-10-03: the status bar reappears, 54 pt on the phone and 32 pt on
/// the iPad, and the iPad safe-area top goes 0 -> 32). A clear, full-screen, non-key window above the host app's
/// own main window, whose root prefers the measured visibility, restores the viewport's status bar state; with it
/// the tall window's top crop matched the viewport reference pixel for pixel on both devices. Placed below the
/// host app's main window, it lost to that window's visible status bar (measured 2026-10-03).
private final class StatusBarAppearanceController: UIViewController {
    let hidesStatusBar: Bool

    init(hidesStatusBar: Bool) {
        self.hidesStatusBar = hidesStatusBar
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var prefersStatusBarHidden: Bool { hidesStatusBar }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .clear
        self.view = view
    }
}

@MainActor
private final class LayoutFrame: NSObject {
    private var continuation: CheckedContinuation<Void, Never>?
    private var displayLink: CADisplayLink?

    static func wait() async {
        let frame = LayoutFrame()
        await withCheckedContinuation { continuation in
            frame.continuation = continuation
            let link = CADisplayLink(target: frame, selector: #selector(frame.didDisplay))
            frame.displayLink = link
            link.add(to: .main, forMode: .common)
        }
    }

    @objc private func didDisplay() {
        displayLink?.invalidate()
        displayLink = nil
        continuation?.resume()
        continuation = nil
    }
}

public enum FullContentHostError: Error {
    case captureExtentReset(expected: CGFloat, actual: CGFloat)
    case clippedItem(String)
    case contentDoesNotExceedViewport(CGFloat)
    case contentHeightExceeded(CGFloat)
    case didNotConverge
    case duplicateExpectedItems
    case emptyImage
    case inactiveWindow
    case invalidArtworkRegion
    case invalidRecordMode
    case invalidViewport(CGSize)
    case itemCensus([String: Int])
    case logicalViewportChanged
    case missingTrailingMarker(String)
    case missingVerticalScrollHost
    case noForegroundActiveScene
    case nativeViewportPixelsChanged(String)
    case renderDidNotSettle
    case renderFailed
    case renderedTextInspectionFailed(String)
    case snapshotFailed(String)
    case statusBarStateChanged(expectedHidden: Bool)
    case visibleViewportPinChangedPixels
}

@MainActor
@Observable
private final class VisibleViewportPin {
    var size: CGSize?
}

private struct ViewportPinnedContent<Content: View>: View {
    let content: Content
    let pin: VisibleViewportPin
    let key: WritableKeyPath<EnvironmentValues, CGSize?>

    var body: some View {
        content.environment(key, pin.size)
    }
}
