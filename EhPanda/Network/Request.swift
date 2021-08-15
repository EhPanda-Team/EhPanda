//
//  PopularItemsRequest.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import OpenCC
import Combine
import Foundation
import SwiftyBeaver

private func mapAppError(error: Error) -> AppError {
    if case .mpvActivated = error as? AppError {
        SwiftyBeaver.warning("MPV is activated.")
    } else {
        SwiftyBeaver.error(error)
    }

    switch error {
    case is ParseError:
        return .parseFailed
    case is URLError:
        return .networkingFailed
    default:
        return error as? AppError ?? .unknown
    }
}

// MARK: Routine
struct GreetingRequest {
    var publisher: AnyPublisher<Greeting, AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.greeting().safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseGreeting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct UserInfoRequest {
    let uid: String

    var publisher: AnyPublisher<User, AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.userInfo(uid: uid).safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseUserInfo)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavoriteNamesRequest {
    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.ehConfig().safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseFavoriteNames)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct TagTranslatorRequest {
    let language: TranslatableLanguage
    let updatedDate: Date

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = Defaults.DateFormat.github
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    var isChinese: Bool {
        [.simplifiedChinese,
         .traditionalChinese]
            .contains(language)
    }

    var publisher: AnyPublisher<TagTranslator, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: language.checkUpdateLink.safeURL())
            .tryMap { data, _ -> Date in
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let postedDateString = dict["published_at"] as? String,
                      let postedDate = dateFormatter.date(from: postedDateString)
                else { throw AppError.networkingFailed }

                guard postedDate > updatedDate
                else { throw AppError.noUpdates }
                return postedDate
            }
            .flatMap { date in
                URLSession.shared
                    .dataTaskPublisher(for: language.downloadLink.safeURL())
                    .tryMap { data, _ in
                        guard let dict = try? JSONSerialization
                                .jsonObject(with: data) as? [String: Any],
                              isChinese ? dict["version"] as? Int == 5 : true
                        else { throw AppError.parseFailed }
                        let translations = parseTranslations(dict: dict)
                        guard !translations.isEmpty else { throw AppError.parseFailed }

                        return TagTranslator(
                            language: language,
                            updatedDate: date,
                            contents: translations
                        )
                    }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    func parseTranslations(dict: [String: Any]) -> [String: String] {
        if isChinese {
            let result = parseChineseTranslations(dict: dict)
            return language != .traditionalChinese ? result
            : convertToTraditionalChinese(dict: result)
        } else {
            return dict as? [String: String] ?? [:]
        }
    }
    func parseChineseTranslations(dict: [String: Any]) -> [String: String] {
        let categories = dict["data"] as? [[String: Any]] ?? []
        let translationsBeforeMapping = categories.compactMap {
            $0["data"] as? [String: Any]
        }.reduce([], +)

        var translations = [String: String]()
        translationsBeforeMapping.forEach { translation in
            let originalText = translation.key
            let dict = translation.value as? [String: Any]

            if let translatedText = dict?["name"] as? String {
                translations[originalText] = translatedText
            }
        }
        return translations
    }
    func convertToTraditionalChinese(dict: [String: String]) -> [String: String] {
        guard let preferredLanguage = Locale.preferredLanguages.first else { return [:] }

        var translations = [String: String]()

        var options: ChineseConverter.Options = [.traditionalize]
        if preferredLanguage.contains("HK") {
            options = [.traditionalize, .hkStandard]
        } else if preferredLanguage.contains("TW") {
            options = [.traditionalize, .twStandard, .twIdiom]
        }

        guard let converter = try? ChineseConverter(options: options)
        else { return [:] }

        dict.forEach { key, value in
            translations[key] = converter.convert(value)
        }
        customConversion(dict: &translations)

        return translations
    }
    func customConversion(dict: inout [String: String]) {
        if dict["full color"] != nil {
            dict["full color"] = "全彩"
        }
    }
}

// MARK: Fetch ListItems
struct SearchItemsRequest {
    let keyword: String
    let filter: Filter

    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.searchList(
                    keyword: keyword,
                    filter: filter
                )
                .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreSearchItemsRequest {
    let keyword: String
    let filter: Filter
    let lastID: String
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreSearchList(
                        keyword: keyword,
                        filter: filter,
                        pageNum: "\(pageNum)",
                        lastID: lastID
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FrontpageItemsRequest {
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.frontpageList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreFrontpageItemsRequest {
    let lastID: String
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreFrontpageList(
                        pageNum: "\(pageNum)",
                        lastID: lastID
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct PopularItemsRequest {
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.popularList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct WatchedItemsRequest {
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.watchedList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreWatchedItemsRequest {
    let lastID: String
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreWatchedList(
                        pageNum: "\(pageNum)",
                        lastID: lastID
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavoritesItemsRequest {
    let favIndex: Int

    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .favoritesList(
                        favIndex: favIndex
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreFavoritesItemsRequest {
    let favIndex: Int
    let lastID: String
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreFavoritesList(
                        favIndex: favIndex,
                        pageNum: "\(pageNum)",
                        lastID: lastID
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaDetailRequest {
    let gid: String
    let galleryURL: String

    var publisher: AnyPublisher<(MangaDetail, MangaState, APIKey), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .mangaDetail(
                        url: galleryURL
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap {
                let detail = try Parser.parseMangaDetail(doc: $0, gid: gid)
                return (detail.0, detail.1, try Parser.parseAPIKey(doc: $0))
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaItemReverseRequest {
    let galleryURL: String
    var gid: String {
        if galleryURL.safeURL().pathComponents.count >= 4 {
            return galleryURL.safeURL().pathComponents[2]
        } else {
            return ""
        }
    }
    var token: String {
        if galleryURL.safeURL().pathComponents.count >= 4 {
            return galleryURL.safeURL().pathComponents[3]
        } else {
            return ""
        }
    }
    func getManga(from detail: MangaDetail?) -> Manga? {
        if let detail = detail {
            return Manga(
                gid: gid,
                token: token,
                title: detail.title,
                rating: detail.rating,
                tags: [],
                category: detail.category,
                language: detail.language,
                uploader: detail.uploader,
                postedDate: detail.postedDate,
                coverURL: detail.coverURL,
                galleryURL: galleryURL
            )
        } else {
            return nil
        }
    }

    var publisher: AnyPublisher<Manga?, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: galleryURL.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap { getManga(from: try? Parser.parseMangaDetail(doc: $0, gid: gid).0) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

}

struct MangaArchiveRequest {
    let archiveURL: String

    var publisher: AnyPublisher<(MangaArchive?, CurrentGP?, CurrentCredits?), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: archiveURL.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map {
                let funds = try? Parser.parseCurrentFunds(doc: $0)
                let archive = try? Parser.parseMangaArchive(doc: $0)

                if funds == nil {
                    return (archive, nil, nil)
                } else {
                    return (archive, funds?.0, funds?.1)
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaArchiveFundsRequest {
    let gid: String
    let galleryURL: String

    var alterGalleryURL: String {
        galleryURL.replacingOccurrences(
            of: Defaults.URL.exhentai,
            with: Defaults.URL.ehentai
        )
    }

    var publisher: AnyPublisher<(CurrentGP, CurrentCredits)?, AppError> {
        archiveURL(url: alterGalleryURL)
            .flatMap(funds)
            .eraseToAnyPublisher()
    }

    func archiveURL(url: String) -> AnyPublisher<String, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap { try? Parser
            .parseMangaDetail(doc: $0, gid: gid).0
                .archiveURL
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    func funds(url: String) -> AnyPublisher<(CurrentGP, CurrentCredits)?, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseCurrentFunds)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaTorrentsRequest {
    let gid: String
    let token: String

    var publisher: AnyPublisher<[MangaTorrent], AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .mangaTorrents(
                        gid: gid,
                        token: token
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(Parser.parseMangaTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaPreviewsRequest {
    let url: String

    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: url.safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parsePreviews)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaContentsRequest {
    let url: String

    var publisher: AnyPublisher<[Int: String], AppError> {
        preContents(url: url)
            .flatMap(contents)
            .eraseToAnyPublisher()
    }

    func preContents(url: String) -> AnyPublisher<[(Int, URL)], AppError> {
        URLSession.shared
            .dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseMangaPreContents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    func contents(preContents: [(Int, URL)])
    -> AnyPublisher<[Int: String], AppError> {
        preContents
            .publisher
            .flatMap { index, url in
                URLSession.shared
                    .dataTaskPublisher(for: url)
                    .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                    .tryMap { try Parser.parseMangaContent(doc: $0, index: index) }
            }
            .collect()
            .map { tuples in
                var contents = [Int: String]()
                for (index, imageURL) in tuples {
                    contents[index] = imageURL
                }
                return contents
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaMPVContentRequest {
    let gid: Int
    let index: Int
    let mpvKey: String
    let imgKey: String

    var publisher: AnyPublisher<String, AppError> {
        let url = Defaults.URL.ehAPI()
        let params: [String: Any] = [
            "method": "imagedispatch",
            "gid": gid,
            "page": index,
            "imgkey": imgKey,
            "mpvkey": mpvKey
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map(\.data).tryMap { data in
                guard let dict = try JSONSerialization
                        .jsonObject(with: data) as? [String: Any],
                      let imageURL = dict["i"] as? String
                else { throw AppError.parseFailed }
                return imageURL
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

// MARK: Account Ops
struct LoginRequest {
    let username: String
    let password: String

    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.login
        let params: [String: String] = [
            "b": "d",
            "bt": "1-1",
            "CookieDate": "1",
            "UserName": username,
            "PassWord": password,
            "ipb_login_submit": "Login!"
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct VerifyProfileRequest {
    var publisher: AnyPublisher<(Int?, Bool), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.ehConfig().safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseProfileIndex)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct CreateProfileRequest {
    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.ehConfig()
        let params: [String: String] = [
            "profile_action": "create",
            "profile_name": "EhPanda"
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EhProfileRequest {
    var publisher: AnyPublisher<EhProfile, AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.ehConfig().safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhProfile)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct SubmitEhProfileChangesRequest {
    let profile: EhProfile

    var publisher: AnyPublisher<EhProfile, AppError> {
        let url = Defaults.URL.ehConfig()
        var params: [String: String] = [
            "uh": String(profile.loadThroughHathSetting.rawValue),
            "xr": String(profile.imageResolution.rawValue),
            "rx": String(Int(profile.imageSizeWidth)),
            "ry": String(Int(profile.imageSizeHeight)),
            "tl": String(profile.galleryName.rawValue),
            "ar": String(profile.archiverBehavior.rawValue),
            "dm": String(profile.displayMode.rawValue),
            "ct_doujinshi": profile.doujinshiDisabled ? "1" : "0",
            "ct_manga": profile.mangaDisabled ? "1" : "0",
            "ct_artistcg": profile.artistCGDisabled ? "1" : "0",
            "ct_gamecg": profile.gameCGDisabled ? "1" : "0",
            "ct_western": profile.westernDisabled ? "1" : "0",
            "ct_non-h": profile.nonHDisabled ? "1" : "0",
            "ct_imageset": profile.imageSetDisabled ? "1" : "0",
            "ct_cosplay": profile.cosplayDisabled ? "1" : "0",
            "ct_asianporn": profile.asianPornDisabled ? "1" : "0",
            "ct_misc": profile.miscDisabled ? "1" : "0",
            "favorite_0": profile.favoriteName0,
            "favorite_1": profile.favoriteName1,
            "favorite_2": profile.favoriteName2,
            "favorite_3": profile.favoriteName3,
            "favorite_4": profile.favoriteName4,
            "favorite_5": profile.favoriteName5,
            "favorite_6": profile.favoriteName6,
            "favorite_7": profile.favoriteName7,
            "favorite_8": profile.favoriteName8,
            "favorite_9": profile.favoriteName9,
            "fs": String(profile.favoritesSortOrder.rawValue),
            "ru": profile.ratingsColor,
            "xn_1": profile.reclassExcluded ? "1" : "0",
            "xn_2": profile.languageExcluded ? "1" : "0",
            "xn_3": profile.parodyExcluded ? "1" : "0",
            "xn_4": profile.characterExcluded ? "1" : "0",
            "xn_5": profile.groupExcluded ? "1" : "0",
            "xn_6": profile.artistExcluded ? "1" : "0",
            "xn_7": profile.maleExcluded ? "1" : "0",
            "xn_8": profile.femaleExcluded ? "1" : "0",
            "ft": String(Int(profile.tagFilteringThreshold)),
            "wt": String(Int(profile.tagWatchingThreshold)),
            "xu": profile.excludedUploaders,
            "rc": String(profile.searchResultCount.rawValue),
            "lt": String(profile.thumbnailLoadTiming.rawValue),
            "ts": String(profile.thumbnailConfigSize.rawValue),
            "tr": String(profile.thumbnailConfigRows.rawValue),
            "tp": String(Int(profile.thumbnailScaleFactor)),
            "vp": String(Int(profile.viewportVirtualWidth)),
            "cs": String(profile.commentsSortOrder.rawValue),
            "sc": String(profile.commentVotesShowTiming.rawValue),
            "tb": String(profile.tagsSortOrder.rawValue),
            "pn": profile.galleryShowPageNumbers ? "1" : "0",
            "hh": profile.hathLocalNetworkHost,
            "apply": "Apply"
        ]

        if let useOriginalImages = profile.useOriginalImages {
            params["oi"] = useOriginalImages ? "1" : "0"
        }
        if let useMultiplePageViewer = profile.useMultiplePageViewer {
            params["qb"] = useMultiplePageViewer ? "1" : "0"
        }
        if let multiplePageViewerStyle = profile.multiplePageViewerStyle {
            params["ms"] = String(multiplePageViewerStyle.rawValue)
        }
        if let multiplePageViewerShowThumbnailPane = profile.multiplePageViewerShowThumbnailPane {
            params["mt"] = multiplePageViewerShowThumbnailPane ? "0" : "1"
        }

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhProfile)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct AddFavoriteRequest {
    let gid: String
    let token: String
    let favIndex: Int

    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.addFavorite(gid: gid, token: token)
        let params: [String: String] = [
            "favcat": "\(favIndex)",
            "favnote": "",
            "apply": "Add to Favorites",
            "update": "1"
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct DeleteFavoriteRequest {
    let gid: String

    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.ehFavorites()
        let params: [String: String] = [
            "ddact": "delete",
            "modifygids[]": gid,
            "apply": "Apply"
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct SendDownloadCommandRequest {
    let archiveURL: String
    let resolution: String

    var publisher: AnyPublisher<String?, AppError> {
        let params: [String: String] = [
            "hathdl_xres": resolution
        ]

        var request = URLRequest(url: archiveURL.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseDownloadCommandResponse)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct RateRequest {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let rating: Int

    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.ehAPI()
        let params: [String: Any] = [
            "method": "rategallery",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "rating": rating
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct CommentRequest {
    let content: String
    let galleryURL: String

    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let params: [String: String] = ["commenttext_new": fixedContent]

        var request = URLRequest(url: galleryURL.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EditCommentRequest {
    let commentID: String
    let content: String
    let galleryURL: String

    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let params: [String: String] = [
            "edit_comment": commentID,
            "commenttext_edit": fixedContent
        ]

        var request = URLRequest(url: galleryURL.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct VoteCommentRequest {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let commentID: Int
    let commentVote: Int

    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.ehAPI()
        let params: [String: Any] = [
            "method": "votecomment",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "comment_id": commentID,
            "comment_vote": commentVote
        ]

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
