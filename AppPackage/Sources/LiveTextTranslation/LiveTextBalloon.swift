import CoreGraphics
import Foundation

/// The closed region of one color a group's lettering sits in: a speech balloon, a caption box, a
/// panel's plain background. Its lettering is painted out with the colors around it, which leaves the
/// balloon whole, outline and all, and the translation is set in the room the balloon has, its lines
/// following the balloon's shape.
///
/// Groups lettered in one balloon share it: each has the part nearer its own lettering than any
/// other's.
struct LiveTextBalloon {
    /// How far a translation stays from anything in its balloon it may not cover, such as the outline,
    /// art, or other lettering, in line heights: about as close as a letterer sets lettering.
    static let padding = 0.15
    /// How far past its lettering's bounds a hole in the paper may reach and still be one of its
    /// glyphs, in line heights: the bounds Vision finds hug the lettering.
    static let glyphReach = 0.3
    /// The largest speck, such as dust or noise in the paper, which a translation may cover: a hole in
    /// the paper no larger than a square this share of a line height on a side.
    static let speckSize = 0.1
    /// How far, in line heights, a speck lies from any other hole in the paper but the group's glyphs:
    /// dust lies alone, where a dot of punctuation Vision did not read, which a translation must leave
    /// be, comes in a row or beside a glyph.
    static let speckSpacing = 0.5
    /// How far beyond the glyphs their paint reaches, in bitmap pixels, so it covers their
    /// anti-aliased edges, which pass for paper.
    static let fringe = 2

    /// The balloon's paper color.
    let color: LiveTextColor
    /// The bounds of the group's lettering, in page pixels.
    private let lettering: LiveTextOrientedRect
    /// The bounds of the lettering of the other groups in the balloon.
    private let rivals: [LiveTextOrientedRect]
    /// The height of the group's lines, in page pixels.
    private let lineHeight: Double
    private let region: LiveTextBalloonRegion
    private let bitmap: LiveTextPageBitmap
    /// The numbers of the holes in the paper that are the group's glyphs.
    private let glyphs: Set<Int32>
    /// The numbers of the holes in the paper that are specks.
    private let specks: Set<Int32>

    fileprivate init(
        color: LiveTextColor,
        lettering: LiveTextOrientedRect,
        rivals: [LiveTextOrientedRect],
        lineHeight: Double,
        region: LiveTextBalloonRegion,
        bitmap: LiveTextPageBitmap
    ) {
        self.color = color
        self.lettering = lettering
        self.rivals = rivals
        self.lineHeight = lineHeight
        self.region = region
        self.bitmap = bitmap
        let grown = lettering.expanded(by: Self.glyphReach * lineHeight)
        let glyphs = Set(region.holeBoxes.filter { _, box in
            box.corners(in: bitmap).allSatisfy(grown.contains)
                && Self.isNearer(box.center(in: bitmap), to: lettering, than: rivals)
        }.keys)
        let side = Self.speckSize * lineHeight * bitmap.horizontalScale
        let spacing = Int((Self.speckSpacing * lineHeight * bitmap.horizontalScale).rounded(.up))
        let others = region.holeBoxes.filter({ !glyphs.contains($0.key) })
        specks = Set(others.filter { hole, box in
            let isSmall = region.holeSizes[hole].map({ Double($0) <= side * side }) ?? false
            let surroundings = box.expanded(by: spacing)
            return isSmall && !others.contains(where: { $0.key != hole && $0.value.intersection(surroundings) != nil })
        }.keys)
        self.glyphs = glyphs
    }

    /// The color a translation is set in: black or white, whichever stands out more.
    var textColor: LiveTextColor {
        color.contrast(with: .white) > color.contrast(with: .black) ? .white : .black
    }

