import Foundation

public struct ReadingOrientationPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var landscapeDirection: HorizontalReadingDirection
    public var portraitDirection: ReadingDirection

    public init(
        isEnabled: Bool = true,
        landscapeDirection: HorizontalReadingDirection = .rightToLeft,
        portraitDirection: ReadingDirection = .vertical
    ) {
        self.isEnabled = isEnabled
        self.landscapeDirection = landscapeDirection
        self.portraitDirection = portraitDirection
    }
}

public enum HorizontalReadingDirection: Int, Codable, CaseIterable, Identifiable, Sendable {
    case rightToLeft
    case leftToRight

    public var id: Self { self }

    public var readingDirection: ReadingDirection {
        switch self {
        case .rightToLeft: .rightToLeft
        case .leftToRight: .leftToRight
        }
    }
}
