import CoreGraphics
import Foundation

/// The closed region of one color a group's lettering sits in: a speech balloon, a caption box, a
/// panel's plain background. Its lettering is painted out with the colors around it, which leaves the
/// balloon whole, outline and all, and the translation is set in the room the balloon has.
struct LiveTextBalloon {
    /// How far a translation stays from anything in its balloon that is not paper, such as the outline
    /// or other lettering, in line heights: about the room a letterer leaves.
    static let padding = 0.3
    /// The share of a room that may be specks, such as dust or noise in the paper.
    static let speckShare = 0.005
    /// How far beyond the lettering's glyphs their paint reaches, in bitmap pixels, so it covers their
    /// anti-aliased edges, which pass for paper.
    static let fringe = 2
    /// Halvings of the search for a room's width or height: under a 1/4000 of the balloon's.
    private static let searchSteps = 12
    /// The widths a room is tried at, evenly up to the widest.
    private static let roomWidths = 12

    /// The balloon's paper color.
    let color: LiveTextColor
    fileprivate let region: LiveTextBalloonRegion
    /// The numbers of the holes in the paper that are this group's lettering.
    fileprivate let glyphs: Set<Int32>
    fileprivate let bitmap: LiveTextPageBitmap

    /// The color a translation is set in: black or white, whichever stands out more.
    var textColor: LiveTextColor {
        color.contrast(with: .white) > color.contrast(with: .black) ? .white : .black
    }

    /// The largest space, centered where `area` is and turned with it, that the balloon has free of
    /// everything but paper and this group's lettering, `padding` page pixels clear of the rest and of
    /// `others`; `area`'s size when the balloon has no larger one.
    ///
    /// A turned room is measured by its upright bounds, which only ever underestimates it.
    func room(around area: LiveTextOrientedRect, padding: Double, avoiding others: [LiveTextOrientedRect]) -> CGSize {
        let table = LiveTextFreeTable(balloon: self, blocking: others.map(bitmapBox(of:)))
        let allowance = Int(Double(bitmapBox(of: area).count) * Self.speckShare)
        func fits(width: Double, height: Double) -> Bool {
            let room = LiveTextOrientedRect(
                center: area.center,
                size: CGSize(width: width, height: height),
                angle: area.angle
            )
            let box = bitmapBox(of: room.expanded(by: padding))
            return box.count - table.freeCount(in: box) <= allowance
        }
        func largest(upTo limit: Double, where isFitting: (Double) -> Bool) -> Double {
            var fitting = 0.0
            var failing = limit
            for _ in 0..<Self.searchSteps {
                let middle = (fitting + failing) / 2
                if isFitting(middle) {
                    fitting = middle
                } else {
                    failing = middle
                }
            }
            return fitting
        }

        let widthLimit = Double(region.box.width) / bitmap.horizontalScale
        let heightLimit = Double(region.box.height) / bitmap.verticalScale
        let shortest = area.size.height / 2
        let widest = largest(upTo: widthLimit) { fits(width: $0, height: shortest) }
        var best = area.size
        for step in 1...Self.roomWidths {
            let width = widest * Double(step) / Double(Self.roomWidths)
            let height = largest(upTo: heightLimit) { fits(width: width, height: $0) }
            if width * height > best.width * best.height {
                best = CGSize(width: width, height: height)
            }
        }
        return best
    }

