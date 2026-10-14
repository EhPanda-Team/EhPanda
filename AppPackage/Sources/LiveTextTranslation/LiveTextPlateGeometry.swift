import AppModels
public import CoreGraphics
import Foundation

/// A rectangle turned about its center, in page pixels with the origin at the page's top left.
public struct LiveTextOrientedRect: Equatable, Sendable {
    public var center: CGPoint
    public var size: CGSize
    /// The turn from the page's horizontal, in radians; a positive turn is clockwise on screen.
    public var angle: Double

    public init(center: CGPoint, size: CGSize, angle: Double) {
        self.center = center
        self.size = size
        self.angle = angle
    }

    /// This rectangle with `margin` added on every side.
    func expanded(by margin: Double) -> Self {
        Self(
            center: center,
            size: CGSize(width: size.width + margin * 2, height: size.height + margin * 2),
            angle: angle
        )
    }

    /// This rectangle scaled by `factor` about its center.
    func scaled(by factor: Double) -> Self {
        Self(center: center, size: CGSize(width: size.width * factor, height: size.height * factor), angle: angle)
    }

    /// The rectangle unturned and centered on the origin, the space its contents are drawn in.
    var localBounds: CGRect {
        CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    }

    /// Takes a point of ``localBounds`` to the page.
    var transform: CGAffineTransform {
        CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: center.x, y: center.y))
    }

    /// The corners on the page, clockwise from the top left as turned.
    var corners: [CGPoint] {
        let bounds = localBounds
        return [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
            CGPoint(x: bounds.minX, y: bounds.maxY)
        ]
        .map({ $0.applying(transform) })
    }

    /// The upright rectangle around the corners.
    var boundingBox: CGRect {
        corners.reduce(CGRect.null, { $0.union(CGRect(origin: $1, size: .zero)) })
    }

    /// Whether `point`, on the page, lies in the rectangle.
    func contains(_ point: CGPoint) -> Bool {
        localBounds.contains(point.applying(transform.inverted()))
    }

    /// How far `point`, on the page, lies from the rectangle; 0 inside it.
    func distance(to point: CGPoint) -> Double {
        let local = point.applying(transform.inverted())
        let bounds = localBounds
        let across = Swift.max(bounds.minX - local.x, 0, local.x - bounds.maxX)
        let down = Swift.max(bounds.minY - local.y, 0, local.y - bounds.maxY)
        return hypot(across, down)
    }
}

/// Where a recognized group sits on its page: the rectangle its lines fill, turned with them.
struct LiveTextGroupGeometry: Equatable, Sendable {
    /// The steepest turn a translation keeps. Steeper lettering, such as vertical CJK text, is laid out
    /// level in the group's upright bounds, as a translation is read across.
    static let maximumAngle = Double.pi / 4

    let textRect: LiveTextOrientedRect
    /// The median height of the group's lines, the measure of its lettering's size.
    let lineHeight: Double

    init?(group: LiveTextGroup, pageSize: CGSize) {
        let lines = group.blocks.map({ PixelLine(bounds: $0.bounds, pageSize: pageSize) })
        let sine = lines.map({ sin($0.angle) }).reduce(0, +)
        let cosine = lines.map({ cos($0.angle) }).reduce(0, +)
        guard !lines.isEmpty, sine.isFinite, cosine.isFinite, let lineHeight = lines.map(\.height).median else {
            return nil
        }
        let meanAngle = atan2(sine, cosine)
        let angle = abs(meanAngle) <= Self.maximumAngle ? meanAngle : 0
        let across = CGVector(dx: cos(angle), dy: sin(angle))
        let down = CGVector(dx: -sin(angle), dy: cos(angle))
        let corners = lines.flatMap(\.corners)
        let alongAcross = corners.map({ $0.x * across.dx + $0.y * across.dy })
        let alongDown = corners.map({ $0.x * down.dx + $0.y * down.dy })
        guard let left = alongAcross.min(), let right = alongAcross.max(),
              let top = alongDown.min(), let bottom = alongDown.max(),
              left < right, top < bottom, lineHeight > 0
        else {
            return nil
        }
        let middleAcross = (left + right) / 2
        let middleDown = (top + bottom) / 2
        let center = CGPoint(
            x: across.dx * middleAcross + down.dx * middleDown,
            y: across.dy * middleAcross + down.dy * middleDown
        )
        textRect = LiveTextOrientedRect(
            center: center,
            size: CGSize(width: right - left, height: bottom - top),
            angle: angle
        )
        self.lineHeight = lineHeight
    }
}

/// A recognized line's corners in page pixels, where its angle is true to the page's aspect.
private struct PixelLine {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint

    init(bounds: LiveTextBounds, pageSize: CGSize) {
        func pixel(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * pageSize.width, y: point.y * pageSize.height)
        }
        topLeft = pixel(bounds.topLeft)
        topRight = pixel(bounds.topRight)
        bottomRight = pixel(bounds.bottomRight)
        bottomLeft = pixel(bounds.bottomLeft)
    }

    var corners: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    var angle: Double {
        atan2(topRight.y - topLeft.y, topRight.x - topLeft.x)
    }

    var height: Double {
        hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)
    }
}

extension Array where Element == Double {
    /// The middle value, or the lower of the two middle ones; `nil` for no values.
    var median: Double? {
        let values = sorted()
        return values.dropFirst((values.count - 1) / 2).first
    }
}
