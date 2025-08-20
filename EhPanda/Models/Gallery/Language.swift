//
//  Language.swift
//  EhPanda
//

enum Language: String, Codable {
    static let allExcludedCases: [Self] = [
        .japanese, .english, .chinese, .dutch, .french, .german, .hungarian, .italian,
        .korean, .polish, .portuguese, .russian, .spanish, .thai, .vietnamese, .invalid, .other
    ]
    // swiftlint:disable line_length
    case invalid = "N/A"; case other = "Other"; case afrikaans = "Afrikaans"; case albanian = "Albanian"; case arabic = "Arabic"; case bengali = "Bengali"; case bosnian = "Bosnian"; case bulgarian = "Bulgarian"; case burmese = "Burmese"; case catalan = "Catalan"; case cebuano = "Cebuano"; case chinese = "Chinese"; case croatian = "Croatian"; case czech = "Czech"; case danish = "Danish"; case dutch = "Dutch"; case english = "English"; case esperanto = "Esperanto"; case estonian = "Estonian"; case finnish = "Finnish"; case french = "French"; case georgian = "Georgian"; case german = "German"; case greek = "Greek"; case hebrew = "Hebrew"; case hindi = "Hindi"; case hmong = "Hmong"; case hungarian = "Hungarian"; case indonesian = "Indonesian"; case italian = "Italian"; case japanese = "Japanese"; case kazakh = "Kazakh"; case khmer = "Khmer"; case korean = "Korean"; case kurdish = "Kurdish"; case lao = "Lao"; case latin = "Latin"; case mongolian = "Mongolian"; case ndebele = "Ndebele"; case nepali = "Nepali"; case norwegian = "Norwegian"; case oromo = "Oromo"; case pashto = "Pashto"; case persian = "Persian"; case polish = "Polish"; case portuguese = "Portuguese"; case punjabi = "Punjabi"; case romanian = "Romanian"; case russian = "Russian"; case sango = "Sango"; case serbian = "Serbian"; case shona = "Shona"; case slovak = "Slovak"; case slovenian = "Slovenian"; case somali = "Somali"; case spanish = "Spanish"; case swahili = "Swahili"; case swedish = "Swedish"; case tagalog = "Tagalog"; case thai = "Thai"; case tigrinya = "Tigrinya"; case turkish = "Turkish"; case ukrainian = "Ukrainian"; case urdu = "Urdu"; case vietnamese = "Vietnamese"; case zulu = "Zulu"
    // swiftlint:enable line_length
}

