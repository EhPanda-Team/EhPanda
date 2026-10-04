import UIKit
import Vision

/// Counts the census markers in a rendered full-content image by reading its pixels through overlapping windows at
/// two scales and merging the reads by location.
///
/// Vision reduces each request to a roughly fixed internal grid, so one request over the whole tall capture would
/// shrink its markers away, and even viewport-sized bands are too coarse on the iPad: the gate's box quantization
/// implies a grid of about 464x320 for an iPad viewport band (about 0.38 grid px per pt) against 0.51-0.57 for phone
/// bands. Body-size markers on the iPad therefore fell under Vision's documented default minimum text height (1/32
/// of the image height), which dropped them, misread them, or returned homoglyphs. The fine scale restores the
/// resolution; the coarse scale, full width by the viewport height, contains the large markers (Reader page
/// markers reach about 595x180 pt).
///
/// Midpoint band ownership, which credited each read to exactly one band, both lost markers (one band read VC5, but
/// the band owning its midpoint missed it) and double counted them (one VD16 read at midY 5004.0 and at 5006.0,
/// either side of an ownership boundary). Instead, a read counts only when its window holds it whole
/// (``isInterior(_:in:imageSize:)``), and reads at one location merge into one occurrence
/// (``occurrences(of:imageSize:words:)``), so every extra window adds redundancy rather than a chance to miss or
/// repeat a marker. This changes only how the same pixels are read; the census stays exactly as strict.
enum RenderedContentInspection {
    /// The two window scales, read in this order.
    enum WindowScale: String, CaseIterable, Sendable {
        /// Squares of ``RenderedContentInspection/fineWindowSide``, clamped to the image, for resolution.
        case fine
        /// Full image width by the viewport height, clamped to the image, for markers too large for a fine window.
        case coarse

        func windowSize(imageSize: CGSize, viewportHeight: CGFloat) -> CGSize {
            switch self {
            case .fine:
                CGSize(width: min(fineWindowSide, imageSize.width), height: min(fineWindowSide, imageSize.height))
            case .coarse:
                CGSize(width: imageSize.width, height: min(viewportHeight, imageSize.height))
            }
        }
    }

    /// A rectangle of the full image, in points, that one Vision request reads.
    struct Window: Equatable, Sendable {
        let rect: CGRect
        let scale: WindowScale
    }

    /// A confident recognition in full-image point coordinates, with the window that produced it.
    struct Read: Equatable, Sendable {
        let label: String
        let confidence: Float
        let frame: CGRect
        let window: Window
    }

    /// One marker location: the label and frame of its first accepted read, and the indices of every accepted read
    /// at that location.
    struct Occurrence: Equatable {
        let label: String
        let frame: CGRect
        var readIndices: [Int]
    }

    /// The fine window side, in points. Vision's default minimum text height for a 420 pt window is about 13 pt
    /// (1/32), comfortably under the 16-21 pt boxes of body-size markers. Fine windows alone missed every Reader
    /// page marker (too large for them), which is why the coarse scale stays; the two scales together passed all 31
    /// captured coordinates on the host and in the simulator.
    static let fineWindowSide: CGFloat = 420

    /// The distance, in points, a read must keep from every inner window edge. A box that close to an edge may
    /// belong to a line the crop cut through, which Vision can return truncated (a cut VC12 could read as VC1,
    /// another census word). Eight points is several times the box jitter between windows (one VD16 read 2 pt apart
    /// in two bands), and with the half stride a window still holds whole any line up to half its side minus 16 pt.
    static let edgeMargin: CGFloat = 8

    /// How close, in points, a window's far edge must come to the image's far edge to lie on the image boundary,
    /// which exempts it from ``edgeMargin``: nothing lies beyond it to be cut.
    static let boundaryTolerance: CGFloat = 0.5

    /// The Vision requests kept in flight. Measured in the simulator, eight in flight gave identical results 5-6x
    /// faster than one at a time (27.8 s to 5.4 s on the failing iPad Comments coordinate, 92.0 s to 15.8 s on iPad
    /// landscape AX5 Reader); one at a time puts a matrix test at risk of FeatureTests' 10-minute execution
    /// allowance. The cap bounds how many window crops and Vision buffers are alive at once.
    static let maximumRequestsInFlight = 8

    /// Every window over an image of `imageSize` points: the fine scale first, then the coarse one, each row-major
    /// (y outer, x inner). Reads are merged in this order, so it is deterministic.
    static func windows(imageSize: CGSize, viewportHeight: CGFloat) -> [Window] {
        WindowScale.allCases.flatMap { scale in
            let size = scale.windowSize(imageSize: imageSize, viewportHeight: viewportHeight)
            return origins(total: imageSize.height, size: size.height).flatMap { originY in
                origins(total: imageSize.width, size: size.width).map { originX in
                    Window(rect: CGRect(origin: CGPoint(x: originX, y: originY), size: size), scale: scale)
                }
            }
        }
    }

    /// The window origins along an axis of `total` points for windows `size` points long: one window when it covers
    /// the axis, otherwise a stride of half a window from 0, then one window aligned to the far edge.
    ///
    /// With the half stride, any line no longer than `size / 2 - 2 * edgeMargin` along the axis (194 pt for a fine
    /// window) lies whole, margins included, inside at least one window, so interior acceptance never discards the
    /// only whole read a scale can produce. The far-edge window ends coverage exactly at the image boundary.
    static func origins(total: CGFloat, size: CGFloat) -> [CGFloat] {
        guard size < total else { return [0] }
        return Array(stride(from: 0, to: total - size, by: size / 2)) + [total - size]
    }

