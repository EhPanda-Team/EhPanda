//
//  EhSetting.swift
//  EhSetting
//
//  Created by 荒木辰造 on R 3/08/08.
//

// MARK: EhSetting
struct EhSetting: Equatable {
    // swiftlint:disable line_length
    static let empty: Self = .init(ehProfiles: [.empty], capableLoadThroughHathSetting: .anyClient, capableImageResolution: .auto, capableSearchResultCount: .fifty, capableThumbnailConfigSize: .normal, capableThumbnailConfigRowCount: .forty, loadThroughHathSetting: .anyClient, browsingCountry: .autoDetect, literalBrowsingCountry: "", imageResolution: .auto, imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default, archiverBehavior: .autoSelectOriginalAutoStart, displayMode: .compact, disabledCategories: Array(repeating: false, count: 10), favoriteNames: Array(repeating: "", count: 10), favoritesSortOrder: .favoritedTime, ratingsColor: "", excludedNamespaces: Array(repeating: false, count: 11), tagFilteringThreshold: 0, tagWatchingThreshold: 0, excludedLanguages: Array(repeating: false, count: 50), excludedUploaders: "", searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad, thumbnailConfigSize: .normal, thumbnailConfigRows: .ten, thumbnailScaleFactor: 0, viewportVirtualWidth: 0, commentsSortOrder: .recent, commentVotesShowTiming: .always, tagsSortOrder: .alphabetical, galleryShowPageNumbers: true, hathLocalNetworkHost: "")
    // swiftlint:enable line_length

    static let categoryNames = Category.allFiltersCases.map(\.rawValue).map { value in
        value.lowercased().replacingOccurrences(of: " ", with: "")
    }
    static let languageValues = [
        1024, 2048, 1, 1025, 2049, 10, 1034, 2058,
        20, 1044, 2068, 30, 1054, 2078, 40, 1064, 2088,
        50, 1074, 2098, 60, 1084, 2108, 70, 1094, 2118,
        80, 1104, 2128, 90, 1114, 2138, 100, 1124, 2148,
        110, 1134, 2158, 120, 1144, 2168, 130, 1154, 2178,
        254, 1278, 2302, 255, 1279, 2303
    ]

    let ehProfiles: [EhProfile]
    var ehpandaProfile: EhProfile? {
        ehProfiles.filter({ EhSetting.verifyEhPandaProfileName(with: $0.name) }).first
    }
    static func verifyEhPandaProfileName(with name: String?) -> Bool {
        ["EhPanda", "EhPanda (Default)"].contains(name ?? "")
    }

    var capableLoadThroughHathSetting: LoadThroughHathSetting
    var capableImageResolution: ImageResolution
    var capableSearchResultCount: SearchResultCount
    var capableThumbnailConfigSize: ThumbnailSize
    var capableThumbnailConfigRowCount: ThumbnailRowCount

    var capableLoadThroughHathSettings: [LoadThroughHathSetting] {
        LoadThroughHathSetting.allCases.filter { setting in
            setting <= capableLoadThroughHathSetting
        }
    }
    var capableImageResolutions: [ImageResolution] {
        ImageResolution.allCases.filter { resolution in
            resolution <= capableImageResolution
        }
    }
    var capableSearchResultCounts: [SearchResultCount] {
        SearchResultCount.allCases.filter { count in
            count <= capableSearchResultCount
        }
    }
    var capableThumbnailConfigSizes: [ThumbnailSize] {
        ThumbnailSize.allCases.filter { size in
            size <= capableThumbnailConfigSize
        }
    }
    var capableThumbnailConfigRowCounts: [ThumbnailRowCount] {
        ThumbnailRowCount.allCases.filter { row in
            row <= capableThumbnailConfigRowCount
        }
    }

