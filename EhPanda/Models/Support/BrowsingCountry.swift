//
//  BrowsingCountry.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/30.
//

import Foundation

// swiftlint:disable line_length
extension EhSetting {
    enum BrowsingCountry: String, CaseIterable, Identifiable, Equatable {
        case autoDetect = "-"; case afghanistan = "AF"; case alandIslands = "AX"; case albania = "AL"; case algeria = "DZ"; case americanSamoa = "AS"; case andorra = "AD"; case angola = "AO"; case anguilla = "AI"; case antarctica = "AQ"; case antiguaAndBarbuda = "AG"; case argentina = "AR"; case armenia = "AM"; case aruba = "AW"; case asiaPacificRegion = "AP"; case australia = "AU"; case austria = "AT"; case azerbaijan = "AZ"; case bahamas = "BS"; case bahrain = "BH"; case bangladesh = "BD"; case barbados = "BB"; case belarus = "BY"; case belgium = "BE"; case belize = "BZ"; case benin = "BJ"; case bermuda = "BM"; case bhutan = "BT"; case bolivia = "BO"; case bonaireSaintEustatiusAndSaba = "BQ"; case bosniaAndHerzegovina = "BA"; case botswana = "BW"; case bouvetIsland = "BV"; case brazil = "BR"; case britishIndianOceanTerritory = "IO"; case bruneiDarussalam = "BN"; case bulgaria = "BG"; case burkinaFaso = "BF"; case burundi = "BI"; case cambodia = "KH"; case cameroon = "CM"; case canada = "CA"; case capeVerde = "CV"; case caymanIslands = "KY"; case centralAfricanRepublic = "CF"; case chad = "TD"; case chile = "CL"; case china = "CN"; case christmasIsland = "CX"; case cocosIslands = "CC"; case colombia = "CO"; case comoros = "KM"; case congo = "CG"; case theDemocraticRepublicOfTheCongo = "CD"; case cookIslands = "CK"; case costaRica = "CR"; case coteDIvoire = "CI"; case croatia = "HR"; case cuba = "CU"; case curacao = "CW"; case cyprus = "CY"; case czechRepublic = "CZ"; case denmark = "DK"; case djibouti = "DJ"; case dominica = "DM"; case dominicanRepublic = "DO"; case ecuador = "EC"; case egypt = "EG"; case elSalvador = "SV"; case equatorialGuinea = "GQ"; case eritrea = "ER"; case estonia = "EE"; case ethiopia = "ET"; case europe = "EU"; case falklandIslands = "FK"; case faroeIslands = "FO"; case fiji = "FJ"; case finland = "FI"; case france = "FR"; case frenchGuiana = "GF"; case frenchPolynesia = "PF"; case frenchSouthernTerritories = "TF"; case gabon = "GA"; case gambia = "GM"; case georgia = "GE"; case germany = "DE"; case ghana = "GH"; case gibraltar = "GI"; case greece = "GR"; case greenland = "GL"; case grenada = "GD"; case guadeloupe = "GP"; case guam = "GU"; case guatemala = "GT"; case guernsey = "GG"; case guinea = "GN"; case guineaBissau = "GW"; case guyana = "GY"; case haiti = "HT"; case heardIslandAndMcDonaldIslands = "HM"; case vaticanCityState = "VA"; case honduras = "HN"; case hongKong = "HK"; case hungary = "HU"; case iceland = "IS"; case india = "IN"; case indonesia = "ID"; case iran = "IR"; case iraq = "IQ"; case ireland = "IE"; case isleOfMan = "IM"; case israel = "IL"; case italy = "IT"; case jamaica = "JM"; case japan = "JP"; case jersey = "JE"; case jordan = "JO"; case kazakhstan = "KZ"; case kenya = "KE"; case kiribati = "KI"; case kuwait = "KW"; case kyrgyzstan = "KG"; case laoPeoplesDemocraticRepublic = "LA"; case latvia = "LV"; case lebanon = "LB"; case lesotho = "LS"; case liberia = "LR"; case libya = "LY"; case liechtenstein = "LI"; case lithuania = "LT"; case luxembourg = "LU"; case macau = "MO"; case macedonia = "MK"; case madagascar = "MG"; case malawi = "MW"; case malaysia = "MY"; case maldives = "MV"; case mali = "ML"; case malta = "MT"; case marshallIslands = "MH"; case martinique = "MQ"; case mauritania = "MR"; case mauritius = "MU"; case mayotte = "YT"; case mexico = "MX"; case micronesia = "FM"; case moldova = "MD"; case monaco = "MC"; case mongolia = "MN"; case montenegro = "ME"; case montserrat = "MS"; case morocco = "MA"; case mozambique = "MZ"; case myanmar = "MM"; case namibia = "NA"; case nauru = "NR"; case nepal = "NP"; case netherlands = "NL"; case newCaledonia = "NC"; case newZealand = "NZ"; case nicaragua = "NI"; case niger = "NE"; case nigeria = "NG"; case niue = "NU"; case norfolkIsland = "NF"; case northKorea = "KP"; case northernMarianaIslands = "MP"; case norway = "NO"; case oman = "OM"; case pakistan = "PK"; case palau = "PW"; case palestinianTerritory = "PS"; case panama = "PA"; case papuaNewGuinea = "PG"; case paraguay = "PY"; case peru = "PE"; case philippines = "PH"; case pitcairnIslands = "PN"; case poland = "PL"; case portugal = "PT"; case puertoRico = "PR"; case qatar = "QA"; case reunion = "RE"; case romania = "RO"; case russianFederation = "RU"; case rwanda = "RW"; case saintBarthelemy = "BL"; case saintHelena = "SH"; case saintKittsAndNevis = "KN"; case saintLucia = "LC"; case saintMartin = "MF"; case saintPierreAndMiquelon = "PM"; case saintVincentAndTheGrenadines = "VC"; case samoa = "WS"; case sanMarino = "SM"; case saoTomeAndPrincipe = "ST"; case saudiArabia = "SA"; case senegal = "SN"; case serbia = "RS"; case seychelles = "SC"; case sierraLeone = "SL"; case singapore = "SG"; case sintMaarten = "SX"; case slovakia = "SK"; case slovenia = "SI"; case solomonIslands = "SB"; case somalia = "SO"; case southAfrica = "ZA"; case southGeorgiaAndTheSouthSandwichIslands = "GS"; case southKorea = "KR"; case southSudan = "SS"; case spain = "ES"; case sriLanka = "LK"; case sudan = "SD"; case suriname = "SR"; case svalbardAndJanMayen = "SJ"; case swaziland = "SZ"; case sweden = "SE"; case switzerland = "CH"; case syrianArabRepublic = "SY"; case taiwan = "TW"; case tajikistan = "TJ"; case tanzania = "TZ"; case thailand = "TH"; case timorLeste = "TL"; case togo = "TG"; case tokelau = "TK"; case tonga = "TO"; case trinidadAndTobago = "TT"; case tunisia = "TN"; case turkey = "TR"; case turkmenistan = "TM"; case turksAndCaicosIslands = "TC"; case tuvalu = "TV"; case uganda = "UG"; case ukraine = "UA"; case unitedArabEmirates = "AE"; case unitedKingdom = "GB"; case unitedStates = "US"; case unitedStatesMinorOutlyingIslands = "UM"; case uruguay = "UY"; case uzbekistan = "UZ"; case vanuatu = "VU"; case venezuela = "VE"; case vietnam = "VN"; case virginIslandsBritish = "VG"; case virginIslandsUS = "VI"; case wallisAndFutuna = "WF"; case westernSahara = "EH"; case yemen = "YE"; case zambia = "ZM"; case zimbabwe = "ZW"
    }
}
extension EhSetting.BrowsingCountry {
    var id: Int { hashValue }
    var name: String {
        getName()
    }
    var englishName: String {
        getName(preferredLanguages: ["en"])
    }
    private func getName(preferredLanguages: [String]? = nil) -> String {
        switch self {
        case .autoDetect:
            return R.string.localizable.enumBrowsingCountryNameAutoDetect(preferredLanguages: preferredLanguages)
        case .afghanistan:
            return R.string.localizable.enumBrowsingCountryNameAfghanistan(preferredLanguages: preferredLanguages)
        case .alandIslands:
            return R.string.localizable.enumBrowsingCountryNameAlandIslands(preferredLanguages: preferredLanguages)
        case .albania:
            return R.string.localizable.enumBrowsingCountryNameAlbania(preferredLanguages: preferredLanguages)
        case .algeria:
            return R.string.localizable.enumBrowsingCountryNameAlgeria(preferredLanguages: preferredLanguages)
        case .americanSamoa:
            return R.string.localizable.enumBrowsingCountryNameAmericanSamoa(preferredLanguages: preferredLanguages)
        case .andorra:
            return R.string.localizable.enumBrowsingCountryNameAndorra(preferredLanguages: preferredLanguages)
        case .angola:
            return R.string.localizable.enumBrowsingCountryNameAngola(preferredLanguages: preferredLanguages)
        case .anguilla:
            return R.string.localizable.enumBrowsingCountryNameAnguilla(preferredLanguages: preferredLanguages)
        case .antarctica:
            return R.string.localizable.enumBrowsingCountryNameAntarctica(preferredLanguages: preferredLanguages)
        case .antiguaAndBarbuda:
            return R.string.localizable.enumBrowsingCountryNameAntiguaAndBarbuda(preferredLanguages: preferredLanguages)
        case .argentina:
            return R.string.localizable.enumBrowsingCountryNameArgentina(preferredLanguages: preferredLanguages)
        case .armenia:
            return R.string.localizable.enumBrowsingCountryNameArmenia(preferredLanguages: preferredLanguages)
        case .aruba:
            return R.string.localizable.enumBrowsingCountryNameAruba(preferredLanguages: preferredLanguages)
        case .asiaPacificRegion:
            return R.string.localizable.enumBrowsingCountryNameAsiaPacificRegion(preferredLanguages: preferredLanguages)
        case .australia:
            return R.string.localizable.enumBrowsingCountryNameAustralia(preferredLanguages: preferredLanguages)
        case .austria:
            return R.string.localizable.enumBrowsingCountryNameAustria(preferredLanguages: preferredLanguages)
        case .azerbaijan:
            return R.string.localizable.enumBrowsingCountryNameAzerbaijan(preferredLanguages: preferredLanguages)
        case .bahamas:
            return R.string.localizable.enumBrowsingCountryNameBahamas(preferredLanguages: preferredLanguages)
        case .bahrain:
            return R.string.localizable.enumBrowsingCountryNameBahrain(preferredLanguages: preferredLanguages)
        case .bangladesh:
            return R.string.localizable.enumBrowsingCountryNameBangladesh(preferredLanguages: preferredLanguages)
        case .barbados:
            return R.string.localizable.enumBrowsingCountryNameBarbados(preferredLanguages: preferredLanguages)
        case .belarus:
            return R.string.localizable.enumBrowsingCountryNameBelarus(preferredLanguages: preferredLanguages)
        case .belgium:
            return R.string.localizable.enumBrowsingCountryNameBelgium(preferredLanguages: preferredLanguages)
        case .belize:
            return R.string.localizable.enumBrowsingCountryNameBelize(preferredLanguages: preferredLanguages)
        case .benin:
            return R.string.localizable.enumBrowsingCountryNameBenin(preferredLanguages: preferredLanguages)
        case .bermuda:
            return R.string.localizable.enumBrowsingCountryNameBermuda(preferredLanguages: preferredLanguages)
        case .bhutan:
            return R.string.localizable.enumBrowsingCountryNameBhutan(preferredLanguages: preferredLanguages)
        case .bolivia:
            return R.string.localizable.enumBrowsingCountryNameBolivia(preferredLanguages: preferredLanguages)
        case .bonaireSaintEustatiusAndSaba:
            return R.string.localizable.enumBrowsingCountryNameBonaireSaintEustatiusAndSaba(preferredLanguages: preferredLanguages)
        case .bosniaAndHerzegovina:
            return R.string.localizable.enumBrowsingCountryNameBosniaAndHerzegovina(preferredLanguages: preferredLanguages)
        case .botswana:
            return R.string.localizable.enumBrowsingCountryNameBotswana(preferredLanguages: preferredLanguages)
        case .bouvetIsland:
            return R.string.localizable.enumBrowsingCountryNameBouvetIsland(preferredLanguages: preferredLanguages)
        case .brazil:
            return R.string.localizable.enumBrowsingCountryNameBrazil(preferredLanguages: preferredLanguages)
        case .britishIndianOceanTerritory:
            return R.string.localizable.enumBrowsingCountryNameBritishIndianOceanTerritory(preferredLanguages: preferredLanguages)
        case .bruneiDarussalam:
            return R.string.localizable.enumBrowsingCountryNameBruneiDarussalam(preferredLanguages: preferredLanguages)
        case .bulgaria:
            return R.string.localizable.enumBrowsingCountryNameBulgaria(preferredLanguages: preferredLanguages)
        case .burkinaFaso:
            return R.string.localizable.enumBrowsingCountryNameBurkinaFaso(preferredLanguages: preferredLanguages)
        case .burundi:
            return R.string.localizable.enumBrowsingCountryNameBurundi(preferredLanguages: preferredLanguages)
        case .cambodia:
            return R.string.localizable.enumBrowsingCountryNameCambodia(preferredLanguages: preferredLanguages)
        case .cameroon:
            return R.string.localizable.enumBrowsingCountryNameCameroon(preferredLanguages: preferredLanguages)
        case .canada:
            return R.string.localizable.enumBrowsingCountryNameCanada(preferredLanguages: preferredLanguages)
        case .capeVerde:
            return R.string.localizable.enumBrowsingCountryNameCapeVerde(preferredLanguages: preferredLanguages)
        case .caymanIslands:
            return R.string.localizable.enumBrowsingCountryNameCaymanIslands(preferredLanguages: preferredLanguages)
        case .centralAfricanRepublic:
            return R.string.localizable.enumBrowsingCountryNameCentralAfricanRepublic(preferredLanguages: preferredLanguages)
        case .chad:
            return R.string.localizable.enumBrowsingCountryNameChad(preferredLanguages: preferredLanguages)
        case .chile:
            return R.string.localizable.enumBrowsingCountryNameChile(preferredLanguages: preferredLanguages)
        case .china:
            return R.string.localizable.enumBrowsingCountryNameChina(preferredLanguages: preferredLanguages)
        case .christmasIsland:
            return R.string.localizable.enumBrowsingCountryNameChristmasIsland(preferredLanguages: preferredLanguages)
        case .cocosIslands:
            return R.string.localizable.enumBrowsingCountryNameCocosIslands(preferredLanguages: preferredLanguages)
        case .colombia:
            return R.string.localizable.enumBrowsingCountryNameColombia(preferredLanguages: preferredLanguages)
        case .comoros:
            return R.string.localizable.enumBrowsingCountryNameComoros(preferredLanguages: preferredLanguages)
        case .congo:
            return R.string.localizable.enumBrowsingCountryNameCongo(preferredLanguages: preferredLanguages)
        case .theDemocraticRepublicOfTheCongo:
            return R.string.localizable.enumBrowsingCountryNameTheDemocraticRepublicOfTheCongo(preferredLanguages: preferredLanguages)
        case .cookIslands:
            return R.string.localizable.enumBrowsingCountryNameCookIslands(preferredLanguages: preferredLanguages)
        case .costaRica:
            return R.string.localizable.enumBrowsingCountryNameCostaRica(preferredLanguages: preferredLanguages)
        case .coteDIvoire:
            return R.string.localizable.enumBrowsingCountryNameCoteDIvoire(preferredLanguages: preferredLanguages)
        case .croatia:
            return R.string.localizable.enumBrowsingCountryNameCroatia(preferredLanguages: preferredLanguages)
        case .cuba:
            return R.string.localizable.enumBrowsingCountryNameCuba(preferredLanguages: preferredLanguages)
        case .curacao:
            return R.string.localizable.enumBrowsingCountryNameCuracao(preferredLanguages: preferredLanguages)
        case .cyprus:
            return R.string.localizable.enumBrowsingCountryNameCyprus(preferredLanguages: preferredLanguages)
        case .czechRepublic:
            return R.string.localizable.enumBrowsingCountryNameCzechRepublic(preferredLanguages: preferredLanguages)
        case .denmark:
            return R.string.localizable.enumBrowsingCountryNameDenmark(preferredLanguages: preferredLanguages)
        case .djibouti:
            return R.string.localizable.enumBrowsingCountryNameDjibouti(preferredLanguages: preferredLanguages)
        case .dominica:
            return R.string.localizable.enumBrowsingCountryNameDominica(preferredLanguages: preferredLanguages)
        case .dominicanRepublic:
            return R.string.localizable.enumBrowsingCountryNameDominicanRepublic(preferredLanguages: preferredLanguages)
        case .ecuador:
            return R.string.localizable.enumBrowsingCountryNameEcuador(preferredLanguages: preferredLanguages)
        case .egypt:
            return R.string.localizable.enumBrowsingCountryNameEgypt(preferredLanguages: preferredLanguages)
        case .elSalvador:
            return R.string.localizable.enumBrowsingCountryNameElSalvador(preferredLanguages: preferredLanguages)
        case .equatorialGuinea:
            return R.string.localizable.enumBrowsingCountryNameEquatorialGuinea(preferredLanguages: preferredLanguages)
        case .eritrea:
            return R.string.localizable.enumBrowsingCountryNameEritrea(preferredLanguages: preferredLanguages)
        case .estonia:
            return R.string.localizable.enumBrowsingCountryNameEstonia(preferredLanguages: preferredLanguages)
        case .ethiopia:
            return R.string.localizable.enumBrowsingCountryNameEthiopia(preferredLanguages: preferredLanguages)
        case .europe:
            return R.string.localizable.enumBrowsingCountryNameEurope(preferredLanguages: preferredLanguages)
        case .falklandIslands:
            return R.string.localizable.enumBrowsingCountryNameFalklandIslands(preferredLanguages: preferredLanguages)
        case .faroeIslands:
            return R.string.localizable.enumBrowsingCountryNameFaroeIslands(preferredLanguages: preferredLanguages)
        case .fiji:
            return R.string.localizable.enumBrowsingCountryNameFiji(preferredLanguages: preferredLanguages)
        case .finland:
            return R.string.localizable.enumBrowsingCountryNameFinland(preferredLanguages: preferredLanguages)
        case .france:
            return R.string.localizable.enumBrowsingCountryNameFrance(preferredLanguages: preferredLanguages)
        case .frenchGuiana:
            return R.string.localizable.enumBrowsingCountryNameFrenchGuiana(preferredLanguages: preferredLanguages)
        case .frenchPolynesia:
            return R.string.localizable.enumBrowsingCountryNameFrenchPolynesia(preferredLanguages: preferredLanguages)
        case .frenchSouthernTerritories:
            return R.string.localizable.enumBrowsingCountryNameFrenchSouthernTerritories(preferredLanguages: preferredLanguages)
        case .gabon:
            return R.string.localizable.enumBrowsingCountryNameGabon(preferredLanguages: preferredLanguages)
        case .gambia:
            return R.string.localizable.enumBrowsingCountryNameGambia(preferredLanguages: preferredLanguages)
        case .georgia:
            return R.string.localizable.enumBrowsingCountryNameGeorgia(preferredLanguages: preferredLanguages)
        case .germany:
            return R.string.localizable.enumBrowsingCountryNameGermany(preferredLanguages: preferredLanguages)
        case .ghana:
            return R.string.localizable.enumBrowsingCountryNameGhana(preferredLanguages: preferredLanguages)
        case .gibraltar:
            return R.string.localizable.enumBrowsingCountryNameGibraltar(preferredLanguages: preferredLanguages)
        case .greece:
            return R.string.localizable.enumBrowsingCountryNameGreece(preferredLanguages: preferredLanguages)
        case .greenland:
            return R.string.localizable.enumBrowsingCountryNameGreenland(preferredLanguages: preferredLanguages)
        case .grenada:
            return R.string.localizable.enumBrowsingCountryNameGrenada(preferredLanguages: preferredLanguages)
        case .guadeloupe:
            return R.string.localizable.enumBrowsingCountryNameGuadeloupe(preferredLanguages: preferredLanguages)
        case .guam:
            return R.string.localizable.enumBrowsingCountryNameGuam(preferredLanguages: preferredLanguages)
        case .guatemala:
            return R.string.localizable.enumBrowsingCountryNameGuatemala(preferredLanguages: preferredLanguages)
        case .guernsey:
            return R.string.localizable.enumBrowsingCountryNameGuernsey(preferredLanguages: preferredLanguages)
        case .guinea:
            return R.string.localizable.enumBrowsingCountryNameGuinea(preferredLanguages: preferredLanguages)
        case .guineaBissau:
            return R.string.localizable.enumBrowsingCountryNameGuineaBissau(preferredLanguages: preferredLanguages)
        case .guyana:
            return R.string.localizable.enumBrowsingCountryNameGuyana(preferredLanguages: preferredLanguages)
        case .haiti:
            return R.string.localizable.enumBrowsingCountryNameHaiti(preferredLanguages: preferredLanguages)
        case .heardIslandAndMcDonaldIslands:
            return R.string.localizable.enumBrowsingCountryNameHeardIslandAndMcDonaldIslands(preferredLanguages: preferredLanguages)
        case .vaticanCityState:
            return R.string.localizable.enumBrowsingCountryNameVaticanCityState(preferredLanguages: preferredLanguages)
        case .honduras:
            return R.string.localizable.enumBrowsingCountryNameHonduras(preferredLanguages: preferredLanguages)
        case .hongKong:
            return R.string.localizable.enumBrowsingCountryNameHongKong(preferredLanguages: preferredLanguages)
        case .hungary:
            return R.string.localizable.enumBrowsingCountryNameHungary(preferredLanguages: preferredLanguages)
        case .iceland:
            return R.string.localizable.enumBrowsingCountryNameIceland(preferredLanguages: preferredLanguages)
        case .india:
            return R.string.localizable.enumBrowsingCountryNameIndia(preferredLanguages: preferredLanguages)
        case .indonesia:
            return R.string.localizable.enumBrowsingCountryNameIndonesia(preferredLanguages: preferredLanguages)
        case .iran:
            return R.string.localizable.enumBrowsingCountryNameIran(preferredLanguages: preferredLanguages)
        case .iraq:
            return R.string.localizable.enumBrowsingCountryNameIraq(preferredLanguages: preferredLanguages)
        case .ireland:
            return R.string.localizable.enumBrowsingCountryNameIreland(preferredLanguages: preferredLanguages)
        case .isleOfMan:
            return R.string.localizable.enumBrowsingCountryNameIsleOfMan(preferredLanguages: preferredLanguages)
        case .israel:
            return R.string.localizable.enumBrowsingCountryNameIsrael(preferredLanguages: preferredLanguages)
        case .italy:
            return R.string.localizable.enumBrowsingCountryNameItaly(preferredLanguages: preferredLanguages)
        case .jamaica:
            return R.string.localizable.enumBrowsingCountryNameJamaica(preferredLanguages: preferredLanguages)
        case .japan:
            return R.string.localizable.enumBrowsingCountryNameJapan(preferredLanguages: preferredLanguages)
        case .jersey:
            return R.string.localizable.enumBrowsingCountryNameJersey(preferredLanguages: preferredLanguages)
        case .jordan:
            return R.string.localizable.enumBrowsingCountryNameJordan(preferredLanguages: preferredLanguages)
        case .kazakhstan:
            return R.string.localizable.enumBrowsingCountryNameKazakhstan(preferredLanguages: preferredLanguages)
        case .kenya:
            return R.string.localizable.enumBrowsingCountryNameKenya(preferredLanguages: preferredLanguages)
        case .kiribati:
            return R.string.localizable.enumBrowsingCountryNameKiribati(preferredLanguages: preferredLanguages)
        case .kuwait:
            return R.string.localizable.enumBrowsingCountryNameKuwait(preferredLanguages: preferredLanguages)
        case .kyrgyzstan:
            return R.string.localizable.enumBrowsingCountryNameKyrgyzstan(preferredLanguages: preferredLanguages)
        case .laoPeoplesDemocraticRepublic:
            return R.string.localizable.enumBrowsingCountryNameLaoPeoplesDemocraticRepublic(preferredLanguages: preferredLanguages)
        case .latvia:
            return R.string.localizable.enumBrowsingCountryNameLatvia(preferredLanguages: preferredLanguages)
        case .lebanon:
            return R.string.localizable.enumBrowsingCountryNameLebanon(preferredLanguages: preferredLanguages)
        case .lesotho:
            return R.string.localizable.enumBrowsingCountryNameLesotho(preferredLanguages: preferredLanguages)
        case .liberia:
            return R.string.localizable.enumBrowsingCountryNameLiberia(preferredLanguages: preferredLanguages)
        case .libya:
            return R.string.localizable.enumBrowsingCountryNameLibya(preferredLanguages: preferredLanguages)
        case .liechtenstein:
            return R.string.localizable.enumBrowsingCountryNameLiechtenstein(preferredLanguages: preferredLanguages)
        case .lithuania:
            return R.string.localizable.enumBrowsingCountryNameLithuania(preferredLanguages: preferredLanguages)
        case .luxembourg:
            return R.string.localizable.enumBrowsingCountryNameLuxembourg(preferredLanguages: preferredLanguages)
        case .macau:
            return R.string.localizable.enumBrowsingCountryNameMacau(preferredLanguages: preferredLanguages)
        case .macedonia:
            return R.string.localizable.enumBrowsingCountryNameMacedonia(preferredLanguages: preferredLanguages)
        case .madagascar:
            return R.string.localizable.enumBrowsingCountryNameMadagascar(preferredLanguages: preferredLanguages)
        case .malawi:
            return R.string.localizable.enumBrowsingCountryNameMalawi(preferredLanguages: preferredLanguages)
        case .malaysia:
            return R.string.localizable.enumBrowsingCountryNameMalaysia(preferredLanguages: preferredLanguages)
        case .maldives:
            return R.string.localizable.enumBrowsingCountryNameMaldives(preferredLanguages: preferredLanguages)
        case .mali:
            return R.string.localizable.enumBrowsingCountryNameMali(preferredLanguages: preferredLanguages)
        case .malta:
            return R.string.localizable.enumBrowsingCountryNameMalta(preferredLanguages: preferredLanguages)
        case .marshallIslands:
            return R.string.localizable.enumBrowsingCountryNameMarshallIslands(preferredLanguages: preferredLanguages)
        case .martinique:
            return R.string.localizable.enumBrowsingCountryNameMartinique(preferredLanguages: preferredLanguages)
        case .mauritania:
            return R.string.localizable.enumBrowsingCountryNameMauritania(preferredLanguages: preferredLanguages)
        case .mauritius:
            return R.string.localizable.enumBrowsingCountryNameMauritius(preferredLanguages: preferredLanguages)
        case .mayotte:
            return R.string.localizable.enumBrowsingCountryNameMayotte(preferredLanguages: preferredLanguages)
        case .mexico:
            return R.string.localizable.enumBrowsingCountryNameMexico(preferredLanguages: preferredLanguages)
        case .micronesia:
            return R.string.localizable.enumBrowsingCountryNameMicronesia(preferredLanguages: preferredLanguages)
        case .moldova:
            return R.string.localizable.enumBrowsingCountryNameMoldova(preferredLanguages: preferredLanguages)
        case .monaco:
            return R.string.localizable.enumBrowsingCountryNameMonaco(preferredLanguages: preferredLanguages)
        case .mongolia:
            return R.string.localizable.enumBrowsingCountryNameMongolia(preferredLanguages: preferredLanguages)
        case .montenegro:
            return R.string.localizable.enumBrowsingCountryNameMontenegro(preferredLanguages: preferredLanguages)
        case .montserrat:
            return R.string.localizable.enumBrowsingCountryNameMontserrat(preferredLanguages: preferredLanguages)
        case .morocco:
            return R.string.localizable.enumBrowsingCountryNameMorocco(preferredLanguages: preferredLanguages)
        case .mozambique:
            return R.string.localizable.enumBrowsingCountryNameMozambique(preferredLanguages: preferredLanguages)
        case .myanmar:
            return R.string.localizable.enumBrowsingCountryNameMyanmar(preferredLanguages: preferredLanguages)
        case .namibia:
            return R.string.localizable.enumBrowsingCountryNameNamibia(preferredLanguages: preferredLanguages)
        case .nauru:
            return R.string.localizable.enumBrowsingCountryNameNauru(preferredLanguages: preferredLanguages)
        case .nepal:
            return R.string.localizable.enumBrowsingCountryNameNepal(preferredLanguages: preferredLanguages)
        case .netherlands:
            return R.string.localizable.enumBrowsingCountryNameNetherlands(preferredLanguages: preferredLanguages)
        case .newCaledonia:
            return R.string.localizable.enumBrowsingCountryNameNewCaledonia(preferredLanguages: preferredLanguages)
        case .newZealand:
            return R.string.localizable.enumBrowsingCountryNameNewZealand(preferredLanguages: preferredLanguages)
        case .nicaragua:
            return R.string.localizable.enumBrowsingCountryNameNicaragua(preferredLanguages: preferredLanguages)
        case .niger:
            return R.string.localizable.enumBrowsingCountryNameNiger(preferredLanguages: preferredLanguages)
        case .nigeria:
            return R.string.localizable.enumBrowsingCountryNameNigeria(preferredLanguages: preferredLanguages)
        case .niue:
            return R.string.localizable.enumBrowsingCountryNameNiue(preferredLanguages: preferredLanguages)
        case .norfolkIsland:
            return R.string.localizable.enumBrowsingCountryNameNorfolkIsland(preferredLanguages: preferredLanguages)
        case .northKorea:
            return R.string.localizable.enumBrowsingCountryNameNorthKorea(preferredLanguages: preferredLanguages)
        case .northernMarianaIslands:
            return R.string.localizable.enumBrowsingCountryNameNorthernMarianaIslands(preferredLanguages: preferredLanguages)
        case .norway:
            return R.string.localizable.enumBrowsingCountryNameNorway(preferredLanguages: preferredLanguages)
        case .oman:
            return R.string.localizable.enumBrowsingCountryNameOman(preferredLanguages: preferredLanguages)
        case .pakistan:
            return R.string.localizable.enumBrowsingCountryNamePakistan(preferredLanguages: preferredLanguages)
        case .palau:
            return R.string.localizable.enumBrowsingCountryNamePalau(preferredLanguages: preferredLanguages)
        case .palestinianTerritory:
            return R.string.localizable.enumBrowsingCountryNamePalestinianTerritory(preferredLanguages: preferredLanguages)
        case .panama:
            return R.string.localizable.enumBrowsingCountryNamePanama(preferredLanguages: preferredLanguages)
        case .papuaNewGuinea:
            return R.string.localizable.enumBrowsingCountryNamePapuaNewGuinea(preferredLanguages: preferredLanguages)
        case .paraguay:
            return R.string.localizable.enumBrowsingCountryNameParaguay(preferredLanguages: preferredLanguages)
        case .peru:
            return R.string.localizable.enumBrowsingCountryNamePeru(preferredLanguages: preferredLanguages)
        case .philippines:
            return R.string.localizable.enumBrowsingCountryNamePhilippines(preferredLanguages: preferredLanguages)
        case .pitcairnIslands:
            return R.string.localizable.enumBrowsingCountryNamePitcairnIslands(preferredLanguages: preferredLanguages)
        case .poland:
            return R.string.localizable.enumBrowsingCountryNamePoland(preferredLanguages: preferredLanguages)
        case .portugal:
            return R.string.localizable.enumBrowsingCountryNamePortugal(preferredLanguages: preferredLanguages)
        case .puertoRico:
            return R.string.localizable.enumBrowsingCountryNamePuertoRico(preferredLanguages: preferredLanguages)
        case .qatar:
            return R.string.localizable.enumBrowsingCountryNameQatar(preferredLanguages: preferredLanguages)
        case .reunion:
            return R.string.localizable.enumBrowsingCountryNameReunion(preferredLanguages: preferredLanguages)
        case .romania:
            return R.string.localizable.enumBrowsingCountryNameRomania(preferredLanguages: preferredLanguages)
        case .russianFederation:
            return R.string.localizable.enumBrowsingCountryNameRussianFederation(preferredLanguages: preferredLanguages)
        case .rwanda:
            return R.string.localizable.enumBrowsingCountryNameRwanda(preferredLanguages: preferredLanguages)
        case .saintBarthelemy:
            return R.string.localizable.enumBrowsingCountryNameSaintBarthelemy(preferredLanguages: preferredLanguages)
        case .saintHelena:
            return R.string.localizable.enumBrowsingCountryNameSaintHelena(preferredLanguages: preferredLanguages)
        case .saintKittsAndNevis:
            return R.string.localizable.enumBrowsingCountryNameSaintKittsAndNevis(preferredLanguages: preferredLanguages)
        case .saintLucia:
            return R.string.localizable.enumBrowsingCountryNameSaintLucia(preferredLanguages: preferredLanguages)
        case .saintMartin:
            return R.string.localizable.enumBrowsingCountryNameSaintMartin(preferredLanguages: preferredLanguages)
        case .saintPierreAndMiquelon:
            return R.string.localizable.enumBrowsingCountryNameSaintPierreAndMiquelon(preferredLanguages: preferredLanguages)
        case .saintVincentAndTheGrenadines:
            return R.string.localizable.enumBrowsingCountryNameSaintVincentAndTheGrenadines(preferredLanguages: preferredLanguages)
        case .samoa:
            return R.string.localizable.enumBrowsingCountryNameSamoa(preferredLanguages: preferredLanguages)
        case .sanMarino:
            return R.string.localizable.enumBrowsingCountryNameSanMarino(preferredLanguages: preferredLanguages)
        case .saoTomeAndPrincipe:
            return R.string.localizable.enumBrowsingCountryNameSaoTomeAndPrincipe(preferredLanguages: preferredLanguages)
        case .saudiArabia:
            return R.string.localizable.enumBrowsingCountryNameSaudiArabia(preferredLanguages: preferredLanguages)
        case .senegal:
            return R.string.localizable.enumBrowsingCountryNameSenegal(preferredLanguages: preferredLanguages)
        case .serbia:
            return R.string.localizable.enumBrowsingCountryNameSerbia(preferredLanguages: preferredLanguages)
        case .seychelles:
            return R.string.localizable.enumBrowsingCountryNameSeychelles(preferredLanguages: preferredLanguages)
        case .sierraLeone:
            return R.string.localizable.enumBrowsingCountryNameSierraLeone(preferredLanguages: preferredLanguages)
        case .singapore:
            return R.string.localizable.enumBrowsingCountryNameSingapore(preferredLanguages: preferredLanguages)
        case .sintMaarten:
            return R.string.localizable.enumBrowsingCountryNameSintMaarten(preferredLanguages: preferredLanguages)
        case .slovakia:
            return R.string.localizable.enumBrowsingCountryNameSlovakia(preferredLanguages: preferredLanguages)
        case .slovenia:
            return R.string.localizable.enumBrowsingCountryNameSlovenia(preferredLanguages: preferredLanguages)
        case .solomonIslands:
            return R.string.localizable.enumBrowsingCountryNameSolomonIslands(preferredLanguages: preferredLanguages)
        case .somalia:
            return R.string.localizable.enumBrowsingCountryNameSomalia(preferredLanguages: preferredLanguages)
        case .southAfrica:
            return R.string.localizable.enumBrowsingCountryNameSouthAfrica(preferredLanguages: preferredLanguages)
        case .southGeorgiaAndTheSouthSandwichIslands:
            return R.string.localizable.enumBrowsingCountryNameSouthGeorgiaAndTheSouthSandwichIslands(preferredLanguages: preferredLanguages)
        case .southKorea:
            return R.string.localizable.enumBrowsingCountryNameSouthKorea(preferredLanguages: preferredLanguages)
        case .southSudan:
            return R.string.localizable.enumBrowsingCountryNameSouthSudan(preferredLanguages: preferredLanguages)
        case .spain:
            return R.string.localizable.enumBrowsingCountryNameSpain(preferredLanguages: preferredLanguages)
        case .sriLanka:
            return R.string.localizable.enumBrowsingCountryNameSriLanka(preferredLanguages: preferredLanguages)
        case .sudan:
            return R.string.localizable.enumBrowsingCountryNameSudan(preferredLanguages: preferredLanguages)
        case .suriname:
            return R.string.localizable.enumBrowsingCountryNameSuriname(preferredLanguages: preferredLanguages)
        case .svalbardAndJanMayen:
            return R.string.localizable.enumBrowsingCountryNameSvalbardAndJanMayen(preferredLanguages: preferredLanguages)
        case .swaziland:
            return R.string.localizable.enumBrowsingCountryNameSwaziland(preferredLanguages: preferredLanguages)
        case .sweden:
            return R.string.localizable.enumBrowsingCountryNameSweden(preferredLanguages: preferredLanguages)
        case .switzerland:
            return R.string.localizable.enumBrowsingCountryNameSwitzerland(preferredLanguages: preferredLanguages)
        case .syrianArabRepublic:
            return R.string.localizable.enumBrowsingCountryNameSyrianArabRepublic(preferredLanguages: preferredLanguages)
        case .taiwan:
            return R.string.localizable.enumBrowsingCountryNameTaiwan(preferredLanguages: preferredLanguages)
        case .tajikistan:
            return R.string.localizable.enumBrowsingCountryNameTajikistan(preferredLanguages: preferredLanguages)
        case .tanzania:
            return R.string.localizable.enumBrowsingCountryNameTanzania(preferredLanguages: preferredLanguages)
        case .thailand:
            return R.string.localizable.enumBrowsingCountryNameThailand(preferredLanguages: preferredLanguages)
        case .timorLeste:
            return R.string.localizable.enumBrowsingCountryNameTimorLeste(preferredLanguages: preferredLanguages)
        case .togo:
            return R.string.localizable.enumBrowsingCountryNameTogo(preferredLanguages: preferredLanguages)
        case .tokelau:
            return R.string.localizable.enumBrowsingCountryNameTokelau(preferredLanguages: preferredLanguages)
        case .tonga:
            return R.string.localizable.enumBrowsingCountryNameTonga(preferredLanguages: preferredLanguages)
        case .trinidadAndTobago:
            return R.string.localizable.enumBrowsingCountryNameTrinidadAndTobago(preferredLanguages: preferredLanguages)
        case .tunisia:
            return R.string.localizable.enumBrowsingCountryNameTunisia(preferredLanguages: preferredLanguages)
        case .turkey:
            return R.string.localizable.enumBrowsingCountryNameTurkey(preferredLanguages: preferredLanguages)
        case .turkmenistan:
            return R.string.localizable.enumBrowsingCountryNameTurkmenistan(preferredLanguages: preferredLanguages)
        case .turksAndCaicosIslands:
            return R.string.localizable.enumBrowsingCountryNameTurksAndCaicosIslands(preferredLanguages: preferredLanguages)
        case .tuvalu:
            return R.string.localizable.enumBrowsingCountryNameTuvalu(preferredLanguages: preferredLanguages)
        case .uganda:
            return R.string.localizable.enumBrowsingCountryNameUganda(preferredLanguages: preferredLanguages)
        case .ukraine:
            return R.string.localizable.enumBrowsingCountryNameUkraine(preferredLanguages: preferredLanguages)
        case .unitedArabEmirates:
            return R.string.localizable.enumBrowsingCountryNameUnitedArabEmirates(preferredLanguages: preferredLanguages)
        case .unitedKingdom:
            return R.string.localizable.enumBrowsingCountryNameUnitedKingdom(preferredLanguages: preferredLanguages)
        case .unitedStates:
            return R.string.localizable.enumBrowsingCountryNameUnitedStates(preferredLanguages: preferredLanguages)
        case .unitedStatesMinorOutlyingIslands:
            return R.string.localizable.enumBrowsingCountryNameUnitedStatesMinorOutlyingIslands(preferredLanguages: preferredLanguages)
        case .uruguay:
            return R.string.localizable.enumBrowsingCountryNameUruguay(preferredLanguages: preferredLanguages)
        case .uzbekistan:
            return R.string.localizable.enumBrowsingCountryNameUzbekistan(preferredLanguages: preferredLanguages)
        case .vanuatu:
            return R.string.localizable.enumBrowsingCountryNameVanuatu(preferredLanguages: preferredLanguages)
        case .venezuela:
            return R.string.localizable.enumBrowsingCountryNameVenezuela(preferredLanguages: preferredLanguages)
        case .vietnam:
            return R.string.localizable.enumBrowsingCountryNameVietnam(preferredLanguages: preferredLanguages)
        case .virginIslandsBritish:
            return R.string.localizable.enumBrowsingCountryNameVirginIslandsBritish(preferredLanguages: preferredLanguages)
        case .virginIslandsUS:
            return R.string.localizable.enumBrowsingCountryNameVirginIslandsUS(preferredLanguages: preferredLanguages)
        case .wallisAndFutuna:
            return R.string.localizable.enumBrowsingCountryNameWallisAndFutuna(preferredLanguages: preferredLanguages)
        case .westernSahara:
            return R.string.localizable.enumBrowsingCountryNameWesternSahara(preferredLanguages: preferredLanguages)
        case .yemen:
            return R.string.localizable.enumBrowsingCountryNameYemen(preferredLanguages: preferredLanguages)
        case .zambia:
            return R.string.localizable.enumBrowsingCountryNameZambia(preferredLanguages: preferredLanguages)
        case .zimbabwe:
            return R.string.localizable.enumBrowsingCountryNameZimbabwe(preferredLanguages: preferredLanguages)
        }
    }
}
// swiftlint:enable line_length
