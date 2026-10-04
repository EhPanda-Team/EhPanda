import AppFeature
import CustomDump
import UIKit
@testable import VisualSnapshotSupport
import XCTest

final class RenderedContentInspectionTests: XCTestCase {
    private typealias Inspection = RenderedContentInspection

    /// These tests need no app state, but they run inside the host app, whose scene phase changes reach its download
    /// client at any time. Re-preparing the inert host clients for every test keeps such a change from resolving an
    /// unimplemented test dependency and failing whichever test happens to be running.
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    private static let imageSize = CGSize(width: 1210, height: 2000)
    private static let censusWords: Set<String> = ["VC1", "VC3", "VC4", "VC7", "VH3"]
    private static let topCoarseWindow = Inspection.Window(
        rect: CGRect(x: 0, y: 0, width: 1210, height: 834), scale: .coarse
    )
    private static let fineWindow = Inspection.Window(rect: CGRect(x: 0, y: 210, width: 420, height: 420), scale: .fine)

    func testWindowOriginsUseOneWindowWhenItCoversTheAxis() {
        expectNoDifference(Inspection.origins(total: 300, size: 420), [0])
        expectNoDifference(Inspection.origins(total: 420, size: 420), [0])
        // Both scales clamp to an image smaller than their windows.
        expectNoDifference(Inspection.windows(imageSize: CGSize(width: 300, height: 400), viewportHeight: 834), [
            Inspection.Window(rect: CGRect(x: 0, y: 0, width: 300, height: 400), scale: .fine),
            Inspection.Window(rect: CGRect(x: 0, y: 0, width: 300, height: 400), scale: .coarse)
        ])
    }

    /// Consecutive windows overlap by half a window, so every line up to half a window minus both margins long lies
    /// whole, margins included, inside some window. A stride landing exactly on the far edge adds no duplicate.
    func testWindowOriginsStrideByHalfAWindow() {
        let origins = Inspection.origins(total: 1050, size: 420)
        expectNoDifference(origins, [0, 210, 420, 630])
        let image = CGSize(width: 1050, height: 40)
        let longest = 420 / 2 - 2 * Inspection.edgeMargin
        for start in stride(from: 0, through: image.width - longest, by: 0.5) {
            let line = CGRect(x: start, y: 10, width: longest, height: 20)
            XCTAssertTrue(origins.contains(where: { origin in
                Inspection.isInterior(line, in: CGRect(x: origin, y: 0, width: 420, height: 40), imageSize: image)
            }), "\(line)")
        }
    }

    func testWindowOriginsAlignTheLastWindowToTheFarEdge() {
        // The stride stops short of 580, so the last window starts there and ends exactly at 1000.
        expectNoDifference(Inspection.origins(total: 1000, size: 420), [0, 210, 420, 580])
    }

    func testWindowsReadTheFineScaleThenTheCoarseScaleRowMajor() {
        let windows = Inspection.windows(imageSize: CGSize(width: 600, height: 900), viewportHeight: 500)
        let fine = [0, 210, 420, 480].flatMap { originY in
            [0, 180].map { originX in
                Inspection.Window(rect: CGRect(x: originX, y: originY, width: 420, height: 420), scale: .fine)
            }
        }
        let coarse = [0, 250, 400].map { originY in
            Inspection.Window(rect: CGRect(x: 0, y: originY, width: 600, height: 500), scale: .coarse)
        }
        expectNoDifference(windows, fine + coarse)
    }

    func testInteriorAcceptanceKeepsTheMarginFromEveryInnerEdge() {
        let window = CGRect(x: 210, y: 420, width: 420, height: 420)
        let flush = CGRect(x: 218, y: 428, width: 404, height: 404)
        XCTAssertTrue(Inspection.isInterior(flush, in: window, imageSize: Self.imageSize))
        // Each crosses exactly one inner edge's margin by half a point.
        let crossing = [
            flush.offsetBy(dx: -0.5, dy: 0), flush.offsetBy(dx: 0.5, dy: 0),
            flush.offsetBy(dx: 0, dy: -0.5), flush.offsetBy(dx: 0, dy: 0.5)
        ]
        for frame in crossing {
            XCTAssertFalse(Inspection.isInterior(frame, in: window, imageSize: Self.imageSize), "\(frame)")
        }
    }

