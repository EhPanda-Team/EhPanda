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

/// Keeps the scene, window and SwiftUI root at the measured device viewport. Only the selected
/// native scroll host grows for the output image; no scrolled viewport images are composited.
@MainActor
public final class FullContentHost<Content: View> {
    public let controller: UIHostingController<AnyView>
    public let scene: UIWindowScene
    public let window: UIWindow
    public let viewport: MeasuredViewport

    private let previousKeyWindow: UIWindow?
    private let verticalScrollHost: UIScrollView

    public init(rootView: Content) async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw FullContentHostError.noForegroundActiveScene
        }
        self.scene = scene
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
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
                if resolvedScrollHost != nil { break }
            }
        } catch {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            throw error
        }
        guard let scrollHost = resolvedScrollHost else {
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
        expectedItemTitles: [String],
        trailingMarker: String,
        outputDirectory: URL,
        record: SnapshotTestingConfiguration.Record = .never
    ) async throws -> FullContentCaptureEvidence {
        guard isAttachedToActiveWindow else { throw FullContentHostError.inactiveWindow }
        guard record == .never || record == .all else { throw FullContentHostError.invalidRecordMode }
        guard Set(expectedItemTitles).count == expectedItemTitles.count else {
            throw FullContentHostError.duplicateExpectedItems
        }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let normalImage = try render(size: viewport.size)
        let normalURL = outputDirectory.appending(path: "capture.viewport.png")
        try store(normalImage, at: normalURL, name: "viewport", directory: outputDirectory, record: record)

        let originalScrollFrame = verticalScrollHost.frame
        let originalScrollBounds = verticalScrollHost.bounds
        let originalOffset = verticalScrollHost.contentOffset
        let originalRootBounds = controller.view.bounds
        let originalSceneBounds = scene.effectiveGeometry.coordinateSpace.bounds
        let originalOrientation = scene.effectiveGeometry.interfaceOrientation
        let scrollGeometry = Self.descendants(of: controller.view)
            .compactMap({ $0 as? UIScrollView })
            .filter({ $0 !== verticalScrollHost })
            .map({ ScrollGeometry(view: $0, frame: $0.convert($0.bounds, to: controller.view)) })
        var clippingStates: [ClippingState] = []
        var ancestor: UIView? = verticalScrollHost
        while let view = ancestor {
            clippingStates.append(ClippingState(view: view, clipsToBounds: view.clipsToBounds))
            view.clipsToBounds = false
            ancestor = view.superview
        }
        defer {
            verticalScrollHost.frame = originalScrollFrame
            verticalScrollHost.bounds = originalScrollBounds
            verticalScrollHost.setContentOffset(originalOffset, animated: false)
            for state in clippingStates { state.view.clipsToBounds = state.clipsToBounds }
            controller.view.layoutIfNeeded()
        }

        var previousHeight: CGFloat?
        var stableIterations = 0
        var contentHeight: CGFloat = 0
        var captureHeight = originalScrollBounds.height
        var outputSize = viewport.size
        for _ in 1...12 {
            try Task.checkCancellation()
            guard isAttachedToActiveWindow else { throw FullContentHostError.inactiveWindow }
            contentHeight = verticalScrollHost.contentSize.height
            let insets = verticalScrollHost.adjustedContentInset
            let height = ceil((contentHeight + insets.top + insets.bottom) * viewport.scale) / viewport.scale
            captureHeight = height
            outputSize.height = viewport.size.height + height - originalScrollBounds.height
            guard outputSize.height * viewport.scale <= 32_768 else {
                throw FullContentHostError.contentHeightExceeded(outputSize.height * viewport.scale)
            }
            guard outputSize.height > viewport.size.height else {
                throw FullContentHostError.contentDoesNotExceedViewport(contentHeight)
            }
            verticalScrollHost.frame.size.height = height
            verticalScrollHost.setContentOffset(CGPoint(x: originalOffset.x, y: -insets.top), animated: false)
            verticalScrollHost.layoutIfNeeded()
            await LayoutFrame.wait()
            controller.view.layoutIfNeeded()
            let currentHeight = verticalScrollHost.contentSize.height
            let isStable = previousHeight.map({ abs(currentHeight - $0) * viewport.scale <= 1 }) ?? false
            stableIterations = isStable ? stableIterations + 1 : 0
            previousHeight = currentHeight
            if stableIterations >= 2 { break }
        }
        let elements = Self.accessibilityElements(in: controller.view, window: window)
        let census = Dictionary(uniqueKeysWithValues: expectedItemTitles.map { title in
            (title, elements.filter({ $0.label.components(separatedBy: ", ").contains(title) }).count)
        })
        try writeDiagnostics(
            elements: elements,
            census: census,
            layout: LayoutMeasurement(
                contentHeight: contentHeight, outputSize: outputSize, stableIterations: stableIterations
            ),
            directory: outputDirectory
        )
        guard stableIterations >= 2 else { throw FullContentHostError.didNotConverge }
        let tolerance = 1 / viewport.scale
        guard abs(verticalScrollHost.bounds.height - captureHeight) <= tolerance else {
            throw FullContentHostError.captureExtentReset(
                expected: captureHeight, actual: verticalScrollHost.bounds.height
            )
        }
        guard window.bounds.size == viewport.size,
              controller.view.bounds == originalRootBounds,
              scene.effectiveGeometry.coordinateSpace.bounds == originalSceneBounds,
              scene.effectiveGeometry.interfaceOrientation == originalOrientation,
              scrollGeometry.allSatisfy({ $0.isUnchanged(in: controller.view, tolerance: tolerance) }) else {
            throw FullContentHostError.logicalViewportChanged
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = viewport.scale
        format.opaque = true
        let fullImage = UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            controller.view.layer.render(in: context.cgContext)
        }
        let fullURL = outputDirectory.appending(path: "capture.full-content.png")
        try store(fullImage, at: fullURL, name: "full-content", directory: outputDirectory, record: record)
        guard let normalCG = normalImage.cgImage, let fullCG = fullImage.cgImage,
              let viewportCG = fullCG.cropping(to: CGRect(
                x: 0, y: 0, width: normalCG.width, height: normalCG.height
              )) else { throw FullContentHostError.emptyImage }
        let fullViewport = UIImage(cgImage: viewportCG, scale: viewport.scale, orientation: .up)
        let imageStrategy: Snapshotting<UIImage, UIImage> = .image
        try imageStrategy.diffing.toData(fullViewport)
            .write(to: outputDirectory.appending(path: "capture.layer-viewport.png"), options: .atomic)
        if let difference = imageStrategy.diffing.diffV2(normalImage, fullViewport) {
            throw FullContentHostError.nativeViewportPixelsChanged(difference.0)
        }
        guard abs(verticalScrollHost.bounds.height - captureHeight) <= tolerance else {
            throw FullContentHostError.captureExtentReset(
                expected: captureHeight, actual: verticalScrollHost.bounds.height
            )
        }
        guard census.values.allSatisfy({ $0 == 1 }) else { throw FullContentHostError.itemCensus(census) }
        guard let marker = elements.first(where: { $0.label == trailingMarker }) else {
            throw FullContentHostError.missingTrailingMarker(trailingMarker)
        }
        let outputBounds = CGRect(origin: .zero, size: outputSize)
        var itemFrames: [String: CGRect] = [:]
        for title in expectedItemTitles {
            guard let item = elements.first(where: { $0.label.components(separatedBy: ", ").contains(title) }),
                  item.frame.width > 0, item.frame.height > 0,
                  outputBounds.insetBy(dx: -tolerance, dy: -tolerance).contains(item.frame) else {
                throw FullContentHostError.clippedItem(title)
            }
            itemFrames[title] = item.frame
        }
        guard marker.frame.height > 0, outputBounds.contains(marker.frame) else {
            throw FullContentHostError.clippedItem(trailingMarker)
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

    private func render(size: CGSize) throws -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = viewport.scale
        format.opaque = true
        var rendered = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            rendered = controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        guard rendered, image.cgImage != nil else { throw FullContentHostError.renderFailed }
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
            // This gate explicitly writes disposable candidates using SnapshotTesting's encoder.
            // Its assert API intentionally fails when recording; ordinary comparisons use .never.
            try strategy.diffing.toData(image).write(to: url, options: .atomic)
        } else if let failure = verifySnapshot(
            of: image,
            as: strategy,
            named: name,
            record: .never,
            snapshotDirectory: directory.path,
            testName: "capture"
        ) {
            throw FullContentHostError.snapshotFailed(failure)
        }
    }

    private func writeDiagnostics(
        elements: [AccessibleElement],
        census: [String: Int],
        layout: LayoutMeasurement,
        directory: URL
    ) throws {
        let diagnostics: [String: Any] = [
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

    private static func accessibilityElements(in root: UIView, window: UIWindow) -> [AccessibleElement] {
        var visited: Set<ObjectIdentifier> = []
        var result: [AccessibleElement] = []
        func visit(_ object: NSObject) {
            guard visited.insert(ObjectIdentifier(object)).inserted,
                  !object.accessibilityElementsHidden else { return }
            if let view = object as? UIView, view.isHidden || view.alpha == 0 { return }
            if object.isAccessibilityElement {
                if let label = object.accessibilityLabel, !label.isEmpty {
                    result.append(AccessibleElement(
                        label: label, frame: window.convert(object.accessibilityFrame, from: nil)
                    ))
                }
                return
            }
            if let elements = object.accessibilityElements, !elements.isEmpty {
                for case let element as NSObject in elements { visit(element) }
                return
            }
            let count = object.accessibilityElementCount()
            if count > 0, count < 10_000 {
                for index in 0..<count {
                    if let element = object.accessibilityElement(at: index) as? NSObject { visit(element) }
                }
                return
            }
            if let view = object as? UIView {
                for child in view.subviews { visit(child) }
            }
        }
        visit(root)
        return result
    }
}

private struct AccessibleElement {
    let label: String
    let frame: CGRect
}

private struct LayoutMeasurement {
    let contentHeight: CGFloat
    let outputSize: CGSize
    let stableIterations: Int
}

@MainActor
private struct ClippingState {
    let view: UIView
    let clipsToBounds: Bool
}

@MainActor
private struct ScrollGeometry {
    let view: UIScrollView
    let frame: CGRect

    func isUnchanged(in root: UIView, tolerance: CGFloat) -> Bool {
        let current = view.convert(view.bounds, to: root)
        return abs(current.minX - frame.minX) <= tolerance
            && abs(current.minY - frame.minY) <= tolerance
            && abs(current.width - frame.width) <= tolerance
            && abs(current.height - frame.height) <= tolerance
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
    case invalidRecordMode
    case invalidViewport(CGSize)
    case itemCensus([String: Int])
    case logicalViewportChanged
    case missingTrailingMarker(String)
    case missingVerticalScrollHost
    case noForegroundActiveScene
    case nativeViewportPixelsChanged(String)
    case renderFailed
    case snapshotFailed(String)
}
