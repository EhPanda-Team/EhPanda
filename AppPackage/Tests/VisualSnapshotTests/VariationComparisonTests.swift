import Foundation
import UIKit
import VisualSnapshotSupport
import XCTest

/// One line of a pairs file (``VariationComparisonTests/testComparesPairs()``): the key and its picture in run A and in
/// run B.
private struct VariationPair: Decodable {
    enum CodingKeys: String, CodingKey {
        case key
        case pictureA = "a"
        case pictureB = "b"
    }

    let key: String
    let pictureA: String
    let pictureB: String
}

/// Compares two runs' pictures key by key with the matrix's own comparison (19-27, D-10), for the run-to-run
/// variation (`Scripts/visual/snapshot_variation.py`).
///
/// Every verdict comes from ``HostedWindowCapture``: the pixels it reads (``HostedWindowCapture/comparedBytes(_:)``)
/// and its comparison (``HostedWindowCapture/compare(_:reference:)``), with no tolerance of its own. Run A's picture is
/// the reference and run B's stands for B's capture: a PNG is lossless, so the file holds the picture B's run captured.
/// The region, the largest channel step and the differing bytes describe a difference; they never decide one.
///
/// `testComparesPairs` runs only with `EHPANDA_VARIATION_PAIRS` (a JSON Lines file of `key`, `a` and `b` picture
/// paths) and `EHPANDA_VARIATION_OUTPUT` (a directory): it writes one line per pair, in order, to `outcomes.jsonl`
/// and each `beyond-tolerance` key's difference picture to `difference/<key>.png`.
final class VariationComparisonTests: XCTestCase {
    /// How one pair compared.
    enum Kind: String, Codable {
        case identicalPixels = "identical-pixels"
        case withinTolerance = "within-tolerance"
        case beyondTolerance = "beyond-tolerance"
        case sizeDiffers = "size-differs"
        case unreadable
    }

    /// One line of `outcomes.jsonl`.
    struct Outcome: Codable, Equatable {
        let key: String
        let outcome: Kind
        /// The bounding box of the differing pixels, ``HostedWindowCapture/changedRegion(_:_:width:)``.
        var region: String?
        /// The largest difference of one channel byte between the two pictures.
        var largestStep: Int?
        /// How many channel bytes differ.
        var differingBytes: Int?
    }

    /// A compared pair and, for `beyond-tolerance`, the comparison's difference picture.
    struct Comparison {
        let outcome: Outcome
        let difference: Data?
    }

    @MainActor
    func testOutcomes() throws {
        let directory = try Self.temporaryDirectory()
        let base = Self.pixels(width: 200, height: 200)
        var oneStep = base
        oneStep[0] += 1
        var block = base
        for row in 40..<60 {
            for column in 30..<50 {
                let start = (row * 200 + column) * 4
                block.replaceSubrange(start..<(start + 3), with: [10, 200, 30])
            }
        }
        for (name, bytes) in ["reference": base, "same": base, "step": oneStep, "block": block] {
            try Self.pngData(of: bytes, width: 200, height: 200).write(to: directory.appending(path: "\(name).png"))
        }
        try Self.pngData(of: Self.pixels(width: 200, height: 201), width: 200, height: 201)
            .write(to: directory.appending(path: "taller.png"))
        try Data("not a picture".utf8).write(to: directory.appending(path: "broken.png"))
        func compared(_ name: String) throws -> Comparison {
            try Self.compare(
                key: name, pictureA: directory.appending(path: "reference.png"),
                pictureB: directory.appending(path: "\(name).png")
            )
        }

        XCTAssertEqual(try compared("same").outcome.outcome, .identicalPixels)
        let step = try compared("step")
        XCTAssertEqual(step.outcome.outcome, .withinTolerance)
        XCTAssertEqual(step.outcome.largestStep, 1)
        XCTAssertEqual(step.outcome.differingBytes, 1)
        let changed = try compared("block")
        XCTAssertEqual(changed.outcome.outcome, .beyondTolerance)
        XCTAssertEqual(changed.outcome.region, "pixels:30,40,20x20")
        XCTAssertNotNil(changed.difference)
        XCTAssertEqual(try compared("taller").outcome.outcome, .sizeDiffers)
        XCTAssertEqual(try compared("broken").outcome.outcome, .unreadable)
        XCTAssertThrowsError(try compared("absent"))
    }