    var loadThroughHathSetting: LoadThroughHathSetting
    var browsingCountry: BrowsingCountry
    let literalBrowsingCountry: String
    var imageResolution: ImageResolution
    var imageSizeWidth: Float
    var imageSizeHeight: Float
    var galleryName: GalleryName
    var archiverBehavior: ArchiverBehavior
    var displayMode: DisplayMode
    var disabledCategories: [Bool]
    var favoriteNames: [String]
    var favoritesSortOrder: FavoritesSortOrder
    var ratingsColor: String
    var excludedNamespaces: [Bool]
    var tagFilteringThreshold: Float
    var tagWatchingThreshold: Float
    var excludedLanguages: [Bool]
    var excludedUploaders: String
    var searchResultCount: SearchResultCount
    var thumbnailLoadTiming: ThumbnailLoadTiming
    var thumbnailConfigSize: ThumbnailSize
    var thumbnailConfigRows: ThumbnailRowCount
    var thumbnailScaleFactor: Float
    var viewportVirtualWidth: Float
    var commentsSortOrder: CommentsSortOrder
    var commentVotesShowTiming: CommentVotesShowTiming
    var tagsSortOrder: TagsSortOrder
    var galleryShowPageNumbers: Bool
    var hathLocalNetworkHost: String
    var useOriginalImages: Bool?
    var useMultiplePageViewer: Bool?
    var multiplePageViewerStyle: MultiplePageViewerStyle?
    var multiplePageViewerShowThumbnailPane: Bool?
}

// MARK: EhProfile
struct EhProfile: Comparable, Identifiable, Hashable {
    static let empty: Self = .init(
        value: 0, name: "", isSelected: true
    )
    static func < (lhs: EhProfile, rhs: EhProfile) -> Bool {
        lhs.value < rhs.value
    }
    var id: Int { value }

    let value: Int
    let name: String
    let isSelected: Bool
    var isDefault: Bool {
        value == 1
    }
}
enum EhProfileAction: String {
    case create
    case delete
    case rename
    case `default`
}

// MARK: LoadThroughHathSetting
extension EhSetting {
    enum LoadThroughHathSetting: Int, CaseIterable, Identifiable, Comparable {
        case anyClient
        case defaultPortOnly
        case no
    }
}
extension EhSetting.LoadThroughHathSetting {
    var id: Int { rawValue }
    static func < (
        lhs: EhSetting.LoadThroughHathSetting,
        rhs: EhSetting.LoadThroughHathSetting
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .anyClient:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingValueAnyClient()
        case .defaultPortOnly:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingValueDefaultPortOnly()
        case .no:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingValueNo()
        }
    }
    var description: String {
        switch self {
        case .anyClient:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingDescriptionAnyClient()
        case .defaultPortOnly:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingDescriptionDefaultPortOnly()
        case .no:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingDescriptionNo()
        }
    }
}

// MARK: ImageResolution
extension EhSetting {
    enum ImageResolution: Int, CaseIterable, Identifiable, Comparable {
        case auto
        case x780
        case x980
        case x1280
        case x1600
        case x2400
    }
}
extension EhSetting.ImageResolution {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .auto:
            return R.string.localizable.enumEhSettingImageResolutionValueAuto()
        case .x780:
            return "780x"
        case .x980:
            return "980x"
        case .x1280:
            return "1280x"
        case .x1600:
            return "1600x"
        case .x2400:
            return "2400x"
        }
    }
}

// MARK: GalleryName
extension EhSetting {
    enum GalleryName: Int, CaseIterable, Identifiable {
        case `default`
        case japanese
    }
}
extension EhSetting.GalleryName {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .default:
            return R.string.localizable.enumEhSettingGalleryNameValueDefault()
        case .japanese:
            return R.string.localizable.enumEhSettingGalleryNameValueJapanese()
        }
    }
}

// MARK: ArchiverBehavior
extension EhSetting {
    enum ArchiverBehavior: Int, CaseIterable, Identifiable {
        case manualSelectManualStart
        case manualSelectAutoStart
        case autoSelectOriginalManualStart
        case autoSelectOriginalAutoStart
        case autoSelectResampleManualStart
        case autoSelectResampleAutoStart
    }
}
extension EhSetting.ArchiverBehavior {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .manualSelectManualStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueManualSelectManualStart()
        case .manualSelectAutoStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueManualSelectAutoStart()
        case .autoSelectOriginalManualStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectOriginalManualStart()
        case .autoSelectOriginalAutoStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectOriginalAutoStart()
        case .autoSelectResampleManualStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectResampleManualStart()
        case .autoSelectResampleAutoStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectResampleAutoStart()
        }
    }
}

