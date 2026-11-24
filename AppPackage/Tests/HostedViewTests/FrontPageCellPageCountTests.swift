import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
@testable import HomeFeature
import Resources
import Sharing
import SwiftUI
import Testing
import UIKit

/// A Front Page cell keeps its page count and its language whole and on its leading edge at every Dynamic Type size
/// (19-31).
///
/// The cell used to be exactly as wide as its cover. The cover's scale stops at `GalleryCoverStyle.maximumScale`
/// while the text keeps growing, so from `.accessibility4` up a page count was wider than the cell, wrapped after
/// its number ("26" / "Seiten", and inside the unit in Japanese), and the `Button` centred the wrapped lines. The owner
/// chose a wider column over a broken field (2026-11-25). These tests host the real wall (`ScrollView`,
/// `HomeFrontPageWall`, `Button`, `HomeFrontPageCell`), read each cell's accessibility frame and its picture, and check
/// that the cell is exactly as wide as the widest of its cover and its fields' one-line widths, that the fields are one
/// line each and start on the cell's leading edge, that the cover keeps its size, and that no ink reaches the next
/// column.
@MainActor
struct FrontPageCellPageCountTests {
    /// A size class with a Dynamic Type size, one argument of the test.
    struct TextEnvironment: Sendable {
        let sizeClass: UserInterfaceSizeClass
        let size: DynamicTypeSize

        static let all: [TextEnvironment] = [UserInterfaceSizeClass.regular, .compact].flatMap { sizeClass in
            DynamicTypeSize.allCases.map({ TextEnvironment(sizeClass: sizeClass, size: $0) })
        }
    }

    private struct Scenario {
        let identifier: String
        let sizeClass: UserInterfaceSizeClass
        let size: DynamicTypeSize

        var name: String { "\(identifier) \(sizeClass == .regular ? "regular" : "compact") \(size)" }
    }

    private struct Cell {
        let galleryID: String
        let frame: CGRect
    }

    private struct Measures {
        var pageWidths = [Int: CGFloat]()
        var languageWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var titleHeight: CGFloat = 0
        var coverSize = CGSize.zero
    }

    private struct Expectation {
        let column: Int
        let hasLanguage: Bool
        let measures: Measures
    }

    private struct Ink {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let scale: CGFloat

        /// The horizontal extent in points of each run of text lines in `region`, top to bottom, where a line is a
        /// run of pixel rows with a pixel darker than `threshold`.
        func lines(in region: CGRect, threshold: Int) -> [ClosedRange<CGFloat>] {
            var result = [ClosedRange<CGFloat>]()
            var current: ClosedRange<CGFloat>?
            for row in Self.rows(of: region.minY * scale, region.maxY * scale, limit: height) {
                if let span = span(row: row, region: region, threshold: threshold) {
                    current = current.map({ min($0.lowerBound, span.lowerBound)...max($0.upperBound, span.upperBound) })
                        ?? span
                } else if let finished = current {
                    result.append(finished)
                    current = nil
                }
            }
            if let finished = current { result.append(finished) }
            return result
        }

        /// The bounding box in points of every pixel darker than `threshold` in `region`.
        func bounds(in region: CGRect, threshold: Int) -> CGRect {
            var box = CGRect.null
            for row in Self.rows(of: region.minY * scale, region.maxY * scale, limit: height) {
                guard let span = span(row: row, region: region, threshold: threshold) else { continue }
                let rowBox = CGRect(
                    x: span.lowerBound, y: CGFloat(row) / scale, width: span.upperBound - span.lowerBound,
                    height: 1 / scale
                )
                box = box.union(rowBox)
            }
            return box
        }

        private static func rows(of top: CGFloat, _ bottom: CGFloat, limit: Int) -> Range<Int> {
            let first = max(0, Int(top.rounded(.down)))
            let last = min(limit, Int(bottom.rounded(.up)))
            return first..<max(first, last)
        }

        private func span(row: Int, region: CGRect, threshold: Int) -> ClosedRange<CGFloat>? {
            let first = max(0, Int((region.minX * scale).rounded(.down)))
            let last = min(width, Int((region.maxX * scale).rounded(.up)))
            guard first < last else { return nil }
            let dark = (first..<last).filter { column in
                let index = (row * width + column) * 4
                return (Int(pixels[index]) + Int(pixels[index + 1]) + Int(pixels[index + 2])) / 3 < threshold
            }
            guard let leading = dark.first, let trailing = dark.last else { return nil }
            return (CGFloat(leading) / scale)...(CGFloat(trailing + 1) / scale)
        }
    }

    private static let titlePrefix = "home_front_page_title_"
    private static let probeIdentifier = "cover_probe"
    private static let titleProbeIdentifier = "title_probe"
    private static let cellSpacing: CGFloat = 10
    private static let counts = Array(24...29)
    private static let columnSpacing: CGFloat = 20
    private static let lineSpacing: CGFloat = 4
    private static let window = CGSize(width: 1400, height: 1800)
    /// A glyph starts inside its frame by its own side bearing: about 2 pt for Latin, and for a kana up to about a
    /// quarter of the line's height (9.5 pt at `.accessibility4`). A centred second line starts 30 pt or more in.
    private static func leadingTolerance(lineHeight: CGFloat) -> CGFloat { max(4, 0.3 * lineHeight) }

