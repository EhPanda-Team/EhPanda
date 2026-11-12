import CryptoKit
public import Foundation
public import UIKit

/// Reads one laid-out view hierarchy back from the render server in horizontal slices, then composes the
/// slices into a single image on the CPU.
///
/// `UIView.drawHierarchy(in:afterScreenUpdates:)` returns `false` (and logs "Render server returned error for
/// view") whenever the drawn view is larger than 8192 screen pixels in either dimension, regardless of its
/// content. A long screen therefore cannot be drawn in one call. Shrinking the window and
/// scrolling would move the hierarchy (safe area, toolbar glass, scroll position), so instead the window keeps
/// its full content height, its layout stays fixed during capture, and each slice is a
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
    /// Largest composite the previous height guard admitted at the widest matrix coordinate (2736 px).
    /// Restating that existing allowance as an area admits no larger RGBA buffer, while allowing narrower,
    /// taller captures. This is a tested allocation policy, not a CoreGraphics dimension limit.
    public static let maximumCompositePixelCount = 2736 * 32_768
    /// Retained 16-pixel planning grid. Alignment does not guarantee equality across different read origins.
    public static let readOriginGridPixels = 16
    private static let sliceEdgePadding: CGFloat = 64

    /// One render-server read of a rect of the captured view.
    public struct Slice: Sendable {
        /// Output rows owned by this read, in the view's bounds coordinates. Frames partition the full image.
        public let frame: CGRect
        /// Every read has the native viewport size, including a final read that may extend past the content.
        /// Context outside ``frame`` keeps read-edge rasterization out of composed rows and is not gated; excess
        /// bottom rows are discarded.
        public let readFrame: CGRect
        /// Interior context shared with the previous read; geometric evidence only, not a pixel-equality gate.
        public let contextFrame: CGRect?
    }

    /// The two digests of one read at one sample time.
    public struct ReadDigests: Sendable, Equatable {
        /// SHA-256 of the rows this read contributes to the composite: the bytes both passes must agree on.
        public let owned: String
        /// SHA-256 of the whole read, including context and overflow rows. Recorded as evidence, never gated.
        public let read: String
    }

    /// One planned rect's digests at the two sample times, associated with its exact geometry.
    public struct ReadVerification: Sendable {
        public let sliceIndex: Int
        public let slice: Slice
        public let pixelWidth: Int
        public let pixelHeight: Int
        /// Read-local pixel rows composed into the output. Read 0, the native rect, owns all of them.
        public let ownedRows: Range<Int>
        public let firstPass: ReadDigests
        public fileprivate(set) var secondPass: ReadDigests?

        var diagnostics: [String: Any] {
            ["sliceIndex": sliceIndex, "frame": NSCoder.string(for: slice.frame),
             "readFrame": NSCoder.string(for: slice.readFrame), "pixels": [pixelWidth, pixelHeight],
             "ownedRows": [ownedRows.lowerBound, ownedRows.upperBound],
             "firstPassOwnedSHA256": firstPass.owned, "secondPassOwnedSHA256": secondPass?.owned as Any? ?? NSNull(),
             "matched": secondPass.map({ $0.owned == firstPass.owned }) as Any? ?? NSNull(),
             "firstPassReadSHA256": firstPass.read, "secondPassReadSHA256": secondPass?.read as Any? ?? NSNull(),
             "readMatched": secondPass.map({ $0.read == firstPass.read }) as Any? ?? NSNull()]
        }
    }

    /// The composed capture and slice geometry. Canonical pixels are shared with inspection; reads are released.
    public struct Result {
        /// The composed image covering the captured view's whole bounds.
        public let image: UIImage
        /// The slices in top-to-bottom order.
        public let slices: [Slice]
        /// Per-read digests; every second-pass owned-row digest matches before this result can be returned.
        public let readVerifications: [ReadVerification]
        /// The tallest slice the render server accepts at the window's screen scale, in points.
        public let maximumSliceHeight: CGFloat
        /// Height of the retained interior context band; no cross-origin equality is asserted.
        public let contextBandHeight: CGFloat
        /// Minimum context above and below the interior band in both raw reads.
        public let edgePadding: CGFloat
        let raster: CapturedRaster
    }

    /// The tallest read, in points, whose screen-pixel height stays within ``maximumSnapshotDimension``.
    public static func maximumSliceHeight(forScreenScale scale: CGFloat) -> CGFloat {
        floor(maximumSnapshotDimension / scale)
    }

    /// Captures and verifies two complete passes over the same planned rects.
    ///
    /// SF Symbols and Liquid Glass can differ across read origins, even with equal read sizes. Each rect is
    /// instead read twice through the same path, and the rows it contributes to the composite must have the same
    /// canonical RGBA digest in both passes. Context and overflow rows are not gated: under simulator load, glass
    /// cut by a read's bottom edge flips one rim pixel by one level within 9 pt of the cut, and the context rows
    /// exist to keep such read-edge artifacts out of composed output. Read 0 is the native rect and owns all its
    /// rows, so its native viewport edge stays gated. Whole-read digests are still recorded as evidence. This
    /// establishes agreement at the two sample times, not uninterrupted stability or cross-origin seam equality;
    /// callers settle the hierarchy first with ``ownedRowDigests(of:viewportSize:format:contextBandHeight:)``.
    /// Native viewport parity, artwork verification, census and reference comparison remain separate checks.
    /// Basis: 17-02-PLAN.md, the owner approvals of same-rect and owned-row verification (2026-10-05), with the
    /// measurements in 17-02-INTEGRATION-NOTES.md.
    ///
    /// First-pass raw bytes are staged on disk when diagnostics are requested, so failure can preserve both whole
    /// reads without retaining all read images in memory. Successful verification removes that staging.
    @MainActor
    public static func image(
        of view: UIView, viewportSize: CGSize, format: UIGraphicsImageRendererFormat, contextBandHeight: CGFloat = 64,
        diagnosticsDirectory: URL? = nil
    ) throws -> Result {
        guard let window = view.window else { throw RenderServerCaptureError.detachedView }
        return try capture(
            bounds: view.bounds, viewportSize: viewportSize, screenScale: window.screen.scale,
            outputScale: format.scale, contextBandHeight: contextBandHeight, diagnosticsDirectory: diagnosticsDirectory
        ) { geometry in
            try canonicalRead(of: view, in: window, geometry: geometry, format: format)
        }
    }

    /// Reads every planned rect once and returns each read's owned-row digest, in plan order. Consecutive passes
    /// compare these to settle the hierarchy before
    /// ``image(of:viewportSize:format:contextBandHeight:diagnosticsDirectory:)`` verifies it; nothing is composed.
    @MainActor
    static func ownedRowDigests(
        of view: UIView, viewportSize: CGSize, format: UIGraphicsImageRendererFormat, contextBandHeight: CGFloat = 64
    ) throws -> [String] {
        guard let window = view.window else { throw RenderServerCaptureError.detachedView }
        return try ownedRowDigests(
            bounds: view.bounds, viewportSize: viewportSize, screenScale: window.screen.scale,
            outputScale: format.scale, contextBandHeight: contextBandHeight
        ) { geometry in
            try canonicalRead(of: view, in: window, geometry: geometry, format: format)
        }
    }

    /// The shared composition/verification engine. UIKit supplies canonical reads; tests supply row-coded reads
    /// and controlled frame changes to exercise the same ownership, ordering and owned-row digest checks.
    @MainActor
    static func capture(
        bounds: CGRect, viewportSize: CGSize, screenScale: CGFloat, outputScale: CGFloat,
        contextBandHeight: CGFloat = 64, diagnosticsDirectory: URL? = nil,
        read: (Slice) throws -> CapturedRaster
    ) throws -> Result {
        let layout = try ReadLayout(
            bounds: bounds, viewportSize: viewportSize, screenScale: screenScale, outputScale: outputScale,
            contextBandHeight: contextBandHeight
        )
        let archive = diagnosticsDirectory?.appending(path: "render-first-pass", directoryHint: .isDirectory)
        if let archive { try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true) }
        let rowBytes = layout.pixelWidth * 4
        var bytes = Data(count: layout.pixelHeight * rowBytes)
        var records: [ReadVerification] = []
        for (sliceIndex, planned) in layout.reads.enumerated() {
            try autoreleasepool {
                let current = try digestedRead(planned, sliceIndex: sliceIndex, pass: 1, scale: outputScale, read: read)
                if let archive {
                    try current.raster.pixels.write(to: archive.appending(path: "\(sliceIndex).rgba"), options: .atomic)
                }
                let count = planned.outputRows.count * rowBytes
                let sourceStart = planned.readRows.lowerBound * rowBytes
                let destinationStart = planned.outputRows.lowerBound * rowBytes
                bytes.withUnsafeMutableBytes { destination in
                    current.raster.pixels.withUnsafeBytes { source in
                        let rows = UnsafeRawBufferPointer(rebasing: source[sourceStart..<sourceStart + count])
                        let outputRows = UnsafeMutableRawBufferPointer(
                            rebasing: destination[destinationStart..<destinationStart + count]
                        )
                        outputRows.copyMemory(from: rows)
                    }
                }
                records.append(ReadVerification(
                    sliceIndex: sliceIndex, slice: planned.slice, pixelWidth: current.raster.width,
                    pixelHeight: current.raster.height, ownedRows: planned.readRows, firstPass: current.digests,
                    secondPass: nil
                ))
            }
        }
        try writeVerification(records, status: "verifying", scale: outputScale, directory: diagnosticsDirectory)
        // Complete pass 1 before starting pass 2: adjacent A/A, B/B sampling would miss a later change to A.
        for (sliceIndex, planned) in layout.reads.enumerated() {
            try autoreleasepool {
                let first = records[sliceIndex]
                let current = try digestedRead(planned, sliceIndex: sliceIndex, pass: 2, scale: outputScale, read: read)
                records[sliceIndex].secondPass = current.digests
                guard current.digests.owned == first.firstPass.owned else {
                    try writeVerification(
                        records, status: "failed", scale: outputScale, directory: diagnosticsDirectory,
                        failedSliceIndex: sliceIndex
                    )
                    if let archive, let diagnosticsDirectory {
                        let original = CapturedRaster(
                            width: first.pixelWidth, height: first.pixelHeight,
                            pixels: try Data(contentsOf: archive.appending(path: "\(sliceIndex).rgba"))
                        )
                        for (pass, sample) in [(1, original), (2, current.raster)] {
                            guard let png = try sample.comparisonImage(scale: outputScale).pngData() else {
                                throw RenderServerCaptureError.emptyImage
                            }
                            try png.write(to: diagnosticsDirectory.appending(
                                path: "capture.read-\(sliceIndex).pass-\(pass).png"
                            ), options: .atomic)
                        }
                    }
                    throw RenderServerCaptureError.readChanged(sliceIndex: sliceIndex)
                }
            }
        }
        try writeVerification(records, status: "passed", scale: outputScale, directory: diagnosticsDirectory)
        if let archive { try FileManager.default.removeItem(at: archive) }
        let raster = CapturedRaster(width: layout.pixelWidth, height: layout.pixelHeight, pixels: bytes)
        return Result(
            image: try raster.comparisonImage(scale: outputScale), slices: layout.reads.map(\.slice),
            readVerifications: records, maximumSliceHeight: maximumSliceHeight(forScreenScale: screenScale),
            contextBandHeight: contextBandHeight, edgePadding: layout.reads.count == 1 ? 0 : sliceEdgePadding,
            raster: raster
        )
    }

    /// The single-pass engine behind ``ownedRowDigests(of:viewportSize:format:contextBandHeight:)``: the same plan,
    /// read validation and owned rows as
    /// ``capture(bounds:viewportSize:screenScale:outputScale:contextBandHeight:diagnosticsDirectory:read:)``.
    @MainActor
    static func ownedRowDigests(
        bounds: CGRect, viewportSize: CGSize, screenScale: CGFloat, outputScale: CGFloat,
        contextBandHeight: CGFloat = 64, read: (Slice) throws -> CapturedRaster
    ) throws -> [String] {
        let layout = try ReadLayout(
            bounds: bounds, viewportSize: viewportSize, screenScale: screenScale, outputScale: outputScale,
            contextBandHeight: contextBandHeight
        )
        return try layout.reads.enumerated().map { sliceIndex, planned in
            try autoreleasepool {
                try digestedRead(planned, sliceIndex: sliceIndex, pass: 1, scale: outputScale, read: read).digests.owned
            }
        }
    }

    /// Reads one planned rect, requires its exact pixel size and digests its owned rows and the whole read.
    private static func digestedRead(
        _ planned: PlannedRead, sliceIndex: Int, pass: Int, scale: CGFloat, read: (Slice) throws -> CapturedRaster
    ) throws -> DigestedRead {
        let raster = try read(planned.slice)
        let width = Int((planned.slice.readFrame.width * scale).rounded())
        let height = Int((planned.slice.readFrame.height * scale).rounded())
        guard raster.width == width, raster.height == height else {
            throw RenderServerCaptureError.unexpectedReadSize(
                sliceIndex: sliceIndex, pass: pass, expected: CGSize(width: width, height: height),
                actual: CGSize(width: raster.width, height: raster.height)
            )
        }
        let rowBytes = raster.width * 4
        let digests = raster.pixels.withUnsafeBytes { bytes in
            ReadDigests(
                owned: sha256(UnsafeRawBufferPointer(rebasing: bytes[
                    planned.readRows.lowerBound * rowBytes..<planned.readRows.upperBound * rowBytes
                ])),
                read: sha256(bytes)
            )
        }
        return DigestedRead(raster: raster, digests: digests)
    }

    private static func sha256(_ bytes: UnsafeRawBufferPointer) -> String {
        SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined()
    }

    private static func writeVerification(
        _ records: [ReadVerification], status: String, scale: CGFloat, directory: URL?, failedSliceIndex: Int? = nil
    ) throws {
        guard let directory else { return }
        try JSONSerialization.data(withJSONObject: [
            "status": status,
            "comparison": "SHA-256 of each read's owned output rows in canonical 8-bit sRGB RGBA; "
                + "whole-read digests are evidence only",
            "passOrder": "all rects in pass 1, then all identical rects in pass 2", "requestedPasses": 2,
            "displayScale": scale, "readOriginGridPixels": readOriginGridPixels,
            "failedSliceIndex": failedSliceIndex as Any? ?? NSNull(), "reads": records.map(\.diagnostics)
        ], options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: "render-read-verification.json"), options: .atomic)
    }

    /// Preserve the native read rectangle and its complete output rows. Later ownership partitions only the
    /// remaining rows. Equal native sizes, a 16-pixel origin grid and interior context retain the established
    /// read plan; they do not make different origins byte-identical for symbols or glass. The final read may
    /// extend beyond content, but owns only in-bounds rows. Full same-rect rereads verify sample repeatability.
    /// All planning arithmetic uses device-pixel rows to avoid accumulated fractional point rounding.
    static func slicePlan(
        bounds: CGRect, viewportSize: CGSize, screenScale: CGFloat, contextBandHeight: CGFloat = 64
    ) throws -> [Slice] {
        guard screenScale.isFinite, screenScale > 0,
              bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0,
              viewportSize.width == bounds.width, viewportSize.height.isFinite, viewportSize.height > 0,
              viewportSize.height <= bounds.height, contextBandHeight.isFinite, contextBandHeight > 0,
              bounds.height * screenScale < CGFloat(Int.max) else {
            throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
        }
        let maximumRows = Int(maximumSliceHeight(forScreenScale: screenScale) * screenScale)
        guard viewportSize.height * screenScale <= CGFloat(maximumRows),
              contextBandHeight * screenScale < CGFloat(maximumRows) else {
            throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
        }
        let height = Int((bounds.height * screenScale).rounded())
        let viewportRows = Int((viewportSize.height * screenScale).rounded())
        let padding = Int((sliceEdgePadding * screenScale).rounded())
        let bandRows = Int((contextBandHeight * screenScale).rounded())
        let nativeFrame = CGRect(origin: bounds.origin, size: viewportSize)
        var slices = [Slice(frame: nativeFrame, readFrame: nativeFrame, contextFrame: nil)]
        guard height > viewportRows else { return slices }
        // The second read must advance past all native-owned rows while reserving its bottom context.
        guard bandRows > 0, viewportRows > 3 * padding + bandRows + readOriginGridPixels else {
            throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
        }
        func frame(_ start: Int, _ end: Int) -> CGRect {
            CGRect(x: bounds.minX, y: bounds.minY + CGFloat(start) / screenScale,
                   width: bounds.width, height: CGFloat(end - start) / screenScale)
        }
        var ownedEnd = viewportRows
        var previousReadStart = 0
        var previousReadEnd = viewportRows
        while ownedEnd < height {
            let bandEnd = min(ownedEnd, previousReadEnd - padding)
            let bandStart = bandEnd - bandRows
            let readStart = (bandStart - padding) / readOriginGridPixels * readOriginGridPixels
            let readEnd = readStart + viewportRows
            let outputEnd = readEnd >= height ? height : readEnd - padding
            guard readStart >= 0, readStart <= ownedEnd, outputEnd > ownedEnd,
                  bandStart - previousReadStart >= padding, bandStart - readStart >= padding,
                  previousReadEnd - bandEnd >= padding, readEnd - bandEnd >= padding else {
                throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
            }
            slices.append(Slice(
                frame: frame(ownedEnd, outputEnd), readFrame: frame(readStart, readEnd),
                contextFrame: frame(bandStart, bandEnd)
            ))
            ownedEnd = outputEnd
            previousReadStart = readStart
            previousReadEnd = readEnd
        }
        return slices
    }

    /// One drawable replicant read of `geometry.readFrame`, converted to canonical bytes.
    @MainActor
    private static func canonicalRead(
        of view: UIView, in window: UIWindow, geometry: Slice, format: UIGraphicsImageRendererFormat
    ) throws -> CapturedRaster {
        let readFrame = geometry.readFrame
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
        guard let cgImage = image.cgImage else { throw RenderServerCaptureError.emptyImage }
        return try CapturedRaster(image: cgImage)
    }
}

