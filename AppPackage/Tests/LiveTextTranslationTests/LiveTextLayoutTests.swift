import AppModels
import CoreGraphics
import Foundation
@testable import LiveTextTranslation
import Testing

// A translation replaces its lettering: the region its lines fill, turned with them, painted in its
// surroundings' color or as a white plate, and set at the page's one size or 85% of it.
struct LiveTextLayoutTests {
    private static let pageSize = CGSize(width: 1000, height: 2000)

    /// A group of `lines` level lines, each `lineHeight` pixels tall and 400 wide, turned by `degrees`
    /// about the first line's top-left corner at `origin`.
    private static func group(
        origin: CGPoint = CGPoint(x: 100, y: 400),
        lines: Int = 1,
        lineHeight: Double = 50,
        degrees: Double = 0
    ) throws -> LiveTextGroup {
        let angle = degrees * .pi / 180
        func turned(_ across: Double, _ down: Double) -> CGPoint {
            CGPoint(
                x: (origin.x + across * cos(angle) - down * sin(angle)) / pageSize.width,
                y: (origin.y + across * sin(angle) + down * cos(angle)) / pageSize.height
            )
        }
        let blocks = (0..<lines).map { line in
            let top = Double(line) * lineHeight * 1.2
            return LiveTextBlock(
                text: "line \(line)",
                bounds: LiveTextBounds(
                    topLeft: turned(0, top),
                    topRight: turned(400, top),
                    bottomLeft: turned(0, top + lineHeight),
                    bottomRight: turned(400, top + lineHeight)
                )
            )
        }
        return try #require(LiveTextGroup(blocks: blocks))
    }

