import Foundation
import UIKit

/// Reads one laid-out view hierarchy back from the render server in horizontal slices, then composes the
/// slices into a single image on the CPU.
///
/// `UIView.drawHierarchy(in:afterScreenUpdates:)` returns `false` (and logs "Render server returned error for
/// view") whenever the drawn view is larger than 8192 screen pixels in either dimension, regardless of its
/// content. A long screen therefore cannot be drawn in one call. Shrinking the window and
/// scrolling would move the hierarchy (safe area, toolbar glass, scroll position), so instead the window keeps
/// its full content height, the hierarchy is laid out exactly once, and each slice is a
/// `resizableSnapshotView(from:afterScreenUpdates:withCapInsets:)` replicant of one rect of that same committed
/// frame. Only the replicant, which is at most ``maximumSnapshotDimension`` pixels tall, is ever drawn.
///
/// A moving clip view over the hierarchy is deliberately not used: it shifts the hosted view's safe area between
/// slices and leaves a visible seam.
public enum RenderServerCapture {
    /// Inclusive per-dimension ceiling, in screen pixels, for one replicant read. Points x screen scale, never the
    /// trait display scale: overriding `displayScale` does not move the limit.
    ///
    /// The ceiling is deliberately one pixel under 8192. A replicant read of exactly 8192 px returns
    /// `drawHierarchy == true` with an all-black image (measured 2026-10-03 on the 2x iPad: 8190 px valid, 8192 px
    /// silently black, 8194 px refused with `false`; 3x reads cannot land on 8192 px, 8190 px valid and 8193 px
    /// refused). The direct `drawHierarchy` path accepts 8192 px, but this capture only ever draws replicants.
    public static let maximumSnapshotDimension: CGFloat = 8191
    private static let sliceEdgePadding: CGFloat = 64

    /// One render-server read of a rect of the captured view.
    public struct Slice: Sendable {
        /// The slice rect in the captured view's bounds coordinates, in points. Always full width.
        public let frame: CGRect
        /// The render-server read includes context outside ``frame`` to keep rasterization away from crop edges.
        public let readFrame: CGRect
        /// The pixels the render server returned for ``frame``.
        public let image: UIImage
    }

    /// The composed capture together with the slices it was built from, kept for diagnostics and evidence.
    public struct Result {
        /// The composed image covering the captured view's whole bounds.
        public let image: UIImage
        /// The slices in top-to-bottom order.
        public let slices: [Slice]
        /// The tallest slice the render server accepts at the window's screen scale, in points.
        public let maximumSliceHeight: CGFloat
        /// The height, in points, that consecutive slices share and that the seam self-check compares.
        public let overlap: CGFloat
        /// Context read outside each slice, then cropped away without redrawing the captured pixels.
        public let edgePadding: CGFloat
    }

    /// The tallest read, in points, whose screen-pixel height stays within ``maximumSnapshotDimension``.
    public static func maximumSliceHeight(forScreenScale scale: CGFloat) -> CGFloat {
        floor(maximumSnapshotDimension / scale)
    }

