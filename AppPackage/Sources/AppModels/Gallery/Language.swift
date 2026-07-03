import Resources

public enum Language: String, Codable, Sendable {
    public static let allExcludedCases: [Self] = [
        .japanese, .english, .chinese, .dutch, .french, .german, .hungarian, .italian,
        .korean, .polish, .portuguese, .russian, .spanish, .thai, .vietnamese, .invalid, .other
    ]
    // swiftlint:disable line_length
    case invalid = "N/A"; case other = "Other"; case afrikaans = "Afrikaans"; case albanian = "Albanian"; case arabic = "Arabic"; case bengali = "Bengali"; case bosnian = "Bosnian"; case bulgarian = "Bulgarian"; case burmese = "Burmese"; case catalan = "Catalan"; case cebuano = "Cebuano"; case chinese = "Chinese"; case croatian = "Croatian"; case czech = "Czech"; case danish = "Danish"; case dutch = "Dutch"; case english = "English"; case esperanto = "Esperanto"; case estonian = "Estonian"; case finnish = "Finnish"; case french = "French"; case georgian = "Georgian"; case german = "German"; case greek = "Greek"; case hebrew = "Hebrew"; case hindi = "Hindi"; case hmong = "Hmong"; case hungarian = "Hungarian"; case indonesian = "Indonesian"; case italian = "Italian"; case japanese = "Japanese"; case kazakh = "Kazakh"; case khmer = "Khmer"; case korean = "Korean"; case kurdish = "Kurdish"; case lao = "Lao"; case latin = "Latin"; case mongolian = "Mongolian"; case ndebele = "Ndebele"; case nepali = "Nepali"; case norwegian = "Norwegian"; case oromo = "Oromo"; case pashto = "Pashto"; case persian = "Persian"; case polish = "Polish"; case portuguese = "Portuguese"; case punjabi = "Punjabi"; case romanian = "Romanian"; case russian = "Russian"; case sango = "Sango"; case serbian = "Serbian"; case shona = "Shona"; case slovak = "Slovak"; case slovenian = "Slovenian"; case somali = "Somali"; case spanish = "Spanish"; case swahili = "Swahili"; case swedish = "Swedish"; case tagalog = "Tagalog"; case thai = "Thai"; case tigrinya = "Tigrinya"; case turkish = "Turkish"; case ukrainian = "Ukrainian"; case urdu = "Urdu"; case vietnamese = "Vietnamese"; case zulu = "Zulu"
    // swiftlint:enable line_length
}

