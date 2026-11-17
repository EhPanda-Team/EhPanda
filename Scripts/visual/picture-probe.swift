// Reads the text and the pixel statistics of candidate pictures for `snapshot_precheck.py` (19-13 Task 1, D-17).
//
// Input, one JSON object per line on standard input: `{"path": "...", "languages": ["ja-JP", "en-US"]}`.
// Output, one JSON object per line on standard output, in the same order:
// `{"path", "width", "height", "lumaDeviation", "dominantShare", "grayRectangles", "lines"}`, or `{"path", "error"}`.
//
// - `lumaDeviation` is the standard deviation of the luminance (0 to 255) and `dominantShare` the share of the most
//   common colour (5 bits a channel): a blank or near-uniform picture has a tiny deviation or a share near 1.
// - `grayRectangles` are the solid rectangles of the colour of the app's image placeholder (`systemGray5` in light
//   and dark), at least `minimumSide` pixels a side: where an image failed to load, the app draws one with a spinner.
// - `lines` is Vision's text, read at twice the picture's size so the smallest text size is legible, with the
//   first language first (the first recognition language picks the model) and a minimum text height far under
//   Vision's default of 1/32 of the image, which misses body text on the iPad.
//
// Compiled once by the pre-check (`swiftc -O`), then run as several processes at a time.

import CoreGraphics
import Foundation
import ImageIO
import Vision

struct Request: Decodable {
    let path: String
    let languages: [String]
}

struct Rectangle: Encodable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let color: String
}

struct Line: Encodable {
    let text: String
    let confidence: Float
    let box: [Double]
}

struct Probe: Encodable {
    let path: String
    let width: Int
    let height: Int
    let lumaDeviation: Double
    let dominantShare: Double
    let grayRectangles: [Rectangle]
    let lines: [Line]
}

struct Failure: Encodable {
    let path: String
    let error: String
}

enum ProbeError: Error {
    case unreadable
    case noContext
}

/// The placeholder colour, `UIColor.systemGray5`, as drawn in light and dark.
let placeholderColors: [(name: String, red: Int, green: Int, blue: Int)] = [
    ("systemGray5-light", 229, 229, 234), ("systemGray5-dark", 44, 44, 46)
]
let minimumSide = 24
let ocrScale = 2

func loadImage(at path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ProbeError.unreadable }
    return image
}

/// The image's pixels as sRGB RGBA, 8 bits a channel, rows top first.
func pixels(of image: CGImage) throws -> [UInt8] {
    let width = image.width
    let height = image.height
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { throw ProbeError.noContext }
    return buffer
}

func statistics(of buffer: [UInt8], count: Int) -> (deviation: Double, dominantShare: Double) {
    var sum = 0.0
    var squares = 0.0
    var histogram = [Int: Int]()
    for index in 0..<count {
        let red = Int(buffer[index * 4])
        let green = Int(buffer[index * 4 + 1])
        let blue = Int(buffer[index * 4 + 2])
        let luma = 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
        sum += luma
        squares += luma * luma
        histogram[(red >> 3) << 10 | (green >> 3) << 5 | blue >> 3, default: 0] += 1
    }
    let mean = sum / Double(count)
    let variance = max(0, squares / Double(count) - mean * mean)
    return (variance.squareRoot(), Double(histogram.values.max() ?? 0) / Double(count))
}

/// Solid rectangles of one colour: rows whose run of that colour, at least `minimumSide` wide, overlaps the run of
/// the row above, stacked at least `minimumSide` high. A spinner splits a row's run; the rows above and below it
/// still hold the rectangle's full width.
func rectangles(in buffer: [UInt8], width: Int, height: Int) -> [Rectangle] {
    var found = [Rectangle]()
    for color in placeholderColors {
        var open: (top: Int, left: Int, right: Int)?
        func close(at row: Int) {
            if let current = open, row - current.top >= minimumSide {
                found.append(Rectangle(x: current.left, y: current.top, width: current.right - current.left,
                                       height: row - current.top, color: color.name))
            }
            open = nil
        }
        for row in 0..<height {
            var best: (left: Int, right: Int)?
            var start: Int?
            for column in 0...width {
                let matches = column < width && {
                    let offset = (row * width + column) * 4
                    return abs(Int(buffer[offset]) - color.red) <= 1 && abs(Int(buffer[offset + 1]) - color.green) <= 1
                        && abs(Int(buffer[offset + 2]) - color.blue) <= 1
                }()
                if matches, start == nil {
                    start = column
                } else if !matches, let left = start {
                    if column - left >= minimumSide, column - left > (best.map({ $0.right - $0.left }) ?? 0) {
                        best = (left, column)
                    }
                    start = nil
                }
            }
            if let run = best, let current = open, run.left < current.right, current.left < run.right {
                open = (current.top, max(current.left, run.left), min(current.right, run.right))
            } else {
                close(at: row)
                if let run = best {
                    open = (row, run.left, run.right)
                }
            }
        }
        close(at: height)
    }
    return found
}

func scaled(_ image: CGImage, by factor: Int) throws -> CGImage {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil, width: image.width * factor, height: image.height * factor, bitsPerComponent: 8,
            bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { throw ProbeError.noContext }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width * factor, height: image.height * factor))
    guard let result = context.makeImage() else { throw ProbeError.noContext }
    return result
}

func text(in image: CGImage, languages: [String]) async throws -> [Line] {
    var request = RecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = languages.map { Locale.Language(identifier: $0) }
    request.usesLanguageCorrection = true
    request.minimumTextHeightFraction = 0.008
    let observations = try await request.perform(on: try scaled(image, by: ocrScale))
    return observations.compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox.cgRect
        return Line(text: candidate.string, confidence: candidate.confidence,
                    box: [box.origin.x, box.origin.y, box.width, box.height])
    }
}

func probe(_ request: Request) async throws -> Probe {
    let image = try loadImage(at: request.path)
    let buffer = try pixels(of: image)
    let stats = statistics(of: buffer, count: image.width * image.height)
    return Probe(
        path: request.path, width: image.width, height: image.height, lumaDeviation: stats.deviation,
        dominantShare: stats.dominantShare,
        grayRectangles: rectangles(in: buffer, width: image.width, height: image.height),
        lines: try await text(in: image, languages: request.languages)
    )
}

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
while let input = readLine() {
    guard !input.isEmpty else { continue }
    let output: Data
    do {
        let request = try decoder.decode(Request.self, from: Data(input.utf8))
        do {
            output = try encoder.encode(try await probe(request))
        } catch {
            output = try encoder.encode(Failure(path: request.path, error: String(describing: error)))
        }
    } catch {
        output = Data(#"{"error":"unreadable request"}"#.utf8)
    }
    FileHandle.standardOutput.write(output + Data("\n".utf8))
}