    /// The room the balloon has for the group's translation: at each height, how far the paper, which
    /// the group's glyphs and specks count as, reaches either way from the room's axis.
    ///
    /// The axis runs down the middle of the paper beside the lettering, so a translation sits in the
    /// middle of its share of the balloon, as lettering is set, even where the letterer crowded one
    /// side. It stays within the lettering's bounds, so in a balloon as large as a panel's plain
    /// background a translation keeps to where its lettering was. The room centers at the lettering's
    /// own height, where its letterer centered it in the balloon.
    func room() -> LiveTextBalloonRoom {
        let padding = Self.padding * lineHeight
        // Rows, and the points along them, a bitmap pixel apart at most.
        let step = 1 / Swift.max(bitmap.horizontalScale, bitmap.verticalScale)
        // Points measured across and down from the lettering's center, turned with it.
        let toPage = lettering.transform
        func isFree(across distance: Double, down depth: Double) -> Bool {
            isRoom(at: CGPoint(x: distance, y: depth).applying(toPage))
        }
        let corners = region.box.corners(in: bitmap).map({ $0.applying(toPage.inverted()) })
        guard let top = corners.map(\.y).min(),
              let bottom = corners.map(\.y).max(),
              let farthest = corners.map({ abs($0.x) }).max()
        else {
            return LiveTextBalloonRoom(axis: 0, reaches: [], top: 0, rowStep: step, padding: padding)
        }
        // How many points in a row, `step` apart from `start` one way, are free.
        func run(down depth: Double, from start: Double, by stride: Double) -> Int {
            var count = 0
            while abs(start + Double(count) * stride) <= farthest,
                  isFree(across: start + Double(count) * stride, down: depth) {
                count += 1
            }
            return count
        }

        // The paper in a row either way from the lettering's center, when a line through it fits there.
        func span(atRow rowNumber: Int) -> ClosedRange<Double>? {
            let depth = Double(rowNumber) * step
            let right = Double(run(down: depth, from: 0, by: step) - 1) * step
            let left = Double(run(down: depth, from: -step, by: -step)) * step
            return Swift.min(left, right) > padding ? -left...right : nil
        }
        // The rows a line through the lettering's center could take, as far up and down as one could.
        var rowsAbove = [(depth: Double, span: ClosedRange<Double>)]()
        for rowNumber in stride(from: 0, through: Int((top / step).rounded(.down)), by: -1) {
            guard let span = span(atRow: rowNumber) else {
                break
            }
            rowsAbove.append((depth: Double(rowNumber) * step, span: span))
        }
        var rowsBelow = [(depth: Double, span: ClosedRange<Double>)]()
        for rowNumber in stride(from: 1, through: Int((bottom / step).rounded(.up)), by: 1) {
            guard let span = span(atRow: rowNumber) else {
                break
            }
            rowsBelow.append((depth: Double(rowNumber) * step, span: span))
        }
        let rows = rowsAbove.reversed() + rowsBelow

        // The axis most of them center on: a median, so neither a tail nor a neck into a balloon joined
        // to this one draws the room off its own.
        let midpoint = rows.map({ ($0.span.lowerBound + $0.span.upperBound) / 2 }).median ?? 0
        let axis = Swift.min(Swift.max(midpoint, -lettering.size.width / 2), lettering.size.width / 2)

        let firstRow = Int((top / step).rounded(.down))
        let lastRow = Int((bottom / step).rounded(.up))
        let reaches = (firstRow...lastRow).map { rowNumber in
            let depth = Double(rowNumber) * step
            var reached = 0
            while Double(reached) * step <= 2 * farthest,
                  isFree(across: axis + Double(reached) * step, down: depth),
                  isFree(across: axis - Double(reached) * step, down: depth) {
                reached += 1
            }
            return Double(reached - 1) * step
        }
        return LiveTextBalloonRoom(
            axis: axis,
            reaches: reaches,
            top: Double(firstRow) * step,
            rowStep: step,
            padding: padding
        )
    }

    /// The group's lettering painted out, and the specks its translation covers, which sits in `area`:
    /// their pixels and their fringe, in the colors of the paper around them, filled in from the
    /// outside, so a gradient or a texture in the paper carries on.
    func paint(clearing area: LiveTextOrientedRect) -> LiveTextPaint? {
        let areaBox = LiveTextPixelBox(covering: area, in: bitmap)
        let coveredSpecks = specks.filter { speck in
            region.holeBoxes[speck].map { box in
                box.intersection(areaBox) != nil && isOwn(box.center(in: bitmap))
            } ?? false
        }
        let holes = glyphs.union(coveredSpecks)
        let holeBoxes = holes.compactMap({ region.holeBoxes[$0]?.expanded(by: Self.fringe) })
        guard let firstBox = holeBoxes.first,
              let paintBox = holeBoxes.dropFirst().reduce(firstBox, { $0.union($1) }).intersection(region.box)
        else {
            return nil
        }

        // Every pixel to paint: a hole's, or one of paper within the fringe of one.
        var isPainted = [Bool](repeating: false, count: paintBox.count)
        for row in paintBox.minRow...paintBox.maxRow {
            for column in paintBox.minColumn...paintBox.maxColumn
            where holes.contains(region.hole(column: column, row: row)) {
                guard let near = LiveTextPixelBox(column: column, row: row)
                    .expanded(by: Self.fringe)
                    .intersection(paintBox)
                else {
                    continue
                }
                for nearRow in near.minRow...near.maxRow {
                    for nearColumn in near.minColumn...near.maxColumn
                    where region.isPaper(column: nearColumn, row: nearRow)
                        || holes.contains(region.hole(column: nearColumn, row: nearRow)) {
                        isPainted[paintBox.index(column: nearColumn, row: nearRow)] = true
                    }
                }
            }
        }
        return LiveTextPaint(
            filling: isPainted,
            in: paintBox,
            from: { column, row in region.isPaper(column: column, row: row) },
            bitmap: bitmap,
            paper: color
        )
    }