    /// Captures `view` as one image of its whole bounds.
    ///
    /// The view must be attached to a window, which supplies the screen scale that the render-server ceiling is
    /// measured in. Slices cover `view.bounds` top to bottom. Multi-slice reads reserve context above and below
    /// each slice within the dimension ceiling, then crop away that context without redrawing. A view that fits
    /// in one read is captured as exactly one slice with no seam check.
    ///
    /// Each slice is drawn through a replicant temporarily added to the window. The Boolean returned by
    /// `drawHierarchy(in:afterScreenUpdates:)` is the only proof of a successful draw: a refused draw still yields
    /// an image (fully transparent, or opaque fill), so a produced image is never treated as success.
    ///
    /// Consecutive slices overlap by `overlap` points. That band depicts the same region of the same committed
    /// frame in both slices, so its 8-bit sRGB RGBA bytes must be identical; any difference means the reads cannot
    /// be combined faithfully, so the capture fails instead.
    ///
    /// - Parameters:
    ///   - view: The laid-out view to capture, attached to a window.
    ///   - format: The renderer format used for every slice and for the composite.
    ///   - overlap: Points shared by consecutive slices for the seam self-check. Must be non-negative and smaller
    ///     than the maximum slice height.
    ///   - diagnosticsDirectory: Optional destination for the original slices and their rects when a seam fails.
    @MainActor
    public static func image(
        of view: UIView, format: UIGraphicsImageRendererFormat, overlap: CGFloat = 64,
        diagnosticsDirectory: URL? = nil
    ) throws -> Result {
        guard let window = view.window else { throw RenderServerCaptureError.detachedView }
        let scale = window.screen.scale
        let maximumSliceHeight = maximumSliceHeight(forScreenScale: scale)
        guard view.bounds.width * scale <= maximumSnapshotDimension else {
            throw RenderServerCaptureError.widthExceedsSnapshotDimension(view.bounds.width)
        }
        let fitsSingleRead = view.bounds.height <= maximumSliceHeight
        let edgePadding = fitsSingleRead ? 0 : sliceEdgePadding
        precondition(
            overlap >= 0 && overlap < maximumSliceHeight - 2 * edgePadding,
            "Slice overlap must leave a positive stride after reserving edge context"
        )
        let frames = sliceFrames(
            of: view.bounds, maximumSliceHeight: maximumSliceHeight - 2 * edgePadding, overlap: overlap
        )
        let slices = try frames.map({ frame in
            let top = max(view.bounds.minY, frame.minY - edgePadding)
            let bottom = min(view.bounds.maxY, frame.maxY + edgePadding)
            let readFrame = CGRect(x: frame.minX, y: top, width: frame.width, height: bottom - top)
            return try slice(of: view, in: window, frame: frame, readFrame: readFrame, format: format)
        })
        if slices.count > 1, overlap > 0 {
            do {
                try verifySeams(of: slices, bandPixelHeight: Int((overlap * scale).rounded()))
            } catch {
                if let diagnosticsDirectory {
                    try writeDiagnostics(slices: slices, scale: scale, overlap: overlap, to: diagnosticsDirectory)
                }
                throw error
            }
        }
        // Copy exactly the canonical bytes checked at the seams. Drawing the slices again through a renderer
        // can apply another color-space conversion and round otherwise identical glass pixels by one byte.
        let image = try CapturedRaster(slices: slices, bounds: view.bounds, scale: format.scale)
            .comparisonImage(scale: format.scale)
        return Result(
            image: image, slices: slices, maximumSliceHeight: maximumSliceHeight,
            overlap: overlap, edgePadding: edgePadding
        )
    }

    private static func sliceFrames(
        of bounds: CGRect, maximumSliceHeight: CGFloat, overlap: CGFloat
    ) -> [CGRect] {
        let sliceStride = maximumSliceHeight - overlap
        var frames: [CGRect] = []
        var minY = bounds.minY
        while true {
            let height = min(maximumSliceHeight, bounds.maxY - minY)
            frames.append(CGRect(x: bounds.minX, y: minY, width: bounds.width, height: height))
            guard minY + height < bounds.maxY else { return frames }
            minY += sliceStride
        }
    }

    @MainActor
    private static func slice(
        of view: UIView, in window: UIWindow, frame: CGRect, readFrame: CGRect, format: UIGraphicsImageRendererFormat
    ) throws -> Slice {
        guard let replicant = view.resizableSnapshotView(
            from: readFrame, afterScreenUpdates: true, withCapInsets: .zero
        ) else { throw RenderServerCaptureError.snapshotRefused(readFrame) }
        // The replicant is only drawable while it is in a window; its own size is what the render server checks.
        replicant.frame = CGRect(origin: .zero, size: readFrame.size)
        window.addSubview(replicant)
        defer { replicant.removeFromSuperview() }
        var drew = false
        let image = UIGraphicsImageRenderer(bounds: replicant.bounds, format: format).image { _ in
            drew = replicant.drawHierarchy(in: replicant.bounds, afterScreenUpdates: true)
        }
        guard drew else { throw RenderServerCaptureError.renderServerRefused(readFrame) }
        // Snapshot rect edges can rerasterize a clipped glyph by one byte. Read context on both sides, then crop
        // immutable CGImage pixels so the entire strict overlap band comes from the interior of both reads.
        guard let pixels = image.cgImage?.cropping(to: CGRect(
            x: 0, y: ((frame.minY - readFrame.minY) * image.scale).rounded(),
            width: (frame.width * image.scale).rounded(), height: (frame.height * image.scale).rounded()
        )) else { throw RenderServerCaptureError.emptyImage }
        return Slice(
            frame: frame, readFrame: readFrame, image: UIImage(cgImage: pixels, scale: image.scale, orientation: .up)
        )
    }