extension Language {
    public var codes: [String]? {
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
    public var abbreviation: String {
        switch self {
        // swiftlint:disable switch_case_alignment line_length
        case .invalid, .other: return "N/A"; case .afrikaans: return "AF"; case .albanian: return "SQ"; case .arabic: return "AR"; case .bengali: return "BN"; case .bosnian: return "BS"; case .bulgarian: return "BG"; case .burmese: return "MY"; case .catalan: return "CA"; case .cebuano: return "CEB"; case .chinese: return "ZH"; case .croatian: return "HR"; case .czech: return "CS"; case .danish: return "DA"; case .dutch: return "NL"; case .english: return "EN"; case .esperanto: return "EO"; case .estonian: return "ET"; case .finnish: return "FI"; case .french: return "FR"; case .georgian: return "KA"; case .german: return "DE"; case .greek: return "EL"; case .hebrew: return "HE"; case .hindi: return "HI"; case .hmong: return "HMN"; case .hungarian: return "HU"; case .indonesian: return "ID"; case .italian: return "IT"; case .japanese: return "JA"; case .kazakh: return "KK"; case .khmer: return "KM"; case .korean: return "KO"; case .kurdish: return "KU"; case .lao: return "LO"; case .latin: return "LA"; case .mongolian: return "MN"; case .ndebele: return "ND"; case .nepali: return "NE"; case .norwegian: return "NO"; case .oromo: return "OM"; case .pashto: return "PS"; case .persian: return "FA"; case .polish: return "PL"; case .portuguese: return "PT"; case .punjabi: return "PA"; case .romanian: return "RO"; case .russian: return "RU"; case .sango: return "SG"; case .serbian: return "SR"; case .shona: return "SN"; case .slovak: return "SK"; case .slovenian: return "SL"; case .somali: return "SO"; case .spanish: return "ES"; case .swahili: return "SW"; case .swedish: return "SV"; case .tagalog: return "TL"; case .thai: return "TH"; case .tigrinya: return "TI"; case .turkish: return "TR"; case .ukrainian: return "UK"; case .urdu: return "UR"; case .vietnamese: return "VI"; case .zulu: return "ZU"
        // swiftlint:enable switch_case_alignment line_length
        }
    }
    public var value: String {
        switch self {
        case .invalid: return String(localized: .languageInvalid)
        case .other: return String(localized: .languageOther)
        case .afrikaans: return String(localized: .languageAfrikaans)
        case .albanian: return String(localized: .languageAlbanian)
        case .arabic: return String(localized: .languageArabic)
        case .bengali: return String(localized: .languageBengali)
        case .bosnian: return String(localized: .languageBosnian)
        case .bulgarian: return String(localized: .languageBulgarian)
        case .burmese: return String(localized: .languageBurmese)
        case .catalan: return String(localized: .languageCatalan)
        case .cebuano: return String(localized: .languageCebuano)
        case .chinese: return String(localized: .languageChinese)
        case .croatian: return String(localized: .languageCroatian)
        case .czech: return String(localized: .languageCzech)
        case .danish: return String(localized: .languageDanish)
        case .dutch: return String(localized: .languageDutch)
        case .english: return String(localized: .languageEnglish)
        case .esperanto: return String(localized: .languageEsperanto)
        case .estonian: return String(localized: .languageEstonian)
        case .finnish: return String(localized: .languageFinnish)
        case .french: return String(localized: .languageFrench)
        case .georgian: return String(localized: .languageGeorgian)
        case .german: return String(localized: .languageGerman)
        case .greek: return String(localized: .languageGreek)
        case .hebrew: return String(localized: .languageHebrew)
        case .hindi: return String(localized: .languageHindi)
        case .hmong: return String(localized: .languageHmong)
        case .hungarian: return String(localized: .languageHungarian)
        case .indonesian: return String(localized: .languageIndonesian)
        case .italian: return String(localized: .languageItalian)
        case .japanese: return String(localized: .languageJapanese)
        case .kazakh: return String(localized: .languageKazakh)
        case .khmer: return String(localized: .languageKhmer)
        case .korean: return String(localized: .languageKorean)
        case .kurdish: return String(localized: .languageKurdish)
        case .lao: return String(localized: .languageLao)
        case .latin: return String(localized: .languageLatin)
        case .mongolian: return String(localized: .languageMongolian)
        case .ndebele: return String(localized: .languageNdebele)
        case .nepali: return String(localized: .languageNepali)
        case .norwegian: return String(localized: .languageNorwegian)
        case .oromo: return String(localized: .languageOromo)
        case .pashto: return String(localized: .languagePashto)
        case .persian: return String(localized: .languagePersian)
        case .polish: return String(localized: .languagePolish)
        case .portuguese: return String(localized: .languagePortuguese)
        case .punjabi: return String(localized: .languagePunjabi)
        case .romanian: return String(localized: .languageRomanian)
        case .russian: return String(localized: .languageRussian)
        case .sango: return String(localized: .languageSango)
        case .serbian: return String(localized: .languageSerbian)
        case .shona: return String(localized: .languageShona)
        case .slovak: return String(localized: .languageSlovak)
        case .slovenian: return String(localized: .languageSlovenian)
        case .somali: return String(localized: .languageSomali)
        case .spanish: return String(localized: .languageSpanish)
        case .swahili: return String(localized: .languageSwahili)
        case .swedish: return String(localized: .languageSwedish)
        case .tagalog: return String(localized: .languageTagalog)
        case .thai: return String(localized: .languageThai)
        case .tigrinya: return String(localized: .languageTigrinya)
        case .turkish: return String(localized: .languageTurkish)
        case .ukrainian: return String(localized: .languageUkrainian)
        case .urdu: return String(localized: .languageUrdu)
        case .vietnamese: return String(localized: .languageVietnamese)
        case .zulu: return String(localized: .languageZulu)
        }
    }
}
