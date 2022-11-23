//
//  TagCategory.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

enum TagNamespace: String, Codable, CaseIterable {
    case reclass
    case language
    case parody
    case character
    case group
    case artist
    case male
    case female
    case mixed
    case cosplayer
    case other
    case temp

    static let abbreviations: [String: String] = {
        let tuples: [(String, String)] = allCases.compactMap {
            if let abbreviation = $0.abbreviation {
                return ($0.rawValue, abbreviation)
            } else {
                return nil
            }
        }
        return [String: String](uniqueKeysWithValues: tuples)
    }()
}

extension TagNamespace {
    var weight: Float {
        switch self {
        case .reclass:
            return 1
        case .language:
            return 2
        case .parody:
            return 3.3
        case .character:
            return 2.8
        case .group:
            return 2.2
        case .artist:
            return 2.5
        case .male:
            return 8.5
        case .female:
            return 9
        case .mixed:
            return 8
        case .cosplayer:
            return 2.4
        case .other:
            return 10
        case .temp:
            return 0.1
        }
    }
    var abbreviation: String? {
        switch self {
        case .reclass:
            return "r"
        case .language:
            return "l"
        case .parody:
            return "p"
        case .character:
            return "c"
        case .group:
            return "g"
        case .artist:
            return "a"
        case .male:
            return "m"
        case .female:
            return "f"
        case .mixed:
            return "x"
        case .cosplayer:
            return "cos"
        case .other:
            return "o"
        case .temp:
            return nil
        }
    }
    var value: String {
        switch self {
        case .reclass:
            return L10n.Localizable.Enum.TagNamespace.Value.reclass
        case .language:
            return L10n.Localizable.Enum.TagNamespace.Value.language
        case .parody:
            return L10n.Localizable.Enum.TagNamespace.Value.parody
        case .character:
            return L10n.Localizable.Enum.TagNamespace.Value.character
        case .group:
            return L10n.Localizable.Enum.TagNamespace.Value.group
        case .artist:
            return L10n.Localizable.Enum.TagNamespace.Value.artist
        case .male:
            return L10n.Localizable.Enum.TagNamespace.Value.male
        case .female:
            return L10n.Localizable.Enum.TagNamespace.Value.female
        case .mixed:
            return L10n.Localizable.Enum.TagNamespace.Value.mixed
        case .cosplayer:
            return L10n.Localizable.Enum.TagNamespace.Value.cosplayer
        case .other:
            return L10n.Localizable.Enum.TagNamespace.Value.other
        case .temp:
            return L10n.Localizable.Enum.TagNamespace.Value.temp
        }
    }
}
