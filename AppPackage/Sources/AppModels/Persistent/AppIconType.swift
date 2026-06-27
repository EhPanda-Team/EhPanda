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
            return L10n.Localizable.Enum.AppIconType.Value.default

        case .ukiyoe:
            return L10n.Localizable.Enum.AppIconType.Value.ukiyoe

        case .developer:
            return L10n.Localizable.Enum.AppIconType.Value.developer

        case .standWithUkraine2022:
            return L10n.Localizable.Enum.AppIconType.Value.standWithUkraine2022

        case .notMyPresidnet:
            return L10n.Localizable.Enum.AppIconType.Value.notMyPresident
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
