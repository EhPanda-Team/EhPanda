import CoreGraphics

/// Device capabilities are separate from the current window's available space.
public enum WindowDevice: Equatable, Sendable {
    case other
    case pad
    case duo(HingeState)

    public enum HingeState: Equatable, Sendable {
        case closed
        case partiallyOpen
        case fullyOpen
    }

    public var supportsAutomaticLayout: Bool { self != .other }

    public func supportsLandscapePanes(in size: CGSize) -> Bool {
        guard size.width.isFinite, size.height.isFinite, size.height > 0, size.width > size.height else {
            return false
        }
        switch self {
        case .pad, .duo(.partiallyOpen), .duo(.fullyOpen): return true
        case .other, .duo(.closed): return false
        }
    }
}