// MARK: DisplayMode
extension EhSetting {
    enum DisplayMode: Int, CaseIterable, Identifiable {
        case compact
        case thumbnail
        case extended
        case minimal
        case minimalPlus
    }
}
extension EhSetting.DisplayMode {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .compact:
            return R.string.localizable.enumEhSettingDisplayModeValueCompact()
        case .thumbnail:
            return R.string.localizable.enumEhSettingDisplayModeValueThumbnail()
        case .extended:
            return R.string.localizable.enumEhSettingDisplayModeValueExtended()
        case .minimal:
            return R.string.localizable.enumEhSettingDisplayModeValueMinimal()
        case .minimalPlus:
            return R.string.localizable.enumEhSettingDisplayModeValueMinimalPlus()
        }
    }
}

// MARK: FavoritesSortOrder
extension EhSetting {
    enum FavoritesSortOrder: Int, CaseIterable, Identifiable {
        case lastUpdateTime
        case favoritedTime
    }
}
extension EhSetting.FavoritesSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .lastUpdateTime:
            return R.string.localizable.enumEhSettingFavoritesSortOrderValueLastUpdateTime()
        case .favoritedTime:
            return R.string.localizable.enumEhSettingFavoritesSortOrderValueFavoritedTime()
        }
    }
}

// MARK: ExcludedLanguagesCategory
extension EhSetting {
    enum ExcludedLanguagesCategory: Int, Identifiable, CaseIterable {
        case original
        case translated
        case rewrite
    }
}
extension EhSetting.ExcludedLanguagesCategory {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .original:
            return R.string.localizable.enumEhSettingExcludedLanguagesCategoryValueOriginal()
        case .translated:
            return R.string.localizable.enumEhSettingExcludedLanguagesCategoryValueTranslated()
        case .rewrite:
            return R.string.localizable.enumEhSettingExcludedLanguagesCategoryValueRewrite()
        }
    }
}

// MARK: SearchResultCount
extension EhSetting {
    enum SearchResultCount: Int, CaseIterable, Identifiable, Comparable {
        case twentyFive
        case fifty
        case oneHundred
        case twoHundred
    }
}
extension EhSetting.SearchResultCount {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .twentyFive:
            return "25"
        case .fifty:
            return "50"
        case .oneHundred:
            return "100"
        case .twoHundred:
            return "200"
        }
    }
}

// MARK: ThumbnailLoadTiming
extension EhSetting {
    enum ThumbnailLoadTiming: Int, CaseIterable, Identifiable {
        case onMouseOver
        case onPageLoad
    }
}
extension EhSetting.ThumbnailLoadTiming {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .onMouseOver:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingValueOnMouseOver()
        case .onPageLoad:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingValueOnPageLoad()
        }
    }
    var description: String {
        switch self {
        case .onMouseOver:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingDescriptionOnMouseOver()
        case .onPageLoad:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingDescriptionOnPageLoad()
        }
    }
}

// MARK: ThumbnailSize
extension EhSetting {
    enum ThumbnailSize: Int, CaseIterable, Identifiable, Comparable {
        case normal
        case large
    }
}
extension EhSetting.ThumbnailSize {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .normal:
            return R.string.localizable.enumEhSettingThumbnailSizeValueNormal()
        case .large:
            return R.string.localizable.enumEhSettingThumbnailSizeValueLarge()
        }
    }
}

// MARK: ThumbnailRowCount
extension EhSetting {
    enum ThumbnailRowCount: Int, CaseIterable, Identifiable, Comparable {
        case four
        case ten
        case twenty
        case forty
    }
}
extension EhSetting.ThumbnailRowCount {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .four:
            return "4"
        case .ten:
            return "10"
        case .twenty:
            return "20"
        case .forty:
            return "40"
        }
    }
}