    /// Whether `frame` keeps ``edgeMargin`` from every inner edge of `window`. An edge on the image boundary (an
    /// origin at or before 0, or a far edge within ``boundaryTolerance`` of the image's) is exempt.
    static func isInterior(_ frame: CGRect, in window: CGRect, imageSize: CGSize) -> Bool {
        (window.minX <= 0 || frame.minX >= window.minX + edgeMargin)
            && (window.maxX >= imageSize.width - boundaryTolerance || frame.maxX <= window.maxX - edgeMargin)
            && (window.minY <= 0 || frame.minY >= window.minY + edgeMargin)
            && (window.maxY >= imageSize.height - boundaryTolerance || frame.maxY <= window.maxY - edgeMargin)
    }

    /// Whether two frames mark one location: either contains the other's center.
    static func sharesLocation(_ first: CGRect, _ second: CGRect) -> Bool {
        first.contains(CGPoint(x: second.midX, y: second.midY))
            || second.contains(CGPoint(x: first.midX, y: first.midY))
    }

    /// Merges `reads`, in order, into one occurrence per location. Only interior reads of a census word take part.
    /// A read of an occurrence's label at its location only adds support; a different census word at any existing
    /// occurrence's location throws ``FullContentHostError/ambiguousRenderedText(_:)``, because picking one label
    /// would hide a misread.
    static func occurrences(of reads: [Read], imageSize: CGSize, words: Set<String>) throws -> [Occurrence] {
        var occurrences: [Occurrence] = []
        for (readIndex, read) in reads.enumerated()
        where words.contains(read.label) && isInterior(read.frame, in: read.window.rect, imageSize: imageSize) {
            if let other = occurrences.first(where: {
                $0.label != read.label && sharesLocation($0.frame, read.frame)
            }) {
                throw FullContentHostError.ambiguousRenderedText(
                    "\(other.label) at \(NSCoder.string(for: other.frame)) and "
                        + "\(read.label) at \(NSCoder.string(for: read.frame)) share one location"
                )
            }
            if let match = occurrences.firstIndex(where: { sharesLocation($0.frame, read.frame) }) {
                occurrences[match].readIndices.append(readIndex)
            } else {
                occurrences.append(Occurrence(label: read.label, frame: read.frame, readIndices: [readIndex]))
            }
        }
        return occurrences
    }

    /// Recognizes text in every window of `image` (whose size is `imageSize` points) and returns the confident reads
    /// in window order, whatever order the requests complete in.
    @concurrent
    static func reads(
        in image: CGImage, imageSize: CGSize, windows: [Window], words: [String]
    ) async throws -> [Read] {
        let request = recognitionRequest(customWords: words)
        let scale = CGFloat(image.width) / imageSize.width
        let results = try await withThrowingTaskGroup(of: WindowReads.self) { group in
            var pending = windows.enumerated().makeIterator()
            func startNextWindow() {
                guard let next = pending.next() else { return }
                group.addTask {
                    WindowReads(
                        windowIndex: next.offset,
                        reads: try await reads(in: image, window: next.element, scale: scale, request: request)
                    )
                }
            }
            for _ in 0..<maximumRequestsInFlight {
                startNextWindow()
            }
            var collected: [WindowReads] = []
            while let result = try await group.next() {
                collected.append(result)
                startNextWindow()
            }
            return collected
        }
        return results.sorted(by: { $0.windowIndex < $1.windowIndex }).flatMap(\.reads)
    }

    private static func recognitionRequest(customWords: [String]) -> RecognizeTextRequest {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "en")]
        request.usesLanguageCorrection = false
        request.customWords = customWords
        return request
    }

    private static func reads(
        in image: CGImage, window: Window, scale: CGFloat, request: RecognizeTextRequest
    ) async throws -> [Read] {
        let left = (window.rect.minX * scale).rounded()
        let top = (window.rect.minY * scale).rounded()
        let pixels = CGRect(
            x: left, y: top,
            width: (window.rect.maxX * scale).rounded() - left, height: (window.rect.maxY * scale).rounded() - top
        )
        guard !pixels.isEmpty, let crop = image.cropping(to: pixels) else {
            throw FullContentHostError.renderedTextInspectionFailed(
                "Window \(NSCoder.string(for: window.rect)) is empty"
            )
        }
        let observations: [RecognizedTextObservation]
        do {
            observations = try await ImageRequestHandler(crop).perform(request)
        } catch {
            throw FullContentHostError.renderedTextInspectionFailed(String(describing: error))
        }
        try Task.checkCancellation()
        let cropSize = CGSize(width: pixels.width / scale, height: pixels.height / scale)
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.8 else {
                return nil
            }
            let frame = observation.boundingBox
                .toImageCoordinates(cropSize, origin: .upperLeft)
                .offsetBy(dx: left / scale, dy: top / scale)
            return Read(label: candidate.string, confidence: candidate.confidence, frame: frame, window: window)
        }
    }
}

/// One window's reads, tagged with the window's index so results merge in window order.
private struct WindowReads: Sendable {
    let windowIndex: Int
    let reads: [RenderedContentInspection.Read]
}