    /// The group's lettering painted out: its glyphs and their fringe, in the colors of the paper
    /// around them, filled in from the outside, so a gradient or a texture in the paper carries on.
    func paint() -> LiveTextPaint? {
        let glyphBoxes = glyphs.compactMap({ region.holeBoxes[$0]?.expanded(by: Self.fringe) })
        guard let firstBox = glyphBoxes.first,
              let paintBox = glyphBoxes.dropFirst().reduce(firstBox, { $0.union($1) }).intersection(region.box)
        else {
            return nil
        }

        // Every pixel to paint: a glyph's, or one of paper within the fringe of one.
        var isPainted = [Bool](repeating: false, count: paintBox.count)
        for row in paintBox.minRow...paintBox.maxRow {
            for column in paintBox.minColumn...paintBox.maxColumn
            where glyphs.contains(region.hole(column: column, row: row)) {
                guard let near = LiveTextPixelBox(column: column, row: row)
                    .expanded(by: Self.fringe)
                    .intersection(paintBox)
                else {
                    continue
                }
                for nearRow in near.minRow...near.maxRow {
                    for nearColumn in near.minColumn...near.maxColumn where isFree(column: nearColumn, row: nearRow) {
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

    /// Whether the pixel is the balloon's paper or this group's lettering.
    fileprivate func isFree(column: Int, row: Int) -> Bool {
        region.isPaper(column: column, row: row) || glyphs.contains(region.hole(column: column, row: row))
    }

    /// The bitmap pixels covering `rect`'s upright bounds, which may reach beyond the bitmap.
    private func bitmapBox(of rect: LiveTextOrientedRect) -> LiveTextPixelBox {
        LiveTextPixelBox(covering: rect, in: bitmap)
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

    /// The balloon the lettering in `area` sits in, or `nil` when it sits on open paper or busy art.
    ///
    /// Its paper is the color most of `area` is; the balloon is where that paper, flooded from `area`,
    /// spreads. A hole the paper closes around is the group's lettering when it lies within `area`
    /// grown by `margin` page pixels.
    mutating func balloon(around area: LiveTextOrientedRect, margin: Double) -> LiveTextBalloon? {
        let pixels = LiveTextPixelBox(covering: area, in: bitmap).pixels(in: area, of: bitmap)
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
        let grown = area.expanded(by: margin)
        let glyphs = region.holeBoxes.filter({ $0.value.corners(in: bitmap).allSatisfy(grown.contains) }).keys
        return LiveTextBalloon(color: LiveTextColor(paper), region: region, glyphs: Set(glyphs), bitmap: bitmap)
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
        self.box = box
        self.paper = paper
        self.holes = holes.map({ $0 == outside ? 0 : $0 })
        self.holeBoxes = holeBoxes
    }

    func isPaper(column: Int, row: Int) -> Bool {
        box.contains(column: column, row: row) && paper[box.index(column: column, row: row)]
    }

    /// The number of the hole at the pixel, or 0.
    func hole(column: Int, row: Int) -> Int32 {
        box.contains(column: column, row: row) ? holes[box.index(column: column, row: row)] : 0
    }
}

/// How many of a balloon's pixels are free for a translation within any box, read in constant time
/// from running sums.
private struct LiveTextFreeTable {
    private let box: LiveTextPixelBox
    /// The free pixels above and to the left of each corner of `box`'s pixels, row by row.
    private let sums: [Int]

    init(balloon: LiveTextBalloon, blocking blocked: [LiveTextPixelBox]) {
        let box = balloon.region.box
        var isFree = [Bool](repeating: false, count: box.count)
        for row in box.minRow...box.maxRow {
            for column in box.minColumn...box.maxColumn {
                isFree[box.index(column: column, row: row)] = balloon.isFree(column: column, row: row)
            }
        }
        for blockedBox in blocked.compactMap({ $0.intersection(box) }) {
            for row in blockedBox.minRow...blockedBox.maxRow {
                for column in blockedBox.minColumn...blockedBox.maxColumn {
                    isFree[box.index(column: column, row: row)] = false
                }
            }
        }
        let stride = box.width + 1
        var sums = [Int](repeating: 0, count: stride * (box.height + 1))
        for row in 0..<box.height {
            var rowSum = 0
            for column in 0..<box.width {
                rowSum += isFree[row * box.width + column] ? 1 : 0
                sums[(row + 1) * stride + column + 1] = sums[row * stride + column + 1] + rowSum
            }
        }
        self.box = box
        self.sums = sums
    }

    /// The free pixels in `query`; none of its pixels beyond the balloon's box are.
    func freeCount(in query: LiveTextPixelBox) -> Int {
        guard let overlap = query.intersection(box) else {
            return 0
        }
        let stride = box.width + 1
        let left = overlap.minColumn - box.minColumn
        let right = overlap.maxColumn - box.minColumn + 1
        let top = overlap.minRow - box.minRow
        let bottom = overlap.maxRow - box.minRow + 1
        return sums[bottom * stride + right] - sums[top * stride + right]
            - sums[bottom * stride + left] + sums[top * stride + left]
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
