//
//  BrowsingCountry.swift
//  EhPanda
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
        switch self {
        case .autoDetect: return L10n.Localizable.Enum.BrowsingCountry.Name.autoDetect
        case .afghanistan: return L10n.Localizable.Enum.BrowsingCountry.Name.afghanistan
        case .alandIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.alandIslands
        case .albania: return L10n.Localizable.Enum.BrowsingCountry.Name.albania
        case .algeria: return L10n.Localizable.Enum.BrowsingCountry.Name.algeria
        case .americanSamoa: return L10n.Localizable.Enum.BrowsingCountry.Name.americanSamoa
        case .andorra: return L10n.Localizable.Enum.BrowsingCountry.Name.andorra
        case .angola: return L10n.Localizable.Enum.BrowsingCountry.Name.angola
        case .anguilla: return L10n.Localizable.Enum.BrowsingCountry.Name.anguilla
        case .antarctica: return L10n.Localizable.Enum.BrowsingCountry.Name.antarctica
        case .antiguaAndBarbuda: return L10n.Localizable.Enum.BrowsingCountry.Name.antiguaAndBarbuda
        case .argentina: return L10n.Localizable.Enum.BrowsingCountry.Name.argentina
        case .armenia: return L10n.Localizable.Enum.BrowsingCountry.Name.armenia
        case .aruba: return L10n.Localizable.Enum.BrowsingCountry.Name.aruba
        case .asiaPacificRegion: return L10n.Localizable.Enum.BrowsingCountry.Name.asiaPacificRegion
        case .australia: return L10n.Localizable.Enum.BrowsingCountry.Name.australia
        case .austria: return L10n.Localizable.Enum.BrowsingCountry.Name.austria
        case .azerbaijan: return L10n.Localizable.Enum.BrowsingCountry.Name.azerbaijan
        case .bahamas: return L10n.Localizable.Enum.BrowsingCountry.Name.bahamas
        case .bahrain: return L10n.Localizable.Enum.BrowsingCountry.Name.bahrain
        case .bangladesh: return L10n.Localizable.Enum.BrowsingCountry.Name.bangladesh
        case .barbados: return L10n.Localizable.Enum.BrowsingCountry.Name.barbados
        case .belarus: return L10n.Localizable.Enum.BrowsingCountry.Name.belarus
        case .belgium: return L10n.Localizable.Enum.BrowsingCountry.Name.belgium
        case .belize: return L10n.Localizable.Enum.BrowsingCountry.Name.belize
        case .benin: return L10n.Localizable.Enum.BrowsingCountry.Name.benin
        case .bermuda: return L10n.Localizable.Enum.BrowsingCountry.Name.bermuda
        case .bhutan: return L10n.Localizable.Enum.BrowsingCountry.Name.bhutan
        case .bolivia: return L10n.Localizable.Enum.BrowsingCountry.Name.bolivia
        case .bonaireSaintEustatiusAndSaba: return L10n.Localizable.Enum.BrowsingCountry.Name.bonaireSaintEustatiusAndSaba
        case .bosniaAndHerzegovina: return L10n.Localizable.Enum.BrowsingCountry.Name.bosniaAndHerzegovina
        case .botswana: return L10n.Localizable.Enum.BrowsingCountry.Name.botswana
        case .bouvetIsland: return L10n.Localizable.Enum.BrowsingCountry.Name.bouvetIsland
        case .brazil: return L10n.Localizable.Enum.BrowsingCountry.Name.brazil
        case .britishIndianOceanTerritory: return L10n.Localizable.Enum.BrowsingCountry.Name.britishIndianOceanTerritory
        case .bruneiDarussalam: return L10n.Localizable.Enum.BrowsingCountry.Name.bruneiDarussalam
        case .bulgaria: return L10n.Localizable.Enum.BrowsingCountry.Name.bulgaria
        case .burkinaFaso: return L10n.Localizable.Enum.BrowsingCountry.Name.burkinaFaso
        case .burundi: return L10n.Localizable.Enum.BrowsingCountry.Name.burundi
        case .cambodia: return L10n.Localizable.Enum.BrowsingCountry.Name.cambodia
        case .cameroon: return L10n.Localizable.Enum.BrowsingCountry.Name.cameroon
        case .canada: return L10n.Localizable.Enum.BrowsingCountry.Name.canada
        case .capeVerde: return L10n.Localizable.Enum.BrowsingCountry.Name.capeVerde
        case .caymanIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.caymanIslands
        case .centralAfricanRepublic: return L10n.Localizable.Enum.BrowsingCountry.Name.centralAfricanRepublic
        case .chad: return L10n.Localizable.Enum.BrowsingCountry.Name.chad
        case .chile: return L10n.Localizable.Enum.BrowsingCountry.Name.chile
        case .china: return L10n.Localizable.Enum.BrowsingCountry.Name.china
        case .christmasIsland: return L10n.Localizable.Enum.BrowsingCountry.Name.christmasIsland
        case .cocosIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.cocosIslands
        case .colombia: return L10n.Localizable.Enum.BrowsingCountry.Name.colombia
        case .comoros: return L10n.Localizable.Enum.BrowsingCountry.Name.comoros
        case .congo: return L10n.Localizable.Enum.BrowsingCountry.Name.congo
        case .theDemocraticRepublicOfTheCongo: return L10n.Localizable.Enum.BrowsingCountry.Name.theDemocraticRepublicOfTheCongo
        case .cookIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.cookIslands
        case .costaRica: return L10n.Localizable.Enum.BrowsingCountry.Name.costaRica
        case .coteDIvoire: return L10n.Localizable.Enum.BrowsingCountry.Name.coteDIvoire
        case .croatia: return L10n.Localizable.Enum.BrowsingCountry.Name.croatia
        case .cuba: return L10n.Localizable.Enum.BrowsingCountry.Name.cuba
        case .curacao: return L10n.Localizable.Enum.BrowsingCountry.Name.curacao
        case .cyprus: return L10n.Localizable.Enum.BrowsingCountry.Name.cyprus
        case .czechRepublic: return L10n.Localizable.Enum.BrowsingCountry.Name.czechRepublic
        case .denmark: return L10n.Localizable.Enum.BrowsingCountry.Name.denmark
        case .djibouti: return L10n.Localizable.Enum.BrowsingCountry.Name.djibouti
        case .dominica: return L10n.Localizable.Enum.BrowsingCountry.Name.dominica
        case .dominicanRepublic: return L10n.Localizable.Enum.BrowsingCountry.Name.dominicanRepublic
        case .ecuador: return L10n.Localizable.Enum.BrowsingCountry.Name.ecuador
        case .egypt: return L10n.Localizable.Enum.BrowsingCountry.Name.egypt
        case .elSalvador: return L10n.Localizable.Enum.BrowsingCountry.Name.elSalvador
        case .equatorialGuinea: return L10n.Localizable.Enum.BrowsingCountry.Name.equatorialGuinea
        case .eritrea: return L10n.Localizable.Enum.BrowsingCountry.Name.eritrea
        case .estonia: return L10n.Localizable.Enum.BrowsingCountry.Name.estonia
        case .ethiopia: return L10n.Localizable.Enum.BrowsingCountry.Name.ethiopia
        case .europe: return L10n.Localizable.Enum.BrowsingCountry.Name.europe
        case .falklandIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.falklandIslands
        case .faroeIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.faroeIslands
        case .fiji: return L10n.Localizable.Enum.BrowsingCountry.Name.fiji
        case .finland: return L10n.Localizable.Enum.BrowsingCountry.Name.finland
        case .france: return L10n.Localizable.Enum.BrowsingCountry.Name.france
        case .frenchGuiana: return L10n.Localizable.Enum.BrowsingCountry.Name.frenchGuiana
        case .frenchPolynesia: return L10n.Localizable.Enum.BrowsingCountry.Name.frenchPolynesia
        case .frenchSouthernTerritories: return L10n.Localizable.Enum.BrowsingCountry.Name.frenchSouthernTerritories
        case .gabon: return L10n.Localizable.Enum.BrowsingCountry.Name.gabon
        case .gambia: return L10n.Localizable.Enum.BrowsingCountry.Name.gambia
        case .georgia: return L10n.Localizable.Enum.BrowsingCountry.Name.georgia
        case .germany: return L10n.Localizable.Enum.BrowsingCountry.Name.germany
        case .ghana: return L10n.Localizable.Enum.BrowsingCountry.Name.ghana
        case .gibraltar: return L10n.Localizable.Enum.BrowsingCountry.Name.gibraltar
        case .greece: return L10n.Localizable.Enum.BrowsingCountry.Name.greece
        case .greenland: return L10n.Localizable.Enum.BrowsingCountry.Name.greenland
        case .grenada: return L10n.Localizable.Enum.BrowsingCountry.Name.grenada
        case .guadeloupe: return L10n.Localizable.Enum.BrowsingCountry.Name.guadeloupe
        case .guam: return L10n.Localizable.Enum.BrowsingCountry.Name.guam
        case .guatemala: return L10n.Localizable.Enum.BrowsingCountry.Name.guatemala
        case .guernsey: return L10n.Localizable.Enum.BrowsingCountry.Name.guernsey
        case .guinea: return L10n.Localizable.Enum.BrowsingCountry.Name.guinea
        case .guineaBissau: return L10n.Localizable.Enum.BrowsingCountry.Name.guineaBissau
        case .guyana: return L10n.Localizable.Enum.BrowsingCountry.Name.guyana
        case .haiti: return L10n.Localizable.Enum.BrowsingCountry.Name.haiti
        case .heardIslandAndMcDonaldIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.heardIslandAndMcDonaldIslands
        case .vaticanCityState: return L10n.Localizable.Enum.BrowsingCountry.Name.vaticanCityState
        case .honduras: return L10n.Localizable.Enum.BrowsingCountry.Name.honduras
        case .hongKong: return L10n.Localizable.Enum.BrowsingCountry.Name.hongKong
        case .hungary: return L10n.Localizable.Enum.BrowsingCountry.Name.hungary
        case .iceland: return L10n.Localizable.Enum.BrowsingCountry.Name.iceland
        case .india: return L10n.Localizable.Enum.BrowsingCountry.Name.india
        case .indonesia: return L10n.Localizable.Enum.BrowsingCountry.Name.indonesia
        case .iran: return L10n.Localizable.Enum.BrowsingCountry.Name.iran
        case .iraq: return L10n.Localizable.Enum.BrowsingCountry.Name.iraq
        case .ireland: return L10n.Localizable.Enum.BrowsingCountry.Name.ireland
        case .isleOfMan: return L10n.Localizable.Enum.BrowsingCountry.Name.isleOfMan
        case .israel: return L10n.Localizable.Enum.BrowsingCountry.Name.israel
        case .italy: return L10n.Localizable.Enum.BrowsingCountry.Name.italy
        case .jamaica: return L10n.Localizable.Enum.BrowsingCountry.Name.jamaica
        case .japan: return L10n.Localizable.Enum.BrowsingCountry.Name.japan
        case .jersey: return L10n.Localizable.Enum.BrowsingCountry.Name.jersey
        case .jordan: return L10n.Localizable.Enum.BrowsingCountry.Name.jordan
        case .kazakhstan: return L10n.Localizable.Enum.BrowsingCountry.Name.kazakhstan
        case .kenya: return L10n.Localizable.Enum.BrowsingCountry.Name.kenya
        case .kiribati: return L10n.Localizable.Enum.BrowsingCountry.Name.kiribati
        case .kuwait: return L10n.Localizable.Enum.BrowsingCountry.Name.kuwait
        case .kyrgyzstan: return L10n.Localizable.Enum.BrowsingCountry.Name.kyrgyzstan
        case .laoPeoplesDemocraticRepublic: return L10n.Localizable.Enum.BrowsingCountry.Name.laoPeoplesDemocraticRepublic
        case .latvia: return L10n.Localizable.Enum.BrowsingCountry.Name.latvia
        case .lebanon: return L10n.Localizable.Enum.BrowsingCountry.Name.lebanon
        case .lesotho: return L10n.Localizable.Enum.BrowsingCountry.Name.lesotho
        case .liberia: return L10n.Localizable.Enum.BrowsingCountry.Name.liberia
        case .libya: return L10n.Localizable.Enum.BrowsingCountry.Name.libya
        case .liechtenstein: return L10n.Localizable.Enum.BrowsingCountry.Name.liechtenstein
        case .lithuania: return L10n.Localizable.Enum.BrowsingCountry.Name.lithuania
        case .luxembourg: return L10n.Localizable.Enum.BrowsingCountry.Name.luxembourg
        case .macau: return L10n.Localizable.Enum.BrowsingCountry.Name.macau
        case .macedonia: return L10n.Localizable.Enum.BrowsingCountry.Name.macedonia
        case .madagascar: return L10n.Localizable.Enum.BrowsingCountry.Name.madagascar
        case .malawi: return L10n.Localizable.Enum.BrowsingCountry.Name.malawi
        case .malaysia: return L10n.Localizable.Enum.BrowsingCountry.Name.malaysia
        case .maldives: return L10n.Localizable.Enum.BrowsingCountry.Name.maldives
        case .mali: return L10n.Localizable.Enum.BrowsingCountry.Name.mali
        case .malta: return L10n.Localizable.Enum.BrowsingCountry.Name.malta
        case .marshallIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.marshallIslands
        case .martinique: return L10n.Localizable.Enum.BrowsingCountry.Name.martinique
        case .mauritania: return L10n.Localizable.Enum.BrowsingCountry.Name.mauritania
        case .mauritius: return L10n.Localizable.Enum.BrowsingCountry.Name.mauritius
        case .mayotte: return L10n.Localizable.Enum.BrowsingCountry.Name.mayotte
        case .mexico: return L10n.Localizable.Enum.BrowsingCountry.Name.mexico
        case .micronesia: return L10n.Localizable.Enum.BrowsingCountry.Name.micronesia
        case .moldova: return L10n.Localizable.Enum.BrowsingCountry.Name.moldova
        case .monaco: return L10n.Localizable.Enum.BrowsingCountry.Name.monaco
        case .mongolia: return L10n.Localizable.Enum.BrowsingCountry.Name.mongolia
        case .montenegro: return L10n.Localizable.Enum.BrowsingCountry.Name.montenegro
        case .montserrat: return L10n.Localizable.Enum.BrowsingCountry.Name.montserrat
        case .morocco: return L10n.Localizable.Enum.BrowsingCountry.Name.morocco
        case .mozambique: return L10n.Localizable.Enum.BrowsingCountry.Name.mozambique
        case .myanmar: return L10n.Localizable.Enum.BrowsingCountry.Name.myanmar
        case .namibia: return L10n.Localizable.Enum.BrowsingCountry.Name.namibia
        case .nauru: return L10n.Localizable.Enum.BrowsingCountry.Name.nauru
        case .nepal: return L10n.Localizable.Enum.BrowsingCountry.Name.nepal
        case .netherlands: return L10n.Localizable.Enum.BrowsingCountry.Name.netherlands
        case .newCaledonia: return L10n.Localizable.Enum.BrowsingCountry.Name.newCaledonia
        case .newZealand: return L10n.Localizable.Enum.BrowsingCountry.Name.newZealand
        case .nicaragua: return L10n.Localizable.Enum.BrowsingCountry.Name.nicaragua
        case .niger: return L10n.Localizable.Enum.BrowsingCountry.Name.niger
        case .nigeria: return L10n.Localizable.Enum.BrowsingCountry.Name.nigeria
        case .niue: return L10n.Localizable.Enum.BrowsingCountry.Name.niue
        case .norfolkIsland: return L10n.Localizable.Enum.BrowsingCountry.Name.norfolkIsland
        case .northKorea: return L10n.Localizable.Enum.BrowsingCountry.Name.northKorea
        case .northernMarianaIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.northernMarianaIslands
        case .norway: return L10n.Localizable.Enum.BrowsingCountry.Name.norway
        case .oman: return L10n.Localizable.Enum.BrowsingCountry.Name.oman
        case .pakistan: return L10n.Localizable.Enum.BrowsingCountry.Name.pakistan
        case .palau: return L10n.Localizable.Enum.BrowsingCountry.Name.palau
        case .palestinianTerritory: return L10n.Localizable.Enum.BrowsingCountry.Name.palestinianTerritory
        case .panama: return L10n.Localizable.Enum.BrowsingCountry.Name.panama
        case .papuaNewGuinea: return L10n.Localizable.Enum.BrowsingCountry.Name.papuaNewGuinea
        case .paraguay: return L10n.Localizable.Enum.BrowsingCountry.Name.paraguay
        case .peru: return L10n.Localizable.Enum.BrowsingCountry.Name.peru
        case .philippines: return L10n.Localizable.Enum.BrowsingCountry.Name.philippines
        case .pitcairnIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.pitcairnIslands
        case .poland: return L10n.Localizable.Enum.BrowsingCountry.Name.poland
        case .portugal: return L10n.Localizable.Enum.BrowsingCountry.Name.portugal
        case .puertoRico: return L10n.Localizable.Enum.BrowsingCountry.Name.puertoRico
        case .qatar: return L10n.Localizable.Enum.BrowsingCountry.Name.qatar
        case .reunion: return L10n.Localizable.Enum.BrowsingCountry.Name.reunion
        case .romania: return L10n.Localizable.Enum.BrowsingCountry.Name.romania
        case .russianFederation: return L10n.Localizable.Enum.BrowsingCountry.Name.russianFederation
        case .rwanda: return L10n.Localizable.Enum.BrowsingCountry.Name.rwanda
        case .saintBarthelemy: return L10n.Localizable.Enum.BrowsingCountry.Name.saintBarthelemy
        case .saintHelena: return L10n.Localizable.Enum.BrowsingCountry.Name.saintHelena
        case .saintKittsAndNevis: return L10n.Localizable.Enum.BrowsingCountry.Name.saintKittsAndNevis
        case .saintLucia: return L10n.Localizable.Enum.BrowsingCountry.Name.saintLucia
        case .saintMartin: return L10n.Localizable.Enum.BrowsingCountry.Name.saintMartin
        case .saintPierreAndMiquelon: return L10n.Localizable.Enum.BrowsingCountry.Name.saintPierreAndMiquelon
        case .saintVincentAndTheGrenadines: return L10n.Localizable.Enum.BrowsingCountry.Name.saintVincentAndTheGrenadines
        case .samoa: return L10n.Localizable.Enum.BrowsingCountry.Name.samoa
        case .sanMarino: return L10n.Localizable.Enum.BrowsingCountry.Name.sanMarino
        case .saoTomeAndPrincipe: return L10n.Localizable.Enum.BrowsingCountry.Name.saoTomeAndPrincipe
        case .saudiArabia: return L10n.Localizable.Enum.BrowsingCountry.Name.saudiArabia
        case .senegal: return L10n.Localizable.Enum.BrowsingCountry.Name.senegal
        case .serbia: return L10n.Localizable.Enum.BrowsingCountry.Name.serbia
        case .seychelles: return L10n.Localizable.Enum.BrowsingCountry.Name.seychelles
        case .sierraLeone: return L10n.Localizable.Enum.BrowsingCountry.Name.sierraLeone
        case .singapore: return L10n.Localizable.Enum.BrowsingCountry.Name.singapore
        case .sintMaarten: return L10n.Localizable.Enum.BrowsingCountry.Name.sintMaarten
        case .slovakia: return L10n.Localizable.Enum.BrowsingCountry.Name.slovakia
        case .slovenia: return L10n.Localizable.Enum.BrowsingCountry.Name.slovenia
        case .solomonIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.solomonIslands
        case .somalia: return L10n.Localizable.Enum.BrowsingCountry.Name.somalia
        case .southAfrica: return L10n.Localizable.Enum.BrowsingCountry.Name.southAfrica
        case .southGeorgiaAndTheSouthSandwichIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.southGeorgiaAndTheSouthSandwichIslands
        case .southKorea: return L10n.Localizable.Enum.BrowsingCountry.Name.southKorea
        case .southSudan: return L10n.Localizable.Enum.BrowsingCountry.Name.southSudan
        case .spain: return L10n.Localizable.Enum.BrowsingCountry.Name.spain
        case .sriLanka: return L10n.Localizable.Enum.BrowsingCountry.Name.sriLanka
        case .sudan: return L10n.Localizable.Enum.BrowsingCountry.Name.sudan
        case .suriname: return L10n.Localizable.Enum.BrowsingCountry.Name.suriname
        case .svalbardAndJanMayen: return L10n.Localizable.Enum.BrowsingCountry.Name.svalbardAndJanMayen
        case .swaziland: return L10n.Localizable.Enum.BrowsingCountry.Name.swaziland
        case .sweden: return L10n.Localizable.Enum.BrowsingCountry.Name.sweden
        case .switzerland: return L10n.Localizable.Enum.BrowsingCountry.Name.switzerland
        case .syrianArabRepublic: return L10n.Localizable.Enum.BrowsingCountry.Name.syrianArabRepublic
        case .taiwan: return L10n.Localizable.Enum.BrowsingCountry.Name.taiwan
        case .tajikistan: return L10n.Localizable.Enum.BrowsingCountry.Name.tajikistan
        case .tanzania: return L10n.Localizable.Enum.BrowsingCountry.Name.tanzania
        case .thailand: return L10n.Localizable.Enum.BrowsingCountry.Name.thailand
        case .timorLeste: return L10n.Localizable.Enum.BrowsingCountry.Name.timorLeste
        case .togo: return L10n.Localizable.Enum.BrowsingCountry.Name.togo
        case .tokelau: return L10n.Localizable.Enum.BrowsingCountry.Name.tokelau
        case .tonga: return L10n.Localizable.Enum.BrowsingCountry.Name.tonga
        case .trinidadAndTobago: return L10n.Localizable.Enum.BrowsingCountry.Name.trinidadAndTobago
        case .tunisia: return L10n.Localizable.Enum.BrowsingCountry.Name.tunisia
        case .turkey: return L10n.Localizable.Enum.BrowsingCountry.Name.turkey
        case .turkmenistan: return L10n.Localizable.Enum.BrowsingCountry.Name.turkmenistan
        case .turksAndCaicosIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.turksAndCaicosIslands
        case .tuvalu: return L10n.Localizable.Enum.BrowsingCountry.Name.tuvalu
        case .uganda: return L10n.Localizable.Enum.BrowsingCountry.Name.uganda
        case .ukraine: return L10n.Localizable.Enum.BrowsingCountry.Name.ukraine
        case .unitedArabEmirates: return L10n.Localizable.Enum.BrowsingCountry.Name.unitedArabEmirates
        case .unitedKingdom: return L10n.Localizable.Enum.BrowsingCountry.Name.unitedKingdom
        case .unitedStates: return L10n.Localizable.Enum.BrowsingCountry.Name.unitedStates
        case .unitedStatesMinorOutlyingIslands: return L10n.Localizable.Enum.BrowsingCountry.Name.unitedStatesMinorOutlyingIslands
        case .uruguay: return L10n.Localizable.Enum.BrowsingCountry.Name.uruguay
        case .uzbekistan: return L10n.Localizable.Enum.BrowsingCountry.Name.uzbekistan
        case .vanuatu: return L10n.Localizable.Enum.BrowsingCountry.Name.vanuatu
        case .venezuela: return L10n.Localizable.Enum.BrowsingCountry.Name.venezuela
        case .vietnam: return L10n.Localizable.Enum.BrowsingCountry.Name.vietnam
        case .virginIslandsBritish: return L10n.Localizable.Enum.BrowsingCountry.Name.virginIslandsBritish
        case .virginIslandsUS: return L10n.Localizable.Enum.BrowsingCountry.Name.virginIslandsUS
        case .wallisAndFutuna: return L10n.Localizable.Enum.BrowsingCountry.Name.wallisAndFutuna
        case .westernSahara: return L10n.Localizable.Enum.BrowsingCountry.Name.westernSahara
        case .yemen: return L10n.Localizable.Enum.BrowsingCountry.Name.yemen
        case .zambia: return L10n.Localizable.Enum.BrowsingCountry.Name.zambia
        case .zimbabwe: return L10n.Localizable.Enum.BrowsingCountry.Name.zimbabwe
        }
    }
    var englishName: String {
        switch self {
        case .autoDetect: return "Auto-Detect"
        case .afghanistan: return "Afghanistan"
        case .alandIslands: return "Aland Islands"
        case .albania: return "Albania"
        case .algeria: return "Algeria"
        case .americanSamoa: return "American Samoa"
        case .andorra: return "Andorra"
        case .angola: return "Angola"
        case .anguilla: return "Anguilla"
        case .antarctica: return "Antarctica"
        case .antiguaAndBarbuda: return "Antigua and Barbuda"
        case .argentina: return "Argentina"
        case .armenia: return "Armenia"
        case .aruba: return "Aruba"
        case .asiaPacificRegion: return "Asia-Pacific Region"
        case .australia: return "Australia"
        case .austria: return "Austria"
        case .azerbaijan: return "Azerbaijan"
        case .bahamas: return "Bahamas"
        case .bahrain: return "Bahrain"
        case .bangladesh: return "Bangladesh"
        case .barbados: return "Barbados"
        case .belarus: return "Belarus"
        case .belgium: return "Belgium"
        case .belize: return "Belize"
        case .benin: return "Benin"
        case .bermuda: return "Bermuda"
        case .bhutan: return "Bhutan"
        case .bolivia: return "Bolivia"
        case .bonaireSaintEustatiusAndSaba: return "Bonaire Saint Eustatius and Saba"
        case .bosniaAndHerzegovina: return "Bosnia and Herzegovina"
        case .botswana: return "Botswana"
        case .bouvetIsland: return "Bouvet Island"
        case .brazil: return "Brazil"
        case .britishIndianOceanTerritory: return "British Indian Ocean Territory"
        case .bruneiDarussalam: return "Brunei Darussalam"
        case .bulgaria: return "Bulgaria"
        case .burkinaFaso: return "Burkina Faso"
        case .burundi: return "Burundi"
        case .cambodia: return "Cambodia"
        case .cameroon: return "Cameroon"
        case .canada: return "Canada"
        case .capeVerde: return "Cape Verde"
        case .caymanIslands: return "Cayman Islands"
        case .centralAfricanRepublic: return "Central African Republic"
        case .chad: return "Chad"
        case .chile: return "Chile"
        case .china: return "China"
        case .christmasIsland: return "Christmas Island"
        case .cocosIslands: return "Cocos Islands"
        case .colombia: return "Colombia"
        case .comoros: return "Comoros"
        case .congo: return "Congo"
        case .theDemocraticRepublicOfTheCongo: return "The Democratic Republic of the Congo"
        case .cookIslands: return "Cook Islands"
        case .costaRica: return "Costa Rica"
        case .coteDIvoire: return "Cote D'Ivoire"
        case .croatia: return "Croatia"
        case .cuba: return "Cuba"
        case .curacao: return "Curacao"
        case .cyprus: return "Cyprus"
        case .czechRepublic: return "Czech Republic"
        case .denmark: return "Denmark"
        case .djibouti: return "Djibouti"
        case .dominica: return "Dominica"
        case .dominicanRepublic: return "Dominican Republic"
        case .ecuador: return "Ecuador"
        case .egypt: return "Egypt"
        case .elSalvador: return "El Salvador"
        case .equatorialGuinea: return "Equatorial Guinea"
        case .eritrea: return "Eritrea"
        case .estonia: return "Estonia"
        case .ethiopia: return "Ethiopia"
        case .europe: return "Europe"
        case .falklandIslands: return "Falkland Islands"
        case .faroeIslands: return "Faroe Islands"
        case .fiji: return "Fiji"
        case .finland: return "Finland"
        case .france: return "France"
        case .frenchGuiana: return "French Guiana"
        case .frenchPolynesia: return "French Polynesia"
        case .frenchSouthernTerritories: return "French Southern Territories"
        case .gabon: return "Gabon"
        case .gambia: return "Gambia"
        case .georgia: return "Georgia"
        case .germany: return "Germany"
        case .ghana: return "Ghana"
        case .gibraltar: return "Gibraltar"
        case .greece: return "Greece"
        case .greenland: return "Greenland"
        case .grenada: return "Grenada"
        case .guadeloupe: return "Guadeloupe"
        case .guam: return "Guam"
        case .guatemala: return "Guatemala"
        case .guernsey: return "Guernsey"
        case .guinea: return "Guinea"
        case .guineaBissau: return "Guinea-Bissau"
        case .guyana: return "Guyana"
        case .haiti: return "Haiti"
        case .heardIslandAndMcDonaldIslands: return "Heard Island and McDonald Islands"
        case .vaticanCityState: return "Vatican City State"
        case .honduras: return "Honduras"
        case .hongKong: return "Hong Kong"
        case .hungary: return "Hungary"
        case .iceland: return "Iceland"
        case .india: return "India"
        case .indonesia: return "Indonesia"
        case .iran: return "Iran"
        case .iraq: return "Iraq"
        case .ireland: return "Ireland"
        case .isleOfMan: return "Isle of Man"
        case .israel: return "Israel"
        case .italy: return "Italy"
        case .jamaica: return "Jamaica"
        case .japan: return "Japan"
        case .jersey: return "Jersey"
        case .jordan: return "Jordan"
        case .kazakhstan: return "Kazakhstan"
        case .kenya: return "Kenya"
        case .kiribati: return "Kiribati"
        case .kuwait: return "Kuwait"
        case .kyrgyzstan: return "Kyrgyzstan"
        case .laoPeoplesDemocraticRepublic: return "Lao People's Democratic Republic"
        case .latvia: return "Latvia"
        case .lebanon: return "Lebanon"
        case .lesotho: return "Lesotho"
        case .liberia: return "Liberia"
        case .libya: return "Libya"
        case .liechtenstein: return "Liechtenstein"
        case .lithuania: return "Lithuania"
        case .luxembourg: return "Luxembourg"
        case .macau: return "Macau"
        case .macedonia: return "Macedonia"
        case .madagascar: return "Madagascar"
        case .malawi: return "Malawi"
        case .malaysia: return "Malaysia"
        case .maldives: return "Maldives"
        case .mali: return "Mali"
        case .malta: return "Malta"
        case .marshallIslands: return "Marshall Islands"
        case .martinique: return "Martinique"
        case .mauritania: return "Mauritania"
        case .mauritius: return "Mauritius"
        case .mayotte: return "Mayotte"
        case .mexico: return "Mexico"
        case .micronesia: return "Micronesia"
        case .moldova: return "Moldova"
        case .monaco: return "Monaco"
        case .mongolia: return "Mongolia"
        case .montenegro: return "Montenegro"
        case .montserrat: return "Montserrat"
        case .morocco: return "Morocco"
        case .mozambique: return "Mozambique"
        case .myanmar: return "Myanmar"
        case .namibia: return "Namibia"
        case .nauru: return "Nauru"
        case .nepal: return "Nepal"
        case .netherlands: return "Netherlands"
        case .newCaledonia: return "New Caledonia"
        case .newZealand: return "New Zealand"
        case .nicaragua: return "Nicaragua"
        case .niger: return "Niger"
        case .nigeria: return "Nigeria"
        case .niue: return "Niue"
        case .norfolkIsland: return "Norfolk Island"
        case .northKorea: return "North Korea"
        case .northernMarianaIslands: return "Northern Mariana Islands"
        case .norway: return "Norway"
        case .oman: return "Oman"
        case .pakistan: return "Pakistan"
        case .palau: return "Palau"
        case .palestinianTerritory: return "Palestinian Territory"
        case .panama: return "Panama"
        case .papuaNewGuinea: return "Papua New Guinea"
        case .paraguay: return "Paraguay"
        case .peru: return "Peru"
        case .philippines: return "Philippines"
        case .pitcairnIslands: return "Pitcairn Islands"
        case .poland: return "Poland"
        case .portugal: return "Portugal"
        case .puertoRico: return "Puerto Rico"
        case .qatar: return "Qatar"
        case .reunion: return "Reunion"
        case .romania: return "Romania"
        case .russianFederation: return "Russian Federation"
        case .rwanda: return "Rwanda"
        case .saintBarthelemy: return "Saint Barthelemy"
        case .saintHelena: return "Saint Helena"
        case .saintKittsAndNevis: return "Saint Kitts and Nevis"
        case .saintLucia: return "Saint Lucia"
        case .saintMartin: return "Saint Martin"
        case .saintPierreAndMiquelon: return "Saint Pierre and Miquelon"
        case .saintVincentAndTheGrenadines: return "Saint Vincent and the Grenadines"
        case .samoa: return "Samoa"
        case .sanMarino: return "San Marino"
        case .saoTomeAndPrincipe: return "Sao Tome and Principe"
        case .saudiArabia: return "Saudi Arabia"
        case .senegal: return "Senegal"
        case .serbia: return "Serbia"
        case .seychelles: return "Seychelles"
        case .sierraLeone: return "Sierra Leone"
        case .singapore: return "Singapore"
        case .sintMaarten: return "Sint Maarten"
        case .slovakia: return "Slovakia"
        case .slovenia: return "Slovenia"
        case .solomonIslands: return "Solomon Islands"
        case .somalia: return "Somalia"
        case .southAfrica: return "South Africa"
        case .southGeorgiaAndTheSouthSandwichIslands: return "South Georgia and the South Sandwich Islands"
        case .southKorea: return "South Korea"
        case .southSudan: return "South Sudan"
        case .spain: return "Spain"
        case .sriLanka: return "Sri Lanka"
        case .sudan: return "Sudan"
        case .suriname: return "Suriname"
        case .svalbardAndJanMayen: return "Svalbard and Jan Mayen"
        case .swaziland: return "Swaziland"
        case .sweden: return "Sweden"
        case .switzerland: return "Switzerland"
        case .syrianArabRepublic: return "Syrian Arab Republic"
        case .taiwan: return "Taiwan"
        case .tajikistan: return "Tajikistan"
        case .tanzania: return "Tanzania"
        case .thailand: return "Thailand"
        case .timorLeste: return "Timor-Leste"
        case .togo: return "Togo"
        case .tokelau: return "Tokelau"
        case .tonga: return "Tonga"
        case .trinidadAndTobago: return "Trinidad and Tobago"
        case .tunisia: return "Tunisia"
        case .turkey: return "Turkey"
        case .turkmenistan: return "Turkmenistan"
        case .turksAndCaicosIslands: return "Turks and Caicos Islands"
        case .tuvalu: return "Tuvalu"
        case .uganda: return "Uganda"
        case .ukraine: return "Ukraine"
        case .unitedArabEmirates: return "United Arab Emirates"
        case .unitedKingdom: return "United Kingdom"
        case .unitedStates: return "United States"
        case .unitedStatesMinorOutlyingIslands: return "United States Minor Outlying Islands"
        case .uruguay: return "Uruguay"
        case .uzbekistan: return "Uzbekistan"
        case .vanuatu: return "Vanuatu"
        case .venezuela: return "Venezuela"
        case .vietnam: return "Vietnam"
        case .virginIslandsBritish: return "British Virgin Islands"
        case .virginIslandsUS: return "U.S. Virgin Islands"
        case .wallisAndFutuna: return "Wallis and Futuna"
        case .westernSahara: return "Western Sahara"
        case .yemen: return "Yemen"
        case .zambia: return "Zambia"
        case .zimbabwe: return "Zimbabwe"
        }
    }
}
// swiftlint:enable line_length
