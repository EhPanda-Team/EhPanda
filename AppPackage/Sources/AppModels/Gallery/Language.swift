import Foundation
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
    public var value: LocalizedStringResource {
        switch self {
        case .invalid: return .languageInvalid
        case .other: return .languageOther
        case .afrikaans: return .languageAfrikaans
        case .albanian: return .languageAlbanian
        case .arabic: return .languageArabic
        case .bengali: return .languageBengali
        case .bosnian: return .languageBosnian
        case .bulgarian: return .languageBulgarian
        case .burmese: return .languageBurmese
        case .catalan: return .languageCatalan
        case .cebuano: return .languageCebuano
        case .chinese: return .languageChinese
        case .croatian: return .languageCroatian
        case .czech: return .languageCzech
        case .danish: return .languageDanish
        case .dutch: return .languageDutch
        case .english: return .languageEnglish
        case .esperanto: return .languageEsperanto
        case .estonian: return .languageEstonian
        case .finnish: return .languageFinnish
        case .french: return .languageFrench
        case .georgian: return .languageGeorgian
        case .german: return .languageGerman
        case .greek: return .languageGreek
        case .hebrew: return .languageHebrew
        case .hindi: return .languageHindi
        case .hmong: return .languageHmong
        case .hungarian: return .languageHungarian
        case .indonesian: return .languageIndonesian
        case .italian: return .languageItalian
        case .japanese: return .languageJapanese
        case .kazakh: return .languageKazakh
        case .khmer: return .languageKhmer
        case .korean: return .languageKorean
        case .kurdish: return .languageKurdish
        case .lao: return .languageLao
        case .latin: return .languageLatin
        case .mongolian: return .languageMongolian
        case .ndebele: return .languageNdebele
        case .nepali: return .languageNepali
        case .norwegian: return .languageNorwegian
        case .oromo: return .languageOromo
        case .pashto: return .languagePashto
        case .persian: return .languagePersian
        case .polish: return .languagePolish
        case .portuguese: return .languagePortuguese
        case .punjabi: return .languagePunjabi
        case .romanian: return .languageRomanian
        case .russian: return .languageRussian
        case .sango: return .languageSango
        case .serbian: return .languageSerbian
        case .shona: return .languageShona
        case .slovak: return .languageSlovak
        case .slovenian: return .languageSlovenian
        case .somali: return .languageSomali
        case .spanish: return .languageSpanish
        case .swahili: return .languageSwahili
        case .swedish: return .languageSwedish
        case .tagalog: return .languageTagalog
        case .thai: return .languageThai
        case .tigrinya: return .languageTigrinya
        case .turkish: return .languageTurkish
        case .ukrainian: return .languageUkrainian
        case .urdu: return .languageUrdu
        case .vietnamese: return .languageVietnamese
        case .zulu: return .languageZulu
        }
    }
}
