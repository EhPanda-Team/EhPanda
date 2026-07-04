import Foundation
import Resources

public enum AppIconType: Int, Codable, Identifiable, CaseIterable, Sendable {
    public var id: Int { rawValue }

    case `default`
    case ukiyoe
    case developer
    case standWithUkraine2022
    case notMyPresidnet
}

extension AppIconType {
    public var name: LocalizedStringResource {
        switch self {
        case .default:
            return .appIconTypeDefault

        case .ukiyoe:
            return .appIconTypeUkiyoe

        case .developer:
            return .appIconTypeDeveloper

        case .standWithUkraine2022:
            return .appIconTypeStandWithUkraine2022

        case .notMyPresidnet:
            return .appIconTypeNotMyPresident
        }
    }

    public var filename: String {
        switch self {
        case .default:
            return "AppIcon_Default"

        case .ukiyoe:
            return "AppIcon_Ukiyoe"

        case .developer:
            return "AppIcon_Developer"

        case .standWithUkraine2022:
            return "AppIcon_StandWithUkraine2022"

        case .notMyPresidnet:
            return "AppIcon_NotMyPresident"
        }
    }
}
