import Foundation
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
    public let sceneBounds: CGRect
    public let stableIterations: Int
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

/// Measures native device geometry independently from the library's full-content output size.
/// The long image uses SnapshotTesting's controller strategy and is checked against a native viewport.
/// No viewport images are stitched.
@MainActor
public final class FullContentHost<Content: View> {
    public private(set) var controller: UIHostingController<AnyView>
    public let scene: UIWindowScene
    public let window: UIWindow
    public let viewport: MeasuredViewport

    private let previousKeyWindow: UIWindow?
    private let drawHierarchyInKeyWindow: Bool
    private let rootView: Content
    private var verticalScrollHost: UIScrollView

    public init(
        rootView: Content, contentSizeCategory: UIContentSizeCategory? = nil,
        drawHierarchyInKeyWindow: Bool = true,
        isViewportReady: @MainActor () -> Bool = { true }
    ) async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw FullContentHostError.noForegroundActiveScene
        }
        self.scene = scene
        self.rootView = rootView
        self.drawHierarchyInKeyWindow = drawHierarchyInKeyWindow
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        if let contentSizeCategory {
            window.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        }
        controller = UIHostingController(rootView: AnyView(rootView))
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
            window.frame = originalWindowFrame
            if window.rootViewController != nil {
                controller.view.frame = window.bounds
                verticalScrollHost.setContentOffset(originalOffset, animated: false)
                controller.view.layoutIfNeeded()
            } else {
                window.isHidden = true
                previousKeyWindow?.makeKey()
            }
        }
        let normalImage = try renderNativeViewport()
        let normalURL = outputDirectory.appending(path: "capture.viewport.png")
        try store(normalImage, at: normalURL, name: "viewport", directory: outputDirectory, record: record)

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
        let fullImage = try await render(size: outputSize)
        let fullURL = outputDirectory.appending(path: "capture.full-content.png")
        try store(fullImage, at: fullURL, name: "full-content", directory: outputDirectory, record: record)
        try writeDiagnostics(
            elements: [], census: [:],
            layout: LayoutMeasurement(
                contentHeight: contentHeight, outputSize: outputSize, stableIterations: stableIterations
            ), directory: outputDirectory
        )
        guard let normalCG = normalImage.cgImage, let fullCG = fullImage.cgImage,
              let viewportCG = fullCG.cropping(to: CGRect(
                x: 0, y: 0, width: normalCG.width, height: normalCG.height
              )) else { throw FullContentHostError.emptyImage }
        let fullViewport = UIImage(cgImage: viewportCG, scale: viewport.scale, orientation: .up)
        let imageStrategy: Snapshotting<UIImage, UIImage> = .image
        try imageStrategy.diffing.toData(fullViewport)
            .write(to: outputDirectory.appending(path: "capture.full-content-viewport.png"), options: .atomic)
        if let difference = imageStrategy.diffing.diffV2(normalImage, fullViewport) {
            throw FullContentHostError.nativeViewportPixelsChanged(difference.0)
        }
        try JSONSerialization.data(withJSONObject: [
            "comparison": "SnapshotTesting strict sRGB image diff", "matched": true,
            "viewportPixels": [normalCG.width, normalCG.height]
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: outputDirectory.appending(path: "native-viewport-parity.json"), options: .atomic)
        let elements = try await RenderedContentInspection.text(
            in: fullCG, size: outputSize, words: expectedItems.map(\.marker) + [trailingMarker]
        )
        let census = Dictionary(uniqueKeysWithValues: expectedItems.map { item in
            (item.title, elements.filter({ $0.label == item.marker }).count)
        })
        try writeDiagnostics(
            elements: elements, census: census,
            layout: LayoutMeasurement(
                contentHeight: contentHeight, outputSize: outputSize, stableIterations: stableIterations
            ), directory: outputDirectory
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
            sceneBounds: scene.effectiveGeometry.coordinateSpace.bounds,
            stableIterations: stableIterations,
            testHostPath: executable.path,
            trailingMarkerFrame: marker.frame,
            viewport: viewport,
            windowBounds: window.bounds,
            windowIsAttached: isAttachedToActiveWindow
        )
    }

    private func renderNativeViewport() throws -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = viewport.scale
        format.opaque = true
        var rendered = false
        let image = UIGraphicsImageRenderer(size: viewport.size, format: format).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: viewport.size))
            rendered = controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        guard rendered, image.cgImage != nil else { throw FullContentHostError.renderFailed }
        return image
    }

    private func restoreNativeHost(frame: CGRect) async throws {
        window.frame = frame
        if drawHierarchyInKeyWindow {
            controller = UIHostingController(rootView: AnyView(rootView))
            window.rootViewController = controller
        }
        controller.view.frame = window.bounds
        window.layoutIfNeeded()
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

    private func render(size: CGSize) async throws -> UIImage {
        // The default layer strategy creates its own Window. Give it a fresh controller,
        // matching the library's SwiftUI strategy, instead of moving an attached root to it.
        let captureController = drawHierarchyInKeyWindow
            ? controller : UIHostingController(rootView: AnyView(rootView))
        let originalAutoresizingMask = captureController.view.autoresizingMask
        captureController.view.autoresizingMask = []
        defer { captureController.view.autoresizingMask = originalAutoresizingMask }
        let strategy: Snapshotting<UIViewController, UIImage> = .image(
            on: ViewImageConfig(safeArea: viewport.safeAreaInsets, size: size, traits: viewport.traits),
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow, size: size, traits: viewport.traits
        )
        let image: UIImage = await withCheckedContinuation { continuation in
            strategy.snapshot(captureController).run { continuation.resume(returning: $0) }
        }
        // SnapshotTesting consumes controller attachment. Reusing that controller after its
        // explicit appearance cleanup is unsafe; successful capture restores a fresh native host.
        guard image.size == size, image.scale == viewport.scale else { throw FullContentHostError.renderFailed }
        return image
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
        layout: LayoutMeasurement,
        directory: URL
    ) throws {
        let diagnostics: [String: Any] = [
            "renderer": "Snapshotting<UIViewController, UIImage>.image(on:size:)",
            "drawHierarchyInKeyWindow": drawHierarchyInKeyWindow,
            "censusBasis": "OCR of actual rendered fixture markers; artwork bounds from captured pixels",
            "contentHeight": layout.contentHeight,
            "displayScale": viewport.scale,
            "census": census,
            "logicalViewport": [viewport.size.width, viewport.size.height],
            "rootBounds": NSCoder.string(for: controller.view.bounds),
            "scrollBounds": NSCoder.string(for: verticalScrollHost.bounds),
            "outputSize": [layout.outputSize.width, layout.outputSize.height],
            "stableIterations": layout.stableIterations,
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
    @concurrent
    static func text(in image: CGImage, size: CGSize, words: [String]) async throws -> [RenderedText] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "en")]
        request.usesLanguageCorrection = false
        request.customWords = words
        let handler = ImageRequestHandler(image)
        let observations: [RecognizedTextObservation]
        do {
            observations = try await handler.perform(request)
        } catch {
            throw FullContentHostError.renderedTextInspectionFailed(String(describing: error))
        }
        try Task.checkCancellation()
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.8 else { return nil }
            let frame = observation.boundingBox.toImageCoordinates(size, origin: .upperLeft)
            return RenderedText(label: candidate.string, frame: frame)
        }
    }
}

