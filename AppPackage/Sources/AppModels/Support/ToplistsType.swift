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
            return String(localized: .toplistsTypeYesterday)
        case .pastMonth:
            return String(localized: .toplistsTypePastMonth)
        case .pastYear:
            return String(localized: .toplistsTypePastYear)
        case .allTime:
            return String(localized: .toplistsTypeAllTime)
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
