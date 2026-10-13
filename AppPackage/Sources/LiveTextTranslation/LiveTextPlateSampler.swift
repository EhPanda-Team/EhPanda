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
    /// The region's lettering sits in a balloon, a caption box or another closed region of one color,
    /// and the translation fits in it: the lettering is painted out in the colors around it, which
    /// leaves the balloon whole, and the text is black or white, whichever stands out more.
    case balloon(LiveTextPaint, text: LiveTextColor)
    /// The region's surroundings are one color, as on a page's plain margin: the region is painted that
    /// color, so it blends in, and the text is black or white, whichever stands out more.
    case background(LiveTextColor, text: LiveTextColor)
    /// The region sits on busy art: a white plate with a soft shadow carries black text, as Live Text
    /// has always drawn its regions.
    case plate

    /// The color the translation is set in.
    public var textColor: LiveTextColor {
        switch self {
        case .balloon(_, let text), .background(_, let text):
            text
        case .plate:
            .black
        }
    }
}

enum LiveTextPlateSampler {
    /// How far outside a plate its surroundings are read, in line heights, nearest first: just beyond
    /// the plate, which a plate must match to blend in, and a little further out, past lettering
    /// strokes that spill beyond the recognized lines.
    static let ringMargins = [0.15, 0.4]
    /// The share of a ring that must match its median for the ring to count as one color. A share
    /// rather than a variance, so a balloon's outline crossing the ring does not turn a white balloon
    /// into a plate.
    static let uniformShare = 0.85
    /// How far, in any one component, a sample may stray from the median and still match it, enough
    /// for JPEG noise and paper texture.
    static let tolerance = 0.06
    /// Fewer samples than this, as on a region at the page's edge, do not tell its surroundings.
    static let minimumSampleCount = 16

    /// The color of the nearest ring around `plate` that is one color, or a plate when none is. Each
    /// ring is judged alone, so a caption box only a little larger than its lettering keeps its color.
    static func fill(
        around plate: LiveTextOrientedRect,
        lineHeight: Double,
        on bitmap: LiveTextPageBitmap
    ) -> LiveTextFill {
        let step = 2 / Swift.max(bitmap.horizontalScale, bitmap.verticalScale)
        for margin in ringMargins {
            let ring = perimeter(of: plate.expanded(by: margin * lineHeight), step: step)
            if let background = uniformColor(of: ring.compactMap(bitmap.color(at:))) {
                let isDark = background.contrast(with: .white) > background.contrast(with: .black)
                return .background(background, text: isDark ? .white : .black)
            }
        }
        return .plate
    }

    /// The median of `samples` when enough of them match it.
    private static func uniformColor(of samples: [LiveTextColor]) -> LiveTextColor? {
        guard samples.count >= minimumSampleCount,
              let red = samples.map(\.red).median,
              let green = samples.map(\.green).median,
              let blue = samples.map(\.blue).median
        else {
            return nil
        }
        let median = LiveTextColor(red: red, green: green, blue: blue)
        let matching = samples.filter({ $0.distance(to: median) <= tolerance }).count
        return Double(matching) >= Double(samples.count) * uniformShare ? median : nil
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
