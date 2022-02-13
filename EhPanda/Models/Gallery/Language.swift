//
//  Language.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/30.
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
    var codes: [String] {
        switch self {
        case .english:
            return ["en-US"]
        case .french:
            return ["fr-FR"]
        case .italian:
            return ["it-IT"]
        case .german:
            return ["de-DE"]
        case .spanish:
            return ["es-ES"]
        case .portuguese:
            return ["pt-BR"]
        case .chinese:
            return ["zh-Hans", "zh-Hant"]
        default:
            return []
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
        case .invalid:
            return R.string.localizable.enumLanguageValueInvalid()
        case .other:
            return R.string.localizable.enumLanguageValueOther()
        case .afrikaans:
            return R.string.localizable.enumLanguageValueAfrikaans()
        case .albanian:
            return R.string.localizable.enumLanguageValueAlbanian()
        case .arabic:
            return R.string.localizable.enumLanguageValueArabic()
        case .bengali:
            return R.string.localizable.enumLanguageValueBengali()
        case .bosnian:
            return R.string.localizable.enumLanguageValueBosnian()
        case .bulgarian:
            return R.string.localizable.enumLanguageValueBulgarian()
        case .burmese:
            return R.string.localizable.enumLanguageValueBurmese()
        case .catalan:
            return R.string.localizable.enumLanguageValueCatalan()
        case .cebuano:
            return R.string.localizable.enumLanguageValueCebuano()
        case .chinese:
            return R.string.localizable.enumLanguageValueChinese()
        case .croatian:
            return R.string.localizable.enumLanguageValueCroatian()
        case .czech:
            return R.string.localizable.enumLanguageValueCzech()
        case .danish:
            return R.string.localizable.enumLanguageValueDanish()
        case .dutch:
            return R.string.localizable.enumLanguageValueDutch()
        case .english:
            return R.string.localizable.enumLanguageValueEnglish()
        case .esperanto:
            return R.string.localizable.enumLanguageValueEsperanto()
        case .estonian:
            return R.string.localizable.enumLanguageValueEstonian()
        case .finnish:
            return R.string.localizable.enumLanguageValueFinnish()
        case .french:
            return R.string.localizable.enumLanguageValueFrench()
        case .georgian:
            return R.string.localizable.enumLanguageValueGeorgian()
        case .german:
            return R.string.localizable.enumLanguageValueGerman()
        case .greek:
            return R.string.localizable.enumLanguageValueGreek()
        case .hebrew:
            return R.string.localizable.enumLanguageValueHebrew()
        case .hindi:
            return R.string.localizable.enumLanguageValueHindi()
        case .hmong:
            return R.string.localizable.enumLanguageValueHmong()
        case .hungarian:
            return R.string.localizable.enumLanguageValueHungarian()
        case .indonesian:
            return R.string.localizable.enumLanguageValueIndonesian()
        case .italian:
            return R.string.localizable.enumLanguageValueItalian()
        case .japanese:
            return R.string.localizable.enumLanguageValueJapanese()
        case .kazakh:
            return R.string.localizable.enumLanguageValueKazakh()
        case .khmer:
            return R.string.localizable.enumLanguageValueKhmer()
        case .korean:
            return R.string.localizable.enumLanguageValueKorean()
        case .kurdish:
            return R.string.localizable.enumLanguageValueKurdish()
        case .lao:
            return R.string.localizable.enumLanguageValueLao()
        case .latin:
            return R.string.localizable.enumLanguageValueLatin()
        case .mongolian:
            return R.string.localizable.enumLanguageValueMongolian()
        case .ndebele:
            return R.string.localizable.enumLanguageValueNdebele()
        case .nepali:
            return R.string.localizable.enumLanguageValueNepali()
        case .norwegian:
            return R.string.localizable.enumLanguageValueNorwegian()
        case .oromo:
            return R.string.localizable.enumLanguageValueOromo()
        case .pashto:
            return R.string.localizable.enumLanguageValuePashto()
        case .persian:
            return R.string.localizable.enumLanguageValuePersian()
        case .polish:
            return R.string.localizable.enumLanguageValuePolish()
        case .portuguese:
            return R.string.localizable.enumLanguageValuePortuguese()
        case .punjabi:
            return R.string.localizable.enumLanguageValuePunjabi()
        case .romanian:
            return R.string.localizable.enumLanguageValueRomanian()
        case .russian:
            return R.string.localizable.enumLanguageValueRussian()
        case .sango:
            return R.string.localizable.enumLanguageValueSango()
        case .serbian:
            return R.string.localizable.enumLanguageValueSerbian()
        case .shona:
            return R.string.localizable.enumLanguageValueShona()
        case .slovak:
            return R.string.localizable.enumLanguageValueSlovak()
        case .slovenian:
            return R.string.localizable.enumLanguageValueSlovenian()
        case .somali:
            return R.string.localizable.enumLanguageValueSomali()
        case .spanish:
            return R.string.localizable.enumLanguageValueSpanish()
        case .swahili:
            return R.string.localizable.enumLanguageValueSwahili()
        case .swedish:
            return R.string.localizable.enumLanguageValueSwedish()
        case .tagalog:
            return R.string.localizable.enumLanguageValueTagalog()
        case .thai:
            return R.string.localizable.enumLanguageValueThai()
        case .tigrinya:
            return R.string.localizable.enumLanguageValueTigrinya()
        case .turkish:
            return R.string.localizable.enumLanguageValueTurkish()
        case .ukrainian:
            return R.string.localizable.enumLanguageValueUkrainian()
        case .urdu:
            return R.string.localizable.enumLanguageValueUrdu()
        case .vietnamese:
            return R.string.localizable.enumLanguageValueVietnamese()
        case .zulu:
            return R.string.localizable.enumLanguageValueZulu()
        }
    }
}
