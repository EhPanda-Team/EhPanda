// Draws the pre-check's contact sheets for the agent's visual pass (19-13 Task 1, D-17).
//
// Input, one JSON object per line on standard input:
// `{"out": "sheet-0001.png", "columns": 4, "tile": 400, "tiles": [{"path": "...", "label": "..."}]}`.
// Each picture is scaled to fit a `tile`-pixel square, keeping its proportions, with its label under it; the sheet is
// written as a PNG at `out`. One line of output per sheet: the path written, or `error <path>: <reason>`.
//
// Compiled once by the pre-check (`swiftc -O`).

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Tile: Decodable {
    let path: String
    let label: String
}

struct Sheet: Decodable {
    let out: String
    let columns: Int
    let tile: Int
    let tiles: [Tile]
}

enum SheetError: Error {
    case unreadable(String)
    case noContext
    case notWritten
}

let labelHeight = 40
let gap = 12
let fontSize: CGFloat = 15

func loadImage(at path: String) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw SheetError.unreadable(path) }
    return image
}

func drawLabel(_ text: String, in context: CGContext, at origin: CGPoint, width: CGFloat) {
    let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
    ]
    let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let path = CGPath(rect: CGRect(origin: origin, size: CGSize(width: width, height: CGFloat(labelHeight))),
                      transform: nil)
    CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil), context)
}

func draw(_ sheet: Sheet) throws {
    let rows = (sheet.tiles.count + sheet.columns - 1) / sheet.columns
    let cell = CGSize(width: sheet.tile + gap, height: sheet.tile + labelHeight + gap)
    let size = CGSize(width: CGFloat(sheet.columns) * cell.width + CGFloat(gap),
                      height: CGFloat(rows) * cell.height + CGFloat(gap))
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { throw SheetError.noContext }
    // A mid grey, so neither a light nor a dark picture's edges vanish into the sheet.
    context.setFillColor(CGColor(gray: 0.62, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))
    context.interpolationQuality = .high
    for (index, tile) in sheet.tiles.enumerated() {
        let image = try loadImage(at: tile.path)
        let scale = min(CGFloat(sheet.tile) / CGFloat(image.width), CGFloat(sheet.tile) / CGFloat(image.height))
        let drawn = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let column = index % sheet.columns
        let row = index / sheet.columns
        // Core Graphics counts rows from the bottom; the first tile goes top left.
        let cellOrigin = CGPoint(x: CGFloat(gap) + CGFloat(column) * cell.width,
                                 y: size.height - CGFloat(row + 1) * cell.height)
        let imageOrigin = CGPoint(x: cellOrigin.x + (CGFloat(sheet.tile) - drawn.width) / 2,
                                  y: cellOrigin.y + CGFloat(labelHeight) + (CGFloat(sheet.tile) - drawn.height))
        context.draw(image, in: CGRect(origin: imageOrigin, size: drawn))
        context.setStrokeColor(CGColor(gray: 0.2, alpha: 1))
        context.stroke(CGRect(origin: imageOrigin, size: drawn), width: 1)
        drawLabel(tile.label, in: context, at: cellOrigin, width: CGFloat(sheet.tile))
    }
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: sheet.out) as CFURL, UTType.png.identifier as CFString, 1, nil
          )
    else { throw SheetError.noContext }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw SheetError.notWritten }
}

let decoder = JSONDecoder()
while let input = readLine() {
    guard !input.isEmpty else { continue }
    do {
        let sheet = try decoder.decode(Sheet.self, from: Data(input.utf8))
        do {
            try draw(sheet)
            print(sheet.out)
        } catch {
            print("error \(sheet.out): \(error)")
        }
    } catch {
        print("error <request>: \(error)")
    }
}
