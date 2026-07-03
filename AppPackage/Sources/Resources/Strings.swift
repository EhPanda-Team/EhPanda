// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum L10n {
  public enum Constant {
    /// Constant.strings
    ///   EhPanda
    public static let galleryUnavailable = L10n.tr("Constant", "gallery_unavailable", fallback: "This gallery has been removed or is unavailable.")
  }
  public enum Localizable {
    /// Login
    public static let notLoginViewlogin = L10n.tr("Localizable", "not_login_viewlogin", fallback: "Login")
    public enum AccountSettingView {
      /// Login
      public static let login = L10n.tr("Localizable", "account_setting_view.login", fallback: "Login")
    }
    public enum AppActivityLogsView {
      public enum Level {
        /// Debug
        public static let debug = L10n.tr("Localizable", "app_activity_logs_view.level.debug", fallback: "Debug")
        /// Error
        public static let error = L10n.tr("Localizable", "app_activity_logs_view.level.error", fallback: "Error")
        /// Fault
        public static let fault = L10n.tr("Localizable", "app_activity_logs_view.level.fault", fallback: "Fault")
        /// Info
        public static let info = L10n.tr("Localizable", "app_activity_logs_view.level.info", fallback: "Info")
        /// Notice
        public static let notice = L10n.tr("Localizable", "app_activity_logs_view.level.notice", fallback: "Notice")
        /// Undefined
        public static let undefined = L10n.tr("Localizable", "app_activity_logs_view.level.undefined", fallback: "Undefined")
      }
    }
    public enum AppError {
      /// Authentication Required
      public static let authenticationRequired = L10n.tr("Localizable", "app_error.authentication_required", fallback: "Authentication Required")
      /// Login required to access this download.
      public static let authenticationRequiredDescription = L10n.tr("Localizable", "app_error.authentication_required_description", fallback: "Login required to access this download.")
      /// Copyright Claim
      public static let copyrightClaim = L10n.tr("Localizable", "app_error.copyright_claim", fallback: "Copyright Claim")
      /// Database Corrupted
      public static let databaseCorrupted = L10n.tr("Localizable", "app_error.database_corrupted", fallback: "Database Corrupted")
      /// File Operation Failed
      public static let fileOperationFailed = L10n.tr("Localizable", "app_error.file_operation_failed", fallback: "File Operation Failed")
      /// Gallery Expunged
      public static let galleryExpunged = L10n.tr("Localizable", "app_error.gallery_expunged", fallback: "Gallery Expunged")
      /// IP Banned
      public static let ipBanned = L10n.tr("Localizable", "app_error.ip_banned", fallback: "IP Banned")
      /// Local file operation failed.
      public static let localFileOperationFailed = L10n.tr("Localizable", "app_error.local_file_operation_failed", fallback: "Local file operation failed.")
      /// Network Error
      public static let networkError = L10n.tr("Localizable", "app_error.network_error", fallback: "Network Error")
      /// No updates available
      public static let noUpdatesAvailable = L10n.tr("Localizable", "app_error.no_updates_available", fallback: "No updates available")
      /// Not found
      public static let notFound = L10n.tr("Localizable", "app_error.not_found", fallback: "Not found")
      /// Parse Error
      public static let parseError = L10n.tr("Localizable", "app_error.parse_error", fallback: "Parse Error")
      /// Quota Exceeded
      public static let quotaExceeded = L10n.tr("Localizable", "app_error.quota_exceeded", fallback: "Quota Exceeded")
      /// Image quota exceeded.
      /// Please wait and try again later.
      public static let quotaExceededDescription = L10n.tr("Localizable", "app_error.quota_exceeded_description", fallback: "Image quota exceeded.\nPlease wait and try again later.")
      /// Unknown Error
      public static let unknownError = L10n.tr("Localizable", "app_error.unknown_error", fallback: "Unknown Error")
      /// Web image loading error
      public static let webImageLoadingError = L10n.tr("Localizable", "app_error.web_image_loading_error", fallback: "Web image loading error")
    }
    public enum AppIconType {
      /// Default
      public static let `default` = L10n.tr("Localizable", "app_icon_type.default", fallback: "Default")
      /// Developer
      public static let developer = L10n.tr("Localizable", "app_icon_type.developer", fallback: "Developer")
      /// NOT MY PRESIDENT
      public static let notMyPresident = L10n.tr("Localizable", "app_icon_type.not_my_president", fallback: "NOT MY PRESIDENT")
      /// Stand With Ukraine (2022)
      public static let standWithUkraine2022 = L10n.tr("Localizable", "app_icon_type.stand_with_ukraine_2022", fallback: "Stand With Ukraine (2022)")
      /// Ukiyo-e
      public static let ukiyoe = L10n.tr("Localizable", "app_icon_type.ukiyoe", fallback: "Ukiyo-e")
    }
    public enum ArchiveResolution {
      /// Original
      public static let original = L10n.tr("Localizable", "archive_resolution.original", fallback: "Original")
    }
    public enum AutoLockPolicy {
      /// Instantly
      public static let instantly = L10n.tr("Localizable", "auto_lock_policy.instantly", fallback: "Instantly")
      /// Never
      public static let never = L10n.tr("Localizable", "auto_lock_policy.never", fallback: "Never")
    }
    public enum BanInterval {
      /// and
      public static let and = L10n.tr("Localizable", "ban_interval.and", fallback: "and")
    }
    public enum BrowsingCountry {
      /// Afghanistan
      public static let afghanistan = L10n.tr("Localizable", "browsing_country.afghanistan", fallback: "Afghanistan")
      /// Aland Islands
      public static let alandIslands = L10n.tr("Localizable", "browsing_country.aland_islands", fallback: "Aland Islands")
      /// Albania
      public static let albania = L10n.tr("Localizable", "browsing_country.albania", fallback: "Albania")
      /// Algeria
      public static let algeria = L10n.tr("Localizable", "browsing_country.algeria", fallback: "Algeria")
      /// American Samoa
      public static let americanSamoa = L10n.tr("Localizable", "browsing_country.american_samoa", fallback: "American Samoa")
      /// Andorra
      public static let andorra = L10n.tr("Localizable", "browsing_country.andorra", fallback: "Andorra")
      /// Angola
      public static let angola = L10n.tr("Localizable", "browsing_country.angola", fallback: "Angola")
      /// Anguilla
      public static let anguilla = L10n.tr("Localizable", "browsing_country.anguilla", fallback: "Anguilla")
      /// Antarctica
      public static let antarctica = L10n.tr("Localizable", "browsing_country.antarctica", fallback: "Antarctica")
      /// Antigua and Barbuda
      public static let antiguaAndBarbuda = L10n.tr("Localizable", "browsing_country.antigua_and_barbuda", fallback: "Antigua and Barbuda")
      /// Argentina
      public static let argentina = L10n.tr("Localizable", "browsing_country.argentina", fallback: "Argentina")
      /// Armenia
      public static let armenia = L10n.tr("Localizable", "browsing_country.armenia", fallback: "Armenia")
      /// Aruba
      public static let aruba = L10n.tr("Localizable", "browsing_country.aruba", fallback: "Aruba")
      /// Asia-Pacific Region
      public static let asiaPacificRegion = L10n.tr("Localizable", "browsing_country.asia_pacific_region", fallback: "Asia-Pacific Region")
      /// Australia
      public static let australia = L10n.tr("Localizable", "browsing_country.australia", fallback: "Australia")
      /// Austria
      public static let austria = L10n.tr("Localizable", "browsing_country.austria", fallback: "Austria")
      /// Auto-Detect
      public static let autoDetect = L10n.tr("Localizable", "browsing_country.auto_detect", fallback: "Auto-Detect")
      /// Azerbaijan
      public static let azerbaijan = L10n.tr("Localizable", "browsing_country.azerbaijan", fallback: "Azerbaijan")
      /// Bahamas
      public static let bahamas = L10n.tr("Localizable", "browsing_country.bahamas", fallback: "Bahamas")
      /// Bahrain
      public static let bahrain = L10n.tr("Localizable", "browsing_country.bahrain", fallback: "Bahrain")
      /// Bangladesh
      public static let bangladesh = L10n.tr("Localizable", "browsing_country.bangladesh", fallback: "Bangladesh")
      /// Barbados
      public static let barbados = L10n.tr("Localizable", "browsing_country.barbados", fallback: "Barbados")
      /// Belarus
      public static let belarus = L10n.tr("Localizable", "browsing_country.belarus", fallback: "Belarus")
      /// Belgium
      public static let belgium = L10n.tr("Localizable", "browsing_country.belgium", fallback: "Belgium")
      /// Belize
      public static let belize = L10n.tr("Localizable", "browsing_country.belize", fallback: "Belize")
      /// Benin
      public static let benin = L10n.tr("Localizable", "browsing_country.benin", fallback: "Benin")
      /// Bermuda
      public static let bermuda = L10n.tr("Localizable", "browsing_country.bermuda", fallback: "Bermuda")
      /// Bhutan
      public static let bhutan = L10n.tr("Localizable", "browsing_country.bhutan", fallback: "Bhutan")
      /// Bolivia
      public static let bolivia = L10n.tr("Localizable", "browsing_country.bolivia", fallback: "Bolivia")
      /// Bonaire Saint Eustatius and Saba
      public static let bonaireSaintEustatiusAndSaba = L10n.tr("Localizable", "browsing_country.bonaire_saint_eustatius_and_saba", fallback: "Bonaire Saint Eustatius and Saba")
      /// Bosnia and Herzegovina
      public static let bosniaAndHerzegovina = L10n.tr("Localizable", "browsing_country.bosnia_and_herzegovina", fallback: "Bosnia and Herzegovina")
      /// Botswana
      public static let botswana = L10n.tr("Localizable", "browsing_country.botswana", fallback: "Botswana")
      /// Bouvet Island
      public static let bouvetIsland = L10n.tr("Localizable", "browsing_country.bouvet_island", fallback: "Bouvet Island")
      /// Brazil
      public static let brazil = L10n.tr("Localizable", "browsing_country.brazil", fallback: "Brazil")
      /// British Indian Ocean Territory
      public static let britishIndianOceanTerritory = L10n.tr("Localizable", "browsing_country.british_indian_ocean_territory", fallback: "British Indian Ocean Territory")
      /// Brunei Darussalam
      public static let bruneiDarussalam = L10n.tr("Localizable", "browsing_country.brunei_darussalam", fallback: "Brunei Darussalam")
      /// Bulgaria
      public static let bulgaria = L10n.tr("Localizable", "browsing_country.bulgaria", fallback: "Bulgaria")
      /// Burkina Faso
      public static let burkinaFaso = L10n.tr("Localizable", "browsing_country.burkina_faso", fallback: "Burkina Faso")
      /// Burundi
      public static let burundi = L10n.tr("Localizable", "browsing_country.burundi", fallback: "Burundi")
      /// Cambodia
      public static let cambodia = L10n.tr("Localizable", "browsing_country.cambodia", fallback: "Cambodia")
      /// Cameroon
      public static let cameroon = L10n.tr("Localizable", "browsing_country.cameroon", fallback: "Cameroon")
      /// Canada
      public static let canada = L10n.tr("Localizable", "browsing_country.canada", fallback: "Canada")
      /// Cape Verde
      public static let capeVerde = L10n.tr("Localizable", "browsing_country.cape_verde", fallback: "Cape Verde")
      /// Cayman Islands
      public static let caymanIslands = L10n.tr("Localizable", "browsing_country.cayman_islands", fallback: "Cayman Islands")
      /// Central African Republic
      public static let centralAfricanRepublic = L10n.tr("Localizable", "browsing_country.central_african_republic", fallback: "Central African Republic")
      /// Chad
      public static let chad = L10n.tr("Localizable", "browsing_country.chad", fallback: "Chad")
      /// Chile
      public static let chile = L10n.tr("Localizable", "browsing_country.chile", fallback: "Chile")
      /// China
      public static let china = L10n.tr("Localizable", "browsing_country.china", fallback: "China")
      /// Christmas Island
      public static let christmasIsland = L10n.tr("Localizable", "browsing_country.christmas_island", fallback: "Christmas Island")
      /// Cocos Islands
      public static let cocosIslands = L10n.tr("Localizable", "browsing_country.cocos_islands", fallback: "Cocos Islands")
      /// Colombia
      public static let colombia = L10n.tr("Localizable", "browsing_country.colombia", fallback: "Colombia")
      /// Comoros
      public static let comoros = L10n.tr("Localizable", "browsing_country.comoros", fallback: "Comoros")
      /// Congo
      public static let congo = L10n.tr("Localizable", "browsing_country.congo", fallback: "Congo")
      /// Cook Islands
      public static let cookIslands = L10n.tr("Localizable", "browsing_country.cook_islands", fallback: "Cook Islands")
      /// Costa Rica
      public static let costaRica = L10n.tr("Localizable", "browsing_country.costa_rica", fallback: "Costa Rica")
      /// Cote D'Ivoire
      public static let coteDIvoire = L10n.tr("Localizable", "browsing_country.cote_d_ivoire", fallback: "Cote D'Ivoire")
      /// Croatia
      public static let croatia = L10n.tr("Localizable", "browsing_country.croatia", fallback: "Croatia")
      /// Cuba
      public static let cuba = L10n.tr("Localizable", "browsing_country.cuba", fallback: "Cuba")
      /// Curacao
      public static let curacao = L10n.tr("Localizable", "browsing_country.curacao", fallback: "Curacao")
      /// Cyprus
      public static let cyprus = L10n.tr("Localizable", "browsing_country.cyprus", fallback: "Cyprus")
      /// Czech Republic
      public static let czechRepublic = L10n.tr("Localizable", "browsing_country.czech_republic", fallback: "Czech Republic")
      /// Denmark
      public static let denmark = L10n.tr("Localizable", "browsing_country.denmark", fallback: "Denmark")
      /// Djibouti
      public static let djibouti = L10n.tr("Localizable", "browsing_country.djibouti", fallback: "Djibouti")
      /// Dominica
      public static let dominica = L10n.tr("Localizable", "browsing_country.dominica", fallback: "Dominica")
      /// Dominican Republic
      public static let dominicanRepublic = L10n.tr("Localizable", "browsing_country.dominican_republic", fallback: "Dominican Republic")
      /// Ecuador
      public static let ecuador = L10n.tr("Localizable", "browsing_country.ecuador", fallback: "Ecuador")
      /// Egypt
      public static let egypt = L10n.tr("Localizable", "browsing_country.egypt", fallback: "Egypt")
      /// El Salvador
      public static let elSalvador = L10n.tr("Localizable", "browsing_country.el_salvador", fallback: "El Salvador")
      /// Equatorial Guinea
      public static let equatorialGuinea = L10n.tr("Localizable", "browsing_country.equatorial_guinea", fallback: "Equatorial Guinea")
      /// Eritrea
      public static let eritrea = L10n.tr("Localizable", "browsing_country.eritrea", fallback: "Eritrea")
      /// Estonia
      public static let estonia = L10n.tr("Localizable", "browsing_country.estonia", fallback: "Estonia")
      /// Ethiopia
      public static let ethiopia = L10n.tr("Localizable", "browsing_country.ethiopia", fallback: "Ethiopia")
      /// Europe
      public static let europe = L10n.tr("Localizable", "browsing_country.europe", fallback: "Europe")
      /// Falkland Islands
      public static let falklandIslands = L10n.tr("Localizable", "browsing_country.falkland_islands", fallback: "Falkland Islands")
      /// Faroe Islands
      public static let faroeIslands = L10n.tr("Localizable", "browsing_country.faroe_islands", fallback: "Faroe Islands")
      /// Fiji
      public static let fiji = L10n.tr("Localizable", "browsing_country.fiji", fallback: "Fiji")
      /// Finland
      public static let finland = L10n.tr("Localizable", "browsing_country.finland", fallback: "Finland")
      /// France
      public static let france = L10n.tr("Localizable", "browsing_country.france", fallback: "France")
      /// French Guiana
      public static let frenchGuiana = L10n.tr("Localizable", "browsing_country.french_guiana", fallback: "French Guiana")
      /// French Polynesia
      public static let frenchPolynesia = L10n.tr("Localizable", "browsing_country.french_polynesia", fallback: "French Polynesia")
      /// French Southern Territories
      public static let frenchSouthernTerritories = L10n.tr("Localizable", "browsing_country.french_southern_territories", fallback: "French Southern Territories")
      /// Gabon
      public static let gabon = L10n.tr("Localizable", "browsing_country.gabon", fallback: "Gabon")
      /// Gambia
      public static let gambia = L10n.tr("Localizable", "browsing_country.gambia", fallback: "Gambia")
      /// Georgia
      public static let georgia = L10n.tr("Localizable", "browsing_country.georgia", fallback: "Georgia")
      /// Germany
      public static let germany = L10n.tr("Localizable", "browsing_country.germany", fallback: "Germany")
      /// Ghana
      public static let ghana = L10n.tr("Localizable", "browsing_country.ghana", fallback: "Ghana")
      /// Gibraltar
      public static let gibraltar = L10n.tr("Localizable", "browsing_country.gibraltar", fallback: "Gibraltar")
      /// Greece
      public static let greece = L10n.tr("Localizable", "browsing_country.greece", fallback: "Greece")
      /// Greenland
      public static let greenland = L10n.tr("Localizable", "browsing_country.greenland", fallback: "Greenland")
      /// Grenada
      public static let grenada = L10n.tr("Localizable", "browsing_country.grenada", fallback: "Grenada")
      /// Guadeloupe
      public static let guadeloupe = L10n.tr("Localizable", "browsing_country.guadeloupe", fallback: "Guadeloupe")
      /// Guam
      public static let guam = L10n.tr("Localizable", "browsing_country.guam", fallback: "Guam")
      /// Guatemala
      public static let guatemala = L10n.tr("Localizable", "browsing_country.guatemala", fallback: "Guatemala")
      /// Guernsey
      public static let guernsey = L10n.tr("Localizable", "browsing_country.guernsey", fallback: "Guernsey")
      /// Guinea
      public static let guinea = L10n.tr("Localizable", "browsing_country.guinea", fallback: "Guinea")
      /// Guinea-Bissau
      public static let guineaBissau = L10n.tr("Localizable", "browsing_country.guinea_bissau", fallback: "Guinea-Bissau")
      /// Guyana
      public static let guyana = L10n.tr("Localizable", "browsing_country.guyana", fallback: "Guyana")
      /// Haiti
      public static let haiti = L10n.tr("Localizable", "browsing_country.haiti", fallback: "Haiti")
      /// Heard Island and McDonald Islands
      public static let heardIslandAndMcDonaldIslands = L10n.tr("Localizable", "browsing_country.heard_island_and_mc_donald_islands", fallback: "Heard Island and McDonald Islands")
      /// Honduras
      public static let honduras = L10n.tr("Localizable", "browsing_country.honduras", fallback: "Honduras")
      /// Hong Kong
      public static let hongKong = L10n.tr("Localizable", "browsing_country.hong_kong", fallback: "Hong Kong")
      /// Hungary
      public static let hungary = L10n.tr("Localizable", "browsing_country.hungary", fallback: "Hungary")
      /// Iceland
      public static let iceland = L10n.tr("Localizable", "browsing_country.iceland", fallback: "Iceland")
      /// India
      public static let india = L10n.tr("Localizable", "browsing_country.india", fallback: "India")
      /// Indonesia
      public static let indonesia = L10n.tr("Localizable", "browsing_country.indonesia", fallback: "Indonesia")
      /// Iran
      public static let iran = L10n.tr("Localizable", "browsing_country.iran", fallback: "Iran")
      /// Iraq
      public static let iraq = L10n.tr("Localizable", "browsing_country.iraq", fallback: "Iraq")
      /// Ireland
      public static let ireland = L10n.tr("Localizable", "browsing_country.ireland", fallback: "Ireland")
      /// Isle of Man
      public static let isleOfMan = L10n.tr("Localizable", "browsing_country.isle_of_man", fallback: "Isle of Man")
      /// Israel
      public static let israel = L10n.tr("Localizable", "browsing_country.israel", fallback: "Israel")
      /// Italy
      public static let italy = L10n.tr("Localizable", "browsing_country.italy", fallback: "Italy")
      /// Jamaica
      public static let jamaica = L10n.tr("Localizable", "browsing_country.jamaica", fallback: "Jamaica")
      /// Japan
      public static let japan = L10n.tr("Localizable", "browsing_country.japan", fallback: "Japan")
      /// Jersey
      public static let jersey = L10n.tr("Localizable", "browsing_country.jersey", fallback: "Jersey")
      /// Jordan
      public static let jordan = L10n.tr("Localizable", "browsing_country.jordan", fallback: "Jordan")
      /// Kazakhstan
      public static let kazakhstan = L10n.tr("Localizable", "browsing_country.kazakhstan", fallback: "Kazakhstan")
      /// Kenya
      public static let kenya = L10n.tr("Localizable", "browsing_country.kenya", fallback: "Kenya")
      /// Kiribati
      public static let kiribati = L10n.tr("Localizable", "browsing_country.kiribati", fallback: "Kiribati")
      /// Kuwait
      public static let kuwait = L10n.tr("Localizable", "browsing_country.kuwait", fallback: "Kuwait")
      /// Kyrgyzstan
      public static let kyrgyzstan = L10n.tr("Localizable", "browsing_country.kyrgyzstan", fallback: "Kyrgyzstan")
      /// Lao People's Democratic Republic
      public static let laoPeoplesDemocraticRepublic = L10n.tr("Localizable", "browsing_country.lao_peoples_democratic_republic", fallback: "Lao People's Democratic Republic")
      /// Latvia
      public static let latvia = L10n.tr("Localizable", "browsing_country.latvia", fallback: "Latvia")
      /// Lebanon
      public static let lebanon = L10n.tr("Localizable", "browsing_country.lebanon", fallback: "Lebanon")
      /// Lesotho
      public static let lesotho = L10n.tr("Localizable", "browsing_country.lesotho", fallback: "Lesotho")
      /// Liberia
      public static let liberia = L10n.tr("Localizable", "browsing_country.liberia", fallback: "Liberia")
      /// Libya
      public static let libya = L10n.tr("Localizable", "browsing_country.libya", fallback: "Libya")
      /// Liechtenstein
      public static let liechtenstein = L10n.tr("Localizable", "browsing_country.liechtenstein", fallback: "Liechtenstein")
      /// Lithuania
      public static let lithuania = L10n.tr("Localizable", "browsing_country.lithuania", fallback: "Lithuania")
      /// Luxembourg
      public static let luxembourg = L10n.tr("Localizable", "browsing_country.luxembourg", fallback: "Luxembourg")
      /// Macau
      public static let macau = L10n.tr("Localizable", "browsing_country.macau", fallback: "Macau")
      /// Macedonia
      public static let macedonia = L10n.tr("Localizable", "browsing_country.macedonia", fallback: "Macedonia")
      /// Madagascar
      public static let madagascar = L10n.tr("Localizable", "browsing_country.madagascar", fallback: "Madagascar")
      /// Malawi
      public static let malawi = L10n.tr("Localizable", "browsing_country.malawi", fallback: "Malawi")
      /// Malaysia
      public static let malaysia = L10n.tr("Localizable", "browsing_country.malaysia", fallback: "Malaysia")
      /// Maldives
      public static let maldives = L10n.tr("Localizable", "browsing_country.maldives", fallback: "Maldives")
      /// Mali
      public static let mali = L10n.tr("Localizable", "browsing_country.mali", fallback: "Mali")
      /// Malta
      public static let malta = L10n.tr("Localizable", "browsing_country.malta", fallback: "Malta")
      /// Marshall Islands
      public static let marshallIslands = L10n.tr("Localizable", "browsing_country.marshall_islands", fallback: "Marshall Islands")
      /// Martinique
      public static let martinique = L10n.tr("Localizable", "browsing_country.martinique", fallback: "Martinique")
      /// Mauritania
      public static let mauritania = L10n.tr("Localizable", "browsing_country.mauritania", fallback: "Mauritania")
      /// Mauritius
      public static let mauritius = L10n.tr("Localizable", "browsing_country.mauritius", fallback: "Mauritius")
      /// Mayotte
      public static let mayotte = L10n.tr("Localizable", "browsing_country.mayotte", fallback: "Mayotte")
      /// Mexico
      public static let mexico = L10n.tr("Localizable", "browsing_country.mexico", fallback: "Mexico")
      /// Micronesia
      public static let micronesia = L10n.tr("Localizable", "browsing_country.micronesia", fallback: "Micronesia")
      /// Moldova
      public static let moldova = L10n.tr("Localizable", "browsing_country.moldova", fallback: "Moldova")
      /// Monaco
      public static let monaco = L10n.tr("Localizable", "browsing_country.monaco", fallback: "Monaco")
      /// Mongolia
      public static let mongolia = L10n.tr("Localizable", "browsing_country.mongolia", fallback: "Mongolia")
      /// Montenegro
      public static let montenegro = L10n.tr("Localizable", "browsing_country.montenegro", fallback: "Montenegro")
      /// Montserrat
      public static let montserrat = L10n.tr("Localizable", "browsing_country.montserrat", fallback: "Montserrat")
      /// Morocco
      public static let morocco = L10n.tr("Localizable", "browsing_country.morocco", fallback: "Morocco")
      /// Mozambique
      public static let mozambique = L10n.tr("Localizable", "browsing_country.mozambique", fallback: "Mozambique")
      /// Myanmar
      public static let myanmar = L10n.tr("Localizable", "browsing_country.myanmar", fallback: "Myanmar")
      /// Namibia
      public static let namibia = L10n.tr("Localizable", "browsing_country.namibia", fallback: "Namibia")
      /// Nauru
      public static let nauru = L10n.tr("Localizable", "browsing_country.nauru", fallback: "Nauru")
      /// Nepal
      public static let nepal = L10n.tr("Localizable", "browsing_country.nepal", fallback: "Nepal")
      /// Netherlands
      public static let netherlands = L10n.tr("Localizable", "browsing_country.netherlands", fallback: "Netherlands")
      /// New Caledonia
      public static let newCaledonia = L10n.tr("Localizable", "browsing_country.new_caledonia", fallback: "New Caledonia")
      /// New Zealand
      public static let newZealand = L10n.tr("Localizable", "browsing_country.new_zealand", fallback: "New Zealand")
      /// Nicaragua
      public static let nicaragua = L10n.tr("Localizable", "browsing_country.nicaragua", fallback: "Nicaragua")
      /// Niger
      public static let niger = L10n.tr("Localizable", "browsing_country.niger", fallback: "Niger")
      /// Nigeria
      public static let nigeria = L10n.tr("Localizable", "browsing_country.nigeria", fallback: "Nigeria")
      /// Niue
      public static let niue = L10n.tr("Localizable", "browsing_country.niue", fallback: "Niue")
      /// Norfolk Island
      public static let norfolkIsland = L10n.tr("Localizable", "browsing_country.norfolk_island", fallback: "Norfolk Island")
      /// North Korea
      public static let northKorea = L10n.tr("Localizable", "browsing_country.north_korea", fallback: "North Korea")
      /// Northern Mariana Islands
      public static let northernMarianaIslands = L10n.tr("Localizable", "browsing_country.northern_mariana_islands", fallback: "Northern Mariana Islands")
      /// Norway
      public static let norway = L10n.tr("Localizable", "browsing_country.norway", fallback: "Norway")
      /// Oman
      public static let oman = L10n.tr("Localizable", "browsing_country.oman", fallback: "Oman")
      /// Pakistan
      public static let pakistan = L10n.tr("Localizable", "browsing_country.pakistan", fallback: "Pakistan")
      /// Palau
      public static let palau = L10n.tr("Localizable", "browsing_country.palau", fallback: "Palau")
      /// Palestinian Territory
      public static let palestinianTerritory = L10n.tr("Localizable", "browsing_country.palestinian_territory", fallback: "Palestinian Territory")
      /// Panama
      public static let panama = L10n.tr("Localizable", "browsing_country.panama", fallback: "Panama")
      /// Papua New Guinea
      public static let papuaNewGuinea = L10n.tr("Localizable", "browsing_country.papua_new_guinea", fallback: "Papua New Guinea")
      /// Paraguay
      public static let paraguay = L10n.tr("Localizable", "browsing_country.paraguay", fallback: "Paraguay")
      /// Peru
      public static let peru = L10n.tr("Localizable", "browsing_country.peru", fallback: "Peru")
      /// Philippines
      public static let philippines = L10n.tr("Localizable", "browsing_country.philippines", fallback: "Philippines")
      /// Pitcairn Islands
      public static let pitcairnIslands = L10n.tr("Localizable", "browsing_country.pitcairn_islands", fallback: "Pitcairn Islands")
      /// Poland
      public static let poland = L10n.tr("Localizable", "browsing_country.poland", fallback: "Poland")
      /// Portugal
      public static let portugal = L10n.tr("Localizable", "browsing_country.portugal", fallback: "Portugal")
      /// Puerto Rico
      public static let puertoRico = L10n.tr("Localizable", "browsing_country.puerto_rico", fallback: "Puerto Rico")
      /// Qatar
      public static let qatar = L10n.tr("Localizable", "browsing_country.qatar", fallback: "Qatar")
      /// Reunion
      public static let reunion = L10n.tr("Localizable", "browsing_country.reunion", fallback: "Reunion")
      /// Romania
      public static let romania = L10n.tr("Localizable", "browsing_country.romania", fallback: "Romania")
      /// Russian Federation
      public static let russianFederation = L10n.tr("Localizable", "browsing_country.russian_federation", fallback: "Russian Federation")
      /// Rwanda
      public static let rwanda = L10n.tr("Localizable", "browsing_country.rwanda", fallback: "Rwanda")
      /// Saint Barthelemy
      public static let saintBarthelemy = L10n.tr("Localizable", "browsing_country.saint_barthelemy", fallback: "Saint Barthelemy")
      /// Saint Helena
      public static let saintHelena = L10n.tr("Localizable", "browsing_country.saint_helena", fallback: "Saint Helena")
      /// Saint Kitts and Nevis
      public static let saintKittsAndNevis = L10n.tr("Localizable", "browsing_country.saint_kitts_and_nevis", fallback: "Saint Kitts and Nevis")
      /// Saint Lucia
      public static let saintLucia = L10n.tr("Localizable", "browsing_country.saint_lucia", fallback: "Saint Lucia")
      /// Saint Martin
      public static let saintMartin = L10n.tr("Localizable", "browsing_country.saint_martin", fallback: "Saint Martin")
      /// Saint Pierre and Miquelon
      public static let saintPierreAndMiquelon = L10n.tr("Localizable", "browsing_country.saint_pierre_and_miquelon", fallback: "Saint Pierre and Miquelon")
      /// Saint Vincent and the Grenadines
      public static let saintVincentAndTheGrenadines = L10n.tr("Localizable", "browsing_country.saint_vincent_and_the_grenadines", fallback: "Saint Vincent and the Grenadines")
      /// Samoa
      public static let samoa = L10n.tr("Localizable", "browsing_country.samoa", fallback: "Samoa")
      /// San Marino
      public static let sanMarino = L10n.tr("Localizable", "browsing_country.san_marino", fallback: "San Marino")
      /// Sao Tome and Principe
      public static let saoTomeAndPrincipe = L10n.tr("Localizable", "browsing_country.sao_tome_and_principe", fallback: "Sao Tome and Principe")
      /// Saudi Arabia
      public static let saudiArabia = L10n.tr("Localizable", "browsing_country.saudi_arabia", fallback: "Saudi Arabia")
      /// Senegal
      public static let senegal = L10n.tr("Localizable", "browsing_country.senegal", fallback: "Senegal")
      /// Serbia
      public static let serbia = L10n.tr("Localizable", "browsing_country.serbia", fallback: "Serbia")
      /// Seychelles
      public static let seychelles = L10n.tr("Localizable", "browsing_country.seychelles", fallback: "Seychelles")
      /// Sierra Leone
      public static let sierraLeone = L10n.tr("Localizable", "browsing_country.sierra_leone", fallback: "Sierra Leone")
      /// Singapore
      public static let singapore = L10n.tr("Localizable", "browsing_country.singapore", fallback: "Singapore")
      /// Sint Maarten
      public static let sintMaarten = L10n.tr("Localizable", "browsing_country.sint_maarten", fallback: "Sint Maarten")
      /// Slovakia
      public static let slovakia = L10n.tr("Localizable", "browsing_country.slovakia", fallback: "Slovakia")
      /// Slovenia
      public static let slovenia = L10n.tr("Localizable", "browsing_country.slovenia", fallback: "Slovenia")
      /// Solomon Islands
      public static let solomonIslands = L10n.tr("Localizable", "browsing_country.solomon_islands", fallback: "Solomon Islands")
      /// Somalia
      public static let somalia = L10n.tr("Localizable", "browsing_country.somalia", fallback: "Somalia")
      /// South Africa
      public static let southAfrica = L10n.tr("Localizable", "browsing_country.south_africa", fallback: "South Africa")
      /// South Georgia and the South Sandwich Islands
      public static let southGeorgiaAndTheSouthSandwichIslands = L10n.tr("Localizable", "browsing_country.south_georgia_and_the_south_sandwich_islands", fallback: "South Georgia and the South Sandwich Islands")
      /// South Korea
      public static let southKorea = L10n.tr("Localizable", "browsing_country.south_korea", fallback: "South Korea")
      /// South Sudan
      public static let southSudan = L10n.tr("Localizable", "browsing_country.south_sudan", fallback: "South Sudan")
      /// Spain
      public static let spain = L10n.tr("Localizable", "browsing_country.spain", fallback: "Spain")
      /// Sri Lanka
      public static let sriLanka = L10n.tr("Localizable", "browsing_country.sri_lanka", fallback: "Sri Lanka")
      /// Sudan
      public static let sudan = L10n.tr("Localizable", "browsing_country.sudan", fallback: "Sudan")
      /// Suriname
      public static let suriname = L10n.tr("Localizable", "browsing_country.suriname", fallback: "Suriname")
      /// Svalbard and Jan Mayen
      public static let svalbardAndJanMayen = L10n.tr("Localizable", "browsing_country.svalbard_and_jan_mayen", fallback: "Svalbard and Jan Mayen")
      /// Swaziland
      public static let swaziland = L10n.tr("Localizable", "browsing_country.swaziland", fallback: "Swaziland")
      /// Sweden
      public static let sweden = L10n.tr("Localizable", "browsing_country.sweden", fallback: "Sweden")
      /// Switzerland
      public static let switzerland = L10n.tr("Localizable", "browsing_country.switzerland", fallback: "Switzerland")
      /// Syrian Arab Republic
      public static let syrianArabRepublic = L10n.tr("Localizable", "browsing_country.syrian_arab_republic", fallback: "Syrian Arab Republic")
      /// Taiwan
      public static let taiwan = L10n.tr("Localizable", "browsing_country.taiwan", fallback: "Taiwan")
      /// Tajikistan
      public static let tajikistan = L10n.tr("Localizable", "browsing_country.tajikistan", fallback: "Tajikistan")
      /// Tanzania
      public static let tanzania = L10n.tr("Localizable", "browsing_country.tanzania", fallback: "Tanzania")
      /// Thailand
      public static let thailand = L10n.tr("Localizable", "browsing_country.thailand", fallback: "Thailand")
      /// The Democratic Republic of the Congo
      public static let theDemocraticRepublicOfTheCongo = L10n.tr("Localizable", "browsing_country.the_democratic_republic_of_the_congo", fallback: "The Democratic Republic of the Congo")
      /// Timor-Leste
      public static let timorLeste = L10n.tr("Localizable", "browsing_country.timor_leste", fallback: "Timor-Leste")
      /// Togo
      public static let togo = L10n.tr("Localizable", "browsing_country.togo", fallback: "Togo")
      /// Tokelau
      public static let tokelau = L10n.tr("Localizable", "browsing_country.tokelau", fallback: "Tokelau")
      /// Tonga
      public static let tonga = L10n.tr("Localizable", "browsing_country.tonga", fallback: "Tonga")
      /// Trinidad and Tobago
      public static let trinidadAndTobago = L10n.tr("Localizable", "browsing_country.trinidad_and_tobago", fallback: "Trinidad and Tobago")
      /// Tunisia
      public static let tunisia = L10n.tr("Localizable", "browsing_country.tunisia", fallback: "Tunisia")
      /// Turkey
      public static let turkey = L10n.tr("Localizable", "browsing_country.turkey", fallback: "Turkey")
      /// Turkmenistan
      public static let turkmenistan = L10n.tr("Localizable", "browsing_country.turkmenistan", fallback: "Turkmenistan")
      /// Turks and Caicos Islands
      public static let turksAndCaicosIslands = L10n.tr("Localizable", "browsing_country.turks_and_caicos_islands", fallback: "Turks and Caicos Islands")
      /// Tuvalu
      public static let tuvalu = L10n.tr("Localizable", "browsing_country.tuvalu", fallback: "Tuvalu")
      /// Uganda
      public static let uganda = L10n.tr("Localizable", "browsing_country.uganda", fallback: "Uganda")
      /// Ukraine
      public static let ukraine = L10n.tr("Localizable", "browsing_country.ukraine", fallback: "Ukraine")
      /// United Arab Emirates
      public static let unitedArabEmirates = L10n.tr("Localizable", "browsing_country.united_arab_emirates", fallback: "United Arab Emirates")
      /// United Kingdom
      public static let unitedKingdom = L10n.tr("Localizable", "browsing_country.united_kingdom", fallback: "United Kingdom")
      /// United States
      public static let unitedStates = L10n.tr("Localizable", "browsing_country.united_states", fallback: "United States")
      /// United States Minor Outlying Islands
      public static let unitedStatesMinorOutlyingIslands = L10n.tr("Localizable", "browsing_country.united_states_minor_outlying_islands", fallback: "United States Minor Outlying Islands")
      /// Uruguay
      public static let uruguay = L10n.tr("Localizable", "browsing_country.uruguay", fallback: "Uruguay")
      /// Uzbekistan
      public static let uzbekistan = L10n.tr("Localizable", "browsing_country.uzbekistan", fallback: "Uzbekistan")
      /// Vanuatu
      public static let vanuatu = L10n.tr("Localizable", "browsing_country.vanuatu", fallback: "Vanuatu")
      /// Vatican City State
      public static let vaticanCityState = L10n.tr("Localizable", "browsing_country.vatican_city_state", fallback: "Vatican City State")
      /// Venezuela
      public static let venezuela = L10n.tr("Localizable", "browsing_country.venezuela", fallback: "Venezuela")
      /// Vietnam
      public static let vietnam = L10n.tr("Localizable", "browsing_country.vietnam", fallback: "Vietnam")
      /// British Virgin Islands
      public static let virginIslandsBritish = L10n.tr("Localizable", "browsing_country.virgin_islands_british", fallback: "British Virgin Islands")
      /// U.S. Virgin Islands
      public static let virginIslandsUS = L10n.tr("Localizable", "browsing_country.virgin_islands_US", fallback: "U.S. Virgin Islands")
      /// Wallis and Futuna
      public static let wallisAndFutuna = L10n.tr("Localizable", "browsing_country.wallis_and_futuna", fallback: "Wallis and Futuna")
      /// Western Sahara
      public static let westernSahara = L10n.tr("Localizable", "browsing_country.western_sahara", fallback: "Western Sahara")
      /// Yemen
      public static let yemen = L10n.tr("Localizable", "browsing_country.yemen", fallback: "Yemen")
      /// Zambia
      public static let zambia = L10n.tr("Localizable", "browsing_country.zambia", fallback: "Zambia")
      /// Zimbabwe
      public static let zimbabwe = L10n.tr("Localizable", "browsing_country.zimbabwe", fallback: "Zimbabwe")
    }
    public enum Category {
      /// Artist CG
      public static let artistCG = L10n.tr("Localizable", "category.artist_CG", fallback: "Artist CG")
      /// Asian Porn
      public static let asianPorn = L10n.tr("Localizable", "category.asian_porn", fallback: "Asian Porn")
      /// Cosplay
      public static let cosplay = L10n.tr("Localizable", "category.cosplay", fallback: "Cosplay")
      /// Doujinshi
      public static let doujinshi = L10n.tr("Localizable", "category.doujinshi", fallback: "Doujinshi")
      /// Game CG
      public static let gameCG = L10n.tr("Localizable", "category.game_CG", fallback: "Game CG")
      /// Image Set
      public static let imageSet = L10n.tr("Localizable", "category.image_set", fallback: "Image Set")
      /// Manga
      public static let manga = L10n.tr("Localizable", "category.manga", fallback: "Manga")
      /// Misc
      public static let misc = L10n.tr("Localizable", "category.misc", fallback: "Misc")
      /// Non-H
      public static let nonH = L10n.tr("Localizable", "category.non_h", fallback: "Non-H")
      /// Private
      public static let `private` = L10n.tr("Localizable", "category.private", fallback: "Private")
      /// Western
      public static let western = L10n.tr("Localizable", "category.western", fallback: "Western")
    }
    public enum CommentsSortOrder {
      /// By highest score
      public static let highestScore = L10n.tr("Localizable", "comments_sort_order.highest_score", fallback: "By highest score")
      /// Oldest comments first
      public static let oldest = L10n.tr("Localizable", "comments_sort_order.oldest", fallback: "Oldest comments first")
      /// Recent comments first
      public static let recent = L10n.tr("Localizable", "comments_sort_order.recent", fallback: "Recent comments first")
    }
    public enum CommentsVotesShowTiming {
      /// Always
      public static let always = L10n.tr("Localizable", "comments_votes_show_timing.always", fallback: "Always")
      /// On score hover or click
      public static let onHoverOrClick = L10n.tr("Localizable", "comments_votes_show_timing.on_hover_or_click", fallback: "On score hover or click")
    }
    public enum Common {
      /// Cancel
      public static let cancel = L10n.tr("Localizable", "common.cancel", fallback: "Cancel")
      /// %@ day
      public static func day(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.day", String(describing: p1), fallback: "%@ day")
      }
      /// %@ days
      public static func days(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.days", String(describing: p1), fallback: "%@ days")
      }
      /// %@ hour
      public static func hour(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.hour", String(describing: p1), fallback: "%@ hour")
      }
      /// %@ hours
      public static func hours(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.hours", String(describing: p1), fallback: "%@ hours")
      }
      /// %@ minute
      public static func minute(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.minute", String(describing: p1), fallback: "%@ minute")
      }
      /// %@ minutes
      public static func minutes(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.minutes", String(describing: p1), fallback: "%@ minutes")
      }
      /// %@ pages
      public static func pages(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.pages", String(describing: p1), fallback: "%@ pages")
      }
      /// %@ second
      public static func second(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.second", String(describing: p1), fallback: "%@ second")
      }
      /// %@ seconds
      public static func seconds(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.seconds", String(describing: p1), fallback: "%@ seconds")
      }
      /// %@ stars
      public static func stars(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.stars", String(describing: p1), fallback: "%@ stars")
      }
    }
    public enum ConfirmationDialog {
      /// Clear
      public static let clear = L10n.tr("Localizable", "confirmation_dialog.clear", fallback: "Clear")
      /// Are you sure to clear?
      public static let clearDescription = L10n.tr("Localizable", "confirmation_dialog.clear_description", fallback: "Are you sure to clear?")
      /// Delete
      public static let delete = L10n.tr("Localizable", "confirmation_dialog.delete", fallback: "Delete")
      /// Are you sure to delete this item?
      public static let deleteDescription = L10n.tr("Localizable", "confirmation_dialog.delete_description", fallback: "Are you sure to delete this item?")
    }
    public enum DateSeekView {
      /// Seek to date
      public static let dateSeek = L10n.tr("Localizable", "date_seek_view.date_seek", fallback: "Seek to date")
    }
    public enum DetailView {
      /// Delete Download?
      public static let deleteDownload = L10n.tr("Localizable", "detail_view.delete_download", fallback: "Delete Download?")
      /// This will remove the downloaded gallery from this device.
      public static let deleteDownloadedGallery = L10n.tr("Localizable", "detail_view.delete_downloaded_gallery", fallback: "This will remove the downloaded gallery from this device.")
      /// Detail
      public static let detail = L10n.tr("Localizable", "detail_view.detail", fallback: "Detail")
      /// Language
      public static let language = L10n.tr("Localizable", "detail_view.language", fallback: "Language")
      /// Manage Folders
      public static let manageFolders = L10n.tr("Localizable", "detail_view.manage_folders", fallback: "Manage Folders")
      /// Share
      public static let share = L10n.tr("Localizable", "detail_view.share", fallback: "Share")
      /// Update
      public static let update = L10n.tr("Localizable", "detail_view.update", fallback: "Update")
    }
    public enum DisplayMode {
      /// Compact
      public static let compact = L10n.tr("Localizable", "display_mode.compact", fallback: "Compact")
      /// Extended
      public static let extended = L10n.tr("Localizable", "display_mode.extended", fallback: "Extended")
      /// Minimal
      public static let minimal = L10n.tr("Localizable", "display_mode.minimal", fallback: "Minimal")
      /// Minimal+
      public static let minimalPlus = L10n.tr("Localizable", "display_mode.minimalPlus", fallback: "Minimal+")
      /// Thumbnail
      public static let thumbnail = L10n.tr("Localizable", "display_mode.thumbnail", fallback: "Thumbnail")
    }
    public enum DownloadFolderFilter {
      /// All
      public static let all = L10n.tr("Localizable", "download_folder_filter.all", fallback: "All")
    }
    public enum DownloadStore {
      /// The folder name is invalid.
      public static let invalidFolderName = L10n.tr("Localizable", "download_store.invalid_folder_name", fallback: "The folder name is invalid.")
      /// Manifest file is corrupted.
      public static let manifestCorrupted = L10n.tr("Localizable", "download_store.manifest_corrupted", fallback: "Manifest file is corrupted.")
      /// Page %d image data is corrupted.
      public static func pageImageCorrupted(_ p1: Int) -> String {
        return L10n.tr("Localizable", "download_store.page_image_corrupted", p1, fallback: "Page %d image data is corrupted.")
      }
      /// Page %d is missing.
      public static func pageMissing(_ p1: Int) -> String {
        return L10n.tr("Localizable", "download_store.page_missing", p1, fallback: "Page %d is missing.")
      }
    }
    public enum DownloadsView {
      /// Delete Download?
      public static let deleteDownload = L10n.tr("Localizable", "downloads_view.delete_download", fallback: "Delete Download?")
      /// This will remove the downloaded gallery from this device.
      public static let deleteDownloadedGallery = L10n.tr("Localizable", "downloads_view.delete_downloaded_gallery", fallback: "This will remove the downloaded gallery from this device.")
      /// Downloads
      public static let downloads = L10n.tr("Localizable", "downloads_view.downloads", fallback: "Downloads")
      /// Manage Folders
      public static let manageFolders = L10n.tr("Localizable", "downloads_view.manage_folders", fallback: "Manage Folders")
      /// Update
      public static let update = L10n.tr("Localizable", "downloads_view.update", fallback: "Update")
    }
    public enum EhSetting {
      public enum ArchiverBehavior {
        /// Auto Select Original, Auto Start
        public static let autoSelectOriginalAutoStart = L10n.tr("Localizable", "eh_setting.archiver_behavior.auto_select_original_auto_start", fallback: "Auto Select Original, Auto Start")
        /// Auto Select Original, Manual Start
        public static let autoSelectOriginalManualStart = L10n.tr("Localizable", "eh_setting.archiver_behavior.auto_select_original_manual_start", fallback: "Auto Select Original, Manual Start")
        /// Auto Select Resample, Auto Start
        public static let autoSelectResampleAutoStart = L10n.tr("Localizable", "eh_setting.archiver_behavior.auto_select_resample_auto_start", fallback: "Auto Select Resample, Auto Start")
        /// Auto Select Resample, Manual Start
        public static let autoSelectResampleManualStart = L10n.tr("Localizable", "eh_setting.archiver_behavior.auto_select_resample_manual_start", fallback: "Auto Select Resample, Manual Start")
        /// Manual Select, Auto Start
        public static let manualSelectAutoStart = L10n.tr("Localizable", "eh_setting.archiver_behavior.manual_select_auto_start", fallback: "Manual Select, Auto Start")
        /// Manual Select, Manual Start (Default)
        public static let manualSelectManualStart = L10n.tr("Localizable", "eh_setting.archiver_behavior.manual_select_manual_start", fallback: "Manual Select, Manual Start (Default)")
      }
    }
    public enum ErrorView {
      /// This gallery is unavailable due to a copyright claim by %@. Sorry about that.
      public static func copyrightClaim(_ p1: Any) -> String {
        return L10n.tr("Localizable", "error_view.copyright_claim", String(describing: p1), fallback: "This gallery is unavailable due to a copyright claim by %@. Sorry about that.")
      }
      /// The database is corrupted.
      /// Please submit an issue on GitHub.
      public static let databaseCorrupted = L10n.tr("Localizable", "error_view.database_corrupted", fallback: "The database is corrupted.\nPlease submit an issue on GitHub.")
      /// This gallery has been removed or is unavailable.
      public static let galleryUnavailable = L10n.tr("Localizable", "error_view.gallery_unavailable", fallback: "This gallery has been removed or is unavailable.")
      /// Your IP address has been temporarily banned for excessive pageloads which indicates that you are using automated mirroring / harvesting software. The ban expires in %@.
      public static func ipBanned(_ p1: Any) -> String {
        return L10n.tr("Localizable", "error_view.ip_banned", String(describing: p1), fallback: "Your IP address has been temporarily banned for excessive pageloads which indicates that you are using automated mirroring / harvesting software. The ban expires in %@.")
      }
      /// A network error occurred.
      public static let network = L10n.tr("Localizable", "error_view.network", fallback: "A network error occurred.")
      /// There seems to be nothing here.
      public static let notFound = L10n.tr("Localizable", "error_view.not_found", fallback: "There seems to be nothing here.")
      /// A parsing error occurred.
      public static let parsing = L10n.tr("Localizable", "error_view.parsing", fallback: "A parsing error occurred.")
      /// Retry
      public static let retry = L10n.tr("Localizable", "error_view.retry", fallback: "Retry")
      /// Please try again later.
      public static let tryLater = L10n.tr("Localizable", "error_view.try_later", fallback: "Please try again later.")
      /// An unknown error occurred.
      public static let unknown = L10n.tr("Localizable", "error_view.unknown", fallback: "An unknown error occurred.")
    }
    public enum ExcludedLanguagesCategory {
      /// Original
      public static let original = L10n.tr("Localizable", "excluded_languages_category.original", fallback: "Original")
      /// Rewrite
      public static let rewrite = L10n.tr("Localizable", "excluded_languages_category.rewrite", fallback: "Rewrite")
      /// Translated
      public static let translated = L10n.tr("Localizable", "excluded_languages_category.translated", fallback: "Translated")
    }
    public enum FavoriteCategory {
      /// All
      public static let all = L10n.tr("Localizable", "favorite_category.all", fallback: "All")
      /// Favorites %@
      public static func `default`(_ p1: Any) -> String {
        return L10n.tr("Localizable", "favorite_category.default", String(describing: p1), fallback: "Favorites %@")
      }
    }
    public enum FavoritesSortOrder {
      /// By favorited time
      public static let favoritedTime = L10n.tr("Localizable", "favorites_sort_order.favorited_time", fallback: "By favorited time")
      /// By last gallery update time
      public static let lastUpdateTime = L10n.tr("Localizable", "favorites_sort_order.last_update_time", fallback: "By last gallery update time")
    }
    public enum FavoritesView {
      /// Favorites
      public static let favorites = L10n.tr("Localizable", "favorites_view.favorites", fallback: "Favorites")
    }
    public enum FilterRange {
      /// Global
      public static let global = L10n.tr("Localizable", "filter_range.global", fallback: "Global")
      /// Search
      public static let search = L10n.tr("Localizable", "filter_range.search", fallback: "Search")
      /// Watched
      public static let watched = L10n.tr("Localizable", "filter_range.watched", fallback: "Watched")
    }
    public enum FiltersView {
      /// Filters
      public static let filters = L10n.tr("Localizable", "filters_view.filters", fallback: "Filters")
    }
    public enum GalleryName {
      /// Default Title
      public static let `default` = L10n.tr("Localizable", "gallery_name.default", fallback: "Default Title")
      /// Japanese Title (if available)
      public static let japanese = L10n.tr("Localizable", "gallery_name.japanese", fallback: "Japanese Title (if available)")
    }
    public enum GalleryPageNumbering {
      /// None
      public static let `none` = L10n.tr("Localizable", "gallery_page_numbering.none", fallback: "None")
      /// Page Number + Name
      public static let pageNumberAndName = L10n.tr("Localizable", "gallery_page_numbering.page_number_and_name", fallback: "Page Number + Name")
      /// Page Number Only
      public static let pageNumberOnly = L10n.tr("Localizable", "gallery_page_numbering.page_number_only", fallback: "Page Number Only")
    }
    public enum GalleryVisibility {
      /// Expunged
      public static let expunged = L10n.tr("Localizable", "gallery_visibility.expunged", fallback: "Expunged")
      /// No (%@)
      public static func no(_ p1: Any) -> String {
        return L10n.tr("Localizable", "gallery_visibility.no", String(describing: p1), fallback: "No (%@)")
      }
      /// Yes
      public static let yes = L10n.tr("Localizable", "gallery_visibility.yes", fallback: "Yes")
    }
    public enum GeneralSettingView {
      /// Language
      public static let language = L10n.tr("Localizable", "general_setting_view.language", fallback: "Language")
    }
    public enum Greeting {
      ///  and 
      public static let and = L10n.tr("Localizable", "greeting.and", fallback: " and ")
      /// !
      public static let end = L10n.tr("Localizable", "greeting.end", fallback: "!")
      /// , 
      public static let separator = L10n.tr("Localizable", "greeting.separator", fallback: ", ")
      /// You gain 
      public static let start = L10n.tr("Localizable", "greeting.start", fallback: "You gain ")
    }
    public enum HathArchive {
      /// Free
      public static let free = L10n.tr("Localizable", "hath_archive.free", fallback: "Free")
    }
    public enum HomeView {
      /// Home
      public static let home = L10n.tr("Localizable", "home_view.home", fallback: "Home")
    }
    public enum ImageResolution {
      /// Auto
      public static let auto = L10n.tr("Localizable", "image_resolution.auto", fallback: "Auto")
    }
    public enum JumpPageView {
      /// Jump page
      public static let jumpPage = L10n.tr("Localizable", "jump_page_view.jump_page", fallback: "Jump page")
    }
    public enum Language {
      /// Afrikaans
      public static let afrikaans = L10n.tr("Localizable", "language.afrikaans", fallback: "Afrikaans")
      /// Albanian
      public static let albanian = L10n.tr("Localizable", "language.albanian", fallback: "Albanian")
      /// Arabic
      public static let arabic = L10n.tr("Localizable", "language.arabic", fallback: "Arabic")
      /// Bengali
      public static let bengali = L10n.tr("Localizable", "language.bengali", fallback: "Bengali")
      /// Bosnian
      public static let bosnian = L10n.tr("Localizable", "language.bosnian", fallback: "Bosnian")
      /// Bulgarian
      public static let bulgarian = L10n.tr("Localizable", "language.bulgarian", fallback: "Bulgarian")
      /// Burmese
      public static let burmese = L10n.tr("Localizable", "language.burmese", fallback: "Burmese")
      /// Catalan
      public static let catalan = L10n.tr("Localizable", "language.catalan", fallback: "Catalan")
      /// Cebuano
      public static let cebuano = L10n.tr("Localizable", "language.cebuano", fallback: "Cebuano")
      /// Chinese
      public static let chinese = L10n.tr("Localizable", "language.chinese", fallback: "Chinese")
      /// Croatian
      public static let croatian = L10n.tr("Localizable", "language.croatian", fallback: "Croatian")
      /// Czech
      public static let czech = L10n.tr("Localizable", "language.czech", fallback: "Czech")
      /// Danish
      public static let danish = L10n.tr("Localizable", "language.danish", fallback: "Danish")
      /// Dutch
      public static let dutch = L10n.tr("Localizable", "language.dutch", fallback: "Dutch")
      /// English
      public static let english = L10n.tr("Localizable", "language.english", fallback: "English")
      /// Esperanto
      public static let esperanto = L10n.tr("Localizable", "language.esperanto", fallback: "Esperanto")
      /// Estonian
      public static let estonian = L10n.tr("Localizable", "language.estonian", fallback: "Estonian")
      /// Finnish
      public static let finnish = L10n.tr("Localizable", "language.finnish", fallback: "Finnish")
      /// French
      public static let french = L10n.tr("Localizable", "language.french", fallback: "French")
      /// Georgian
      public static let georgian = L10n.tr("Localizable", "language.georgian", fallback: "Georgian")
      /// German
      public static let german = L10n.tr("Localizable", "language.german", fallback: "German")
      /// Greek
      public static let greek = L10n.tr("Localizable", "language.greek", fallback: "Greek")
      /// Hebrew
      public static let hebrew = L10n.tr("Localizable", "language.hebrew", fallback: "Hebrew")
      /// Hindi
      public static let hindi = L10n.tr("Localizable", "language.hindi", fallback: "Hindi")
      /// Hmong
      public static let hmong = L10n.tr("Localizable", "language.hmong", fallback: "Hmong")
      /// Hungarian
      public static let hungarian = L10n.tr("Localizable", "language.hungarian", fallback: "Hungarian")
      /// Indonesian
      public static let indonesian = L10n.tr("Localizable", "language.indonesian", fallback: "Indonesian")
      /// N/A
      public static let invalid = L10n.tr("Localizable", "language.invalid", fallback: "N/A")
      /// Italian
      public static let italian = L10n.tr("Localizable", "language.italian", fallback: "Italian")
      /// Japanese
      public static let japanese = L10n.tr("Localizable", "language.japanese", fallback: "Japanese")
      /// Kazakh
      public static let kazakh = L10n.tr("Localizable", "language.kazakh", fallback: "Kazakh")
      /// Khmer
      public static let khmer = L10n.tr("Localizable", "language.khmer", fallback: "Khmer")
      /// Korean
      public static let korean = L10n.tr("Localizable", "language.korean", fallback: "Korean")
      /// Kurdish
      public static let kurdish = L10n.tr("Localizable", "language.kurdish", fallback: "Kurdish")
      /// Lao
      public static let lao = L10n.tr("Localizable", "language.lao", fallback: "Lao")
      /// Latin
      public static let latin = L10n.tr("Localizable", "language.latin", fallback: "Latin")
      /// Mongolian
      public static let mongolian = L10n.tr("Localizable", "language.mongolian", fallback: "Mongolian")
      /// Ndebele
      public static let ndebele = L10n.tr("Localizable", "language.ndebele", fallback: "Ndebele")
      /// Nepali
      public static let nepali = L10n.tr("Localizable", "language.nepali", fallback: "Nepali")
      /// Norwegian
      public static let norwegian = L10n.tr("Localizable", "language.norwegian", fallback: "Norwegian")
      /// Oromo
      public static let oromo = L10n.tr("Localizable", "language.oromo", fallback: "Oromo")
      /// Other
      public static let other = L10n.tr("Localizable", "language.other", fallback: "Other")
      /// Pashto
      public static let pashto = L10n.tr("Localizable", "language.pashto", fallback: "Pashto")
      /// Persian
      public static let persian = L10n.tr("Localizable", "language.persian", fallback: "Persian")
      /// Polish
      public static let polish = L10n.tr("Localizable", "language.polish", fallback: "Polish")
      /// Portuguese
      public static let portuguese = L10n.tr("Localizable", "language.portuguese", fallback: "Portuguese")
      /// Punjabi
      public static let punjabi = L10n.tr("Localizable", "language.punjabi", fallback: "Punjabi")
      /// Romanian
      public static let romanian = L10n.tr("Localizable", "language.romanian", fallback: "Romanian")
      /// Russian
      public static let russian = L10n.tr("Localizable", "language.russian", fallback: "Russian")
      /// Sango
      public static let sango = L10n.tr("Localizable", "language.sango", fallback: "Sango")
      /// Serbian
      public static let serbian = L10n.tr("Localizable", "language.serbian", fallback: "Serbian")
      /// Shona
      public static let shona = L10n.tr("Localizable", "language.shona", fallback: "Shona")
      /// Slovak
      public static let slovak = L10n.tr("Localizable", "language.slovak", fallback: "Slovak")
      /// Slovenian
      public static let slovenian = L10n.tr("Localizable", "language.slovenian", fallback: "Slovenian")
      /// Somali
      public static let somali = L10n.tr("Localizable", "language.somali", fallback: "Somali")
      /// Spanish
      public static let spanish = L10n.tr("Localizable", "language.spanish", fallback: "Spanish")
      /// Swahili
      public static let swahili = L10n.tr("Localizable", "language.swahili", fallback: "Swahili")
      /// Swedish
      public static let swedish = L10n.tr("Localizable", "language.swedish", fallback: "Swedish")
      /// Tagalog
      public static let tagalog = L10n.tr("Localizable", "language.tagalog", fallback: "Tagalog")
      /// Thai
      public static let thai = L10n.tr("Localizable", "language.thai", fallback: "Thai")
      /// Tigrinya
      public static let tigrinya = L10n.tr("Localizable", "language.tigrinya", fallback: "Tigrinya")
      /// Turkish
      public static let turkish = L10n.tr("Localizable", "language.turkish", fallback: "Turkish")
      /// Ukrainian
      public static let ukrainian = L10n.tr("Localizable", "language.ukrainian", fallback: "Ukrainian")
      /// Urdu
      public static let urdu = L10n.tr("Localizable", "language.urdu", fallback: "Urdu")
      /// Vietnamese
      public static let vietnamese = L10n.tr("Localizable", "language.vietnamese", fallback: "Vietnamese")
      /// Zulu
      public static let zulu = L10n.tr("Localizable", "language.zulu", fallback: "Zulu")
    }
    public enum ListDisplayMode {
      /// Detail
      public static let detail = L10n.tr("Localizable", "list_display_mode.detail", fallback: "Detail")
      /// Thumbnail
      public static let thumbnail = L10n.tr("Localizable", "list_display_mode.thumbnail", fallback: "Thumbnail")
    }
    public enum LoadThroughHathSetting {
      /// Any client
      public static let anyClient = L10n.tr("Localizable", "load_through_hath_setting.any_client", fallback: "Any client")
      /// Recommended.
      public static let anyClientDescription = L10n.tr("Localizable", "load_through_hath_setting.any_client_description", fallback: "Recommended.")
      /// Default port clients only
      public static let defaultPortOnly = L10n.tr("Localizable", "load_through_hath_setting.default_port_only", fallback: "Default port clients only")
      /// Can be slower. Enable if behind firewall/proxy that blocks outgoing non-standard ports.
      public static let defaultPortOnlyDescription = L10n.tr("Localizable", "load_through_hath_setting.default_port_only_description", fallback: "Can be slower. Enable if behind firewall/proxy that blocks outgoing non-standard ports.")
      /// No [Legacy/HTTP]
      public static let legacyNo = L10n.tr("Localizable", "load_through_hath_setting.legacy_no", fallback: "No [Legacy/HTTP]")
      /// Donator only. May not work by default in modern browsers. Recommended for legacy/outdated browsers only.
      public static let legacyNoDescription = L10n.tr("Localizable", "load_through_hath_setting.legacy_no_description", fallback: "Donator only. May not work by default in modern browsers. Recommended for legacy/outdated browsers only.")
      /// No [Modern/HTTPS]
      public static let modernNo = L10n.tr("Localizable", "load_through_hath_setting.modern_no", fallback: "No [Modern/HTTPS]")
      /// Donator only. You will not be able to browse as many pages. Recommended only if having severe problems.
      public static let modernNoDescription = L10n.tr("Localizable", "load_through_hath_setting.modern_no_description", fallback: "Donator only. You will not be able to browse as many pages. Recommended only if having severe problems.")
    }
    public enum LoginView {
      /// Login
      public static let login = L10n.tr("Localizable", "login_view.login", fallback: "Login")
    }
    public enum MultiplePageViewerStyle {
      /// Align center, always scale
      public static let alignCenterAlwaysScale = L10n.tr("Localizable", "multiple_page_viewer_style.align_center_always_scale", fallback: "Align center, always scale")
      /// Align center, scale if overwidth
      public static let alignCenterScaleIfOverWidth = L10n.tr("Localizable", "multiple_page_viewer_style.align_center_scale_if_over_width", fallback: "Align center, scale if overwidth")
      /// Align left, scale if overwidth
      public static let alignLeftScaleIfOverWidth = L10n.tr("Localizable", "multiple_page_viewer_style.align_left_scale_if_over_width", fallback: "Align left, scale if overwidth")
    }
    public enum PreferredColorScheme {
      /// Automatic
      public static let automatic = L10n.tr("Localizable", "preferred_color_scheme.automatic", fallback: "Automatic")
      /// Dark
      public static let dark = L10n.tr("Localizable", "preferred_color_scheme.dark", fallback: "Dark")
      /// Light
      public static let light = L10n.tr("Localizable", "preferred_color_scheme.light", fallback: "Light")
    }
    public enum QuickSearchView {
      /// Quick search
      public static let quickSearch = L10n.tr("Localizable", "quick_search_view.quick_search", fallback: "Quick search")
    }
    public enum ReadingDirection {
      /// Left-to-right
      public static let leftToRight = L10n.tr("Localizable", "reading_direction.left_to_right", fallback: "Left-to-right")
      /// Right-to-left
      public static let rightToLeft = L10n.tr("Localizable", "reading_direction.right_to_left", fallback: "Right-to-left")
      /// Vertical
      public static let vertical = L10n.tr("Localizable", "reading_direction.vertical", fallback: "Vertical")
    }
    public enum ReadingView {
      /// Share
      public static let share = L10n.tr("Localizable", "reading_view.share", fallback: "Share")
    }
    public enum SearchView {
      /// Quick search
      public static let quickSearch = L10n.tr("Localizable", "search_view.quick_search", fallback: "Quick search")
      /// Search
      public static let search = L10n.tr("Localizable", "search_view.search", fallback: "Search")
    }
    public enum SettingView {
      /// Setting
      public static let setting = L10n.tr("Localizable", "setting_view.setting", fallback: "Setting")
    }
    public enum TabItem {
      /// Downloads
      public static let downloads = L10n.tr("Localizable", "tab_item.downloads", fallback: "Downloads")
      /// Favorites
      public static let favorites = L10n.tr("Localizable", "tab_item.favorites", fallback: "Favorites")
      /// Home
      public static let home = L10n.tr("Localizable", "tab_item.home", fallback: "Home")
      /// Search
      public static let search = L10n.tr("Localizable", "tab_item.search", fallback: "Search")
      /// Setting
      public static let setting = L10n.tr("Localizable", "tab_item.setting", fallback: "Setting")
    }
    public enum TagNamespace {
      /// Artist
      public static let artist = L10n.tr("Localizable", "tag_namespace.artist", fallback: "Artist")
      /// Character
      public static let character = L10n.tr("Localizable", "tag_namespace.character", fallback: "Character")
      /// Cosplayer
      public static let cosplayer = L10n.tr("Localizable", "tag_namespace.cosplayer", fallback: "Cosplayer")
      /// Female
      public static let female = L10n.tr("Localizable", "tag_namespace.female", fallback: "Female")
      /// Group
      public static let group = L10n.tr("Localizable", "tag_namespace.group", fallback: "Group")
      /// Language
      public static let language = L10n.tr("Localizable", "tag_namespace.language", fallback: "Language")
      /// Male
      public static let male = L10n.tr("Localizable", "tag_namespace.male", fallback: "Male")
      /// Mixed
      public static let mixed = L10n.tr("Localizable", "tag_namespace.mixed", fallback: "Mixed")
      /// Other
      public static let other = L10n.tr("Localizable", "tag_namespace.other", fallback: "Other")
      /// Parody
      public static let parody = L10n.tr("Localizable", "tag_namespace.parody", fallback: "Parody")
      /// Reclass
      public static let reclass = L10n.tr("Localizable", "tag_namespace.reclass", fallback: "Reclass")
      /// Temp
      public static let temp = L10n.tr("Localizable", "tag_namespace.temp", fallback: "Temp")
    }
    public enum TagsSortOrder {
      /// Alphabetical
      public static let alphabetical = L10n.tr("Localizable", "tags_sort_order.alphabetical", fallback: "Alphabetical")
      /// By tag power
      public static let tagPower = L10n.tr("Localizable", "tags_sort_order.tag_power", fallback: "By tag power")
    }
    public enum ThumbnailLoadTiming {
      /// On mouse-over
      public static let onMouseOver = L10n.tr("Localizable", "thumbnail_load_timing.on_mouse_over", fallback: "On mouse-over")
      /// Pages load faster, but there may be a slight delay before a thumb appears.
      public static let onMouseOverDescription = L10n.tr("Localizable", "thumbnail_load_timing.on_mouse_over_description", fallback: "Pages load faster, but there may be a slight delay before a thumb appears.")
      /// On page load
      public static let onPageLoad = L10n.tr("Localizable", "thumbnail_load_timing.on_page_load", fallback: "On page load")
      /// Pages take longer to load, but there is no delay for loading a thumb after the page has loaded.
      public static let onPageLoadDescription = L10n.tr("Localizable", "thumbnail_load_timing.on_page_load_description", fallback: "Pages take longer to load, but there is no delay for loading a thumb after the page has loaded.")
    }
    public enum ThumbnailSize {
      /// Auto
      public static let auto = L10n.tr("Localizable", "thumbnail_size.auto", fallback: "Auto")
      /// Large
      public static let large = L10n.tr("Localizable", "thumbnail_size.large", fallback: "Large")
      /// Normal
      public static let normal = L10n.tr("Localizable", "thumbnail_size.normal", fallback: "Normal")
      /// Small
      public static let small = L10n.tr("Localizable", "thumbnail_size.small", fallback: "Small")
    }
    public enum ToolbarItem {
      /// Seek to date
      public static let dateSeek = L10n.tr("Localizable", "toolbar_item.date_seek", fallback: "Seek to date")
      /// Filters
      public static let filters = L10n.tr("Localizable", "toolbar_item.filters", fallback: "Filters")
      /// Jump page
      public static let jumpPage = L10n.tr("Localizable", "toolbar_item.jump_page", fallback: "Jump page")
      /// Quick search
      public static let quickSearch = L10n.tr("Localizable", "toolbar_item.quick_search", fallback: "Quick search")
    }
    public enum ToplistsType {
      /// All time
      public static let allTime = L10n.tr("Localizable", "toplists_type.all_time", fallback: "All time")
      /// Past month
      public static let pastMonth = L10n.tr("Localizable", "toplists_type.past_month", fallback: "Past month")
      /// Past year
      public static let pastYear = L10n.tr("Localizable", "toplists_type.past_year", fallback: "Past year")
      /// Yesterday
      public static let yesterday = L10n.tr("Localizable", "toplists_type.yesterday", fallback: "Yesterday")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