    @Test(arguments: ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"], TextEnvironment.all)
    func everyCellKeepsItsFieldsWholeAndOnItsLeadingEdge(identifier: String, environment: TextEnvironment) throws {
        let scenario = Scenario(identifier: identifier, sizeClass: environment.sizeClass, size: environment.size)
        let measures = try Self.measures(scenario)
        let wall = Self.wall(scenario)
        let cells = try Self.cells(of: wall)
        let ink = try Self.ink(of: wall)
        try #require(cells.count == 2 * Self.counts.count, "\(scenario.name): found \(cells.map(\.galleryID)).")
        for (column, count) in Self.counts.enumerated() {
            for hasLanguage in [false, true] {
                let galleryID = "\(hasLanguage ? "B" : "T")\(count)"
                let cell = try #require(cells.first(where: { $0.galleryID == galleryID }))
                let next = cells.first(where: { $0.galleryID == "\(hasLanguage ? "B" : "T")\(count + 1)" })
                try Self.check(
                    cell, next: next, scenario: scenario,
                    expectation: Expectation(column: column, hasLanguage: hasLanguage, measures: measures), ink: ink
                )
            }
        }
    }

    // MARK: Checks

    private static func check(
        _ cell: Cell, next: Cell?, scenario: Scenario, expectation: Expectation, ink: Ink
    ) throws {
        let measures = expectation.measures
        let name = "\(scenario.name) \(cell.galleryID)"
        let pageWidth = try #require(measures.pageWidths[counts[expectation.column]])
        let languageWidth = expectation.hasLanguage ? measures.languageWidth : 0
        let expectedWidth = max(measures.coverSize.width, pageWidth, languageWidth)
        #expect(
            cell.frame.width >= expectedWidth - 0.01 && cell.frame.width <= expectedWidth + 0.5,
            "\(name): the cell is \(cell.frame.width) pt wide, the widest of its cover and fields is \(expectedWidth)."
        )
        let sharesLine = expectation.hasLanguage && pageWidth + 8 + languageWidth <= cell.frame.width + 0.01
        let lineCount = expectation.hasLanguage && !sharesLine ? 2 : 1
        let blockHeight = CGFloat(lineCount) * measures.lineHeight + CGFloat(lineCount - 1) * lineSpacing
        let block = CGRect(
            x: cell.frame.minX - 15, y: cell.frame.maxY - blockHeight - 1,
            width: cell.frame.width + 30, height: blockHeight + 2
        )
        // The cover, the title (two lines are reserved), the fields and the 10 pt between them: one more line anywhere,
        // such as a field that wrapped, makes the cell taller.
        let expectedHeight = measures.coverSize.height + measures.titleHeight + blockHeight + 2 * cellSpacing
        #expect(
            abs(cell.frame.height - expectedHeight) <= 1,
            "\(name): the cell is \(cell.frame.height) tall, expected \(expectedHeight) with \(lineCount) field lines."
        )
        let lines = ink.lines(in: block, threshold: 215)
        #expect(lines.count == lineCount, "\(name): the fields are \(lines.count) lines, expected \(lineCount).")
        for line in lines {
            let offset = line.lowerBound - cell.frame.minX
            #expect(
                offset >= -1 && offset <= leadingTolerance(lineHeight: measures.lineHeight),
                "\(name): a field line starts \(offset) pt from the cell's leading edge."
            )
            #expect(
                line.upperBound <= cell.frame.maxX + 0.5,
                "\(name): a field line ends at \(line.upperBound), past the cell's trailing edge \(cell.frame.maxX)."
            )
        }
        if let next, let trailing = lines.map(\.upperBound).max() {
            #expect(
                trailing + columnSpacing <= next.frame.minX + 0.5,
                "\(name): ink reaches \(trailing), within \(columnSpacing) pt of the next column at \(next.frame.minX)."
            )
        }
        try checkCover(of: cell, measures: measures, ink: ink, name: name)
    }

    private static func checkCover(of cell: Cell, measures: Measures, ink: Ink, name: String) throws {
        let expected = measures.coverSize
        let region = CGRect(
            x: cell.frame.minX - 2, y: cell.frame.minY - 2, width: cell.frame.width + 4, height: expected.height + 7
        )
        let cover = ink.bounds(in: region, threshold: 250)
        let pixel = 1 / ink.scale + 0.01
        #expect(
            abs(cover.width - expected.width) <= pixel,
            "\(name): the cover is \(cover.width) pt wide, not \(expected.width)."
        )
        #expect(
            abs(cover.height - expected.height) <= pixel,
            "\(name): the cover is \(cover.height) pt tall, not \(expected.height)."
        )
        #expect(
            abs(cover.minX - cell.frame.minX) <= pixel,
            "\(name): the cover starts \(cover.minX - cell.frame.minX) pt in."
        )
    }

    // MARK: Hosting

    private static func styled(_ view: some View, _ scenario: Scenario) -> AnyView {
        AnyView(
            view
                .environment(\.dynamicTypeSize, scenario.size)
                .environment(\.locale, Locale(identifier: scenario.identifier))
                .environment(\.horizontalSizeClass, scenario.sizeClass)
                .environment(\.colorScheme, .light)
        )
    }

    private static func gallery(identifier: String, pages: Int, hasLanguage: Bool) -> Gallery {
        let content = GalleryTag.Content(rawNamespace: "language", text: "german", isVotedUp: false, isVotedDown: false)
        return Gallery(
            gid: identifier, token: "a", title: "Visual Home Gallery \(identifier)", rating: 4.5,
            tags: hasLanguage ? [GalleryTag(rawNamespace: "language", contents: [content])] : [],
            category: .doujinshi, uploader: "Visual Fixture", pageCount: pages,
            postedDate: Date(timeIntervalSince1970: 1_700_000_000), coverURL: nil, galleryURL: nil
        )
    }

    /// The real chain of the Home screen: two galleries a column, the lower one with a language.
    private static func wall(_ scenario: Scenario) -> AnyView {
        let columns: [[Gallery]] = counts.map { count in
            [gallery(identifier: "T\(count)", pages: count, hasLanguage: false),
             gallery(identifier: "B\(count)", pages: count, hasLanguage: true)]
        }
        return withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            styled(
                ScrollView(.horizontal) {
                    HomeFrontPageWall(columns: columns, maximumCoverHeight: nil, navigateAction: { _ in })
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .background(Color.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                scenario
            )
        }
    }

    private static func cells(of wall: AnyView) throws -> [Cell] {
        try AccessibilityElements.read(of: wall, size: window) { elements in
            var seen = Set<String>()
            var cells = [Cell]()
            for element in elements {
                guard let identifier = AccessibilityElements.identifier(of: element),
                      identifier.hasPrefix(titlePrefix)
                else { continue }
                let galleryID = identifier.replacingOccurrences(of: titlePrefix, with: "")
                guard seen.insert(galleryID).inserted else { continue }
                cells.append(Cell(galleryID: galleryID, frame: element.accessibilityFrame))
            }
            return cells
        }
    }

    private static func ink(of wall: AnyView) throws -> Ink {
        let picture = try HostedView.withRoot(of: wall, size: window) { root in
            UIGraphicsImageRenderer(bounds: root.bounds).image { _ in
                root.drawHierarchy(in: root.bounds, afterScreenUpdates: true)
            }
        }
        let image = try #require(picture.cgImage)
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Ink(pixels: data, width: image.width, height: image.height, scale: CGFloat(image.width) / window.width)
    }

    // MARK: Measures

    /// The fields' one-line widths, one caption line's height and the cover's size, in the scenario's environment.
    private static func measures(_ scenario: Scenario) throws -> Measures {
        let content = styled(
            VStack(alignment: .leading, spacing: 0) {
                ForEach(counts, id: \.self) { count in
                    Text(.RLocalizable.pages(count: count)).font(.caption).fixedSize()
                }
                Text(Language.german.value).font(.caption).fixedSize()
                Text(verbatim: "One line").font(.caption).fixedSize()
                CoverProbe(style: scenario.sizeClass == .regular ? .homeFrontPage : .homeCompact)
                Text(verbatim: "Title\nTitle")
                    .font(scenario.sizeClass == .regular ? .subheadline.bold() : .footnote.bold())
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(titleProbeIdentifier)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            scenario
        )
        let german = localized(Language.german.value, scenario.identifier)
        var result = Measures()
        try AccessibilityElements.read(of: content, size: window) { elements in
            for element in elements {
                let frame = element.accessibilityFrame
                if AccessibilityElements.identifier(of: element) == probeIdentifier { result.coverSize = frame.size }
                if AccessibilityElements.identifier(of: element) == titleProbeIdentifier {
                    result.titleHeight = frame.height
                }
                guard let label = element.accessibilityLabel, !label.isEmpty else { continue }
                if label == "One line" { result.lineHeight = frame.height }
                if label == german { result.languageWidth = frame.width }
                for count in counts where label.contains("\(count)") { result.pageWidths[count] = frame.width }
            }
        }
        try #require(result.coverSize.width > 0 && result.lineHeight > 0, "\(scenario.name): nothing was measured.")
        return result
    }

    private static func localized(_ resource: LocalizedStringResource, _ identifier: String) -> String {
        var localized = resource
        localized.locale = Locale(identifier: identifier)
        return String(localized: localized)
    }

    /// An empty view of exactly the cover's size at the environment's Dynamic Type size, as an accessibility element.
    private struct CoverProbe: View {
        @GalleryCoverMetrics private var size: CGSize

        init(style: GalleryCoverStyle) {
            _size = GalleryCoverMetrics(style)
        }

        var body: some View {
            Color.clear
                .frame(width: size.width, height: size.height)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(FrontPageCellPageCountTests.probeIdentifier)
        }
    }
}