// MARK: CommentsSortOrder
extension EhSetting {
    enum CommentsSortOrder: Int, CaseIterable, Identifiable {
        case oldest
        case recent
        case highestScore
    }
}
extension EhSetting.CommentsSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .oldest:
            return R.string.localizable.enumEhSettingCommentsSortOrderValueOldest()
        case .recent:
            return R.string.localizable.enumEhSettingCommentsSortOrderValueRecent()
        case .highestScore:
            return R.string.localizable.enumEhSettingCommentsSortOrderValueHighestScore()
        }
    }
}

// MARK: CommentVotesShowTiming
extension EhSetting {
    enum CommentVotesShowTiming: Int, CaseIterable, Identifiable {
        case onHoverOrClick
        case always
    }
}
extension EhSetting.CommentVotesShowTiming {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .onHoverOrClick:
            return R.string.localizable.enumEhSettingCommentsVotesShowTimingValueOnHoverOrClick()
        case .always:
            return R.string.localizable.enumEhSettingCommentsVotesShowTimingValueAlways()
        }
    }
}

// MARK: TagsSortOrder
extension EhSetting {
    enum TagsSortOrder: Int, CaseIterable, Identifiable {
        case alphabetical
        case tagPower
    }
}
extension EhSetting.TagsSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .alphabetical:
            return R.string.localizable.enumEhSettingTagsSortOrderValueAlphabetical()
        case .tagPower:
            return R.string.localizable.enumEhSettingTagsSortOrderValueTagPower()
        }
    }
}

// MARK: MultiplePageViewerStyle
extension EhSetting {
    enum MultiplePageViewerStyle: Int, CaseIterable, Identifiable {
        case alignLeftScaleIfOverWidth
        case alignCenterScaleIfOverWidth
        case alignCenterAlwaysScale
    }
}
extension EhSetting.MultiplePageViewerStyle {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .alignLeftScaleIfOverWidth:
            return R.string.localizable.enumEhSettingMultiplePageViewerStyleValueAlignLeftScaleIfOverWidth()
        case .alignCenterScaleIfOverWidth:
            return R.string.localizable.enumEhSettingMultiplePageViewerStyleValueAlignCenterScaleIfOverWidth()
        case .alignCenterAlwaysScale:
            return R.string.localizable.enumEhSettingMultiplePageViewerStyleValueAlignCenterAlwaysScale()
        }
    }
}