    /// Whether a translation may cover `point`, in page pixels: the balloon's paper, the group's
    /// glyphs, or a speck, nearer the group's lettering than any other's.
    private func isRoom(at point: CGPoint) -> Bool {
        let pixel = point.applying(bitmap.pageToBitmap)
        let column = Int(pixel.x.rounded(.down))
        let row = Int(pixel.y.rounded(.down))
        let hole = region.hole(column: column, row: row)
        guard region.isPaper(column: column, row: row) || glyphs.contains(hole) || specks.contains(hole) else {
            return false
        }
        return isOwn(point)
    }

    /// Whether `point`, in page pixels, lies in the group's share of the balloon.
    private func isOwn(_ point: CGPoint) -> Bool {
        Self.isNearer(point, to: lettering, than: rivals)
    }

    /// Whether `point` lies no farther from `lettering` than from any of `rivals`.
    private static func isNearer(
        _ point: CGPoint,
        to lettering: LiveTextOrientedRect,
        than rivals: [LiveTextOrientedRect]
    ) -> Bool {
        let distance = lettering.distance(to: point)
        return !rivals.contains(where: { $0.distance(to: point) < distance })
    }
}

/// The room a balloon has for a translation, turned with the lettering it replaces: at each height,
/// how far the balloon's paper reaches either way from the room's axis before something the
/// translation may not cover. Its center lies on the axis, at the lettering's center's height.
struct LiveTextBalloonRoom: Equatable {
    /// How far across from the lettering's center the axis runs, which the lines center on.
    let axis: Double
    /// How far the room reaches either way from its axis, row by row down from `top`; negative where
    /// it does not hold the axis.
    let reaches: [Double]
    /// How far below the center the first row lies; negative above it.
    let top: Double
    /// The distance from one row to the next.
    let rowStep: Double
    /// How far a line stays from what bounds the room.
    let padding: Double

    /// The height of the tallest block of lines centered on the center that fits between the first
    /// row and the last, `padding` clear of both.
    var height: Double {
        let bottom = top + Double(reaches.count - 1) * rowStep
        return Swift.max(0, 2 * (Swift.min(-top, bottom) - padding))
    }

    /// How wide a line between `lineTop` and `lineBottom`, measured down from the center, may be,
    /// `padding` clear of what bounds the room on every side; 0 where none fits.
    func width(from lineTop: Double, to lineBottom: Double) -> Double {
        let first = Int(((lineTop - padding - top) / rowStep).rounded(.down))
        let last = Int(((lineBottom + padding - top) / rowStep).rounded(.up))
        guard first >= 0, first <= last, last < reaches.count, let reach = reaches[first...last].min() else {
            return 0
        }
        return Swift.max(0, 2 * (reach - padding))
    }