    func testInteriorAcceptanceExemptsEdgesOnTheImageBoundary() {
        let image = Self.imageSize
        let topLeft = CGRect(x: 0, y: 0, width: 420, height: 420)
        XCTAssertTrue(Inspection.isInterior(CGRect(x: 0, y: 0, width: 40, height: 20), in: topLeft, imageSize: image))
        // The same window's inner right edge still applies.
        XCTAssertFalse(
            Inspection.isInterior(CGRect(x: 380, y: 0, width: 40, height: 20), in: topLeft, imageSize: image)
        )
        let bottomRight = CGRect(x: 790, y: 1580, width: 420, height: 420)
        XCTAssertTrue(
            Inspection.isInterior(CGRect(x: 1170, y: 1980, width: 40, height: 20), in: bottomRight, imageSize: image)
        )
        // A far edge 0.4 pt short of the image's still lies on the boundary.
        let nearlyFlush = CGRect(x: 789.6, y: 1579.6, width: 420, height: 420)
        XCTAssertTrue(Inspection.isInterior(
            CGRect(x: 1169.6, y: 1979.6, width: 40, height: 20), in: nearlyFlush, imageSize: image
        ))
        // One 0.6 pt short is an inner edge, on the right and at the bottom alike.
        let short = CGRect(x: 789.4, y: 1579.4, width: 420, height: 420)
        XCTAssertFalse(
            Inspection.isInterior(CGRect(x: 1169.4, y: 1700, width: 40, height: 20), in: short, imageSize: image)
        )
        XCTAssertFalse(
            Inspection.isInterior(CGRect(x: 900, y: 1979.4, width: 40, height: 20), in: short, imageSize: image)
        )
    }

    func testMergeKeepsOneOccurrenceForOneLabelAtOneLocation() throws {
        let first = CGRect(x: 20, y: 300, width: 36, height: 20)
        let reads = [
            Self.read("VC3", first, in: Self.fineWindow),
            Self.read("VC3", CGRect(x: 21, y: 302, width: 35, height: 19), in: Self.topCoarseWindow)
        ]
        expectNoDifference(
            try Inspection.occurrences(of: reads, imageSize: Self.imageSize, words: Self.censusWords),
            [Inspection.Occurrence(label: "VC3", frame: first, readIndices: [0, 1])]
        )
    }

    func testMergeIgnoresReadsOutsideTheCensusOrNearAnInnerEdge() throws {
        let marker = CGRect(x: 21, y: 301, width: 35, height: 19)
        let reads = [
            Self.read("Public Author", CGRect(x: 20, y: 270, width: 120, height: 18), in: Self.topCoarseWindow),
            // A Cyrillic homoglyph of VH3 at the same location is not a census word, so it neither counts nor
            // conflicts.
            Self.read("V\u{041D}3", CGRect(x: 20, y: 300, width: 36, height: 20), in: Self.topCoarseWindow),
            // Within the margin of the fine window's inner right edge (412 pt).
            Self.read("VC1", CGRect(x: 380, y: 400, width: 36, height: 20), in: Self.fineWindow),
            Self.read("VH3", marker, in: Self.topCoarseWindow)
        ]
        expectNoDifference(
            try Inspection.occurrences(of: reads, imageSize: Self.imageSize, words: Self.censusWords),
            [Inspection.Occurrence(label: "VH3", frame: marker, readIndices: [3])]
        )
    }

    func testMergeThrowsWhenDifferentCensusWordsShareALocation() {
        let reads = [
            Self.read("VC7", CGRect(x: 20, y: 300, width: 36, height: 20), in: Self.fineWindow),
            Self.read("VC1", CGRect(x: 20, y: 301, width: 34, height: 20), in: Self.topCoarseWindow)
        ]
        XCTAssertThrowsError(
            try Inspection.occurrences(of: reads, imageSize: Self.imageSize, words: Self.censusWords)
        ) { error in
            guard case .ambiguousRenderedText(let description) = error as? FullContentHostError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(description.contains("VC7") && description.contains("VC1"), description)
        }
    }

