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
    public var name: String {
        switch self {
        case .default:
            return String(localized: .appIconTypeDefault)

        case .ukiyoe:
            return String(localized: .appIconTypeUkiyoe)

        case .developer:
            return String(localized: .appIconTypeDeveloper)

        case .standWithUkraine2022:
            return String(localized: .appIconTypeStandWithUkraine2022)

        case .notMyPresidnet:
            return String(localized: .appIconTypeNotMyPresident)
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