    /// `text` set at `fontSize` in as few lines as the room holds it in, without breaking a word: each
    /// line as wide as the room is where it lies, and the lines centered on the room's center; `nil`
    /// when the room holds it in none. Measurements down are from the room's center.
    func setting(of text: String, style: LiveTextTextStyle, fontSize: Double) -> LiveTextTextSetting? {
        let lineHeight = LiveTextTextLayout.lineHeight(of: text, style: style, fontSize: fontSize)
        guard lineHeight > 0, height >= lineHeight else {
            return nil
        }
        let mostLines = Int((height / lineHeight).rounded(.up))
        for count in 1...mostLines where Double(count) * lineHeight <= height {
            let blockTop = -Double(count) * lineHeight / 2
            let widths = (0..<count).map { line in
                width(from: blockTop + Double(line) * lineHeight, to: blockTop + Double(line + 1) * lineHeight)
            }
            guard widths.allSatisfy({ $0 > 0 }) else {
                continue
            }
            let layout = LiveTextTextLayout(text: text, style: style, fontSize: fontSize, widths: widths)
            guard layout.lines.count <= count, !layout.breaksWord else {
                continue
            }
            // Fewer lines than there are bands take the top ones, whose widths they were set in.
            let lineWidths = Array(widths.prefix(layout.lines.count))
            return LiveTextTextSetting(
                lineWidths: lineWidths,
                area: CGSize(width: lineWidths.max() ?? 0, height: layout.height),
                center: CGPoint(x: axis, y: blockTop + layout.height / 2)
            )
        }
        return nil
    }
}

/// Lettering painted out: an image laid over the page at `rect`, in page pixels, clear where nothing
/// is painted.
public struct LiveTextPaint: Equatable, Sendable {
    public let image: CGImage
    public let rect: CGRect

    /// Paints the pixels of `box` marked in `isPainted`, filling them in from the pixels around them
    /// that `isKnown` tells, layer by layer, each pixel the mean of its known neighbors; pixels no known
    /// one reaches take `paper`.
    fileprivate init?(
        filling isPainted: [Bool],
        in box: LiveTextPixelBox,
        from isKnown: (Int, Int) -> Bool,
        bitmap: LiveTextPageBitmap,
        paper: LiveTextColor
    ) {
        var colors = [SIMD4<Float>](repeating: .zero, count: box.count)
        var isFilled = [Bool](repeating: false, count: box.count)
        var pending = [Int]()
        for (pixel, painted) in isPainted.enumerated() {
            let column = box.minColumn + pixel % box.width
            let row = box.minRow + pixel / box.width
            if painted {
                pending.append(pixel)
            } else if isKnown(column, row) {
                isFilled[pixel] = true
                colors[pixel] = SIMD4<Float>(bitmap[pixel: row * bitmap.width + column])
            }
        }
        let paperColor = SIMD4<Float>(Float(paper.red), Float(paper.green), Float(paper.blue), 1) * 255
        while !pending.isEmpty {
            var filled = [(pixel: Int, color: SIMD4<Float>)]()
            var unreached = [Int]()
            for pixel in pending {
                let column = pixel % box.width
                let row = pixel / box.width
                var sum = SIMD4<Float>.zero
                var count: Float = 0
                for neighborRow in Swift.max(row - 1, 0)...Swift.min(row + 1, box.height - 1) {
                    for neighborColumn in Swift.max(column - 1, 0)...Swift.min(column + 1, box.width - 1) {
                        let neighbor = neighborRow * box.width + neighborColumn
                        if isFilled[neighbor] {
                            sum += colors[neighbor]
                            count += 1
                        }
                    }
                }
                if count > 0 {
                    filled.append((pixel, sum / count))
                } else {
                    unreached.append(pixel)
                }
            }
            if filled.isEmpty {
                // Nothing known reaches the rest: they take the paper's color.
                filled = unreached.map({ ($0, paperColor) })
                unreached = []
            }
            for (pixel, color) in filled {
                isFilled[pixel] = true
                colors[pixel] = color
            }
            pending = unreached
        }

        let pixels = zip(isPainted, colors).map { painted, color -> SIMD4<UInt8> in
            guard painted else {
                return .zero
            }
            var pixel = SIMD4<UInt8>(color, rounding: .toNearestOrEven)
            pixel.w = 255
            return pixel
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: pixels.withUnsafeBytes({ Data($0) }) as CFData),
              let image = CGImage(
                  width: box.width,
                  height: box.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: box.width * MemoryLayout<SIMD4<UInt8>>.stride,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else {
            return nil
        }
        self.image = image
        rect = CGRect(
            x: Double(box.minColumn) / bitmap.horizontalScale,
            y: Double(box.minRow) / bitmap.verticalScale,
            width: Double(box.width) / bitmap.horizontalScale,
            height: Double(box.height) / bitmap.verticalScale
        )
    }
}

/// Finds the balloons lettering sits in: closed regions of one color, told apart from open paper, such
/// as the gutters and margins every panel shares, by not reaching the page's edge.
struct LiveTextBalloonFinder {
    /// How far, in any one component out of 255, a pixel may stray from a balloon's color and still be
    /// its paper: enough for noise and an outline's anti-aliasing, too little to leak through an outline.
    static let tolerance: Int16 = 31
    /// The share of a group's lettering area that must be paper, the color most of it is. Lettering
    /// covers well under half of its lines.
    static let paperShare = 0.4
    /// The largest share of the page a balloon covers; more is open paper, such as a page's margins.
    static let maximumAreaShare = 0.3

