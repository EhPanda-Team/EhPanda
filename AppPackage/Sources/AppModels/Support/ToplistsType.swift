import Foundation
import Resources

public enum ToplistsType: Int, Codable, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case yesterday
    case pastMonth
    case pastYear
    case allTime
}

extension ToplistsType {
    public var value: LocalizedStringResource {
        switch self {
        case .yesterday:
            return .toplistsTypeYesterday
        case .pastMonth:
            return .toplistsTypePastMonth
        case .pastYear:
            return .toplistsTypePastYear
        case .allTime:
            return .toplistsTypeAllTime
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