// MARK: BrowsingCountry
// swiftlint:disable line_length switch_case_alignment
extension EhSetting {
    enum BrowsingCountry: String, CaseIterable, Identifiable, Equatable {
        case autoDetect = "-"; case afghanistan = "AF"; case alandIslands = "AX"; case albania = "AL"; case algeria = "DZ"; case americanSamoa = "AS"; case andorra = "AD"; case angola = "AO"; case anguilla = "AI"; case antarctica = "AQ"; case antiguaandBarbuda = "AG"; case argentina = "AR"; case armenia = "AM"; case aruba = "AW"; case asiaPacificRegion = "AP"; case australia = "AU"; case austria = "AT"; case azerbaijan = "AZ"; case bahamas = "BS"; case bahrain = "BH"; case bangladesh = "BD"; case barbados = "BB"; case belarus = "BY"; case belgium = "BE"; case belize = "BZ"; case benin = "BJ"; case bermuda = "BM"; case bhutan = "BT"; case bolivia = "BO"; case bonaireSaintEustatiusandSaba = "BQ"; case bosniaandHerzegovina = "BA"; case botswana = "BW"; case bouvetIsland = "BV"; case brazil = "BR"; case britishIndianOceanTerritory = "IO"; case bruneiDarussalam = "BN"; case bulgaria = "BG"; case burkinaFaso = "BF"; case burundi = "BI"; case cambodia = "KH"; case cameroon = "CM"; case canada = "CA"; case capeVerde = "CV"; case caymanIslands = "KY"; case centralAfricanRepublic = "CF"; case chad = "TD"; case chile = "CL"; case china = "CN"; case christmasIsland = "CX"; case cocosIslands = "CC"; case colombia = "CO"; case comoros = "KM"; case congo = "CG"; case congoTheDemocraticRepublicofthe = "CD"; case cookIslands = "CK"; case costaRica = "CR"; case coteDIvoire = "CI"; case croatia = "HR"; case cuba = "CU"; case curacao = "CW"; case cyprus = "CY"; case czechRepublic = "CZ"; case denmark = "DK"; case djibouti = "DJ"; case dominica = "DM"; case dominicanRepublic = "DO"; case ecuador = "EC"; case egypt = "EG"; case elSalvador = "SV"; case equatorialGuinea = "GQ"; case eritrea = "ER"; case estonia = "EE"; case ethiopia = "ET"; case europe = "EU"; case falklandIslands = "FK"; case faroeIslands = "FO"; case fiji = "FJ"; case finland = "FI"; case france = "FR"; case frenchGuiana = "GF"; case frenchPolynesia = "PF"; case frenchSouthernTerritories = "TF"; case gabon = "GA"; case gambia = "GM"; case georgia = "GE"; case germany = "DE"; case ghana = "GH"; case gibraltar = "GI"; case greece = "GR"; case greenland = "GL"; case grenada = "GD"; case guadeloupe = "GP"; case guam = "GU"; case guatemala = "GT"; case guernsey = "GG"; case guinea = "GN"; case guineaBissau = "GW"; case guyana = "GY"; case haiti = "HT"; case heardIslandandMcDonaldIslands = "HM"; case holySeeVaticanCityState = "VA"; case honduras = "HN"; case hongKong = "HK"; case hungary = "HU"; case iceland = "IS"; case india = "IN"; case indonesia = "ID"; case iran = "IR"; case iraq = "IQ"; case ireland = "IE"; case isleofMan = "IM"; case israel = "IL"; case italy = "IT"; case jamaica = "JM"; case japan = "JP"; case jersey = "JE"; case jordan = "JO"; case kazakhstan = "KZ"; case kenya = "KE"; case kiribati = "KI"; case kuwait = "KW"; case kyrgyzstan = "KG"; case laoPeoplesDemocraticRepublic = "LA"; case latvia = "LV"; case lebanon = "LB"; case lesotho = "LS"; case liberia = "LR"; case libya = "LY"; case liechtenstein = "LI"; case lithuania = "LT"; case luxembourg = "LU"; case macau = "MO"; case macedonia = "MK"; case madagascar = "MG"; case malawi = "MW"; case malaysia = "MY"; case maldives = "MV"; case mali = "ML"; case malta = "MT"; case marshallIslands = "MH"; case martinique = "MQ"; case mauritania = "MR"; case mauritius = "MU"; case mayotte = "YT"; case mexico = "MX"; case micronesia = "FM"; case moldova = "MD"; case monaco = "MC"; case mongolia = "MN"; case montenegro = "ME"; case montserrat = "MS"; case morocco = "MA"; case mozambique = "MZ"; case myanmar = "MM"; case namibia = "NA"; case nauru = "NR"; case nepal = "NP"; case netherlands = "NL"; case newCaledonia = "NC"; case newZealand = "NZ"; case nicaragua = "NI"; case niger = "NE"; case nigeria = "NG"; case niue = "NU"; case norfolkIsland = "NF"; case northKorea = "KP"; case northernMarianaIslands = "MP"; case norway = "NO"; case oman = "OM"; case pakistan = "PK"; case palau = "PW"; case palestinianTerritory = "PS"; case panama = "PA"; case papuaNewGuinea = "PG"; case paraguay = "PY"; case peru = "PE"; case philippines = "PH"; case pitcairnIslands = "PN"; case poland = "PL"; case portugal = "PT"; case puertoRico = "PR"; case qatar = "QA"; case reunion = "RE"; case romania = "RO"; case russianFederation = "RU"; case rwanda = "RW"; case saintBarthelemy = "BL"; case saintHelena = "SH"; case saintKittsandNevis = "KN"; case saintLucia = "LC"; case saintMartin = "MF"; case saintPierreandMiquelon = "PM"; case saintVincentandtheGrenadines = "VC"; case samoa = "WS"; case sanMarino = "SM"; case saoTomeandPrincipe = "ST"; case saudiArabia = "SA"; case senegal = "SN"; case serbia = "RS"; case seychelles = "SC"; case sierraLeone = "SL"; case singapore = "SG"; case sintMaarten = "SX"; case slovakia = "SK"; case slovenia = "SI"; case solomonIslands = "SB"; case somalia = "SO"; case southAfrica = "ZA"; case southGeorgiaandtheSouthSandwichIslands = "GS"; case southKorea = "KR"; case southSudan = "SS"; case spain = "ES"; case sriLanka = "LK"; case sudan = "SD"; case suriname = "SR"; case svalbardandJanMayen = "SJ"; case swaziland = "SZ"; case sweden = "SE"; case switzerland = "CH"; case syrianArabRepublic = "SY"; case taiwan = "TW"; case tajikistan = "TJ"; case tanzania = "TZ"; case thailand = "TH"; case timorLeste = "TL"; case togo = "TG"; case tokelau = "TK"; case tonga = "TO"; case trinidadandTobago = "TT"; case tunisia = "TN"; case turkey = "TR"; case turkmenistan = "TM"; case turksandCaicosIslands = "TC"; case tuvalu = "TV"; case uganda = "UG"; case ukraine = "UA"; case unitedArabEmirates = "AE"; case unitedKingdom = "GB"; case unitedStates = "US"; case unitedStatesMinorOutlyingIslands = "UM"; case uruguay = "UY"; case uzbekistan = "UZ"; case vanuatu = "VU"; case venezuela = "VE"; case vietnam = "VN"; case virginIslandsBritish = "VG"; case virginIslandsUS = "VI"; case wallisandFutuna = "WF"; case westernSahara = "EH"; case yemen = "YE"; case zambia = "ZM"; case zimbabwe = "ZW"
    }
}
extension EhSetting.BrowsingCountry {
    var id: Int { hashValue }
    var name: String {
        switch self {
        case .autoDetect: return "Auto-Detect"; case .afghanistan: return "Afghanistan"; case .alandIslands: return "Aland Islands"; case .albania: return "Albania"; case .algeria: return "Algeria"; case .americanSamoa: return "American Samoa"; case .andorra: return "Andorra"; case .angola: return "Angola"; case .anguilla: return "Anguilla"; case .antarctica: return "Antarctica"; case .antiguaandBarbuda: return "Antigua and Barbuda"; case .argentina: return "Argentina"; case .armenia: return "Armenia"; case .aruba: return "Aruba"; case .asiaPacificRegion: return "Asia-Pacific Region"; case .australia: return "Australia"; case .austria: return "Austria"; case .azerbaijan: return "Azerbaijan"; case .bahamas: return "Bahamas"; case .bahrain: return "Bahrain"; case .bangladesh: return "Bangladesh"; case .barbados: return "Barbados"; case .belarus: return "Belarus"; case .belgium: return "Belgium"; case .belize: return "Belize"; case .benin: return "Benin"; case .bermuda: return "Bermuda"; case .bhutan: return "Bhutan"; case .bolivia: return "Bolivia"; case .bonaireSaintEustatiusandSaba: return "Bonaire Saint Eustatius and Saba"; case .bosniaandHerzegovina: return "Bosnia and Herzegovina"; case .botswana: return "Botswana"; case .bouvetIsland: return "Bouvet Island"; case .brazil: return "Brazil"; case .britishIndianOceanTerritory: return "British Indian Ocean Territory"; case .bruneiDarussalam: return "Brunei Darussalam"; case .bulgaria: return "Bulgaria"; case .burkinaFaso: return "Burkina Faso"; case .burundi: return "Burundi"; case .cambodia: return "Cambodia"; case .cameroon: return "Cameroon"; case .canada: return "Canada"; case .capeVerde: return "Cape Verde"; case .caymanIslands: return "Cayman Islands"; case .centralAfricanRepublic: return "Central African Republic"; case .chad: return "Chad"; case .chile: return "Chile"; case .china: return "China"; case .christmasIsland: return "Christmas Island"; case .cocosIslands: return "Cocos Islands"; case .colombia: return "Colombia"; case .comoros: return "Comoros"; case .congo: return "Congo"; case .congoTheDemocraticRepublicofthe: return "The Democratic Republic of the Congo"; case .cookIslands: return "Cook Islands"; case .costaRica: return "Costa Rica"; case .coteDIvoire: return "Cote D'Ivoire"; case .croatia: return "Croatia"; case .cuba: return "Cuba"; case .curacao: return "Curacao"; case .cyprus: return "Cyprus"; case .czechRepublic: return "Czech Republic"; case .denmark: return "Denmark"; case .djibouti: return "Djibouti"; case .dominica: return "Dominica"; case .dominicanRepublic: return "Dominican Republic"; case .ecuador: return "Ecuador"; case .egypt: return "Egypt"; case .elSalvador: return "El Salvador"; case .equatorialGuinea: return "Equatorial Guinea"; case .eritrea: return "Eritrea"; case .estonia: return "Estonia"; case .ethiopia: return "Ethiopia"; case .europe: return "Europe"; case .falklandIslands: return "Falkland Islands"; case .faroeIslands: return "Faroe Islands"; case .fiji: return "Fiji"; case .finland: return "Finland"; case .france: return "France"; case .frenchGuiana: return "French Guiana"; case .frenchPolynesia: return "French Polynesia"; case .frenchSouthernTerritories: return "French Southern Territories"; case .gabon: return "Gabon"; case .gambia: return "Gambia"; case .georgia: return "Georgia"; case .germany: return "Germany"; case .ghana: return "Ghana"; case .gibraltar: return "Gibraltar"; case .greece: return "Greece"; case .greenland: return "Greenland"; case .grenada: return "Grenada"; case .guadeloupe: return "Guadeloupe"; case .guam: return "Guam"; case .guatemala: return "Guatemala"; case .guernsey: return "Guernsey"; case .guinea: return "Guinea"; case .guineaBissau: return "Guinea-Bissau"; case .guyana: return "Guyana"; case .haiti: return "Haiti"; case .heardIslandandMcDonaldIslands: return "Heard Island and McDonald Islands"; case .holySeeVaticanCityState: return "Vatican City State"; case .honduras: return "Honduras"; case .hongKong: return "Hong Kong"; case .hungary: return "Hungary"; case .iceland: return "Iceland"; case .india: return "India"; case .indonesia: return "Indonesia"; case .iran: return "Iran"; case .iraq: return "Iraq"; case .ireland: return "Ireland"; case .isleofMan: return "Isle of Man"; case .israel: return "Israel"; case .italy: return "Italy"; case .jamaica: return "Jamaica"; case .japan: return "Japan"; case .jersey: return "Jersey"; case .jordan: return "Jordan"; case .kazakhstan: return "Kazakhstan"; case .kenya: return "Kenya"; case .kiribati: return "Kiribati"; case .kuwait: return "Kuwait"; case .kyrgyzstan: return "Kyrgyzstan"; case .laoPeoplesDemocraticRepublic: return "Lao People's Democratic Republic"; case .latvia: return "Latvia"; case .lebanon: return "Lebanon"; case .lesotho: return "Lesotho"; case .liberia: return "Liberia"; case .libya: return "Libya"; case .liechtenstein: return "Liechtenstein"; case .lithuania: return "Lithuania"; case .luxembourg: return "Luxembourg"; case .macau: return "Macau"; case .macedonia: return "Macedonia"; case .madagascar: return "Madagascar"; case .malawi: return "Malawi"; case .malaysia: return "Malaysia"; case .maldives: return "Maldives"; case .mali: return "Mali"; case .malta: return "Malta"; case .marshallIslands: return "Marshall Islands"; case .martinique: return "Martinique"; case .mauritania: return "Mauritania"; case .mauritius: return "Mauritius"; case .mayotte: return "Mayotte"; case .mexico: return "Mexico"; case .micronesia: return "Micronesia"; case .moldova: return "Moldova"; case .monaco: return "Monaco"; case .mongolia: return "Mongolia"; case .montenegro: return "Montenegro"; case .montserrat: return "Montserrat"; case .morocco: return "Morocco"; case .mozambique: return "Mozambique"; case .myanmar: return "Myanmar"; case .namibia: return "Namibia"; case .nauru: return "Nauru"; case .nepal: return "Nepal"; case .netherlands: return "Netherlands"; case .newCaledonia: return "New Caledonia"; case .newZealand: return "New Zealand"; case .nicaragua: return "Nicaragua"; case .niger: return "Niger"; case .nigeria: return "Nigeria"; case .niue: return "Niue"; case .norfolkIsland: return "Norfolk Island"; case .northKorea: return "North Korea"; case .northernMarianaIslands: return "Northern Mariana Islands"; case .norway: return "Norway"; case .oman: return "Oman"; case .pakistan: return "Pakistan"; case .palau: return "Palau"; case .palestinianTerritory: return "Palestinian Territory"; case .panama: return "Panama"; case .papuaNewGuinea: return "Papua New Guinea"; case .paraguay: return "Paraguay"; case .peru: return "Peru"; case .philippines: return "Philippines"; case .pitcairnIslands: return "Pitcairn Islands"; case .poland: return "Poland"; case .portugal: return "Portugal"; case .puertoRico: return "Puerto Rico"; case .qatar: return "Qatar"; case .reunion: return "Reunion"; case .romania: return "Romania"; case .russianFederation: return "Russian Federation"; case .rwanda: return "Rwanda"; case .saintBarthelemy: return "Saint Barthelemy"; case .saintHelena: return "Saint Helena"; case .saintKittsandNevis: return "Saint Kitts and Nevis"; case .saintLucia: return "Saint Lucia"; case .saintMartin: return "Saint Martin"; case .saintPierreandMiquelon: return "Saint Pierre and Miquelon"; case .saintVincentandtheGrenadines: return "Saint Vincent and the Grenadines"; case .samoa: return "Samoa"; case .sanMarino: return "San Marino"; case .saoTomeandPrincipe: return "Sao Tome and Principe"; case .saudiArabia: return "Saudi Arabia"; case .senegal: return "Senegal"; case .serbia: return "Serbia"; case .seychelles: return "Seychelles"; case .sierraLeone: return "Sierra Leone"; case .singapore: return "Singapore"; case .sintMaarten: return "Sint Maarten"; case .slovakia: return "Slovakia"; case .slovenia: return "Slovenia"; case .solomonIslands: return "Solomon Islands"; case .somalia: return "Somalia"; case .southAfrica: return "South Africa"; case .southGeorgiaandtheSouthSandwichIslands: return "South Georgia and the South Sandwich Islands"; case .southKorea: return "South Korea"; case .southSudan: return "South Sudan"; case .spain: return "Spain"; case .sriLanka: return "Sri Lanka"; case .sudan: return "Sudan"; case .suriname: return "Suriname"; case .svalbardandJanMayen: return "Svalbard and Jan Mayen"; case .swaziland: return "Swaziland"; case .sweden: return "Sweden"; case .switzerland: return "Switzerland"; case .syrianArabRepublic: return "Syrian Arab Republic"; case .taiwan: return "Taiwan"; case .tajikistan: return "Tajikistan"; case .tanzania: return "Tanzania"; case .thailand: return "Thailand"; case .timorLeste: return "Timor-Leste"; case .togo: return "Togo"; case .tokelau: return "Tokelau"; case .tonga: return "Tonga"; case .trinidadandTobago: return "Trinidad and Tobago"; case .tunisia: return "Tunisia"; case .turkey: return "Turkey"; case .turkmenistan: return "Turkmenistan"; case .turksandCaicosIslands: return "Turks and Caicos Islands"; case .tuvalu: return "Tuvalu"; case .uganda: return "Uganda"; case .ukraine: return "Ukraine"; case .unitedArabEmirates: return "United Arab Emirates"; case .unitedKingdom: return "United Kingdom"; case .unitedStates: return "United States"; case .unitedStatesMinorOutlyingIslands: return "United States Minor Outlying Islands"; case .uruguay: return "Uruguay"; case .uzbekistan: return "Uzbekistan"; case .vanuatu: return "Vanuatu"; case .venezuela: return "Venezuela"; case .vietnam: return "Vietnam"; case .virginIslandsBritish: return "British Virgin Islands"; case .virginIslandsUS: return "U.S. Virgin Islands"; case .wallisandFutuna: return "Wallis and Futuna"; case .westernSahara: return "Western Sahara"; case .yemen: return "Yemen"; case .zambia: return "Zambia"; case .zimbabwe: return "Zimbabwe"
        }
    }
}
// swiftlint:enable line_length switch_case_alignment
