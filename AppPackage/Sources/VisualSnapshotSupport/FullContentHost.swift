import Foundation
import SnapshotTesting
import SwiftUI
import UIKit

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
/// single snapshot), composed into one image. Once the grown window's rendering settles, two complete passes verify
/// that every read's composed rows agree. Every slice reads the stationary hierarchy without scrolling. The top of
/// the long image is
/// then checked against a native viewport capture. SnapshotTesting is still used to record, verify and diff images.
@MainActor
public final class FullContentHost<Content: View> {
    public let controller: UIHostingController<AnyView>
    public let scene: UIWindowScene
    public let window: UIWindow
    public let viewport: MeasuredViewport

    private let previousKeyWindow: UIWindow?
    private let standardImageRange: Bool
    private let setSamplingFrozen: (Bool) -> Void
    private let nativeWindowFrame: CGRect
    private let sceneViewportTraits: UITraitCollection
    private var verticalScrollHost: UIScrollView
    /// The full-screen window that owns the status bar while ``window`` is taller than the screen. See
    /// ``StatusBarAppearanceController``.
    private var companionWindow: UIWindow?

    /// Requires the requested Dynamic Type category to come from the app's system setting.
    /// A window-only AX5 override over system Large lets the native toolbar re-resolve its glyph from 70×85 to
    /// 58×70 pixels during layout, or before the reference even settles. Matching the app-level category keeps
    /// the production 70×85 glyph stable; overriding a second source would make parity an unreliable guarantee.
    public init<Sampling: AnyObject>(
        rootView: Content, sampling: Sampling,
        samplingKey: WritableKeyPath<EnvironmentValues, Sampling?>,
        frozen: ReferenceWritableKeyPath<Sampling, Bool>,
        contentSizeCategory: UIContentSizeCategory? = nil,
        standardImageRange: Bool = false,
        isViewportReady: @MainActor () -> Bool = { true }
    ) async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw FullContentHostError.noForegroundActiveScene
        }
        if let contentSizeCategory, UIApplication.shared.preferredContentSizeCategory != contentSizeCategory {
            throw FullContentHostError.contentSizeCategoryMismatch(
                expected: contentSizeCategory, actual: UIApplication.shared.preferredContentSizeCategory
            )
        }
        self.scene = scene
        self.standardImageRange = standardImageRange
        setSamplingFrozen = { sampling[keyPath: frozen] = $0 }
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        // A tall phone-landscape window derives regular vertical size class, moving an inlineLarge title from
        // centered inline to large leading even though the visible viewport is unchanged. Hold both native
        // scene size classes from creation: a later trait update can itself reconfigure toolbar glyphs.
        sceneViewportTraits = scene.traitCollection
        window.traitOverrides.horizontalSizeClass = sceneViewportTraits.horizontalSizeClass
        window.traitOverrides.verticalSizeClass = sceneViewportTraits.verticalSizeClass
        if standardImageRange {
            window.traitOverrides.displayGamut = .SRGB
            window.traitOverrides.imageDynamicRange = .standard
        }
        controller = UIHostingController(rootView: AnyView(
            ViewportSamplingContent(content: rootView, sampling: sampling, key: samplingKey)
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
        nativeWindowFrame = window.frame
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
                resolvedScrollHost = HostedHierarchy.verticalScrollHost(in: controller.view)
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
        restoreViewportGeometry(frame: nativeWindowFrame)
        setSamplingFrozen(false)
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }

    public func capture(
        expectedItems: [CaptureItemExpectation],
        trailingMarker: String,
        outputDirectory: URL,
        record: SnapshotTestingConfiguration.Record = .never,
        trailingMarkerLanguage: Locale.Language = Locale.Language(identifier: "en"),
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
        let scrollGeometry = HostedHierarchy.descendants(of: controller.view)
            .compactMap({ $0 as? UIScrollView })
            .filter({ $0 !== verticalScrollHost })
            .map({ $0.convert($0.bounds, to: controller.view) })
        defer {
            restoreViewportGeometry(frame: originalWindowFrame)
            setSamplingFrozen(false)
            verticalScrollHost.setContentOffset(originalOffset, animated: false)
            controller.view.layoutIfNeeded()
        }
        let settled = try await settledViewportRendering(
            directory: outputDirectory.appending(path: "native-viewport-settle", directoryHint: .isDirectory)
        )
        let normalImage = settled.value.image
        let normalURL = outputDirectory.appending(path: "capture.viewport.png")
        try store(normalImage, at: normalURL, name: "viewport", directory: outputDirectory, record: record)

        setSamplingFrozen(true)
        await LayoutFrame.wait()
        controller.view.layoutIfNeeded()
        let frozen = try await settledViewportRendering(
            directory: outputDirectory.appending(path: "frozen-viewport-settle", directoryHint: .isDirectory)
        )
        let frozenURL = outputDirectory.appending(path: "capture.frozen-viewport.png")
        try store(
            frozen.value.image, at: frozenURL, name: "frozen-viewport", directory: outputDirectory, record: record
        )
        guard let referenceCG = normalImage.cgImage, let frozenCG = frozen.value.image.cgImage else {
            throw FullContentHostError.emptyImage
        }
        let referencePixels = try CapturedRaster(image: referenceCG).pixels
        let frozenPixels = try CapturedRaster(image: frozenCG).pixels
        let freezeMatches = referenceCG.width == frozenCG.width && referenceCG.height == frozenCG.height
            && referencePixels == frozenPixels
        try JSONSerialization.data(withJSONObject: [
            "comparison": "byte-identical 8-bit sRGB RGBA before growth", "matched": freezeMatches,
            "windowViewport": [viewport.size.width, viewport.size.height],
            "nativeSettleSamples": settled.samples, "frozenSettleSamples": frozen.samples
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: outputDirectory.appending(path: "visible-viewport-freeze-parity.json"), options: .atomic)
        guard freezeMatches else { throw FullContentHostError.visibleViewportFreezeChangedPixels }

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
        var requestedOutputHeights: [CGFloat] = []
        for _ in 1...12 {
            try Task.checkCancellation()
            guard isAttachedToActiveWindow else { throw FullContentHostError.inactiveWindow }
            outputSize.height = ceil(
                (viewport.size.height + contentHeight + originalInsets.top + originalInsets.bottom
                 - originalScrollHeight) * viewport.scale
            ) / viewport.scale
            requestedOutputHeights.append(outputSize.height)
            try writeDiagnostics(
                occurrences: [], census: [:],
                measurement: CaptureMeasurement(
                    contentHeight: contentHeight, outputSize: outputSize, stableIterations: stableIterations,
                    requestedOutputHeights: requestedOutputHeights, renderSettleSamples: settled.samples,
                    renderSettleMilliseconds: Self.milliseconds(settled.settledDuration),
                    statusBarHidden: statusBarHidden
                ),
                rendering: nil, directory: outputDirectory
            )
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
        let measurement = CaptureMeasurement(
            contentHeight: contentHeight, outputSize: outputSize, stableIterations: stableIterations,
            requestedOutputHeights: requestedOutputHeights, renderSettleSamples: settled.samples,
            renderSettleMilliseconds: Self.milliseconds(settled.settledDuration),
            statusBarHidden: statusBarHidden
        )
        try writeDiagnostics(
            occurrences: [], census: [:], measurement: measurement, rendering: nil, directory: outputDirectory
        )
        guard stableIterations >= 2 else { throw FullContentHostError.didNotConverge }
        try await settleFullContent(directory: outputDirectory)
        let rendering = try render(size: outputSize, directory: outputDirectory)
        let fullImage = rendering.image
        let fullURL = outputDirectory.appending(path: "capture.full-content.png")
        try store(fullImage, at: fullURL, name: "full-content", directory: outputDirectory, record: record)
        try writeDiagnostics(
            occurrences: [], census: [:],
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
                let frame = slice.frame.applying(CGAffineTransform(scaleX: viewport.scale, y: viewport.scale))
                guard let sliceCG = fullCG.cropping(to: frame),
                      let data = UIImage(cgImage: sliceCG, scale: viewport.scale, orientation: .up).pngData() else {
                    throw FullContentHostError.emptyImage
                }
                try data.write(
                    to: outputDirectory.appending(path: "capture.render-slice-\(sliceIndex).png"), options: .atomic
                )
            }
            throw FullContentHostError.nativeViewportPixelsChanged(difference.0)
        }
        let censusWords = expectedItems.map(\.marker)
        let censusWindows = RenderedContentInspection.windows(
            imageSize: outputSize, viewportHeight: viewport.size.height
        )
        let reads = try await RenderedContentInspection.reads(
            in: fullCG, imageSize: outputSize, windows: censusWindows, markerWords: censusWords,
            trailingMarker: trailingMarker, trailingMarkerLanguage: trailingMarkerLanguage
        )
        // Written before merging, so even an ambiguous location leaves every raw read on disk.
        try Self.writeCensusReads(
            reads, windows: censusWindows, trailingMarkerLanguage: trailingMarkerLanguage, directory: outputDirectory
        )
        let occurrences = try RenderedContentInspection.occurrences(
            of: reads, imageSize: outputSize, words: Set(censusWords)
        )
        let trailingOccurrences = try RenderedContentInspection.occurrences(
            of: reads, imageSize: outputSize, words: [trailingMarker], pass: .trailingMarker
        )
        let census = Dictionary(uniqueKeysWithValues: expectedItems.map { item in
            (item.title, occurrences.filter({ $0.label == item.marker }).count)
        })
        try writeDiagnostics(
            occurrences: occurrences + trailingOccurrences, census: census,
            measurement: measurement, rendering: rendering, directory: outputDirectory
        )
        guard census.values.allSatisfy({ $0 == 1 }) else { throw FullContentHostError.itemCensus(census) }
        let outputBounds = CGRect(origin: .zero, size: outputSize)
        let raster = rendering.raster
        var itemFrames: [String: CGRect] = [:]
        for item in expectedItems {
            guard let occurrence = occurrences.first(where: { $0.label == item.marker }),
                  outputBounds.contains(occurrence.frame), occurrence.frame.height > 0 else {
                throw FullContentHostError.clippedItem(item.title)
            }
            let frame: CGRect
            if let aspectRatio = item.artworkAspectRatio {
                frame = try raster.artworkFrame(around: occurrence.frame, scale: viewport.scale)
                let isInset = frame.minX > 0 && frame.minY > 0
                    && frame.maxX < outputSize.width && frame.maxY < outputSize.height
                guard abs(frame.width - aspectRatio * frame.height) <= 2 / viewport.scale,
                      outputBounds.contains(frame), !item.requiresInsetArtwork || isInset else {
                    throw FullContentHostError.clippedItem(item.title)
                }
            } else {
                frame = occurrence.frame
            }
            itemFrames[item.title] = frame
        }
        let requiredHeight = viewport.size.height + contentHeight + originalInsets.top + originalInsets.bottom
            - originalScrollHeight
        let trailingMarkerFrame = try RenderedContentInspection.trailingMarkerFrame(
            trailingMarker, occurrences: trailingOccurrences, imageSize: outputSize,
            requiredHeight: requiredHeight, scale: viewport.scale
        )
        try await restoreNativeHost(frame: originalWindowFrame)
        verticalScrollHost.setContentOffset(originalOffset, animated: false)
        let restoredScrollGeometry = HostedHierarchy.descendants(of: controller.view)
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
            renderSettleSamples: measurement.renderSettleSamples,
            renderSliceCount: rendering.slices.count,
            sceneBounds: scene.effectiveGeometry.coordinateSpace.bounds,
            stableIterations: stableIterations,
            statusBarHidden: measurement.statusBarHidden,
            testHostPath: executable.path,
            trailingMarkerFrame: trailingMarkerFrame,
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
        restoreViewportGeometry(frame: frame)
        await LayoutFrame.wait()
        controller.view.layoutIfNeeded()
        setSamplingFrozen(false)
        var previousHeight: CGFloat?
        var stableIterations = 0
        for _ in 1...12 {
            try Task.checkCancellation()
            await LayoutFrame.wait()
            controller.view.layoutIfNeeded()
            guard let scrollHost = HostedHierarchy.verticalScrollHost(in: controller.view) else { continue }
            verticalScrollHost = scrollHost
            let height = scrollHost.contentSize.height
            let isStable = previousHeight.map({ abs(height - $0) * viewport.scale <= 1 }) == true
            stableIterations = isStable ? stableIterations + 1 : 0
            previousHeight = height
            if stableIterations >= 2 { return }
        }
        throw FullContentHostError.didNotConverge
    }

    private func restoreViewportGeometry(frame: CGRect) {
        window.frame = frame
        controller.view.frame = window.bounds
        window.layoutIfNeeded()
        // At viewport size the capture window covers the screen and drives the status bar again.
        removeStatusBarCompanion()
        controller.view.layoutIfNeeded()
    }

    private func removeStatusBarCompanion() {
        companionWindow?.isHidden = true
        companionWindow?.rootViewController = nil
        companionWindow = nil
    }

    /// Samples the viewport rendering until it holds byte-identical under ``RenderSettlement``.
    ///
    /// Each sample is itself a two-pass verified read of the native rect, kept in its own directory. A change
    /// inside a sample rejects it and restarts the stable run, exactly as a change between samples does. The final
    /// full-content capture has no such recovery and fails on any owned-row change.
    private func settledViewportRendering(
        directory: URL
    ) async throws -> RenderSettlement.Settled<RenderServerCapture.Result> {
        try await RenderSettlement.settle(
            clock: ContinuousClock(), failure: .renderDidNotSettle, key: \RenderServerCapture.Result.raster.pixels,
            nextFrame: LayoutFrame.wait
        ) { sample in
            do {
                return try render(
                    size: viewport.size,
                    directory: directory.appending(path: "sample-\(sample)", directoryHint: .isDirectory)
                )
            } catch RenderServerCaptureError.readChanged(_) {
                return nil
            }
        }
    }

    /// Settles the grown window under ``RenderSettlement`` before its verified capture.
    ///
    /// Glass first drawn after the window grows changes once within about 0.1 to 0.45 s, so a capture read right
    /// after layout converges could verify a transient state. Each sample is one pass of owned-row digests over the
    /// same read plan the capture uses. Every pass, and the reads that changed since the previous one, is recorded
    /// in `full-content-settle.json`; a run that never settles leaves that ledger at `settling`.
    private func settleFullContent(directory: URL) async throws {
        let clock = ContinuousClock()
        let start = clock.now
        let ledgerURL = directory.appending(path: "full-content-settle.json")
        var passes: [[String: Any]] = []
        var previous: [String]?
        func writeLedger(status: String, settled: RenderSettlement.Settled<[String]>? = nil) throws {
            try JSONSerialization.data(withJSONObject: [
                "status": status,
                "rule": "consecutive identical owned-row passes over a run spanning at least the stable span",
                "stableSpanMilliseconds": Self.milliseconds(RenderSettlement.stableSpan),
                "maximumPasses": RenderSettlement.maximumSamples, "passes": passes,
                "acceptedPass": settled?.samples as Any? ?? NSNull(),
                "settledMilliseconds": settled.map({ Self.milliseconds($0.settledDuration) }) as Any? ?? NSNull()
            ], options: [.prettyPrinted, .sortedKeys])
                .write(to: ledgerURL, options: .atomic)
        }
        let settled = try await RenderSettlement.settle(
            clock: clock, failure: .fullContentRenderDidNotSettle, key: { $0 }, nextFrame: LayoutFrame.wait
        ) { pass -> [String]? in
            let digests = try RenderServerCapture.ownedRowDigests(
                of: controller.view, viewportSize: viewport.size, format: rendererFormat()
            )
            let changed = previous.map { previous in
                digests.indices.filter({ !previous.indices.contains($0) || previous[$0] != digests[$0] })
            }
            passes.append([
                "pass": pass, "elapsedMilliseconds": Self.milliseconds(start.duration(to: clock.now)),
                "ownedSHA256": digests, "changedSliceIndices": changed as Any? ?? NSNull()
            ])
            previous = digests
            try writeLedger(status: "settling")
            return digests
        }
        try writeLedger(status: "settled", settled: settled)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }

    /// Reads the full-height hierarchy back in render-server slices. The window already has the full content
    /// height, so the hierarchy is never resized or re-hosted for the capture.
    private func render(size: CGSize, directory: URL) throws -> RenderServerCapture.Result {
        let rendering = try RenderServerCapture.image(
            of: controller.view, viewportSize: viewport.size, format: rendererFormat(), diagnosticsDirectory: directory
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
        occurrences: [RenderedContentInspection.Occurrence],
        census: [String: Int],
        measurement: CaptureMeasurement,
        rendering: RenderServerCapture.Result?,
        directory: URL
    ) throws {
        let censusWindowSizes = RenderedContentInspection.WindowScale.allCases.map { scale in
            let size = scale.windowSize(imageSize: measurement.outputSize, viewportHeight: viewport.size.height)
            return (scale.rawValue, [size.width, size.height])
        }
        var diagnostics: [String: Any] = [
            "renderer": "render-server slices via resizableSnapshotView",
            "standardImageRange": standardImageRange,
            "censusBasis": "OCR of actual rendered fixture markers; artwork bounds from captured pixels",
            "censusWindowSizes": Dictionary(uniqueKeysWithValues: censusWindowSizes),
            "censusWindowStride": "half the window size per axis; the last window ends at the far image edge",
            "censusEdgeMargin": RenderedContentInspection.edgeMargin,
            "censusMaximumRequestsInFlight": RenderedContentInspection.maximumRequestsInFlight,
            "censusOccurrences": occurrences.map({
                ["label": $0.label, "frame": NSCoder.string(for: $0.frame), "reads": $0.readIndices]
            }),
            "contentHeight": measurement.contentHeight,
            "displayScale": viewport.scale,
            "census": census,
            "logicalViewport": [viewport.size.width, viewport.size.height],
            "sizeClasses": [
                "sceneAtViewport": Self.sizeClasses(in: sceneViewportTraits),
                "windowAtViewport": Self.sizeClasses(in: viewport.traits),
                "sceneCurrent": Self.sizeClasses(in: scene.traitCollection),
                "windowCurrent": Self.sizeClasses(in: window.traitCollection)
            ],
            "rootBounds": NSCoder.string(for: controller.view.bounds),
            "scrollBounds": NSCoder.string(for: verticalScrollHost.bounds),
            "outputSize": [measurement.outputSize.width, measurement.outputSize.height],
            "stableIterations": measurement.stableIterations,
            "requestedOutputHeights": measurement.requestedOutputHeights,
            "requestedOutputPixelHeights": measurement.requestedOutputHeights.map({
                Int(($0 * viewport.scale).rounded())
            }),
            "maximumCompositePixelCount": RenderServerCapture.maximumCompositePixelCount,
            "renderSettleSamples": measurement.renderSettleSamples,
            "renderSettleMilliseconds": measurement.renderSettleMilliseconds,
            "statusBarHidden": measurement.statusBarHidden
        ]
        if let rendering {
            diagnostics["renderSliceMaximumHeight"] = rendering.maximumSliceHeight
            diagnostics["renderSliceContextBandHeight"] = rendering.contextBandHeight
            diagnostics["renderReadVerificationPasses"] = 2
            diagnostics["renderReadVerifications"] = rendering.readVerifications.map(\.diagnostics)
            diagnostics["renderSliceEdgePadding"] = rendering.edgePadding
            diagnostics["renderReadOriginGridPixels"] = RenderServerCapture.readOriginGridPixels
            diagnostics["renderSlices"] = rendering.slices.map({
                ["frame": NSCoder.string(for: $0.frame), "readFrame": NSCoder.string(for: $0.readFrame),
                 "contextFrame": $0.contextFrame.map(NSCoder.string(for:)) as Any? ?? NSNull()]
            })
        }
        try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: "geometry.json"), options: .atomic)
    }

    /// Persists every raw top candidate with its evidence pass and window, in pass/window order. The `reads` indices of
    /// `censusOccurrences` in `geometry.json` point into this list, so a census failure can be traced to the raw
    /// recognition rather than inferred from the counts.
    private static func writeCensusReads(
        _ reads: [RenderedContentInspection.Read], windows: [RenderedContentInspection.Window],
        trailingMarkerLanguage: Locale.Language, directory: URL
    ) throws {
        let windowEntries = windows.map({ ["rect": NSCoder.string(for: $0.rect), "scale": $0.scale.rawValue] })
        let readEntries: [[String: Any]] = reads.map { read in
            [
                "label": read.label, "confidence": read.confidence, "frame": NSCoder.string(for: read.frame),
                "window": NSCoder.string(for: read.window.rect), "scale": read.window.scale.rawValue,
                "pass": read.pass.rawValue
            ]
        }
        try JSONSerialization.data(
            withJSONObject: [
                "windows": windowEntries, "reads": readEntries,
                "fixtureMarkerLanguage": "en", "fixtureMarkerMinimumConfidence": 0.8,
                "trailingMarkerLanguage": trailingMarkerLanguage.minimalIdentifier,
                "trailingMarkerAcceptance": "exact identity, interior acceptance, location merge and capture bounds"
            ], options: [.prettyPrinted, .sortedKeys]
        )
            .write(to: directory.appending(path: "census-reads.json"), options: .atomic)
    }

    private static func sizeClasses(in traits: UITraitCollection) -> [String: Int] {
        ["horizontal": traits.horizontalSizeClass.rawValue, "vertical": traits.verticalSizeClass.rawValue]
    }
}