    func testMergeCountsDistinctLocationsSeparately() throws {
        let first = CGRect(x: 20, y: 300, width: 36, height: 20)
        // Overlaps the first, but neither frame contains the other's center.
        let adjacent = CGRect(x: 20, y: 311, width: 36, height: 20)
        let other = CGRect(x: 20, y: 500, width: 36, height: 20)
        let far = CGRect(x: 20, y: 1300, width: 36, height: 20)
        let lowerCoarseWindow = Inspection.Window(
            rect: CGRect(x: 0, y: 834, width: 1210, height: 834), scale: .coarse
        )
        let reads = [
            Self.read("VC3", first, in: Self.topCoarseWindow),
            Self.read("VC3", adjacent, in: Self.topCoarseWindow),
            Self.read("VC4", other, in: Self.topCoarseWindow),
            Self.read("VC3", far, in: lowerCoarseWindow)
        ]
        expectNoDifference(
            try Inspection.occurrences(of: reads, imageSize: Self.imageSize, words: Self.censusWords),
            [
                Inspection.Occurrence(label: "VC3", frame: first, readIndices: [0]),
                Inspection.Occurrence(label: "VC3", frame: adjacent, readIndices: [1]),
                Inspection.Occurrence(label: "VC4", frame: other, readIndices: [2]),
                Inspection.Occurrence(label: "VC3", frame: far, readIndices: [3])
            ]
        )
    }

    /// A generated iPad-landscape comment list read end to end through Vision. Every marker counts once, and the
    /// census still notices a blanked marker and a duplicated row.
    @MainActor
    func testVisionCensusFindsEveryMarkerOnceAndNoticesOmissionAndDuplication() async throws {
        let markers = (1...12).map({ "VC\($0)" })
        let words = markers + [CommentCanvas.trailingMarker]
        let once = Dictionary(uniqueKeysWithValues: words.map({ ($0, 1) }))

        let complete = try await Self.census(of: CommentCanvas(markers: markers), words: words)
        expectNoDifference(complete, once)

        let blanked = try await Self.census(
            of: CommentCanvas(markers: markers.map({ $0 == "VC5" ? nil : $0 })), words: words
        )
        var withoutVC5 = once
        withoutVC5["VC5"] = 0
        expectNoDifference(blanked, withoutVC5)

        let duplicated = try await Self.census(
            of: CommentCanvas(markers: markers.flatMap({ $0 == "VC3" ? [$0, $0] : [$0] })), words: words
        )
        var twiceVC3 = once
        twiceVC3["VC3"] = 2
        expectNoDifference(duplicated, twiceVC3)
    }

    /// Native UI labels use their coordinate's language while public artwork markers remain Latin.
    @MainActor
    func testVisionRecognizesLocalizedTrailingLabelsAlongsideLatinMarkers() async throws {
        let labels = ["en": "Other", "de": "Sonstiges", "ja": "その他", "ko": "기타",
                      "zh-Hans": "其它", "zh-Hant": "其他"]
        for identifier in labels.keys.sorted() {
            let label = try XCTUnwrap(labels[identifier])
            let rendered = try Self.localizedCanvas(label: label)
            let attachment = XCTAttachment(image: rendered)
            attachment.name = "localized-census-\(identifier)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let reads = try await Self.localizedReads(rendered, label: label, language: identifier)
            let markers = try Inspection.occurrences(of: reads, imageSize: rendered.size, words: ["VH1"])
            let headings = try Inspection.occurrences(
                of: reads, imageSize: rendered.size, words: [label], pass: .trailingMarker
            )
            expectNoDifference(markers.map(\.label), ["VH1"], "\(identifier): fixture pass")
            expectNoDifference(headings.map(\.label), [label], "\(identifier): trailing pass")
            _ = try Inspection.trailingMarkerFrame(
                label, occurrences: headings, imageSize: rendered.size,
                requiredHeight: rendered.size.height, scale: rendered.scale
            )
        }
    }

