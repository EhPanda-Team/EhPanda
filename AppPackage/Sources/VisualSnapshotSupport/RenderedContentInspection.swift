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
/// (``occurrences(of:imageSize:words:pass:)``), so every extra window adds redundancy rather than a chance to miss or
/// repeat a marker. This changes only how the same pixels are read; the census stays exactly as strict.
enum RenderedContentInspection {
    /// Separate evidence classes: public Latin fixture markers and the localized final section label.
    enum Pass: String, Sendable {
        case fixtureMarkers
        case trailingMarker
    }

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

    /// A raw top candidate in full-image point coordinates, before the pass's acceptance rule is applied. Its frame is
    /// the Vision box kept to the window pixels the request analyzed (``frame(of:within:)``).
    struct Read: Equatable, Sendable {
        let label: String
        let confidence: Float
        let frame: CGRect
        let window: Window
        let pass: Pass
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

    /// A Vision box in full-image points, kept to `analyzed`, the window pixels its request read, or nil when no
    /// part of it lies there.
    ///
    /// Vision boxes are estimates that can reach past the pixels a request analyzed: 5,357 of 109,846 raw reads in a
    /// complete tracer did (2026-10-06). For the iPad AX5 landscape "Other" heading, which starts 16 pt from the
    /// image's left edge, the fine window on that edge returned a box 16 pt too wide, starting at x = -0.59 pt, so the
    /// heading failed its bounds check although nothing was clipped. Nothing outside the window is evidence, so the
    /// frame keeps only the analyzed part, which lies within the image. A box kept at an inner window edge still lies
    /// within ``edgeMargin`` of it, so interior acceptance rejects it there exactly as before.
    static func frame(of box: NormalizedRect, within analyzed: CGRect) -> CGRect? {
        let frame = box.toImageCoordinates(analyzed.size, origin: .upperLeft)
            .offsetBy(dx: analyzed.minX, dy: analyzed.minY)
            .intersection(analyzed)
        return frame.isEmpty ? nil : frame
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
    static func occurrences(
        of reads: [Read], imageSize: CGSize, words: Set<String>, pass: Pass = .fixtureMarkers
    ) throws -> [Occurrence] {
        var occurrences: [Occurrence] = []
        for (readIndex, read) in reads.enumerated()
        where read.pass == pass && (pass == .trailingMarker || read.confidence >= 0.8)
            && words.contains(read.label) && isInterior(read.frame, in: read.window.rect, imageSize: imageSize) {
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

    /// Reads fixture markers with the validated English recognizer, and the heading with its own language.
    /// Each pass retains raw candidates; ``occurrences(of:imageSize:words:pass:)`` applies its acceptance rule.
    ///
    /// On iOS 27, measured candidates occupied three confidence buckets (0.3, 0.5 and 1.0). The Latin recognizer
    /// read 其它 as "HE" at 1.0, while the native recognizer read correct CJK headings at 0.5. Localized heading
    /// evidence therefore uses exact identity under its language, interior acceptance and location merging, without
    /// a confidence floor. Fixture markers keep their independently validated English-only 0.8 floor. Supplying
    /// English second did not provide fallback in the measured requests and lost markers on 6 of 32 gate images.
    /// English headings reuse the same raw recognition, tagged with each evidence pass for diagnostics.
    @concurrent
    static func reads(
        in image: CGImage, imageSize: CGSize, windows: [Window], markerWords: [String], trailingMarker: String,
        trailingMarkerLanguage: Locale.Language = Locale.Language(identifier: "en")
    ) async throws -> [Read] {
        let english = Locale.Language(identifier: "en")
        let sharesRecognition = trailingMarkerLanguage == english
        let fixtureReads = try await readWindows(
            in: image, imageSize: imageSize, windows: windows, pass: .fixtureMarkers,
            request: recognitionRequest(
                customWords: markerWords + (sharesRecognition ? [trailingMarker] : []), language: english
            )
        )
        let trailingReads: [Read]
        if sharesRecognition {
            trailingReads = fixtureReads.map({
                Read(label: $0.label, confidence: $0.confidence, frame: $0.frame,
                     window: $0.window, pass: .trailingMarker)
            })
        } else {
            trailingReads = try await readWindows(
                in: image, imageSize: imageSize, windows: windows, pass: .trailingMarker,
                request: recognitionRequest(customWords: [trailingMarker], language: trailingMarkerLanguage)
            )
        }
        return fixtureReads + trailingReads
    }

    /// Validates the final label's presence and bounds together with the capture's required content height.
    static func trailingMarkerFrame(
        _ label: String, occurrences: [Occurrence], imageSize: CGSize, requiredHeight: CGFloat, scale: CGFloat
    ) throws -> CGRect {
        guard let marker = occurrences.first(where: { $0.label == label }) else {
            throw FullContentHostError.missingTrailingMarker(label)
        }
        guard CGRect(origin: .zero, size: imageSize).contains(marker.frame), marker.frame.height > 0,
              requiredHeight <= imageSize.height + 1 / scale else {
            throw FullContentHostError.clippedItem(label)
        }
        return marker.frame
    }

    /// Completes one recognition pass before starting another, keeping the eight-request memory bound global.
    private static func readWindows(
        in image: CGImage, imageSize: CGSize, windows: [Window], pass: Pass, request: RecognizeTextRequest
    ) async throws -> [Read] {
        let scale = CGFloat(image.width) / imageSize.width
        let results = try await withThrowingTaskGroup(of: WindowReads.self) { group in
            var pending = windows.enumerated().makeIterator()
            func startNextWindow() {
                guard let next = pending.next() else { return }
                group.addTask {
                    WindowReads(
                        windowIndex: next.offset,
                        reads: try await reads(
                            in: image, window: next.element, scale: scale, pass: pass, request: request
                        )
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

    private static func recognitionRequest(
        customWords: [String], language: Locale.Language
    ) -> RecognizeTextRequest {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [language]
        request.automaticallyDetectsLanguage = false
        request.usesLanguageCorrection = false
        request.customWords = customWords
        return request
    }

    private static func reads(
        in image: CGImage, window: Window, scale: CGFloat, pass: Pass, request: RecognizeTextRequest
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
        let analyzed = CGRect(
            x: left / scale, y: top / scale, width: pixels.width / scale, height: pixels.height / scale
        )
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  let frame = frame(of: observation.boundingBox, within: analyzed) else { return nil }
            return Read(label: candidate.string, confidence: candidate.confidence, frame: frame,
                        window: window, pass: pass)
        }
    }
}

/// One window's reads, tagged with the window's index so results merge in window order.
private struct WindowReads: Sendable {
    let windowIndex: Int
    let reads: [RenderedContentInspection.Read]
}
