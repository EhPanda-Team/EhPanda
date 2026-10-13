import CoreGraphics
import Foundation

/// A page image read once into sRGB pixels, row by row from the top left.
struct LiveTextPageBitmap: Sendable {
    /// The longest side the page is read at: the full size of the pages galleries carry, so lettering
    /// is painted out pixel for pixel, while an outsized scan is read smaller.
    static let maximumDimension = 2048

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
        return LiveTextColor(pixels[row * width + column])
    }

    /// The pixel numbered `number`, counting row by row from the top left.
    subscript(pixel number: Int) -> SIMD4<UInt8> {
        pixels[number]
    }

    /// Takes a point on the page to the bitmap.
    var pageToBitmap: CGAffineTransform {
        CGAffineTransform(scaleX: horizontalScale, y: verticalScale)
    }
}

extension LiveTextColor {
    /// The color of an opaque pixel.
    init(_ pixel: SIMD4<UInt8>) {
        self.init(red: Double(pixel.x) / 255, green: Double(pixel.y) / 255, blue: Double(pixel.z) / 255)
    }
}