/// A read's place in the composite: its slice plus the rows it owns, in output and in read-local pixels.
private struct PlannedRead {
    let slice: RenderServerCapture.Slice
    let outputRows: Range<Int>
    let readRows: Range<Int>
}

/// The validated output size and read plan shared by verification passes and settle passes.
private struct ReadLayout {
    let pixelWidth: Int
    let pixelHeight: Int
    let reads: [PlannedRead]

    init(
        bounds: CGRect, viewportSize: CGSize, screenScale: CGFloat, outputScale: CGFloat, contextBandHeight: CGFloat
    ) throws {
        guard screenScale.isFinite, screenScale > 0, outputScale.isFinite, outputScale > 0,
              bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0,
              bounds.width * outputScale < CGFloat(Int.max), bounds.height * outputScale < CGFloat(Int.max) else {
            throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
        }
        guard bounds.width * screenScale <= RenderServerCapture.maximumSnapshotDimension else {
            throw RenderServerCaptureError.widthExceedsSnapshotDimension(bounds.width)
        }
        pixelWidth = Int((bounds.width * outputScale).rounded())
        pixelHeight = Int((bounds.height * outputScale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { throw RenderServerCaptureError.emptyImage }
        guard pixelHeight <= RenderServerCapture.maximumCompositePixelCount / pixelWidth else {
            throw RenderServerCaptureError.compositeExceedsBudget(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        }
        let plan = try RenderServerCapture.slicePlan(
            bounds: bounds, viewportSize: viewportSize, screenScale: screenScale, contextBandHeight: contextBandHeight
        )
        var reads: [PlannedRead] = []
        var ownedEnd = 0
        for slice in plan {
            let firstRow = Int(((slice.frame.minY - bounds.minY) * outputScale).rounded())
            let endRow = Int(((slice.frame.maxY - bounds.minY) * outputScale).rounded())
            let readRow = Int(((slice.frame.minY - slice.readFrame.minY) * outputScale).rounded())
            let readHeight = Int((slice.readFrame.height * outputScale).rounded())
            guard firstRow == ownedEnd, endRow > firstRow, endRow <= pixelHeight,
                  readRow >= 0, readRow + endRow - firstRow <= readHeight else {
                throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
            }
            reads.append(PlannedRead(
                slice: slice, outputRows: firstRow..<endRow, readRows: readRow..<readRow + endRow - firstRow
            ))
            ownedEnd = endRow
        }
        guard ownedEnd == pixelHeight else {
            throw RenderServerCaptureError.invalidSliceGeometry(bounds: bounds, viewportSize: viewportSize)
        }
        self.reads = reads
    }
}

/// One validated read with the digests of its owned rows and of the whole read.
private struct DigestedRead {
    let raster: CapturedRaster
    let digests: RenderServerCapture.ReadDigests
}

/// Why ``RenderServerCapture/image(of:viewportSize:format:contextBandHeight:diagnosticsDirectory:)`` failed.
public enum RenderServerCaptureError: Error {
    /// The view is not in a window, so there is no screen scale and nowhere to host a replicant.
    case detachedView
    /// The view's width, in points, exceeds the render server ceiling on its own; slicing is vertical only.
    case widthExceedsSnapshotDimension(CGFloat)
    /// The converged output would allocate more canonical RGBA pixels than the tested composite budget.
    case compositeExceedsBudget(pixelWidth: Int, pixelHeight: Int)
    /// The native viewport or slice dimensions cannot provide complete output and interior context.
    case invalidSliceGeometry(bounds: CGRect, viewportSize: CGSize)
    /// UIKit returned no replicant for the slice rect.
    case snapshotRefused(CGRect)
    /// `drawHierarchy(in:afterScreenUpdates:)` returned `false` for the slice rect.
    case renderServerRefused(CGRect)
    /// Two reads of the same rect disagree at their sample times; no composite is accepted.
    case readChanged(sliceIndex: Int)
    /// A reader returned a bitmap that does not cover the exact requested rect at the output scale.
    case unexpectedReadSize(sliceIndex: Int, pass: Int, expected: CGSize, actual: CGSize)
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
    let pixels: Data

    init(width: Int, height: Int, pixels: Data) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(image: CGImage) throws {
        var bytes = Data(count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            try Self.draw(image, into: buffer)
        }
        self.init(width: image.width, height: image.height, pixels: bytes)
    }

    /// Converts a native bitmap into canonical bytes. Composition copies owned rows from that same storage.
    static func draw(_ image: CGImage, into buffer: UnsafeMutableRawBufferPointer) throws {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace,
                bitmapInfo: .init(alpha: .premultipliedLast, byteOrder: .order32Big)
              ) else { throw FullContentHostError.emptyImage }
        // Copy canonical RGBA bytes, including alpha, without blending with the destination buffer.
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    func comparisonImage(scale: CGFloat) throws -> UIImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: .init(alpha: .premultipliedLast, byteOrder: .order32Big),
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