    func testPassAcceptanceKeepsMarkerConfidenceAndSeparatesLanguages() throws {
        let frame = CGRect(x: 20, y: 300, width: 36, height: 20)
        let reads = [
            Self.read("VC1", frame, in: Self.fineWindow, confidence: 0.5),
            Self.read("VC3", frame, in: Self.fineWindow, confidence: 0.8),
            Self.read("VC7", frame, in: Self.fineWindow, pass: .trailingMarker),
            Self.read("其他", frame, in: Self.fineWindow, confidence: 0.3, pass: .trailingMarker),
            Self.read("其他", frame, in: Self.fineWindow)
        ]
        expectNoDifference(
            try Inspection.occurrences(of: reads, imageSize: Self.imageSize, words: Self.censusWords),
            [Inspection.Occurrence(label: "VC3", frame: frame, readIndices: [1])]
        )
        expectNoDifference(
            try Inspection.occurrences(of: reads, imageSize: Self.imageSize, words: ["其他"], pass: .trailingMarker),
            [Inspection.Occurrence(label: "其他", frame: frame, readIndices: [3])]
        )
    }

    @MainActor
    func testCJKPassesStillRejectMissingHeadingAndCountDuplicateMarkers() async throws {
        let blanked = try Self.localizedCanvas(label: "其他", includeHeading: false)
        let blankedReads = try await Self.localizedReads(blanked, label: "其他", language: "zh-Hant")
        let blankedHeadings = try Inspection.occurrences(
            of: blankedReads, imageSize: blanked.size, words: ["其他"], pass: .trailingMarker
        )
        XCTAssertThrowsError(try Inspection.trailingMarkerFrame(
            "其他", occurrences: blankedHeadings, imageSize: blanked.size,
            requiredHeight: blanked.size.height, scale: blanked.scale
        )) { error in
            guard case .missingTrailingMarker(let label) = error as? FullContentHostError else {
                return XCTFail("Unexpected error: \(error)")
            }
            expectNoDifference(label, "其他")
        }
        let remainingMarkers = try Inspection.occurrences(of: blankedReads, imageSize: blanked.size, words: ["VH1"])
        expectNoDifference(remainingMarkers.map(\.label), ["VH1"])

        let duplicated = try Self.localizedCanvas(label: "其他", duplicateMarker: true)
        let duplicatedReads = try await Self.localizedReads(duplicated, label: "其他", language: "zh-Hant")
        let markers = try Inspection.occurrences(of: duplicatedReads, imageSize: duplicated.size, words: ["VH1"])
        expectNoDifference(markers.map(\.label), ["VH1", "VH1"])
        let headings = try Inspection.occurrences(
            of: duplicatedReads, imageSize: duplicated.size, words: ["其他"], pass: .trailingMarker
        )
        expectNoDifference(headings.map(\.label), ["其他"])
    }

    func testTrailingMarkerRequiresContainedFrameAndCompleteContentHeight() throws {
        let size = CGSize(width: 420, height: 420)
        let frame = CGRect(x: 20, y: 300, width: 40, height: 20)
        let occurrence = Inspection.Occurrence(label: "其他", frame: frame, readIndices: [0])
        expectNoDifference(try Inspection.trailingMarkerFrame(
            "其他", occurrences: [occurrence], imageSize: size, requiredHeight: 420, scale: 3
        ), frame)
        for outside in [frame.offsetBy(dx: 410, dy: 0), CGRect(x: 20, y: 300, width: 40, height: 0)] {
            XCTAssertThrowsError(try Inspection.trailingMarkerFrame(
                "其他", occurrences: [.init(label: "其他", frame: outside, readIndices: [0])],
                imageSize: size, requiredHeight: 420, scale: 3
            ))
        }
        XCTAssertThrowsError(try Inspection.trailingMarkerFrame(
            "其他", occurrences: [occurrence], imageSize: size, requiredHeight: 421, scale: 3
        ))
    }

    private static func read(
        _ label: String, _ frame: CGRect, in window: Inspection.Window,
        confidence: Float = 1, pass: Inspection.Pass = .fixtureMarkers
    ) -> Inspection.Read {
        Inspection.Read(label: label, confidence: confidence, frame: frame, window: window, pass: pass)
    }