    private let bitmap: LiveTextPageBitmap
    /// The floods so far, by their numbers, counting from 1.
    private var floods = [Int32: LiveTextFlood]()
    /// The number of the last flood to reach each pixel; 0 for none.
    private var reached: [Int32]

    init(bitmap: LiveTextPageBitmap) {
        self.bitmap = bitmap
        reached = [Int32](repeating: 0, count: bitmap.width * bitmap.height)
    }

    /// The balloon the group whose lines `lettering` bounds sits in, or `nil` when it sits on open
    /// paper or busy art. `others` bound the page's other groups, those lettered in the balloon too
    /// among them.
    ///
    /// Its paper is the color most of `lettering` is; the balloon is where that paper, flooded from
    /// `lettering`, spreads.
    mutating func balloon(
        around lettering: LiveTextOrientedRect,
        lineHeight: Double,
        among others: [LiveTextOrientedRect]
    ) -> LiveTextBalloon? {
        let pixels = LiveTextPixelBox(covering: lettering, in: bitmap).pixels(in: lettering, of: bitmap)
        guard let paper = Self.median(of: pixels.map({ bitmap[pixel: $0] })) else {
            return nil
        }
        let seeds = pixels.filter({ Self.matches(bitmap[pixel: $0], paper) })
        guard Double(seeds.count) >= Double(pixels.count) * Self.paperShare else {
            return nil
        }
        var seedCounts = [Int32: Int]()
        for seed in seeds {
            var number = reached[seed]
            if floods[number].map({ !Self.matches($0.color, paper) }) ?? true {
                number = flood(from: seed, color: paper)
            }
            seedCounts[number, default: 0] += 1
        }
        guard let largest = seedCounts.max(by: { $0.value < $1.value }),
              largest.value * 2 >= seeds.count,
              let region = floods[largest.key]?.region
        else {
            return nil
        }
        let bitmap = bitmap
        let rivals = others.filter { other in
            let center = other.center.applying(bitmap.pageToBitmap)
            let column = Int(center.x.rounded(.down))
            let row = Int(center.y.rounded(.down))
            return region.isPaper(column: column, row: row) || region.hole(column: column, row: row) > 0
        }
        return LiveTextBalloon(
            color: LiveTextColor(paper),
            lettering: lettering,
            rivals: rivals,
            lineHeight: lineHeight,
            region: region,
            bitmap: bitmap
        )
    }

    /// Floods the pixels of `color` connected to `seed`, and returns the flood's number.
    private mutating func flood(from seed: Int, color: SIMD4<UInt8>) -> Int32 {
        let number = Int32(floods.count + 1)
        let bitmap = bitmap
        var reached = [Int32]()
        swap(&reached, &self.reached)
        var queue = [Int32(seed)]
        reached[seed] = number
        var box = LiveTextPixelBox(column: seed % bitmap.width, row: seed / bitmap.width)
        func reach(_ neighbor: Int) {
            if reached[neighbor] != number, Self.matches(bitmap[pixel: neighbor], color) {
                reached[neighbor] = number
                queue.append(Int32(neighbor))
            }
        }
        var head = 0
        while head < queue.count {
            let pixel = Int(queue[head])
            head += 1
            let column = pixel % bitmap.width
            let row = pixel / bitmap.width
            box = box.union(LiveTextPixelBox(column: column, row: row))
            if column > 0 {
                reach(pixel - 1)
            }
            if column < bitmap.width - 1 {
                reach(pixel + 1)
            }
            if row > 0 {
                reach(pixel - bitmap.width)
            }
            if row < bitmap.height - 1 {
                reach(pixel + bitmap.width)
            }
        }
        let isOpen = box.minColumn == 0 || box.minRow == 0
            || box.maxColumn == bitmap.width - 1 || box.maxRow == bitmap.height - 1
            || Double(queue.count) > Double(bitmap.width * bitmap.height) * Self.maximumAreaShare
        let region = isOpen ? nil : LiveTextBalloonRegion(box: box.expanded(by: 1)) { column, row in
            reached[row * bitmap.width + column] == number
        }
        swap(&reached, &self.reached)
        floods[number] = LiveTextFlood(color: color, region: region)
        return number
    }