extension Language {
    var codes: [String]? {
        switch self {
        case .english: return ["en-US"]
        case .french: return ["fr-FR"]
        case .italian: return ["it-IT"]
        case .german: return ["de-DE"]
        case .spanish: return ["es-ES"]
        case .portuguese: return ["pt-BR"]
        case .chinese: return ["zh-Hans", "zh-Hant"]
        default: return nil
        }
    }
    var abbreviation: String {
        switch self {
            // swiftlint:disable switch_case_alignment line_length
        case .invalid, .other: return "N/A"; case .afrikaans: return "AF"; case .albanian: return "SQ"; case .arabic: return "AR"; case .bengali: return "BN"; case .bosnian: return "BS"; case .bulgarian: return "BG"; case .burmese: return "MY"; case .catalan: return "CA"; case .cebuano: return "CEB"; case .chinese: return "ZH"; case .croatian: return "HR"; case .czech: return "CS"; case .danish: return "DA"; case .dutch: return "NL"; case .english: return "EN"; case .esperanto: return "EO"; case .estonian: return "ET"; case .finnish: return "FI"; case .french: return "FR"; case .georgian: return "KA"; case .german: return "DE"; case .greek: return "EL"; case .hebrew: return "HE"; case .hindi: return "HI"; case .hmong: return "HMN"; case .hungarian: return "HU"; case .indonesian: return "ID"; case .italian: return "IT"; case .japanese: return "JA"; case .kazakh: return "KK"; case .khmer: return "KM"; case .korean: return "KO"; case .kurdish: return "KU"; case .lao: return "LO"; case .latin: return "LA"; case .mongolian: return "MN"; case .ndebele: return "ND"; case .nepali: return "NE"; case .norwegian: return "NO"; case .oromo: return "OM"; case .pashto: return "PS"; case .persian: return "FA"; case .polish: return "PL"; case .portuguese: return "PT"; case .punjabi: return "PA"; case .romanian: return "RO"; case .russian: return "RU"; case .sango: return "SG"; case .serbian: return "SR"; case .shona: return "SN"; case .slovak: return "SK"; case .slovenian: return "SL"; case .somali: return "SO"; case .spanish: return "ES"; case .swahili: return "SW"; case .swedish: return "SV"; case .tagalog: return "TL"; case .thai: return "TH"; case .tigrinya: return "TI"; case .turkish: return "TR"; case .ukrainian: return "UK"; case .urdu: return "UR"; case .vietnamese: return "VI"; case .zulu: return "ZU"
            // swiftlint:enable switch_case_alignment line_length
        }
    }
    var value: String {
        switch self {
        case .invalid: return L10n.Localizable.Enum.Language.Value.invalid
        case .other: return L10n.Localizable.Enum.Language.Value.other
        case .afrikaans: return L10n.Localizable.Enum.Language.Value.afrikaans
        case .albanian: return L10n.Localizable.Enum.Language.Value.albanian
        case .arabic: return L10n.Localizable.Enum.Language.Value.arabic
        case .bengali: return L10n.Localizable.Enum.Language.Value.bengali
        case .bosnian: return L10n.Localizable.Enum.Language.Value.bosnian
        case .bulgarian: return L10n.Localizable.Enum.Language.Value.bulgarian
        case .burmese: return L10n.Localizable.Enum.Language.Value.burmese
        case .catalan: return L10n.Localizable.Enum.Language.Value.catalan
        case .cebuano: return L10n.Localizable.Enum.Language.Value.cebuano
        case .chinese: return L10n.Localizable.Enum.Language.Value.chinese
        case .croatian: return L10n.Localizable.Enum.Language.Value.croatian
        case .czech: return L10n.Localizable.Enum.Language.Value.czech
        case .danish: return L10n.Localizable.Enum.Language.Value.danish
        case .dutch: return L10n.Localizable.Enum.Language.Value.dutch
        case .english: return L10n.Localizable.Enum.Language.Value.english
        case .esperanto: return L10n.Localizable.Enum.Language.Value.esperanto
        case .estonian: return L10n.Localizable.Enum.Language.Value.estonian
        case .finnish: return L10n.Localizable.Enum.Language.Value.finnish
        case .french: return L10n.Localizable.Enum.Language.Value.french
        case .georgian: return L10n.Localizable.Enum.Language.Value.georgian
        case .german: return L10n.Localizable.Enum.Language.Value.german
        case .greek: return L10n.Localizable.Enum.Language.Value.greek
        case .hebrew: return L10n.Localizable.Enum.Language.Value.hebrew
        case .hindi: return L10n.Localizable.Enum.Language.Value.hindi
        case .hmong: return L10n.Localizable.Enum.Language.Value.hmong
        case .hungarian: return L10n.Localizable.Enum.Language.Value.hungarian
        case .indonesian: return L10n.Localizable.Enum.Language.Value.indonesian
        case .italian: return L10n.Localizable.Enum.Language.Value.italian
        case .japanese: return L10n.Localizable.Enum.Language.Value.japanese
        case .kazakh: return L10n.Localizable.Enum.Language.Value.kazakh
        case .khmer: return L10n.Localizable.Enum.Language.Value.khmer
        case .korean: return L10n.Localizable.Enum.Language.Value.korean
        case .kurdish: return L10n.Localizable.Enum.Language.Value.kurdish
        case .lao: return L10n.Localizable.Enum.Language.Value.lao
        case .latin: return L10n.Localizable.Enum.Language.Value.latin
        case .mongolian: return L10n.Localizable.Enum.Language.Value.mongolian
        case .ndebele: return L10n.Localizable.Enum.Language.Value.ndebele
        case .nepali: return L10n.Localizable.Enum.Language.Value.nepali
        case .norwegian: return L10n.Localizable.Enum.Language.Value.norwegian
        case .oromo: return L10n.Localizable.Enum.Language.Value.oromo
        case .pashto: return L10n.Localizable.Enum.Language.Value.pashto
        case .persian: return L10n.Localizable.Enum.Language.Value.persian
        case .polish: return L10n.Localizable.Enum.Language.Value.polish
        case .portuguese: return L10n.Localizable.Enum.Language.Value.portuguese
        case .punjabi: return L10n.Localizable.Enum.Language.Value.punjabi
        case .romanian: return L10n.Localizable.Enum.Language.Value.romanian
        case .russian: return L10n.Localizable.Enum.Language.Value.russian
        case .sango: return L10n.Localizable.Enum.Language.Value.sango
        case .serbian: return L10n.Localizable.Enum.Language.Value.serbian
        case .shona: return L10n.Localizable.Enum.Language.Value.shona
        case .slovak: return L10n.Localizable.Enum.Language.Value.slovak
        case .slovenian: return L10n.Localizable.Enum.Language.Value.slovenian
        case .somali: return L10n.Localizable.Enum.Language.Value.somali
        case .spanish: return L10n.Localizable.Enum.Language.Value.spanish
        case .swahili: return L10n.Localizable.Enum.Language.Value.swahili
        case .swedish: return L10n.Localizable.Enum.Language.Value.swedish
        case .tagalog: return L10n.Localizable.Enum.Language.Value.tagalog
        case .thai: return L10n.Localizable.Enum.Language.Value.thai
        case .tigrinya: return L10n.Localizable.Enum.Language.Value.tigrinya
        case .turkish: return L10n.Localizable.Enum.Language.Value.turkish
        case .ukrainian: return L10n.Localizable.Enum.Language.Value.ukrainian
        case .urdu: return L10n.Localizable.Enum.Language.Value.urdu
        case .vietnamese: return L10n.Localizable.Enum.Language.Value.vietnamese
        case .zulu: return L10n.Localizable.Enum.Language.Value.zulu
        }
    }
}