    /// A white page, with `draw` painting on it in page pixels, y down.
    private static func page(
        size: CGSize = pageSize,
        _ draw: (CGContext) -> Void = { _ in }
    ) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        draw(context)
        return try #require(context.makeImage())
    }

    // MARK: Geometry

    @Test
    func aLevelGroupFillsItsLines() throws {
        let group = try Self.group(lines: 2)
        let geometry = try #require(LiveTextGroupGeometry(group: group, pageSize: Self.pageSize))

        #expect(abs(geometry.textRect.angle) < 1e-9)
        #expect(abs(geometry.textRect.center.x - 300) < 1e-6)
        #expect(abs(geometry.textRect.center.y - 455) < 1e-6)
        #expect(abs(geometry.textRect.size.width - 400) < 1e-6)
        #expect(abs(geometry.textRect.size.height - 110) < 1e-6)
        #expect(abs(geometry.lineHeight - 50) < 1e-6)
    }

    @Test(arguments: [-40.0, -12.0, 20.0, 44.0])
    func aTurnedGroupKeepsItsTurn(degrees: Double) throws {
        let group = try Self.group(degrees: degrees)
        let geometry = try #require(LiveTextGroupGeometry(group: group, pageSize: Self.pageSize))

        #expect(abs(geometry.textRect.angle - degrees * .pi / 180) < 1e-9)
        #expect(abs(geometry.textRect.size.width - 400) < 1e-6)
        #expect(abs(geometry.textRect.size.height - 50) < 1e-6)
    }

    @Test(arguments: [60.0, 90.0, -80.0])
    func steepLetteringIsLaidOutLevel(degrees: Double) throws {
        let group = try Self.group(degrees: degrees)
        let geometry = try #require(LiveTextGroupGeometry(group: group, pageSize: Self.pageSize))

        #expect(geometry.textRect.angle == 0)
        let width = (group.maxX - group.minX) * Self.pageSize.width
        let height = (group.maxY - group.minY) * Self.pageSize.height
        #expect(abs(geometry.textRect.size.width - width) < 1e-6)
        #expect(abs(geometry.textRect.size.height - height) < 1e-6)
    }

    // MARK: Fill

    private static let plate = LiveTextOrientedRect(
        center: CGPoint(x: 500, y: 1000),
        size: CGSize(width: 300, height: 120),
        angle: 0
    )

    private static func fill(on image: CGImage) throws -> LiveTextFill {
        let bitmap = try #require(LiveTextPageBitmap(image: image))
        return LiveTextPlateSampler.fill(around: Self.plate, lineHeight: 50, on: bitmap)
    }

    @Test
    func aWhiteBalloonStaysWhiteWithBlackText() throws {
        let image = try Self.page { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 380, y: 960, width: 240, height: 80))
        }

        #expect(try Self.fill(on: image) == .background(.white, text: .black))
    }

    @Test
    func aTailCrossingTheSurroundingsKeepsTheBalloonsColor() throws {
        let image = try Self.page { context in
            context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.setLineWidth(6)
            context.move(to: CGPoint(x: 250, y: 1100))
            context.addLine(to: CGPoint(x: 750, y: 900))
            context.strokePath()
        }

        #expect(try Self.fill(on: image) == .background(.white, text: .black))
    }

    @Test
    func aDarkCaptionBoxKeepsItsColorWithWhiteText() throws {
        let image = try Self.page { context in
            context.setFillColor(CGColor(srgbRed: 0.1, green: 0.2, blue: 0.5, alpha: 1))
            context.fill(CGRect(x: 200, y: 800, width: 600, height: 400))
        }

        guard case .background(let color, let text) = try Self.fill(on: image) else {
            Issue.record("A one-color box is painted in its color.")
            return
        }
        #expect(color.distance(to: LiveTextColor(red: 0.1, green: 0.2, blue: 0.5)) < 0.01)
        #expect(text == .white)
    }

    @Test
    func aCaptionBoxJustLargerThanItsLetteringKeepsItsColor() throws {
        // The ring just beyond the plate lies inside the box; the one further out does not.
        let image = try Self.page { context in
            context.setFillColor(CGColor(srgbRed: 1, green: 0.93, blue: 0.6, alpha: 1))
            context.fill(CGRect(x: 336, y: 926, width: 328, height: 148))
        }

        guard case .background(let color, let text) = try Self.fill(on: image) else {
            Issue.record("A box one color just beyond the plate is painted in its color.")
            return
        }
        #expect(color.distance(to: LiveTextColor(red: 1, green: 0.93, blue: 0.6)) < 0.01)
        #expect(text == .black)
    }

    @Test
    func busyArtGetsAPlate() throws {
        let image = try Self.page { context in
            for stripe in 0..<100 {
                let shade = stripe.isMultiple(of: 2) ? 0.0 : 1.0
                context.setFillColor(CGColor(srgbRed: shade, green: 0.5, blue: 1 - shade, alpha: 1))
                context.fill(CGRect(x: Double(stripe) * 10, y: 0, width: 10, height: 2000))
            }
        }

        #expect(try Self.fill(on: image) == .plate)
    }

    @Test
    func aRegionMostlyOffThePageGetsAPlate() throws {
        let image = try Self.page()
        let bitmap = try #require(LiveTextPageBitmap(image: image))
        let plate = LiveTextOrientedRect(
            center: CGPoint(x: -400, y: 1000),
            size: CGSize(width: 300, height: 40),
            angle: 0
        )

        #expect(LiveTextPlateSampler.fill(around: plate, lineHeight: 10, on: bitmap) == .plate)
    }

    // MARK: Text

    private static let english = LiveTextTextStyle(language: .init(identifier: "en"))
    private static let japanese = LiveTextTextStyle(language: .init(identifier: "ja"))

    @Test
    func textWrapsWithinItsWidth() {
        let layout = LiveTextTextLayout(
            text: "Where do you think you are going? I told you to stay here!",
            style: Self.english,
            fontSize: 20,
            width: 160
        )

        #expect(layout.lines.count > 1)
        #expect(layout.lines.allSatisfy({ $0.width <= 160 }))
        #expect(!layout.breaksWord)
        #expect(!layout.isTruncated)
    }

    @Test
    func aWordWiderThanTheLineBreaksIt() {
        let layout = LiveTextTextLayout(
            text: "Donaudampfschifffahrtsgesellschaft",
            style: LiveTextTextStyle(language: .init(identifier: "de")),
            fontSize: 20,
            width: 120
        )

        #expect(layout.breaksWord)
    }

    @Test
    func unspacedTextBreaksBetweenCharacters() {
        let layout = LiveTextTextLayout(
            text: "どこに行くと思うの？ここにいてって言ったでしょ！",
            style: Self.japanese,
            fontSize: 20,
            width: 100
        )

        #expect(layout.lines.count > 1)
        #expect(!layout.breaksWord)
    }

    @Test
    func textBeyondItsHeightEndsInAnEllipsis() {
        let layout = LiveTextTextLayout(
            text: "Where do you think you are going? I told you to stay here!",
            style: Self.english,
            fontSize: 20,
            width: 160,
            maximumHeight: 30
        )

        #expect(layout.isTruncated)
        #expect(layout.lines.count == 1)
        #expect(layout.height <= 30)
    }

    @Test
    func aBalancedWidthKeepsTheLinesAndEvensThem() throws {
        let text = "Where do you think you are going?"
        let oneLine = LiveTextTextLayout(text: text, style: Self.english, fontSize: 30, width: 10_000)
        let width = try #require(oneLine.lines.first).width * 0.85
        let greedy = LiveTextTextLayout(text: text, style: Self.english, fontSize: 30, width: width)
        let balancedWidth = LiveTextTextLayout.balancedWidth(of: text, style: Self.english, fontSize: 30, width: width)
        let balanced = LiveTextTextLayout(text: text, style: Self.english, fontSize: 30, width: balancedWidth)
        func spread(_ layout: LiveTextTextLayout) -> Double {
            let widths = layout.lines.map(\.width)
            return (widths.max() ?? 0) - (widths.min() ?? 0)
        }

        #expect(greedy.lines.count == 2)
        #expect(balanced.lines.count == 2)
        #expect(balancedWidth < width * 0.7)
        #expect(spread(balanced) < spread(greedy) / 2)
    }

    @Test
    func aBalancedWidthNeverBreaksAWord() throws {
        let style = LiveTextTextStyle(language: .init(identifier: "de"))
        let word = "Donaudampfschifffahrtsgesellschaft"
        let oneLine = LiveTextTextLayout(text: word, style: style, fontSize: 20, width: 10_000)
        let wordWidth = try #require(oneLine.lines.first).width
        let text = word + " ahoi"

        let balancedWidth = LiveTextTextLayout.balancedWidth(
            of: text,
            style: style,
            fontSize: 20,
            width: wordWidth * 1.05
        )
        let balanced = LiveTextTextLayout(text: text, style: style, fontSize: 20, width: balancedWidth)

        #expect(balancedWidth > wordWidth)
        #expect(balanced.lines.count == 2)
        #expect(abs(try #require(balanced.lines.first).width - wordWidth) < 0.01)
        #expect(!balanced.breaksWord)
    }

    @Test
    func aSingleLineKeepsItsWidth() {
        #expect(LiveTextTextLayout.balancedWidth(of: "Hi!", style: Self.english, fontSize: 20, width: 400) == 400)
    }

    // MARK: Fitting

    private static func region(_ text: String, width: Double, height: Double) -> LiveTextTextFitter.Region {
        LiveTextTextFitter.Region(id: UUID(), text: text, area: CGSize(width: width, height: height), lineHeight: 40)
    }

    /// The size of the lettering the fitting regions replace, 40 pixels tall.
    private static var letteringSize: Double {
        40 / english.lineHeightRatio
    }

    @Test
    func roomyTextKeepsTheLetteringsSize() {
        let regions = [Self.region("Hi!", width: 400, height: 200)]

        let result = LiveTextTextFitter.fit(regions, style: Self.english, pageWidth: 1000)

        #expect(abs(result.fontSize - Self.letteringSize) < 1e-9)
        #expect(result.placements.map(\.fontSize) == [result.fontSize])
    }

    @Test
    func everyTranslationIsSetAtThePagesSizeOrEightyFivePercentOfIt() {
        let regions = [
            Self.region("Where do you think you are going?", width: 300, height: 120),
            Self.region("I told you to stay here, didn't I? Why don't you ever listen?", width: 260, height: 110),
            Self.region("Wait!", width: 160, height: 60),
            Self.region("We need to talk about what happened yesterday at the station.", width: 220, height: 160)
        ]

        let result = LiveTextTextFitter.fit(regions, style: Self.english, pageWidth: 1000)

        #expect(result.fontSize <= Self.letteringSize)
        #expect(result.fontSize >= 1000 * LiveTextTextFitter.floorShare)
        for placement in result.placements {
            let isPageSize = abs(placement.fontSize - result.fontSize) < 1e-9
            let isReduced = abs(placement.fontSize - result.fontSize * LiveTextTextFitter.reducedScale) < 1e-9
            #expect(isPageSize || isReduced)
        }
    }

    @Test
    func aHopelessTranslationDoesNotHoldThePageDown() throws {
        let roomy = Self.region("Hi!", width: 400, height: 200)
        let text = String(repeating: "Far too much text for this tiny balloon. ", count: 20)
        let hopeless = Self.region(text, width: 60, height: 30)

        let result = LiveTextTextFitter.fit([roomy, hopeless], style: Self.english, pageWidth: 1000)

        #expect(abs(result.fontSize - Self.letteringSize) < 1e-9)
        let placement = try #require(result.placements.first(where: { $0.id == hopeless.id }))
        #expect(placement.isGrown)
        #expect(abs(placement.fontSize - result.fontSize * LiveTextTextFitter.reducedScale) < 1e-9)
    }

    @Test
    func aTightTranslationsStepFitsItsArea() throws {
        let roomy = Self.region("Hi!", width: 400, height: 200)
        let tight = Self.region("Where do you think you are going?", width: 300, height: 40)

        let result = LiveTextTextFitter.fit([roomy, tight], style: Self.english, pageWidth: 1000)
        let placement = try #require(result.placements.first(where: { $0.id == tight.id }))
        let area = placement.isGrown ? CGSize(width: 375, height: 50) : tight.area
        let layout = LiveTextTextLayout(
            text: tight.text,
            style: Self.english,
            fontSize: placement.fontSize,
            width: area.width
        )

        #expect(layout.height <= area.height)
        #expect(!layout.breaksWord)
    }

    // MARK: Page

    @Test
    func aTranslationThatReadsAsItsSourceKeepsItsLettering() throws {
        let kept = try Self.group(origin: CGPoint(x: 100, y: 200))
        let painted = try Self.group(origin: CGPoint(x: 100, y: 800))
        let untranslated = try Self.group(origin: CGPoint(x: 100, y: 1400))

        let page = LiveTextTranslatedPage.layOut(
            groups: [kept, painted, untranslated],
            sources: [kept.id: "Tokyo", painted.id: "Where are you going?", untranslated.id: "Hey"],
            translations: [kept.id: "tokyo", painted.id: "どこに行くの？"],
            language: .init(identifier: "ja"),
            image: try Self.page()
        )

        #expect(page.groups.map(\.id) == [painted.id])
        #expect(page.pageSize == Self.pageSize)
    }

    @Test
    func aPlateSurroundsItsText() throws {
        let group = try Self.group(lines: 2)

        let page = LiveTextTranslatedPage.layOut(
            groups: [group],
            sources: [group.id: "Where are you going?"],
            translations: [group.id: "Wohin gehst du?"],
            language: .init(identifier: "de"),
            image: try Self.page()
        )

        let laidOut = try #require(page.groups.first)
        #expect(laidOut.plate.center == laidOut.textArea.center)
        #expect(laidOut.plate.size.width > laidOut.textArea.size.width)
        #expect(laidOut.plate.size.height > laidOut.textArea.size.height)
        #expect(laidOut.lineWidth <= laidOut.textArea.size.width)
        #expect(laidOut.fill == .background(.white, text: .black))
        #expect(!laidOut.isTruncated)
        #expect(laidOut.fontSize == page.fontSize)
    }
}
