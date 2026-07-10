import CoreGraphics
import SwiftUI

/// The dominant colors extracted from an image: a `background` plus three accent
/// slots (`primary`, `secondary`, `detail`) chosen for contrast and distinctness.
///
/// App-owned, clean-room reimplementation of the narrow surface of the former
/// `jathu/UIImageColors` package that EhPanda consumes (DEP-02, D-01/D-04/D-16).
/// The color-selection algorithm is preserved verbatim so the returned components
/// stay identical; only the I/O is modernized: a `CGImage` goes in and non-optional
/// SwiftUI `Color`s come out, with no `UIKit` dependency and no force unwraps. Final
/// subjective judgment stays with user verification (D-19).
public struct Colors: Sendable {
    public let background: Color
    public let primary: Color
    public let secondary: Color
    public let detail: Color
}

/// Namespace for dominant-color extraction from a `CGImage`.
public enum ImageColors {
    /// Sampling resolution for `ImageColors.colors(from:quality:)`.
    ///
    /// The raw value is the target edge size, in **pixels**, the image is scaled down
    /// to before its pixels are analyzed; a smaller value trades color accuracy for
    /// speed. `.highest` skips scaling and analyzes the image at its native size.
    public enum Quality: CGFloat, Sendable {
        case lowest = 50
        case low = 100
        case high = 250
        case highest = 0
    }

    /// Extracts the dominant `background`/`primary`/`secondary`/`detail` colors from `cgImage`.
    ///
    /// The image is scaled down per `quality`, its pixels are counted, the most common
    /// edge color becomes the background, and up to three contrasting, mutually distinct
    /// accent colors are chosen; empty accent slots fall back to black text on a light
    /// background or white text on a dark background. Returns `nil` if the image is empty
    /// or a bitmap context cannot be created. Pure and `Sendable`, so it is safe to call
    /// off the main actor.
    public static func colors(from cgImage: CGImage, quality: Quality = .high) -> Colors? {
        let scaled = scaledPixelSize(width: cgImage.width, height: cgImage.height, quality: quality)
        let width = scaled.width
        let height = scaled.height
        guard width > 0, height > 0, let pixels = sampledPixels(from: cgImage, width: width, height: height) else {
            return nil
        }

        let threshold = Int(Double(height) * 0.01)
        var proposed: [Double] = [-1, -1, -1, -1]

        var colorCounts: [Double: Int] = .init()
        for column in 0..<width {
            for row in 0..<height {
                let pixel = ((width * row) + column) * 4
                guard pixels[pixel + 3] >= 127 else { continue }
                let color = (Double(pixels[pixel + 2]) * 1_000_000)
                    + (Double(pixels[pixel + 1]) * 1_000)
                    + Double(pixels[pixel])
                colorCounts[color, default: 0] += 1
            }
        }

        proposed[0] = edgeColor(from: colorCounts, threshold: threshold)
        proposed = accentColors(from: colorCounts, proposed: proposed)

        let isDarkBackground = proposed[0].isDarkColor
        for index in 1...3 where proposed[index] == -1 {
            proposed[index] = isDarkBackground ? 255_255_255 : 0
        }

        return Colors(
            background: proposed[0].color,
            primary: proposed[1].color,
            secondary: proposed[2].color,
            detail: proposed[3].color
        )
    }

