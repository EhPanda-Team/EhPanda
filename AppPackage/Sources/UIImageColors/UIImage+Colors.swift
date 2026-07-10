import UIKit

/// One sampled color (encoded as a packed `Double`, see `Double` extension below)
/// paired with how many pixels carried it.
private struct UIImageColorsCounter {
    let color: Double
    let count: Int
}

/// Colors are packed into a single `Double` as `r * 1_000_000 + g * 1_000 + b`,
/// where each channel is a 0...255 value. This extension replays the exact
/// packed-color math the historical `UIImageColors` package used so selection
/// output stays identical (DEP-02, D-16). It is intentionally file-private: the
/// packing scheme is meaningless outside dominant-color extraction.
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

    var uiColor: UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
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

extension UIImage {
    /// Analyzes the image on the calling thread and delivers the result to
    /// `completion`. Kept for API parity with the historical package; EhPanda calls
    /// this from an already-backgrounded async boundary (`LibraryClient`), so the
    /// work no longer needs its own dispatch hop.
    public func getColors(quality: UIImageColorsQuality = .high, _ completion: (UIImageColors?) -> Void) {
        completion(getColors(quality: quality))
    }

    /// Extracts the dominant `background`/`primary`/`secondary`/`detail` colors.
    ///
    /// The image is scaled down per `quality`, its pixels are counted, the most
    /// common edge color becomes the background, and up to three contrasting,
    /// mutually distinct accent colors are chosen; empty accent slots fall back to
    /// black text on a light background or white text on a dark background.
    public func getColors(quality: UIImageColorsQuality = .high) -> UIImageColors? {
        var scaleDownSize = size
        if quality != .highest {
            if size.width < size.height {
                let ratio = size.height / size.width
                scaleDownSize = CGSize(width: quality.rawValue / ratio, height: quality.rawValue)
            } else {
                let ratio = size.width / size.height
                scaleDownSize = CGSize(width: quality.rawValue, height: quality.rawValue / ratio)
            }
        }

        guard let cgImage = resizedForColorAnalysis(to: scaleDownSize)?.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
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

        return UIImageColors(
            background: proposed[0].uiColor,
            primary: proposed[1].uiColor,
            secondary: proposed[2].uiColor,
            detail: proposed[3].uiColor
        )
    }

    /// Picks the background color: the most common color that clears `threshold`,
    /// skipping a black/white edge in favor of a sufficiently common colored one.
    private func edgeColor(from colorCounts: [Double: Int], threshold: Int) -> Double {
        let sortedColors = colorCounts
            .filter { $0.value > threshold }
            .map { UIImageColorsCounter(color: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        var proposedEdgeColor = sortedColors.first ?? UIImageColorsCounter(color: 0, count: 1)
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
    private func accentColors(from colorCounts: [Double: Int], proposed: [Double]) -> [Double] {
        var proposed = proposed
        let findDarkTextColor = !proposed[0].isDarkColor

        let candidates = colorCounts.keys
            .map { $0.with(minSaturation: 0.15) }
            .filter { $0.isDarkColor == findDarkTextColor }
            .map { UIImageColorsCounter(color: $0, count: colorCounts[$0] ?? 0) }
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

    /// Scales the image down for analysis, matching the legacy device-scale, non-opaque,
    /// standard-range rasterization so sampled pixels stay equivalent to the old context.
    private func resizedForColorAnalysis(to newSize: CGSize) -> UIImage? {
        guard newSize.width > 0, newSize.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Draws `cgImage` into an sRGB, premultiplied-first, little-endian buffer so the
    /// returned bytes are laid out B, G, R, A per pixel — the layout the packing math
    /// in the `Double` extension expects (`pixels[i]` = blue ... `pixels[i + 3]` = alpha).
    private func sampledPixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
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
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