    private static func matches(_ pixel: SIMD4<UInt8>, _ color: SIMD4<UInt8>) -> Bool {
        let difference = SIMD4<Int16>(truncatingIfNeeded: pixel) &- SIMD4<Int16>(truncatingIfNeeded: color)
        return Swift.max(abs(difference.x), abs(difference.y), abs(difference.z)) <= tolerance
    }

    /// The median of each component of `pixels`, opaque; `nil` for no pixels.
    private static func median(of pixels: [SIMD4<UInt8>]) -> SIMD4<UInt8>? {
        func component(_ value: (SIMD4<UInt8>) -> UInt8) -> UInt8? {
            let values = pixels.map(value).sorted()
            return values.dropFirst((values.count - 1) / 2).first
        }
        guard let red = component(\.x), let green = component(\.y), let blue = component(\.z) else {
            return nil
        }
        return SIMD4(red, green, blue, 255)
    }
}

/// One flood of the page: a balloon, or open paper when its region is `nil`.
private struct LiveTextFlood {
    let color: SIMD4<UInt8>
    let region: LiveTextBalloonRegion?
}

/// A balloon's pixels within `box`: its paper, and the holes its paper closes around, such as glyphs.
private struct LiveTextBalloonRegion {
    let box: LiveTextPixelBox
    private let paper: [Bool]
    /// Each pixel's hole number, counting from 1; 0 for paper and for what lies outside the balloon.
    private let holes: [Int32]
    /// Each hole's bounds, by its number.
    let holeBoxes: [Int32: LiveTextPixelBox]
    /// Each hole's pixel count, by its number.
    let holeSizes: [Int32: Int]

    /// The region of `box`'s pixels `isPaper` tells, where `box` reaches past the paper on every side.
    init(box: LiveTextPixelBox, isPaper: (Int, Int) -> Bool) {
        var paper = [Bool](repeating: false, count: box.count)
        for row in box.minRow...box.maxRow {
            for column in box.minColumn...box.maxColumn {
                paper[box.index(column: column, row: row)] = isPaper(column, row)
            }
        }
        // What is not paper and reaches the box's edge lies outside the balloon; the rest are holes.
        var holes = [Int32](repeating: 0, count: box.count)
        let outside: Int32 = -1
        func spread(from start: Int, as number: Int32) -> LiveTextPixelBox {
            var queue = [start]
            holes[start] = number
            var bounds = LiveTextPixelBox(
                column: box.minColumn + start % box.width,
                row: box.minRow + start / box.width
            )
            var head = 0
            while head < queue.count {
                let pixel = queue[head]
                head += 1
                let column = pixel % box.width
                let row = pixel / box.width
                bounds = bounds.union(LiveTextPixelBox(column: box.minColumn + column, row: box.minRow + row))
                for neighborRow in Swift.max(row - 1, 0)...Swift.min(row + 1, box.height - 1) {
                    for neighborColumn in Swift.max(column - 1, 0)...Swift.min(column + 1, box.width - 1) {
                        let neighbor = neighborRow * box.width + neighborColumn
                        if !paper[neighbor], holes[neighbor] == 0 {
                            holes[neighbor] = number
                            queue.append(neighbor)
                        }
                    }
                }
            }
            return bounds
        }
        for (pixel, isPaperPixel) in paper.enumerated() where !isPaperPixel && holes[pixel] == 0 {
            let column = pixel % box.width
            let row = pixel / box.width
            if column == 0 || row == 0 || column == box.width - 1 || row == box.height - 1 {
                _ = spread(from: pixel, as: outside)
            }
        }
        var holeBoxes = [Int32: LiveTextPixelBox]()
        for (pixel, isPaperPixel) in paper.enumerated() where !isPaperPixel && holes[pixel] == 0 {
            let number = Int32(holeBoxes.count + 1)
            holeBoxes[number] = spread(from: pixel, as: number)
        }
        var holeSizes = [Int32: Int]()
        for hole in holes where hole > 0 {
            holeSizes[hole, default: 0] += 1
        }
        self.box = box
        self.paper = paper
        self.holes = holes.map({ $0 == outside ? 0 : $0 })
        self.holeBoxes = holeBoxes
        self.holeSizes = holeSizes
    }