private struct RenderedText: Sendable {
    let label: String
    let frame: CGRect
}

private struct LayoutMeasurement {
    let contentHeight: CGFloat
    let outputSize: CGSize
    let stableIterations: Int
}

private struct CapturedRaster {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(image: CGImage) throws {
        let pixelWidth = image.width
        let pixelHeight = image.height
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw FullContentHostError.emptyImage
        }
        var bytes = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        let success = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: pixelWidth, height: pixelHeight,
                bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            return true
        }
        guard success else { throw FullContentHostError.emptyImage }
        width = pixelWidth
        height = pixelHeight
        pixels = bytes
    }

    func artworkFrame(around marker: CGRect, scale: CGFloat) throws -> CGRect {
        let seedColumn = Int(((marker.minX - 2) * scale).rounded(.down))
        let seedRow = Int((marker.midY * scale).rounded(.down))
        guard seedColumn >= 0, seedColumn < width, seedRow >= 0, seedRow < height else {
            throw FullContentHostError.invalidArtworkRegion
        }
        let seed = seedRow * width + seedColumn
        let seedColor = try color(at: seed)
        guard Int(max(seedColor.red, seedColor.green, seedColor.blue))
            - Int(min(seedColor.red, seedColor.green, seedColor.blue)) > 40 else {
            throw FullContentHostError.invalidArtworkRegion
        }
        var visited: Set<Int> = [seed]
        var queue = [seed]
        var cursor = 0
        var minX = seedColumn
        var maxX = seedColumn
        var minY = seedRow
        var maxY = seedRow
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let column = current % width
            let row = current / width
            minX = min(minX, column)
            maxX = max(maxX, column)
            minY = min(minY, row)
            maxY = max(maxY, row)
            var neighbors: [Int] = []
            if column > 0 { neighbors.append(current - 1) }
            if column + 1 < width { neighbors.append(current + 1) }
            if row > 0 { neighbors.append(current - width) }
            if row + 1 < height { neighbors.append(current + width) }
            for neighbor in neighbors where visited.insert(neighbor).inserted {
                let candidate = try color(at: neighbor)
                if abs(Int(candidate.red) - Int(seedColor.red)) <= 8,
                   abs(Int(candidate.green) - Int(seedColor.green)) <= 8,
                   abs(Int(candidate.blue) - Int(seedColor.blue)) <= 8 {
                    queue.append(neighbor)
                }
            }
        }
        return CGRect(
            x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale
        )
    }

    private func color(at pixel: Int) throws -> RasterColor {
        let redIndex = pixel * 4
        let greenIndex = redIndex + 1
        let blueIndex = greenIndex + 1
        guard pixels.indices.contains(redIndex), pixels.indices.contains(greenIndex),
              pixels.indices.contains(blueIndex) else { throw FullContentHostError.invalidArtworkRegion }
        return RasterColor(red: pixels[redIndex], green: pixels[greenIndex], blue: pixels[blueIndex])
    }
}

private struct RasterColor {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
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
    case renderFailed
    case renderedTextInspectionFailed(String)
    case snapshotFailed(String)
}