    private static func verifySeams(of slices: [Slice], bandPixelHeight: Int) throws {
        for (sliceIndex, pair) in zip(slices, slices.dropFirst()).enumerated() {
            guard let upper = pair.0.image.cgImage, let lower = pair.1.image.cgImage,
                  let upperBand = upper.cropping(to: CGRect(
                    x: 0, y: upper.height - bandPixelHeight, width: upper.width, height: bandPixelHeight
                  )),
                  let lowerBand = lower.cropping(to: CGRect(
                    x: 0, y: 0, width: lower.width, height: bandPixelHeight
                  )) else { throw RenderServerCaptureError.emptyImage }
            let upperPixels: [UInt8]
            let lowerPixels: [UInt8]
            do {
                upperPixels = try CapturedRaster(image: upperBand).pixels
                lowerPixels = try CapturedRaster(image: lowerBand).pixels
            } catch {
                // `CapturedRaster` fails only when it cannot create its sRGB bitmap context, which for this
                // capture means the band holds no readable pixels.
                throw RenderServerCaptureError.emptyImage
            }
            guard upperPixels == lowerPixels else {
                throw RenderServerCaptureError.seamMismatch(sliceIndex: sliceIndex)
            }
        }
    }

    private static func writeDiagnostics(slices: [Slice], scale: CGFloat, overlap: CGFloat, to directory: URL) throws {
        for (sliceIndex, slice) in slices.enumerated() {
            guard let data = slice.image.pngData() else { throw RenderServerCaptureError.emptyImage }
            try data.write(to: directory.appending(path: "capture.render-slice-\(sliceIndex).png"), options: .atomic)
        }
        try JSONSerialization.data(withJSONObject: [
            "displayScale": scale, "overlap": overlap,
            "slices": slices.map({
                ["frame": NSCoder.string(for: $0.frame), "readFrame": NSCoder.string(for: $0.readFrame)]
            })
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: "render-slices.json"), options: .atomic)
    }
}

/// Why ``RenderServerCapture/image(of:format:overlap:)`` could not produce a trustworthy image.
public enum RenderServerCaptureError: Error {
    /// The view is not in a window, so there is no screen scale and nowhere to host a replicant.
    case detachedView
    /// The view's width, in points, exceeds the render server ceiling on its own; slicing is vertical only.
    case widthExceedsSnapshotDimension(CGFloat)
    /// UIKit returned no replicant for the slice rect.
    case snapshotRefused(CGRect)
    /// `drawHierarchy(in:afterScreenUpdates:)` returned `false` for the slice rect.
    case renderServerRefused(CGRect)
    /// The overlap band between slice `sliceIndex` and the next one differs, so the composite would hold a seam.
    case seamMismatch(sliceIndex: Int)
    /// A slice or the composite has no pixel data.
    case emptyImage
}

/// An 8-bit sRGB, premultiplied RGBA copy of a captured image.
///
/// Every comparison in this module converts through this one pixel format, so captures that UIKit stored in a
/// different bitmap layout (for example extended range) still compare byte for byte.
struct CapturedRaster {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(slices: [RenderServerCapture.Slice], bounds: CGRect, scale: CGFloat) throws {
        let pixelWidth = Int((bounds.width * scale).rounded())
        let pixelHeight = Int((bounds.height * scale).rounded())
        var bytes = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        for slice in slices {
            guard let image = slice.image.cgImage else { throw RenderServerCaptureError.emptyImage }
            let raster = try CapturedRaster(image: image)
            let firstRow = Int(((slice.frame.minY - bounds.minY) * scale).rounded())
            guard raster.width == pixelWidth, firstRow >= 0, firstRow + raster.height <= pixelHeight else {
                throw RenderServerCaptureError.emptyImage
            }
            let start = firstRow * pixelWidth * 4
            bytes.replaceSubrange(start..<start + raster.pixels.count, with: raster.pixels)
        }
        width = pixelWidth
        height = pixelHeight
        pixels = bytes
    }

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

    func comparisonImage(scale: CGFloat) throws -> UIImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                                        | CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { throw FullContentHostError.emptyImage }
        return UIImage(cgImage: image, scale: scale, orientation: .up)
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