    @MainActor
    private static func localizedCanvas(
        label: String, includeHeading: Bool = true, duplicateMarker: Bool = false
    ) throws -> UIImage {
        let size = CGSize(width: 420, height: duplicateMarker ? 840 : 420)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let artwork = PublicVisualFixtures.artwork(marker: "VH1", colorIndex: 0)
        let titleFont = UIFont.preferredFont(forTextStyle: .title3)
        let boldDescriptor = try XCTUnwrap(titleFont.fontDescriptor.withSymbolicTraits(.traitBold))
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            artwork.draw(in: CGRect(x: 40, y: 24, width: 160, height: 220))
            if duplicateMarker {
                artwork.draw(in: CGRect(x: 40, y: 444, width: 160, height: 220))
            }
            if includeHeading {
                (label as NSString).draw(
                    at: CGPoint(x: 40, y: size.height - 120),
                    withAttributes: [.font: UIFont(descriptor: boldDescriptor, size: 0),
                                     .foregroundColor: UIColor.black]
                )
            }
        }
    }

    private static func localizedReads(
        _ image: UIImage, label: String, language: String
    ) async throws -> [Inspection.Read] {
        try await Inspection.reads(
            in: XCTUnwrap(image.cgImage), imageSize: image.size,
            windows: Inspection.windows(imageSize: image.size, viewportHeight: 420),
            markerWords: ["VH1"], trailingMarker: label, trailingMarkerLanguage: Locale.Language(identifier: language)
        )
    }

    /// The census exactly as the capture host computes it, keyed by marker.
    private static func census(of canvas: CommentCanvas, words: [String]) async throws -> [String: Int] {
        let windows = Inspection.windows(imageSize: canvas.size, viewportHeight: CommentCanvas.viewportHeight)
        let reads = try await Inspection.reads(
            in: canvas.image, imageSize: canvas.size, windows: windows,
            markerWords: words.filter({ $0 != CommentCanvas.trailingMarker }),
            trailingMarker: CommentCanvas.trailingMarker
        )
        let occurrences = try Inspection.occurrences(
            of: reads, imageSize: canvas.size, words: Set(words.filter({ $0 != CommentCanvas.trailingMarker }))
        ) + Inspection.occurrences(
            of: reads, imageSize: canvas.size, words: [CommentCanvas.trailingMarker], pass: .trailingMarker
        )
        return Dictionary(uniqueKeysWithValues: words.map { word in
            (word, occurrences.filter({ $0.label == word }).count)
        })
    }
}

/// An iPad-landscape-like comment list drawn at 2x: each row has an author line, a marker line in the 17 pt system
/// font (the body size whose markers iPad viewport bands lost) and a long body line, and a trailing marker ends it.
/// Twelve rows make it 2000 pt tall.
private struct CommentCanvas {
    static let viewportHeight: CGFloat = 834
    static let trailingMarker = "VCEND"
    private static let width: CGFloat = 1210
    private static let inset: CGFloat = 20
    private static let rowHeight: CGFloat = 160
    private static let footerHeight: CGFloat = 60
    private static let body = "Every rendered row carries a long body line, so each census window also reads "
        + "ordinary paragraph text at the body size."

    let image: CGImage
    let size: CGSize

    /// A `nil` marker blanks that row's marker line and keeps the rest of the row.
    @MainActor
    init(markers: [String?]) throws {
        let size = CGSize(
            width: Self.width, height: Self.inset + CGFloat(markers.count) * Self.rowHeight + Self.footerHeight
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (row, marker) in markers.enumerated() {
                let top = Self.inset + CGFloat(row) * Self.rowHeight
                Self.draw("Public Author", pointSize: 15, color: .darkGray, at: CGPoint(x: Self.inset, y: top + 16))
                if let marker {
                    Self.draw(marker, pointSize: 17, color: .black, at: CGPoint(x: Self.inset, y: top + 48))
                }
                Self.draw(Self.body, pointSize: 17, color: .black, at: CGPoint(x: Self.inset, y: top + 82))
            }
            Self.draw(
                Self.trailingMarker, pointSize: 17, color: .black,
                at: CGPoint(x: Self.inset, y: size.height - Self.footerHeight + 16)
            )
        }
        image = try XCTUnwrap(rendered.cgImage)
        self.size = size
    }

    @MainActor
    private static func draw(_ text: String, pointSize: CGFloat, color: UIColor, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: pointSize), .foregroundColor: color
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: point)
    }
}