/// Queries over a hosted view hierarchy that do not depend on the hosted content's type.
@MainActor
enum HostedHierarchy {
    static func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap({ [$0] + descendants(of: $0) })
    }

    /// The page's vertical scroll host: the scroll view with the tallest content among those that can scroll.
    ///
    /// Scrollability counts the adjusted content insets, exactly as the full-content output height does, because
    /// content shorter than its scroll view still scrolls under bars and safe areas. Home on iPad portrait lays out
    /// 1192, 1200.5, 1210 and 1217.5 pt of content at xSmall, small, medium and Large in its 1210 pt scroll view,
    /// and its adjusted insets add 111 pt, so it scrolls at every size (measured 2026-10-06). Comparing the content
    /// height alone rejected the three smaller sizes as having no host. A nested horizontal scroll view's content
    /// stays within its own bounds, so it never qualifies.
    static func verticalScrollHost(in view: UIView) -> UIScrollView? {
        descendants(of: view)
            .compactMap({ $0 as? UIScrollView })
            .filter({ scrollView in
                let insets = scrollView.adjustedContentInset
                return scrollView.bounds.width > 0
                    && scrollView.contentSize.height + insets.top + insets.bottom > scrollView.bounds.height
            })
            .max(by: { $0.contentSize.height < $1.contentSize.height })
    }
}