    /// Picks the background color: the most common color that clears `threshold`,
    /// skipping a black/white edge in favor of a sufficiently common colored one.
    private static func edgeColor(from colorCounts: [Double: Int], threshold: Int) -> Double {
        let sortedColors = colorCounts
            .filter { $0.value > threshold }
            .map { ColorCounter(color: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        var proposedEdgeColor = sortedColors.first ?? ColorCounter(color: 0, count: 1)
        if proposedEdgeColor.color.isBlackOrWhite, !sortedColors.isEmpty {
            for index in 1..<sortedColors.count {
                let next = sortedColors[index]
                guard Double(next.count) / Double(proposedEdgeColor.count) > 0.3 else { break }
                if !next.color.isBlackOrWhite {
                    proposedEdgeColor = next
                    break
                }
            }
        }
        return proposedEdgeColor.color
    }

    /// Fills the `primary`/`secondary`/`detail` slots of `proposed` (indices 1...3)
    /// with contrasting, mutually distinct colors drawn from the counted colors.
    private static func accentColors(from colorCounts: [Double: Int], proposed: [Double]) -> [Double] {
        var proposed = proposed
        let findDarkTextColor = !proposed[0].isDarkColor

        let candidates = colorCounts.keys
            .map { $0.with(minSaturation: 0.15) }
            .filter { $0.isDarkColor == findDarkTextColor }
            .map { ColorCounter(color: $0, count: colorCounts[$0] ?? 0) }
            .sorted { $0.count > $1.count }

        for candidate in candidates {
            let color = candidate.color
            if proposed[1] == -1 {
                if color.isContrasting(proposed[0]) {
                    proposed[1] = color
                }
            } else if proposed[2] == -1 {
                guard color.isContrasting(proposed[0]), proposed[1].isDistinct(color) else { continue }
                proposed[2] = color
            } else if proposed[3] == -1 {
                guard color.isContrasting(proposed[0]),
                    proposed[2].isDistinct(color),
                    proposed[1].isDistinct(color) else { continue }
                proposed[3] = color
                break
            }
        }
        return proposed
    }

    /// Computes the analysis pixel dimensions for `quality`, scaling the longer edge down
    /// to `quality.rawValue` pixels (preserving aspect ratio); `.highest` keeps native size.
    private static func scaledPixelSize(width: Int, height: Int, quality: Quality) -> (width: Int, height: Int) {
        guard quality != .highest else { return (width, height) }
        let target = quality.rawValue
        if width < height {
            let ratio = CGFloat(height) / CGFloat(width)
            return (Int((target / ratio).rounded()), Int(target.rounded()))
        } else {
            let ratio = CGFloat(width) / CGFloat(height)
            return (Int(target.rounded()), Int((target / ratio).rounded()))
        }
    }

    /// Downsamples `cgImage` into an sRGB, premultiplied-first, little-endian buffer sized
    /// `width`×`height`, returning bytes laid out B, G, R, A per pixel — the layout the packing
    /// math in the `Double` extension expects (`pixels[i]` = blue ... `pixels[i + 3]` = alpha).
    /// A single `CGContext.draw` performs the scale, so the module needs no `UIKit` rasterizer
    /// and stays callable off the main actor.
    private static func sampledPixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerPixel = 4
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}

/// One sampled color (encoded as a packed `Double`, see the `Double` extension below)
/// paired with how many pixels carried it.
private struct ColorCounter {
    let color: Double
    let count: Int
}

/// Colors are packed into a single `Double` as `r * 1_000_000 + g * 1_000 + b`,
/// where each channel is a 0...255 value. This replays the exact packed-color math
/// the historical `UIImageColors` package used so selection output stays identical
/// (DEP-02, D-16). It is intentionally file-private: the packing scheme is meaningless
/// outside dominant-color extraction.
private extension Double {
    var red: Double { fmod(floor(self / 1_000_000), 1_000_000) }
    var green: Double { fmod(floor(self / 1_000), 1_000) }
    var blue: Double { fmod(self, 1_000) }

    var isDarkColor: Bool {
        (red * 0.2126) + (green * 0.7152) + (blue * 0.0722) < 127.5
    }

    var isBlackOrWhite: Bool {
        (red > 232 && green > 232 && blue > 232) || (red < 23 && green < 23 && blue < 23)
    }

    /// The unpacked color as a non-optional sRGB SwiftUI `Color`. Channel values are the
    /// same 0...255 components the algorithm computes, normalized to the 0...1 sRGB range.
    var color: Color {
        Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: 1)
    }

    func isDistinct(_ other: Double) -> Bool {
        let selfRed = red, selfGreen = green, selfBlue = blue
        let otherRed = other.red, otherGreen = other.green, otherBlue = other.blue
        let farApart = fabs(selfRed - otherRed) > 63.75
            || fabs(selfGreen - otherGreen) > 63.75
            || fabs(selfBlue - otherBlue) > 63.75
        let bothNearGray = fabs(selfRed - selfGreen) < 7.65
            && fabs(selfRed - selfBlue) < 7.65
            && fabs(otherRed - otherGreen) < 7.65
            && fabs(otherRed - otherBlue) < 7.65
        return farApart && !bothNearGray
    }

    func isContrasting(_ other: Double) -> Bool {
        let backgroundLuminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue) + 12.75
        let foregroundLuminance = (0.2126 * other.red) + (0.7152 * other.green) + (0.0722 * other.blue) + 12.75
        if backgroundLuminance > foregroundLuminance {
            return 1.6 < backgroundLuminance / foregroundLuminance
        }
        return 1.6 < foregroundLuminance / backgroundLuminance
    }

    /// Returns the same color pushed up to `minSaturation` if it is less saturated,
    /// via an HSV round-trip. Used to give near-gray accent candidates enough color
    /// to be visually usable, matching the original algorithm.
    func with(minSaturation: Double) -> Double {
        let redUnit = red / 255, greenUnit = green / 255, blueUnit = blue / 255
        let maxValue = fmax(redUnit, fmax(greenUnit, blueUnit))
        var chroma = maxValue - fmin(redUnit, fmin(greenUnit, blueUnit))
        let value = maxValue
        let saturation = value == 0 ? 0 : chroma / value

        if minSaturation <= saturation {
            return self
        }

        var hue: Double
        if chroma == 0 {
            hue = 0
        } else if redUnit == maxValue {
            hue = fmod((greenUnit - blueUnit) / chroma, 6)
        } else if greenUnit == maxValue {
            hue = 2 + ((blueUnit - redUnit) / chroma)
        } else {
            hue = 4 + ((redUnit - greenUnit) / chroma)
        }
        if hue < 0 {
            hue += 6
        }

        chroma = value * minSaturation
        let secondary = chroma * (1 - fabs(fmod(hue, 2) - 1))
        var outR: Double
        var outG: Double
        var outB: Double
        switch hue {
        case 0...1:
            outR = chroma
            outG = secondary
            outB = 0
        case 1...2:
            outR = secondary
            outG = chroma
            outB = 0
        case 2...3:
            outR = 0
            outG = chroma
            outB = secondary
        case 3...4:
            outR = 0
            outG = secondary
            outB = chroma
        case 4...5:
            outR = secondary
            outG = 0
            outB = chroma
        case 5..<6:
            outR = chroma
            outG = 0
            outB = secondary
        default:
            outR = 0
            outG = 0
            outB = 0
        }

        let match = value - chroma
        return (floor((outR + match) * 255) * 1_000_000)
            + (floor((outG + match) * 255) * 1_000)
            + floor((outB + match) * 255)
    }
}