    func isPaper(column: Int, row: Int) -> Bool {
        box.contains(column: column, row: row) && paper[box.index(column: column, row: row)]
    }

    /// The number of the hole at the pixel, or 0.
    func hole(column: Int, row: Int) -> Int32 {
        box.contains(column: column, row: row) ? holes[box.index(column: column, row: row)] : 0
    }
}

/// A rectangle of bitmap pixels, its bounds included.
struct LiveTextPixelBox: Equatable {
    var minColumn: Int
    var minRow: Int
    var maxColumn: Int
    var maxRow: Int

    init(column: Int, row: Int) {
        minColumn = column
        minRow = row
        maxColumn = column
        maxRow = row
    }

    /// The pixels `rect`'s upright bounds, in page pixels, cover; they may reach beyond the bitmap.
    init(covering rect: LiveTextOrientedRect, in bitmap: LiveTextPageBitmap) {
        let bounds = rect.boundingBox.applying(bitmap.pageToBitmap)
        minColumn = Int(bounds.minX.rounded(.down))
        minRow = Int(bounds.minY.rounded(.down))
        maxColumn = Int(bounds.maxX.rounded(.up)) - 1
        maxRow = Int(bounds.maxY.rounded(.up)) - 1
    }

    var width: Int {
        Swift.max(0, maxColumn - minColumn + 1)
    }

    var height: Int {
        Swift.max(0, maxRow - minRow + 1)
    }

    var count: Int {
        width * height
    }

    func contains(column: Int, row: Int) -> Bool {
        (minColumn...maxColumn).contains(column) && (minRow...maxRow).contains(row)
    }

    /// The pixel's place in a row-by-row array of this box's pixels.
    func index(column: Int, row: Int) -> Int {
        (row - minRow) * width + column - minColumn
    }

    func expanded(by margin: Int) -> Self {
        var box = self
        box.minColumn -= margin
        box.minRow -= margin
        box.maxColumn += margin
        box.maxRow += margin
        return box
    }

    func union(_ other: Self) -> Self {
        var box = self
        box.minColumn = Swift.min(minColumn, other.minColumn)
        box.minRow = Swift.min(minRow, other.minRow)
        box.maxColumn = Swift.max(maxColumn, other.maxColumn)
        box.maxRow = Swift.max(maxRow, other.maxRow)
        return box
    }

    func intersection(_ other: Self) -> Self? {
        var box = self
        box.minColumn = Swift.max(minColumn, other.minColumn)
        box.minRow = Swift.max(minRow, other.minRow)
        box.maxColumn = Swift.min(maxColumn, other.maxColumn)
        box.maxRow = Swift.min(maxRow, other.maxRow)
        return box.minColumn <= box.maxColumn && box.minRow <= box.maxRow ? box : nil
    }

    /// The box's center in page pixels.
    func center(in bitmap: LiveTextPageBitmap) -> CGPoint {
        CGPoint(
            x: Double(minColumn + maxColumn + 1) / 2 / bitmap.horizontalScale,
            y: Double(minRow + maxRow + 1) / 2 / bitmap.verticalScale
        )
    }

    /// The box's corners in page pixels.
    func corners(in bitmap: LiveTextPageBitmap) -> [CGPoint] {
        let toPage = bitmap.pageToBitmap.inverted()
        return [
            CGPoint(x: minColumn, y: minRow),
            CGPoint(x: maxColumn + 1, y: minRow),
            CGPoint(x: maxColumn + 1, y: maxRow + 1),
            CGPoint(x: minColumn, y: maxRow + 1)
        ]
        .map({ $0.applying(toPage) })
    }

    /// The numbers of the box's pixels on `bitmap` whose centers lie in `rect`, in page pixels.
    func pixels(in rect: LiveTextOrientedRect, of bitmap: LiveTextPageBitmap) -> [Int] {
        let wholeBitmap = LiveTextPixelBox(column: 0, row: 0)
            .union(LiveTextPixelBox(column: bitmap.width - 1, row: bitmap.height - 1))
        guard let onBitmap = intersection(wholeBitmap) else {
            return []
        }
        let toPage = bitmap.pageToBitmap.inverted()
        var numbers = [Int]()
        for row in onBitmap.minRow...onBitmap.maxRow {
            for column in onBitmap.minColumn...onBitmap.maxColumn
            where rect.contains(CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5).applying(toPage)) {
                numbers.append(row * bitmap.width + column)
            }
        }
        return numbers
    }
}