    @MainActor
    func testComparesPairs() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let pairs = environment["EHPANDA_VARIATION_PAIRS"], let output = environment["EHPANDA_VARIATION_OUTPUT"]
        else {
            throw XCTSkip("Pairs are compared only with EHPANDA_VARIATION_PAIRS and EHPANDA_VARIATION_OUTPUT")
        }
        let out = URL(filePath: output, directoryHint: .isDirectory)
        let differences = out.appending(path: "difference", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: differences, withIntermediateDirectories: true)
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var lines = Data()
        let text = try String(contentsOf: URL(filePath: pairs), encoding: .utf8)
        for line in text.split(separator: "\n") where !line.allSatisfy(\.isWhitespace) {
            let pair = try decoder.decode(VariationPair.self, from: Data(line.utf8))
            let comparison = try Self.compare(
                key: pair.key, pictureA: URL(filePath: pair.pictureA), pictureB: URL(filePath: pair.pictureB)
            )
            if let difference = comparison.difference {
                try difference.write(to: differences.appending(path: "\(pair.key).png"))
            }
            lines.append(try encoder.encode(comparison.outcome))
            lines.append(Data("\n".utf8))
        }
        try lines.write(to: out.appending(path: "outcomes.jsonl"))
    }

    /// Compares B's picture with A's, A being the reference; throws when either file cannot be read, so a wrong path
    /// fails the run instead of being classed with the files that are not pictures.
    @MainActor
    static func compare(key: String, pictureA: URL, pictureB: URL) throws -> Comparison {
        let unreadable = Comparison(outcome: Outcome(key: key, outcome: .unreadable), difference: nil)
        guard let reference = try image(at: pictureA), let actual = try image(at: pictureB),
              let old = HostedWindowCapture.comparedBytes(reference),
              let new = HostedWindowCapture.comparedBytes(actual),
              let oldImage = reference.cgImage, let newImage = actual.cgImage
        else { return unreadable }
        guard oldImage.width == newImage.width, oldImage.height == newImage.height else {
            return Comparison(outcome: Outcome(key: key, outcome: .sizeDiffers), difference: nil)
        }
        guard old != new else {
            return Comparison(outcome: Outcome(key: key, outcome: .identicalPixels), difference: nil)
        }
        let steps = Self.steps(old, new)
        let region = HostedWindowCapture.changedRegion(old, new, width: newImage.width)
        switch HostedWindowCapture.compare(actual, reference: pictureA) {
        case .passed:
            let outcome = Outcome(
                key: key, outcome: .withinTolerance, region: region, largestStep: steps.largest,
                differingBytes: steps.differing
            )
            return Comparison(outcome: outcome, difference: nil)
        case .changed(let difference):
            let outcome = Outcome(
                key: key, outcome: .beyondTolerance, region: region, largestStep: steps.largest,
                differingBytes: steps.differing
            )
            return Comparison(outcome: outcome, difference: difference)
        case .missingBaseline, .unreadableBaseline:
            return unreadable
        }
    }

    /// The picture at `url` at scale 1, as the matrix stores and reads its pictures; `nil` when the file is not one.
    private static func image(at url: URL) throws -> UIImage? {
        UIImage(data: try Data(contentsOf: url), scale: 1)
    }

    /// The largest channel step and the number of differing bytes of two reads of the same size, comparing whole
    /// blocks first: the test build is unoptimised and a read is millions of bytes.
    private static func steps(_ old: [UInt8], _ new: [UInt8]) -> (largest: Int, differing: Int) {
        var largest = 0
        var differing = 0
        let block = 256
        old.withUnsafeBytes { oldBytes in
            new.withUnsafeBytes { newBytes in
                for start in stride(from: 0, to: oldBytes.count, by: block) {
                    let range = start..<min(start + block, oldBytes.count)
                    let oldBlock = UnsafeRawBufferPointer(rebasing: oldBytes[range])
                    let newBlock = UnsafeRawBufferPointer(rebasing: newBytes[range])
                    if memcmp(oldBlock.baseAddress, newBlock.baseAddress, range.count) == 0 { continue }
                    for (oldByte, newByte) in zip(oldBlock, newBlock) where oldByte != newByte {
                        largest = max(largest, abs(Int(oldByte) - Int(newByte)))
                        differing += 1
                    }
                }
            }
        }
        return (largest, differing)
    }

    /// An opaque picture of one colour, as 8-bit sRGB premultiplied RGBA bytes.
    private static func pixels(width: Int, height: Int) -> [UInt8] {
        Array([[UInt8]](repeating: [100, 120, 140, 255], count: width * height).joined())
    }

    /// The PNG the matrix would store for the picture `bytes` hold.
    @MainActor
    private static func pngData(of bytes: [UInt8], width: Int, height: Int) throws -> Data {
        var bytes = bytes
        let image = bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
            return CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        return HostedWindowCapture.pngData(UIImage(cgImage: try XCTUnwrap(image), scale: 1, orientation: .up))
    }

    private static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(component: "ehp19-variation-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
