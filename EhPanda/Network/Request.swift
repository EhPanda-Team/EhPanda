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

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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
    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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
    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.popularList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct WatchedItemsRequest {
    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.favoritesList(favIndex: favIndex).safeURL()
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

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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

struct ToplistsItemsRequest {
    let catIndex: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.toplistsList(catIndex: catIndex).safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreToplistsItemsRequest {
    let catIndex: Int
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreToplistsList(
                        catIndex: catIndex,
                        pageNum: "\(pageNum)"
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { (Parser.parsePageNum(doc: $0), Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryDetailRequest {
    let gid: String
    let galleryURL: String

    var publisher: AnyPublisher<(GalleryDetail, GalleryState, APIKey), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .galleryDetail(
                        url: galleryURL
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap {
                let detail = try Parser.parseGalleryDetail(doc: $0, gid: gid)
                return (detail.0, detail.1, try Parser.parseAPIKey(doc: $0))
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryItemReverseRequest {
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
    func getGallery(from detail: GalleryDetail?) -> Gallery? {
        if let detail = detail {
            return Gallery(
                gid: gid,
                token: token,
                title: detail.title,
                rating: detail.rating,
                tags: [],
                category: detail.category,
                language: detail.language,
                uploader: detail.uploader,
                pageCount: detail.pageCount,
                postedDate: detail.postedDate,
                coverURL: detail.coverURL,
                galleryURL: galleryURL
            )
        } else {
            return nil
        }
    }

    var publisher: AnyPublisher<Gallery?, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: galleryURL.safeURL()).retry(3)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap { getGallery(from: try? Parser.parseGalleryDetail(doc: $0, gid: gid).0) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

}

struct GalleryArchiveRequest {
    let archiveURL: String

    var publisher: AnyPublisher<(GalleryArchive?, CurrentGP?, CurrentCredits?), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: archiveURL.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map {
                let funds = try? Parser.parseCurrentFunds(doc: $0)
                let archive = try? Parser.parseGalleryArchive(doc: $0)

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

struct GalleryArchiveFundsRequest {
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
            .parseGalleryDetail(doc: $0, gid: gid).0
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

struct GalleryTorrentsRequest {
    let gid: String
    let token: String

    var publisher: AnyPublisher<[GalleryTorrent], AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .galleryTorrents(
                        gid: gid,
                        token: token
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(Parser.parseGalleryTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryPreviewsRequest {
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

struct GalleryContentsRequest {
    let url: String

    var publisher: AnyPublisher<[Int: String], AppError> {
        preContents(url: url)
            .flatMap(contents)
            .retry(3).eraseToAnyPublisher()
    }

    func preContents(url: String) -> AnyPublisher<[(Int, URL)], AppError> {
        URLSession.shared
            .dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseGalleryPreContents)
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
                    .tryMap { try Parser.parseGalleryContent(doc: $0, index: index) }
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

struct GalleryMPVContentRequest {
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

struct IgneousRequest {
    var publisher: AnyPublisher<Any, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.exhentai.safeURL())
            .map { value in
                if let (_, resp) = value as? (Data, HTTPURLResponse) {
                    setCookie(response: resp)
                }
                return value
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct VerifyEhProfileRequest {
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

struct EhProfileRequest {
    var action: EhProfileAction?
    var name: String?
    var set: Int?

    var publisher: AnyPublisher<EhSetting, AppError> {
        let url = Defaults.URL.ehConfig()
        var params = [String: String]()

        if let action = action {
            params["profile_action"] = action.rawValue
        }
        if let name = name {
            params["profile_name"] = name
        }
        if let set = set {
            params["profile_set"] = "\(set)"
        }

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EhSettingRequest {
    var publisher: AnyPublisher<EhSetting, AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.ehConfig().safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct SubmitEhSettingChangesRequest {
    let ehSetting: EhSetting

    var publisher: AnyPublisher<EhSetting, AppError> {
        let url = Defaults.URL.ehConfig()
        var params: [String: String] = [
            "uh": String(ehSetting.loadThroughHathSetting.rawValue),
            "co": ehSetting.browsingCountry.rawValue,
            "xr": String(ehSetting.imageResolution.rawValue),
            "rx": String(Int(ehSetting.imageSizeWidth)),
            "ry": String(Int(ehSetting.imageSizeHeight)),
            "tl": String(ehSetting.galleryName.rawValue),
            "ar": String(ehSetting.archiverBehavior.rawValue),
            "dm": String(ehSetting.displayMode.rawValue),
            "fs": String(ehSetting.favoritesSortOrder.rawValue),
            "ru": ehSetting.ratingsColor,
            "ft": String(Int(ehSetting.tagFilteringThreshold)),
            "wt": String(Int(ehSetting.tagWatchingThreshold)),
            "xu": ehSetting.excludedUploaders,
            "rc": String(ehSetting.searchResultCount.rawValue),
            "lt": String(ehSetting.thumbnailLoadTiming.rawValue),
            "ts": String(ehSetting.thumbnailConfigSize.rawValue),
            "tr": String(ehSetting.thumbnailConfigRows.rawValue),
            "tp": String(Int(ehSetting.thumbnailScaleFactor)),
            "vp": String(Int(ehSetting.viewportVirtualWidth)),
            "cs": String(ehSetting.commentsSortOrder.rawValue),
            "sc": String(ehSetting.commentVotesShowTiming.rawValue),
            "tb": String(ehSetting.tagsSortOrder.rawValue),
            "pn": ehSetting.galleryShowPageNumbers ? "1" : "0",
            "hh": ehSetting.hathLocalNetworkHost,
            "apply": "Apply"
        ]

        EhSetting.categoryNames.enumerated().forEach { index, name in
            params["ct_\(name)"] = ehSetting.disabledCategories[index] ? "1" : "0"
        }
        Array(0...9).forEach { index in
            params["favorite_\(index)"] = ehSetting.favoriteNames[index]
        }
        Array(0...7).forEach { index in
            params["xn_\(index)"] = ehSetting.excludedNamespaces[index] ? "1" : "0"
        }
        ehSetting.excludedLanguages.enumerated().forEach { index, value in
            guard value else { return }
            params["xl_\(EhSetting.languageValues[index])"] = "on"
        }

        if let useOriginalImages = ehSetting.useOriginalImages {
            params["oi"] = useOriginalImages ? "1" : "0"
        }
        if let useMultiplePageViewer = ehSetting.useMultiplePageViewer {
            params["qb"] = useMultiplePageViewer ? "1" : "0"
        }
        if let multiplePageViewerStyle = ehSetting.multiplePageViewerStyle {
            params["ms"] = String(multiplePageViewerStyle.rawValue)
        }
        if let multiplePageViewerShowThumbnailPane = ehSetting.multiplePageViewerShowThumbnailPane {
            params["mt"] = multiplePageViewerShowThumbnailPane ? "0" : "1"
        }

        var request = URLRequest(url: url.safeURL())

        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting)
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
