import CoreGraphics
import Foundation

/// A color on the page, as sRGB components from 0 to 1.
public struct LiveTextColor: Equatable, Sendable {
    public static let white = Self(red: 1, green: 1, blue: 1)
    public static let black = Self(red: 0, green: 0, blue: 0)

    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The relative luminance WCAG 2 defines.
    var luminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The WCAG 2 contrast ratio with `other`, from 1 to 21.
    func contrast(with other: Self) -> Double {
        let lighter = Swift.max(luminance, other.luminance)
        let darker = Swift.min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The largest difference in any one component.
    func distance(to other: Self) -> Double {
        Swift.max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
    }
}

/// How a translated region is painted.
public enum LiveTextFill: Equatable, Sendable {
    /// The region's surroundings are one color, as in a speech balloon or a caption box: the region is
    /// painted that color, so it blends in, and the text is black or white, whichever stands out more.
    case background(LiveTextColor, text: LiveTextColor)
    /// The region sits on busy art: a white plate with a soft shadow carries black text, as Live Text
    /// has always drawn its regions.
    case plate

    /// The color the translation is set in.
    public var textColor: LiveTextColor {
        switch self {
        case .background(_, let text):
            text
        case .plate:
            .black
        }
    }
}

/// A page image read once into sRGB pixels, small enough to sample quickly.
struct LiveTextPageBitmap: Sendable {
    /// The longest side the page is read at. Sampling surroundings needs color, not detail.
    static let maximumDimension = 1024

    let width: Int
    let height: Int
    /// Bitmap pixels per page pixel, across and down.
    let horizontalScale: Double
    let verticalScale: Double
    private let pixels: [SIMD4<UInt8>]

    /// The page read onto white, so a transparent page samples as the white it sits on.
    init?(image: CGImage) {
        let longestSide = Swift.max(image.width, image.height)
        guard longestSide > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let scale = Swift.min(1, Double(Self.maximumDimension) / Double(longestSide))
        let width = Swift.max(1, Int((Double(image.width) * scale).rounded()))
        let height = Swift.max(1, Int((Double(image.height) * scale).rounded()))
        var pixels = [SIMD4<UInt8>](repeating: .zero, count: width * height)
        let isDrawn = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * MemoryLayout<SIMD4<UInt8>>.stride,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            context.fill(bounds)
            context.interpolationQuality = .medium
            context.draw(image, in: bounds)
            return true
        }
        guard isDrawn else {
            return nil
        }
        self.width = width
        self.height = height
        horizontalScale = Double(width) / Double(image.width)
        verticalScale = Double(height) / Double(image.height)
        self.pixels = pixels
    }

    /// The color at `point` in page pixels, or `nil` off the page.
    func color(at point: CGPoint) -> LiveTextColor? {
        let column = Int((point.x * horizontalScale).rounded(.down))
        let row = Int((point.y * verticalScale).rounded(.down))
        guard (0..<width).contains(column), (0..<height).contains(row) else {
            return nil
        }
        let pixelNumber = row * width + column
        guard pixels.indices.contains(pixelNumber) else {
            return nil
        }
        let pixel = pixels[pixelNumber]
        return LiveTextColor(red: Double(pixel.x) / 255, green: Double(pixel.y) / 255, blue: Double(pixel.z) / 255)
    }
}

enum LiveTextPlateSampler {
    /// How far outside a plate its surroundings are read, in line heights: just beyond the plate and a
    /// little further out, so lettering the plate covers is not read and nearby art is.
    static let ringMargins = [0.15, 0.4]
    /// The share of the surroundings that must match their median for the region to count as one color.
    /// A share rather than a variance, so a balloon's outline crossing the ring does not turn a white
    /// balloon into a plate.
    static let uniformShare = 0.85
    /// How far, in any one component, a sample may stray from the median and still match it, enough
    /// for JPEG noise and paper texture.
    static let tolerance = 0.06
    /// Fewer samples than this, as on a region at the page's edge, do not tell its surroundings.
    static let minimumSampleCount = 16

    static func fill(
        around plate: LiveTextOrientedRect,
        lineHeight: Double,
        on bitmap: LiveTextPageBitmap
    ) -> LiveTextFill {
        let step = 2 / Swift.max(bitmap.horizontalScale, bitmap.verticalScale)
        let samples = ringMargins
            .flatMap({ perimeter(of: plate.expanded(by: $0 * lineHeight), step: step) })
            .compactMap(bitmap.color(at:))
        guard samples.count >= minimumSampleCount,
              let red = samples.map(\.red).median,
              let green = samples.map(\.green).median,
              let blue = samples.map(\.blue).median
        else {
            return .plate
        }
        let background = LiveTextColor(red: red, green: green, blue: blue)
        let matching = samples.filter({ $0.distance(to: background) <= tolerance }).count
        guard Double(matching) >= Double(samples.count) * uniformShare else {
            return .plate
        }
        let isDark = background.contrast(with: .white) > background.contrast(with: .black)
        return .background(background, text: isDark ? .white : .black)
    }

    /// Points `step` apart along the outline of `rect`.
    private static func perimeter(of rect: LiveTextOrientedRect, step: Double) -> [CGPoint] {
        let corners = rect.corners
        return zip(corners, corners.dropFirst() + corners.prefix(1)).flatMap { start, end in
            let count = Swift.max(1, Int(hypot(end.x - start.x, end.y - start.y) / step))
            return (0..<count).map { stepNumber in
                let fraction = Double(stepNumber) / Double(count)
                return CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
            }
        }
    }
}
