import Foundation
import Resources

public enum TagNamespace: String, Codable, CaseIterable, Sendable {
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

    public static let abbreviations: [String: String] = {
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
    public var weight: Float {
        switch self {
        case .reclass: return 1
        case .language: return 2
        case .parody: return 3.3
        case .character: return 2.8
        case .group: return 2.2
        case .artist: return 2.5
        case .male: return 8.5
        case .female: return 9
        case .mixed: return 8
        case .cosplayer: return 2.4
        case .other: return 10
        case .temp: return 0.1
        }
    }
    public var abbreviation: String? {
        switch self {
        case .reclass: return "r"
        case .language: return "l"
        case .parody: return "p"
        case .character: return "c"
        case .group: return "g"
        case .artist: return "a"
        case .male: return "m"
        case .female: return "f"
        case .mixed: return "x"
        case .cosplayer: return "cos"
        case .other: return "o"
        case .temp: return nil
        }
    }
    public var value: LocalizedStringResource {
        switch self {
        case .reclass: return .tagNamespaceReclass
        case .language: return .tagNamespaceLanguage
        case .parody: return .tagNamespaceParody
        case .character: return .tagNamespaceCharacter
        case .group: return .tagNamespaceGroup
        case .artist: return .tagNamespaceArtist
        case .male: return .tagNamespaceMale
        case .female: return .tagNamespaceFemale
        case .mixed: return .tagNamespaceMixed
        case .cosplayer: return .tagNamespaceCosplayer
        case .other: return .tagNamespaceOther
        case .temp: return .tagNamespaceTemp
        }
    }
}