/// The converged layout, the viewport reference's render settle, and the status bar state the capture held the
/// tall window to.
private struct CaptureMeasurement {
    let contentHeight: CGFloat
    let outputSize: CGSize
    let stableIterations: Int
    let requestedOutputHeights: [CGFloat]
    let renderSettleSamples: Int
    let renderSettleMilliseconds: Int
    let statusBarHidden: Bool
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
    /// Two different census words were read at one location; the description names both and their frames.
    case ambiguousRenderedText(String)
    case captureExtentReset(expected: CGFloat, actual: CGFloat)
    case clippedItem(String)
    case contentDoesNotExceedViewport(CGFloat)
    case contentSizeCategoryMismatch(expected: UIContentSizeCategory, actual: UIContentSizeCategory)
    case didNotConverge
    case duplicateExpectedItems
    case emptyImage
    /// The grown window's owned-row passes never stayed identical for the stable span within the pass bound.
    case fullContentRenderDidNotSettle
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
    case visibleViewportFreezeChangedPixels
}

private struct ViewportSamplingContent<Content: View, Sampling: AnyObject>: View {
    let content: Content
    let sampling: Sampling
    let key: WritableKeyPath<EnvironmentValues, Sampling?>

    var body: some View {
        content.environment(key, sampling)
    }
}
