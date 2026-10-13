import AppModels
import CoreGraphics
import CoreText
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

    // MARK: Balloons

    /// The white balloon of ``balloonPage(art:)``, outlined 6 pixels wide.
    private static let balloonBounds = CGRect(x: 50, y: 305, width: 600, height: 300)
    /// The two-line group in it, its lettering black bars.
    private static let balloonOrigin = CGPoint(x: 150, y: 400)

    /// Busy art with a white, outlined balloon around the lettering of the group at ``balloonOrigin``,
    /// joined to a second one in `joined`, and whatever else `art` draws over it, in page pixels, y down.
    private static func balloonPage(
        balloon: Bool = true,
        bounds: CGRect = balloonBounds,
        joined: CGRect? = nil,
        lettering: Bool = true,
        _ art: (CGContext) -> Void = { _ in }
    ) throws -> CGImage {
        try page { context in
            for stripe in 0..<100 {
                let shade = stripe.isMultiple(of: 2) ? 0.2 : 0.8
                context.setFillColor(CGColor(srgbRed: shade, green: 0.5, blue: 1 - shade, alpha: 1))
                context.fill(CGRect(x: Double(stripe) * 10, y: 0, width: 10, height: 2000))
            }
            if balloon {
                // Outlined first and filled after, so joined balloons share their paper.
                let shapes = [bounds] + (joined.map({ [$0] }) ?? [])
                context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
                context.setLineWidth(6)
                shapes.forEach(context.strokeEllipse(in:))
                context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
                shapes.forEach({ context.fillEllipse(in: $0.insetBy(dx: 3, dy: 3)) })
            }
            if lettering {
                context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
                for line in 0..<2 {
                    let top = balloonOrigin.y + Double(line) * 60
                    for left in stride(from: balloonOrigin.x + 10, to: balloonOrigin.x + 390, by: 30) {
                        context.fill(CGRect(x: left, y: top + 8, width: 12, height: 34))
                    }
                }
            }
            art(context)
        }
    }

    /// The two-line group at ``balloonOrigin``.
    private static func balloonGeometry() throws -> LiveTextGroupGeometry {
        try #require(LiveTextGroupGeometry(group: try group(origin: balloonOrigin, lines: 2), pageSize: pageSize))
    }

    /// The balloon of the group `geometry` places, among groups `others` place.
    private static func balloon(
        on image: CGImage,
        for geometry: LiveTextGroupGeometry? = nil,
        among others: [LiveTextGroupGeometry] = []
    ) throws -> LiveTextBalloon? {
        let bitmap = try #require(LiveTextPageBitmap(image: image))
        var finder = LiveTextBalloonFinder(bitmap: bitmap)
        let geometry = try geometry ?? balloonGeometry()
        return finder.balloon(
            around: geometry.textRect,
            lineHeight: geometry.lineHeight,
            among: others.map(\.textRect)
        )
    }

    /// The width a line between `top` and `bottom`, in page pixels, may take in `room`, the room of a
    /// level group whose lettering `lettering` bounds.
    private static func width(
        in room: LiveTextBalloonRoom,
        of lettering: LiveTextOrientedRect,
        from top: Double,
        to bottom: Double
    ) -> Double {
        room.width(from: top - lettering.center.y, to: bottom - lettering.center.y)
    }

    /// The pixel of `paint` at `point` in page pixels, or `nil` outside it.
    private static func pixel(of paint: LiveTextPaint, at point: CGPoint) throws -> SIMD4<UInt8>? {
        guard paint.rect.contains(point) else {
            return nil
        }
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var pixels = [SIMD4<UInt8>](repeating: .zero, count: paint.image.width * paint.image.height)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: paint.image.width,
                height: paint.image.height,
                bitsPerComponent: 8,
                bytesPerRow: paint.image.width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(paint.image, in: CGRect(x: 0, y: 0, width: paint.image.width, height: paint.image.height))
        }
        let column = Int(point.x - paint.rect.minX)
        let row = Int(point.y - paint.rect.minY)
        return pixels.dropFirst(row * paint.image.width + column).first
    }

    @Test
    func letteringInABalloonFindsIt() throws {
        let balloon = try #require(try Self.balloon(on: Self.balloonPage()))

        #expect(balloon.color == .white)
        #expect(balloon.textColor == .black)
    }

    @Test
    func letteringOnBusyArtHasNoBalloon() throws {
        #expect(try Self.balloon(on: Self.balloonPage(balloon: false)) == nil)
    }

    @Test
    func letteringOnOpenPaperHasNoBalloon() throws {
        // The page's margin reaches its edge.
        let image = try Self.page { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            for left in stride(from: Self.balloonOrigin.x + 10, to: Self.balloonOrigin.x + 390, by: 30) {
                context.fill(CGRect(x: left, y: Self.balloonOrigin.y + 8, width: 12, height: 34))
            }
        }

        #expect(try Self.balloon(on: image) == nil)
    }

    @Test
    func thePaintCoversOnlyTheLettering() throws {
        let balloon = try #require(try Self.balloon(on: Self.balloonPage()))
        let paint = try #require(balloon.paint(clearing: try Self.balloonGeometry().letteringArea))

        // A bar, and the paper midway between it and the next, beyond the paint's fringe.
        let glyph = try Self.pixel(of: paint, at: CGPoint(x: 166, y: 425))
        let paper = try Self.pixel(of: paint, at: CGPoint(x: 181, y: 425))
        #expect(glyph == SIMD4(255, 255, 255, 255))
        #expect(paper?.w == 0)
    }

    @Test
    func theRoomFollowsTheBalloonInsideItsOutline() throws {
        let balloon = try #require(try Self.balloon(on: Self.balloonPage()))
        let lettering = try Self.balloonGeometry().textRect

        let room = balloon.room()

        // Centered in the balloon, which centers on the lettering.
        let middle = CGPoint(x: lettering.center.x + room.axis, y: lettering.center.y)
        #expect(abs(middle.x - Self.balloonBounds.midX) < 2)
        // Wide across the middle, narrowing toward the top as the balloon does.
        #expect(room.width(from: -20, to: 20) > room.width(from: -110, to: -80) + 100)
        // The balloon's paper, inside its outline's inner edge, give or take a pixel.
        let radii = CGSize(width: Self.balloonBounds.width / 2 - 2, height: Self.balloonBounds.height / 2 - 2)
        for (rowNumber, reach) in room.reaches.enumerated() where reach >= 0 {
            let down = (middle.y + room.top + Double(rowNumber) * room.rowStep - Self.balloonBounds.midY) / radii.height
            for end in [middle.x - reach, middle.x + reach] {
                let across = (end - Self.balloonBounds.midX) / radii.width
                #expect(across * across + down * down <= 1)
            }
        }
    }

    @Test
    func artInTheBalloonIsNeitherPaintedNorCrowded() throws {
        // Just beyond the lettering, beside its lines.
        let art = CGRect(x: 560, y: 430, width: 40, height: 50)
        let balloon = try #require(try Self.balloon(on: Self.balloonPage { context in
            context.setFillColor(CGColor(srgbRed: 0.8, green: 0.1, blue: 0.1, alpha: 1))
            context.fillEllipse(in: art)
        }))
        let lettering = try Self.balloonGeometry().textRect

        let paint = try #require(balloon.paint(clearing: try Self.balloonGeometry().letteringArea))
        let room = balloon.room()

        let artPixel = try Self.pixel(of: paint, at: CGPoint(x: art.midX, y: art.midY))
        #expect(artPixel == nil || artPixel?.w == 0)
        // A line beside the art ends a padding short of it.
        let besideArt = Self.width(in: room, of: lettering, from: art.minY, to: art.maxY)
        #expect(besideArt > 0)
        #expect(lettering.center.x + room.axis + besideArt / 2 + room.padding <= art.minX + 1)
    }

    @Test
    func groupsInOneBalloonShareIt() throws {
        let upper = try #require(LiveTextGroupGeometry(
            group: try Self.group(origin: Self.balloonOrigin),
            pageSize: Self.pageSize
        ))
        let lower = try #require(LiveTextGroupGeometry(
            group: try Self.group(origin: CGPoint(x: Self.balloonOrigin.x, y: Self.balloonOrigin.y + 60)),
            pageSize: Self.pageSize
        ))
        let page = try Self.balloonPage()

        let upperRoom = try #require(try Self.balloon(on: page, for: upper, among: [lower])).room()
        let lowerRoom = try #require(try Self.balloon(on: page, for: lower, among: [upper])).room()

        // Their shares meet midway between their lines, 455 pixels down the page.
        #expect(Self.width(in: upperRoom, of: upper.textRect, from: 415, to: 435) > 0)
        #expect(Self.width(in: upperRoom, of: upper.textRect, from: 457, to: 475) == 0)
        #expect(Self.width(in: lowerRoom, of: lower.textRect, from: 475, to: 495) > 0)
        #expect(Self.width(in: lowerRoom, of: lower.textRect, from: 435, to: 453) == 0)
    }

    @Test
    func aRoomCentersInItsBalloon() throws {
        // Lettering set 50 pixels left of the balloon's middle.
        let geometry = try #require(LiveTextGroupGeometry(
            group: try Self.group(origin: CGPoint(x: Self.balloonOrigin.x - 50, y: Self.balloonOrigin.y), lines: 2),
            pageSize: Self.pageSize
        ))
        let balloon = try #require(try Self.balloon(on: Self.balloonPage(lettering: false), for: geometry))

        let room = balloon.room()

        #expect(abs(room.axis - 50) < 2)
    }

    @Test
    func aRoomKeepsToItsBalloonPastANeck() throws {
        // A second balloon joined to the right of the lettering's by a neck 60 pixels tall, which the
        // rows through the lettering's middle reach through.
        let joined = CGRect(x: 600, y: 380, width: 300, height: 150)
        let balloon = try #require(try Self.balloon(on: Self.balloonPage(joined: joined)))
        let lettering = try Self.balloonGeometry().textRect

        let room = balloon.room()

        #expect(abs(lettering.center.x + room.axis - Self.balloonBounds.midX) < 2)
    }

    @Test
    func aRoomCentersOnTheRowsItsLinesCouldTake() throws {
        // A tall balloon with a line of lettering low in it, under a row of dots no line may cross.
        // Above them, art cuts into the balloon's left side, which would draw the axis right were the
        // rows beyond the dots, most of the balloon's, counted.
        let bounds = CGRect(x: 50, y: 50, width: 600, height: 750)
        let geometry = try #require(LiveTextGroupGeometry(
            group: try Self.group(origin: CGPoint(x: 150, y: 640)),
            pageSize: Self.pageSize
        ))
        let dots = (0..<6).map({ CGRect(x: 333 + Double($0) * 6, y: 600, width: 2, height: 2) })
        let page = try Self.balloonPage(bounds: bounds, lettering: false) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(dots)
            context.fill(CGRect(x: 40, y: 100, width: 300, height: 460))
        }
        let balloon = try #require(try Self.balloon(on: page, for: geometry))

        let room = balloon.room()

        #expect(abs(room.axis) < 3)
    }

    @Test
    func aRoomCentersNoFartherThanItsLettering() throws {
        // A balloon far larger than the lettering, though under a third of the page, whose middle lies
        // 240 pixels right of the lettering's, past its right edge, 200 pixels across.
        let bounds = CGRect(x: 20, y: 300, width: 960, height: 760)
        let geometry = try #require(LiveTextGroupGeometry(
            group: try Self.group(origin: CGPoint(x: 60, y: 560), lines: 2),
            pageSize: Self.pageSize
        ))
        let page = try Self.balloonPage(bounds: bounds, lettering: false)
        let balloon = try #require(try Self.balloon(on: page, for: geometry))

        let room = balloon.room()

        #expect(room.axis == Double(geometry.textRect.size.width) / 2)
    }

    @Test
    func specksUnderTheTranslationArePaintedOut() throws {
        let covered = CGRect(x: 350, y: 360, width: 2, height: 2)
        let clear = CGRect(x: 350, y: 320, width: 2, height: 2)
        // A row of dots, punctuation Vision did not read, under the translation all the same.
        let dots = (0..<6).map({ CGRect(x: 200 + Double($0) * 6, y: 530, width: 2, height: 2) })
        let balloon = try #require(try Self.balloon(on: Self.balloonPage { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill([covered, clear] + dots)
        }))
        let textArea = try Self.balloonGeometry().textRect.expanded(by: 60)

        let paint = try #require(balloon.paint(clearing: textArea))

        #expect(try Self.pixel(of: paint, at: CGPoint(x: covered.midX, y: covered.midY)) == SIMD4(255, 255, 255, 255))
        for kept in [clear] + dots {
            let keptPixel = try Self.pixel(of: paint, at: CGPoint(x: kept.midX, y: kept.midY))
            #expect(keptPixel == nil || keptPixel?.w == 0)
        }
    }

    @Test
    func aTranslationInItsBalloonPaintsOutItsLettering() throws {
        let group = try Self.group(origin: Self.balloonOrigin, lines: 2)

        let page = LiveTextTranslatedPage.layOut(
            groups: [group],
            sources: [group.id: "Where are you going?"],
            translations: [group.id: "Wohin?"],
            language: .init(identifier: "de"),
            image: try Self.balloonPage()
        )

        let laidOut = try #require(page.groups.first)
        guard case .balloon(_, let text) = laidOut.fill else {
            Issue.record("A translation that fits its balloon paints out its lettering.")
            return
        }
        #expect(text == .black)
    }

    @Test
    func aTranslationTooLongForItsBalloonSpillsOntoAPlate() throws {
        let group = try Self.group(origin: Self.balloonOrigin, lines: 2)
        // Too much even at the smallest size a page is set at.
        let text = String(repeating: "Viel zu viel Text für diese Sprechblase. ", count: 40)

        let page = LiveTextTranslatedPage.layOut(
            groups: [group],
            sources: [group.id: "Where are you going?"],
            translations: [group.id: text],
            language: .init(identifier: "de"),
            image: try Self.balloonPage()
        )

        let laidOut = try #require(page.groups.first)
        if case .balloon = laidOut.fill {
            Issue.record("A translation its balloon cannot hold spills past it onto a plate.")
        }
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
            widths: [160]
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
            widths: [120]
        )

        #expect(layout.breaksWord)
    }

    /// The lines `layout` sets `text` in.
    private static func lines(of layout: LiveTextTextLayout, in text: String) -> [String] {
        let characters = text as NSString
        return layout.lines.map { line in
            let range = CTLineGetStringRange(line.line)
            return characters.substring(with: NSRange(location: range.location, length: range.length))
        }
    }

    @Test
    func koreanKeepsItsWordsWhole() {
        // CoreText alone breaks this inside 알아줬으면 좋겠어 at this width.
        let text = "괜찮아. 알겠어. 그럼 모르겠어. 네 유머 감각을 증오한다는 걸 알아줬으면 좋겠어,"
        let layout = LiveTextTextLayout(
            text: text,
            style: LiveTextTextStyle(language: .init(identifier: "ko")),
            fontSize: 20,
            widths: [120]
        )
        let lineWords = Self.lines(of: layout, in: text).flatMap({ $0.split(whereSeparator: \.isWhitespace) })

        #expect(layout.lines.count > 1)
        #expect(!layout.breaksWord)
        #expect(lineWords == text.split(whereSeparator: \.isWhitespace))
    }

    @Test(arguments: [
        ("zh-Hant", "我真的這樣做。我喜歡和你玩捉迷藏。", ["這樣", "捉迷藏"]),
        ("zh-Hant", "如果什麼都不變的話，那就是…", ["的話"]),
        ("ja", "いいです。", ["です"]),
        ("ja", "どこに行くと思うの？ここにいてって言ったでしょ！", ["行く", "って"])
    ])
    func chineseAndJapaneseKeepTheirWordsWhole(language: String, text: String, words: [String]) {
        let style = LiveTextTextStyle(language: .init(identifier: language))
        // Four characters wide, where CoreText alone breaks inside each of `words`.
        let layout = LiveTextTextLayout(text: text, style: style, fontSize: 20, widths: [80])

        let lines = Self.lines(of: layout, in: text)

        #expect(lines.count > 1)
        #expect(lines.joined() == text)
        #expect(!layout.breaksWord)
        for word in words {
            #expect(lines.contains(where: { $0.contains(word) }), "\(word) breaks across \(lines)")
        }
    }

    @Test
    func textBeyondItsHeightEndsInAnEllipsis() {
        let layout = LiveTextTextLayout(
            text: "Where do you think you are going? I told you to stay here!",
            style: Self.english,
            fontSize: 20,
            widths: [160],
            maximumHeight: 30
        )

        #expect(layout.isTruncated)
        #expect(layout.lines.count == 1)
        #expect(layout.height <= 30)
    }

    @Test
    func aBalancedWidthKeepsTheLinesAndEvensThem() throws {
        let text = "Where do you think you are going?"
        let oneLine = LiveTextTextLayout(text: text, style: Self.english, fontSize: 30, widths: [10_000])
        let width = try #require(oneLine.lines.first).width * 0.85
        let greedy = LiveTextTextLayout(text: text, style: Self.english, fontSize: 30, widths: [width])
        let balancedWidths = LiveTextTextLayout.balancedWidths(
            of: text,
            style: Self.english,
            fontSize: 30,
            widths: [width]
        )
        let balanced = LiveTextTextLayout(text: text, style: Self.english, fontSize: 30, widths: balancedWidths)
        let balancedWidth = try #require(balancedWidths.first)
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
        let oneLine = LiveTextTextLayout(text: word, style: style, fontSize: 20, widths: [10_000])
        let wordWidth = try #require(oneLine.lines.first).width
        let text = word + " ahoi"

        let balancedWidths = LiveTextTextLayout.balancedWidths(
            of: text,
            style: style,
            fontSize: 20,
            widths: [wordWidth * 1.05]
        )
        let balanced = LiveTextTextLayout(text: text, style: style, fontSize: 20, widths: balancedWidths)
        let balancedWidth = try #require(balancedWidths.first)

        #expect(balancedWidth > wordWidth)
        #expect(balanced.lines.count == 2)
        #expect(abs(try #require(balanced.lines.first).width - wordWidth) < 0.01)
        #expect(!balanced.breaksWord)
    }

    @Test
    func aBalancedWidthBreaksNoMoreWords() throws {
        // A word wider than the line, which breaks four characters in.
        let text = "ジョーカー。"
        let greedy = LiveTextTextLayout(text: text, style: Self.japanese, fontSize: 20, widths: [90])
        let balancedWidths = LiveTextTextLayout.balancedWidths(
            of: text,
            style: Self.japanese,
            fontSize: 20,
            widths: [90]
        )
        let balanced = LiveTextTextLayout(text: text, style: Self.japanese, fontSize: 20, widths: balancedWidths)
        func spread(_ layout: LiveTextTextLayout) -> Double {
            let widths = layout.lines.map(\.width)
            return (widths.max() ?? 0) - (widths.min() ?? 0)
        }

        #expect(greedy.lines.count == 2)
        #expect(greedy.breaksWord)
        #expect(balanced.lines.count == 2)
        #expect(spread(balanced) < spread(greedy) / 2)
    }

    @Test
    func aSingleLineKeepsItsWidth() {
        #expect(LiveTextTextLayout.balancedWidths(of: "Hi!", style: Self.english, fontSize: 20, widths: [400]) == [400])
    }

    @Test
    func everyLineKeepsOnePitch() {
        // The Japanese glyphs come from a taller font than the Latin ones.
        let layout = LiveTextTextLayout(
            text: "OK OK OK OK OK OK 大丈夫だよ",
            style: Self.japanese,
            fontSize: 20,
            widths: [60]
        )

        #expect(layout.lines.count > 1)
        #expect(layout.height == Double(layout.lines.count) * layout.lineHeight)
        #expect(layout.lineHeight == LiveTextTextLayout.lineHeight(
            of: "OK OK OK OK OK OK 大丈夫だよ",
            style: Self.japanese,
            fontSize: 20
        ))
    }

    // MARK: Shapes

    /// A balloon's room shaped like a diamond, 300 pixels wide at its center and narrowing toward its
    /// points, 150 pixels above and below it.
    private static let diamond = LiveTextBalloonRoom(
        axis: 0,
        reaches: (-150...150).map({ 150 - abs(Double($0)) }),
        top: -150,
        rowStep: 1,
        padding: 0
    )

    @Test
    func linesFollowTheirBalloonsShape() throws {
        let text = "Where do you think you are going? I told you to stay here!"

        let setting = try #require(LiveTextTextShape.balloon(Self.diamond).setting(
            of: text,
            style: Self.english,
            fontSize: 20,
            breaksWords: false
        ))
        let layout = LiveTextTextLayout(text: text, style: Self.english, fontSize: 20, widths: setting.lineWidths)

        let widths = setting.lineWidths
        #expect(widths.count == layout.lines.count)
        #expect(widths.count >= 3)
        let middle = try #require(widths.dropFirst(widths.count / 2).first)
        #expect(try #require(widths.first) < middle)
        #expect(try #require(widths.last) < middle)
        #expect(zip(layout.lines, widths).allSatisfy({ $0.width <= $1 }))
        #expect(!layout.breaksWord)
        #expect(setting.center == .zero)
        #expect(Double(setting.area.height) == layout.height)
    }

    @Test
    func aRectangleSetsItsTextWhole() throws {
        let size = CGSize(width: 300, height: 200)

        let setting = try #require(LiveTextTextShape.rectangle(size).setting(
            of: "Where do you think you are going?",
            style: Self.english,
            fontSize: 20,
            breaksWords: false
        ))

        #expect(setting == LiveTextTextSetting(lineWidths: [300], area: size, center: .zero))
    }

    @Test
    func aShapeTooSmallSetsNothing() {
        let setting = LiveTextTextShape.balloon(Self.diamond).setting(
            of: String(repeating: "Far too much text for this tiny balloon. ", count: 20),
            style: Self.english,
            fontSize: 20,
            breaksWords: true
        )

        #expect(setting == nil)
    }

    // MARK: Fitting

    /// A region off a balloon, its plate growing by a quarter.
    private static func region(_ text: String, width: Double, height: Double) -> LiveTextTextFitter.Region {
        let scale = LiveTextTextFitter.grownScale
        return LiveTextTextFitter.Region(
            id: UUID(),
            text: text,
            shape: .rectangle(CGSize(width: width, height: height)),
            grownArea: CGSize(width: width * scale, height: height * scale),
            lineHeight: 40
        )
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
        #expect(placement.setting.area == hopeless.grownArea)
        #expect(abs(placement.fontSize - result.fontSize * LiveTextTextFitter.reducedScale) < 1e-9)
    }

    @Test
    func aTightTranslationsStepFitsItsArea() throws {
        let roomy = Self.region("Hi!", width: 400, height: 200)
        let tight = Self.region("Where do you think you are going?", width: 300, height: 40)

        let result = LiveTextTextFitter.fit([roomy, tight], style: Self.english, pageWidth: 1000)
        let placement = try #require(result.placements.first(where: { $0.id == tight.id }))
        let layout = LiveTextTextLayout(
            text: tight.text,
            style: Self.english,
            fontSize: placement.fontSize,
            widths: placement.setting.lineWidths
        )

        #expect(layout.height <= placement.setting.area.height)
        #expect(!layout.breaksWord)
    }

    @Test
    func onlyChineseAndJapaneseBreakAWordToStayInTheirShape() throws {
        // Four and a bit characters wide at 85% of the lettering's size, and two lines tall: the
        // translation's one word fits neither it nor its plate whole.
        let width = Self.letteringSize * LiveTextTextFitter.reducedScale * 4.2
        let japanese = Self.region("ジョーカー。", width: width, height: 80)
        let english = Self.region("Unbelievable!", width: width, height: 80)

        let japaneseResult = LiveTextTextFitter.fit([japanese], style: Self.japanese, pageWidth: 1000)
        let englishResult = LiveTextTextFitter.fit([english], style: Self.english, pageWidth: 1000)
        let japanesePlacement = try #require(japaneseResult.placements.first)
        let layout = LiveTextTextLayout(
            text: japanese.text,
            style: Self.japanese,
            fontSize: japanesePlacement.fontSize,
            widths: japanesePlacement.setting.lineWidths
        )

        #expect(!japanesePlacement.isGrown)
        #expect(abs(japanesePlacement.fontSize - japaneseResult.fontSize * LiveTextTextFitter.reducedScale) < 1e-9)
        #expect(layout.breaksWord)
        #expect(layout.height <= japanesePlacement.setting.area.height)
        #expect(try #require(englishResult.placements.first).isGrown)
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
        #expect(laidOut.lineWidths.allSatisfy({ $0 <= laidOut.textArea.size.width }))
        #expect(laidOut.fill == .background(.white, text: .black))
        #expect(!laidOut.isTruncated)
        #expect(laidOut.fontSize == page.fontSize)
    }
}
