import Resources

public enum ToplistsType: Int, Codable, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case yesterday
    case pastMonth
    case pastYear
    case allTime
}

extension ToplistsType {
    public var value: String {
        switch self {
        case .yesterday:
            return L10n.Localizable.ToplistsType.yesterday
        case .pastMonth:
            return L10n.Localizable.ToplistsType.pastMonth
        case .pastYear:
            return L10n.Localizable.ToplistsType.pastYear
        case .allTime:
            return L10n.Localizable.ToplistsType.allTime
        }
    }
    public var categoryIndex: Int {
        switch self {
        case .yesterday:
            return 15
        case .pastMonth:
            return 13
        case .pastYear:
            return 12
        case .allTime:
            return 11
        }
    }
}
