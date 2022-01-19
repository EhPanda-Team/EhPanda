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
import ComposableArchitecture

protocol Request {
    associatedtype Response

    var publisher: AnyPublisher<Response, AppError> { get }
}
extension Request {
    var effect: Effect<Result<Response, AppError>, Never> {
        publisher.receive(on: DispatchQueue.main).catchToEffect()
    }
//    func cancellableEffect(
//        storeIn cancellableSet: inout Set<AnyCancellable>
//    ) -> Effect<Result<Response, AppError>, Never> {
//        Future { promise in
//            publisher.receive(on: DispatchQueue.main)
//                .sink { completion in
//                    if case .failure(let error) = completion {
//                        promise(.failure(error))
//                    }
//                } receiveValue: { response in
//                    promise(.success(response))
//                }
//                .store(in: &cancellableSet)
//        }
//        .eraseToAnyPublisher()
//        .catchToEffect()
//    }
    func mapAppError(error: Error) -> AppError {
        Logger.error(error)

        switch error {
        case is ParseError:
            return .parseFailed
        case is URLError:
            return .networkingFailed
        default:
            return error as? AppError ?? .unknown
        }
    }
}

private extension Publisher {
    func genericRetry() -> Publishers.Retry<Self> {
        retry(3)
    }
}
private extension URLRequest {
    mutating func setURLEncodedContentType() {
        setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
    }
}
private extension Dictionary where Key == String, Value == String {
    func dictString() -> String {
        var array = [String]()
        keys.forEach { key in
            array.append(key + "=" + self[key].forceUnwrapped)
        }
        return array.joined(separator: "&")
    }
}

// MARK: Routine
struct GreetingRequest: Request {
    var publisher: AnyPublisher<Greeting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.news)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseGreeting).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct UserInfoRequest: Request {
    let uid: String

    var publisher: AnyPublisher<User, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.userInfo(uid: uid))
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseUserInfo).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct FavoriteNamesRequest: Request {
    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseFavoriteNames).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct TagTranslatorRequest: Request {
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
        [.simplifiedChinese, .traditionalChinese].contains(language)
    }

    var publisher: AnyPublisher<TagTranslator, AppError> {
        URLSession.shared.dataTaskPublisher(for: language.checkUpdateURL)
            .genericRetry().tryMap { data, _ -> Date in
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let postedDateString = dict["published_at"] as? String,
                      let postedDate = dateFormatter.date(from: postedDateString)
                else { throw AppError.parseFailed }

                guard postedDate > updatedDate
                else { throw AppError.noUpdates }
                return postedDate
            }
            .flatMap { date in
                URLSession.shared.dataTaskPublisher(for: language.downloadURL)
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
            .mapError(mapAppError).eraseToAnyPublisher()
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
struct SearchGalleriesRequest: Request {
    let keyword: String
    let filter: Filter
    var pageNum: Int?

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.searchList(keyword: keyword, filter: filter, pageNum: pageNum)
        )
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct MoreSearchGalleriesRequest: Request {
    let keyword: String
    let filter: Filter
    let lastID: String
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreSearchList(
            keyword: keyword, filter: filter, pageNum: pageNum, lastID: lastID
        ))
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct FrontpageGalleriesRequest: Request {
    let filter: Filter
    var pageNum: Int?

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.frontpageList(filter: filter, pageNum: pageNum))
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct MoreFrontpageGalleriesRequest: Request {
    let filter: Filter
    let lastID: String
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreFrontpageList(
            filter: filter, pageNum: pageNum, lastID: lastID
        ))
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct PopularGalleriesRequest: Request {
    let filter: Filter

    var publisher: AnyPublisher<[Gallery], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.popularList(filter: filter))
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseListItems).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct WatchedGalleriesRequest: Request {
    let filter: Filter
    var pageNum: Int?
    var keyword: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.watchedList(
            filter: filter, pageNum: pageNum, keyword: keyword
        ))
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct MoreWatchedGalleriesRequest: Request {
    let filter: Filter
    let lastID: String
    let pageNum: Int
    var keyword: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreWatchedList(
            filter: filter, pageNum: pageNum, lastID: lastID, keyword: keyword
        ))
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct FavoritesGalleriesRequest: Request {
    let favIndex: Int
    var pageNum: Int?
    var keyword: String
    var sortOrder: FavoritesSortOrder?

    var publisher: AnyPublisher<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.favoritesList(favIndex: favIndex, pageNum: pageNum, keyword: keyword, sortOrder: sortOrder)
        )
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (
            Parser.parsePageNum(doc: $0),
            Parser.parseFavoritesSortOrder(doc: $0),
            try Parser.parseListItems(doc: $0)
        ) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct MoreFavoritesGalleriesRequest: Request {
    let favIndex: Int
    let lastID: String
    let pageNum: Int
    var keyword: String

    var publisher: AnyPublisher<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreFavoritesList(
            favIndex: favIndex, pageNum: pageNum, lastID: lastID, keyword: keyword
        ))
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (
            Parser.parsePageNum(doc: $0),
            Parser.parseFavoritesSortOrder(doc: $0),
            try Parser.parseListItems(doc: $0)
        ) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct ToplistsGalleriesRequest: Request {
    let catIndex: Int
    var pageNum: Int?

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.toplistsList(catIndex: catIndex, pageNum: pageNum)
        )
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct MoreToplistsGalleriesRequest: Request {
    let catIndex: Int
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreToplistsList(
            catIndex: catIndex, pageNum: pageNum
        ))
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseListItems(doc: $0)) }
        .mapError(mapAppError).eraseToAnyPublisher()
    }
}

// MARK: Fetch others
struct GalleryDetailRequest: Request {
    let gid: String
    let galleryURL: String

    var publisher: AnyPublisher<(GalleryDetail, GalleryState, APIKey, Greeting?), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.galleryDetail(url: galleryURL))
            .genericRetry().compactMap { resp -> HTMLDocument? in
                var htmlDocument: HTMLDocument?
                do {
                    htmlDocument = try Kanna.HTML(html: resp.data, encoding: .utf8)
                } catch {
                    guard let parseError = error as? ParseError, parseError == .EncodingMismatch
                    else { return htmlDocument }

                    htmlDocument = try? Kanna.HTML(html: resp.data.utf8InvalidCharactersRipped, encoding: .utf8)
                }
                return htmlDocument
            }
            .tryMap {
                let (detail, state) = try Parser.parseGalleryDetail(doc: $0, gid: gid)
                return ($0, detail, state, try Parser.parseAPIKey(doc: $0))
            }
            .map { doc, detail, state, apiKey in
                (detail, state, apiKey, try? Parser.parseGreeting(doc: doc))
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryReverseRequest: Request {
    let url: URL
    let isGalleryImageURL: Bool

    func getGallery(from detail: GalleryDetail?, and url: URL) -> Gallery? {
        if let detail = detail {
            return Gallery(
                gid: url.pathComponents[2], token: url.pathComponents[3],
                title: detail.title, rating: detail.rating, tagStrings: [],
                category: detail.category, language: detail.language,
                uploader: detail.uploader, pageCount: detail.pageCount,
                postedDate: detail.postedDate, coverURL: detail.coverURL,
                galleryURL: url.absoluteString
            )
        } else {
            return nil
        }
    }

    var publisher: AnyPublisher<Gallery, AppError> {
        galleryURL(url: url).genericRetry().flatMap(gallery).eraseToAnyPublisher()
    }

    func galleryURL(url: URL) -> AnyPublisher<URL, AppError> {
        switch isGalleryImageURL {
        case true:
            return URLSession.shared.dataTaskPublisher(for: url)
                .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                .tryMap(Parser.parseGalleryURL).mapError(mapAppError)
                .eraseToAnyPublisher()
        case false:
            return Just(url).setFailureType(to: AppError.self).eraseToAnyPublisher()
        }
    }

    func gallery(url: URL) -> AnyPublisher<Gallery, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap {
                guard let (detail, _) = try? Parser.parseGalleryDetail(
                        doc: $0, gid: url.pathComponents[2]
                      )
                else { return nil }

                return getGallery(from: detail, and: url)
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryArchiveRequest: Request {
    let archiveURL: String

    var publisher: AnyPublisher<(GalleryArchive, GalleryPoints?, Credits?), AppError> {
        URLSession.shared.dataTaskPublisher(for: archiveURL.safeURL()).genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (html: HTMLDocument) -> (HTMLDocument, GalleryArchive) in
                let archive = try Parser.parseGalleryArchive(doc: html)
                return (html, archive)
            }
            .map { html, archive in
                guard let (currentGP, currentCredits) =
                        try? Parser.parseCurrentFunds(doc: html)
                else { return (archive, nil, nil) }
                return (archive, currentGP, currentCredits)
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryArchiveFundsRequest: Request {
    let gid: String
    let galleryURL: String

    var alterGalleryURL: String {
        galleryURL.replacingOccurrences(
            of: Defaults.URL.exhentai.absoluteString,
            with: Defaults.URL.ehentai.absoluteString
        )
    }

    var publisher: AnyPublisher<(GalleryPoints, Credits), AppError> {
        archiveURL(url: alterGalleryURL).genericRetry()
            .flatMap(funds).eraseToAnyPublisher()
    }

    func archiveURL(url: String) -> AnyPublisher<String, AppError> {
        URLSession.shared.dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap { try? Parser.parseGalleryDetail(doc: $0, gid: gid).0.archiveURL }
            .mapError(mapAppError).eraseToAnyPublisher()
    }

    func funds(url: String) -> AnyPublisher<(GalleryPoints, Credits), AppError> {
        URLSession.shared.dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseCurrentFunds).mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryTorrentsRequest: Request {
    let gid: String
    let token: String

    var publisher: AnyPublisher<[GalleryTorrent], AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.galleryTorrents(gid: gid, token: token)
        )
        .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .map(Parser.parseGalleryTorrents).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryPreviewsRequest: Request {
    let url: URL

    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parsePreviews).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct MPVKeysRequest: Request {
    let mpvURL: String

    var publisher: AnyPublisher<(String, [Int: String]), AppError> {
        URLSession.shared.dataTaskPublisher(for: mpvURL.safeURL())
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseMPVKeys).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct ThumbnailsRequest: Request {
    let url: String

    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared.dataTaskPublisher(for: url.safeURL())
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseThumbnails).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryNormalContentsRequest: Request {
    let thumbnails: [Int: String]

    var publisher: AnyPublisher<([Int: String], [Int: String]), AppError> {
        thumbnails.publisher
            .flatMap { index, url in
                URLSession.shared.dataTaskPublisher(for: url.safeURL()).genericRetry()
                    .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                    .tryMap { try Parser.parseGalleryNormalContent(doc: $0, index: index) }
            }
            .collect().map { tuples in
                var contents = [Int: String]()
                var originalContents = [Int: String]()
                for (index, imageURL, originalImageURL) in tuples {
                    contents[index] = imageURL
                    originalContents[index] = originalImageURL
                }
                return (contents, originalContents)
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryNormalContentRefetchRequest: Request {
    let index: Int
    let galleryURL: String
    let thumbnailURL: String?
    let storedImageURL: String
    let bypassesSNIFiltering: Bool

    var publisher: AnyPublisher<[Int: String], AppError> {
        storedThumbnail().flatMap(renewThumbnail).flatMap(content)
            .genericRetry().map({ imageURL1, imageURL2 in
                imageURL1 != storedImageURL ? imageURL1 : imageURL2
            }).map({ imageURL in [index: imageURL] })
            .eraseToAnyPublisher()
    }

    func storedThumbnail() -> AnyPublisher<URL, AppError> {
        if let thumbnailURL = thumbnailURL {
            return Just(thumbnailURL).compactMap(URL.init).setFailureType(to: AppError.self).eraseToAnyPublisher()
        } else {
            return URLSession.shared.dataTaskPublisher(for: galleryURL.safeURL())
                .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }.tryMap(Parser.parseThumbnails)
                .compactMap({ thumbnails in URL(string: thumbnails[index] ?? "") })
                .mapError(mapAppError).eraseToAnyPublisher()
        }
    }

    func renewThumbnail(stored: URL) -> AnyPublisher<(URL, String), AppError> {
        URLSession.shared.dataTaskPublisher(for: stored)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap {
                try (Parser.parseRenewedThumbnail(doc: $0, stored: stored),
                     Parser.parseGalleryNormalContent(doc: $0, index: index).1)
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }

    func content(thumbnailURL: URL, anotherImageURL: String) -> AnyPublisher<(String, String), AppError> {
        URLSession.shared.dataTaskPublisher(for: thumbnailURL)
            .tryMap {
                if bypassesSNIFiltering, let (_, resp) = $0 as? (Data, HTTPURLResponse),
                    let setString = resp.allHeaderFields["Set-Cookie"] as? String
                {
                    setString.components(separatedBy: ", ")
                        .flatMap { $0.components(separatedBy: "; ") }
                        .forEach { value in
                            let key = Defaults.Cookie.skipServer
                            if let range = value.range(of: "\(key)=") {
                                CookiesUtil.set(
                                    for: Defaults.URL.host, key: key,
                                    value: String(value[range.upperBound...]), path: "/s/",
                                    expiresTime: TimeInterval(60 * 60 * 24 * 30)
                                )
                            }
                        }
                }
                return try Kanna.HTML(html: $0.data, encoding: .utf8)
            }
            .tryMap { try Parser.parseGalleryNormalContent(doc: $0, index: index) }
            .map(\.1).map({ (anotherImageURL, $0) }).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct GalleryMPVContentRequest: Request {
    let gid: Int
    let index: Int
    let mpvKey: String
    let imgKey: String
    let reloadToken: ReloadToken?

    var publisher: AnyPublisher<(String, String?, ReloadToken), AppError> {
        var params: [String: Any] = [
            "method": "imagedispatch", "gid": gid,
            "page": index, "imgkey": imgKey, "mpvkey": mpvKey
        ]
        if let reloadToken = reloadToken {
            if let reloadToken = reloadToken as? Int {
                params["nl"] = reloadToken
            } else if let reloadToken = reloadToken as? String {
                params["nl"] = reloadToken
            }
        }

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map(\.data).tryMap { data in
                guard let dict = try JSONSerialization
                        .jsonObject(with: data) as? [String: Any],
                      let imageURL = dict["i"] as? String,
                      let reloadToken = dict["s"]
                else { throw AppError.parseFailed }

                if let originalImageURL = dict["lf"] as? String {
                    return (imageURL, Defaults.URL.host.appendingPathComponent(
                        originalImageURL).absoluteString, reloadToken)
                } else {
                    return (imageURL, nil, reloadToken)
                }
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

// MARK: Tool
struct DataRequest: Request {
    let url: URL

    var publisher: AnyPublisher<Data, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .genericRetry().map(\.data).mapError(mapAppError).eraseToAnyPublisher()
    }
}

// MARK: Account Ops
struct LoginRequest: Request {
    let username: String
    let password: String

    var publisher: AnyPublisher<Any, AppError> {
        let params: [String: String] = [
            "b": "d", "bt": "1-1", "CookieDate": "1",
            "UserName": username, "PassWord": password,
            "ipb_login_submit": "Login!"
        ]

        var request = URLRequest(url: Defaults.URL.login)
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request).genericRetry()
            .map { value in
                if let (_, resp) = value as? (Data, HTTPURLResponse) {
                    CookiesUtil.setIgneous(for: resp)
                }
                return value
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct IgneousRequest: Request {
    var publisher: AnyPublisher<Any, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.exhentai)
            .genericRetry().map { value in
                if let (_, resp) = value as? (Data, HTTPURLResponse) {
                    CookiesUtil.setIgneous(for: resp)
                }
                return value
            }
            .mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct VerifyEhProfileRequest: Request {
    var publisher: AnyPublisher<(Int?, Bool), AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseProfileIndex).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct EhProfileRequest: Request {
    var action: EhProfileAction?
    var name: String?
    var set: Int?

    var publisher: AnyPublisher<EhSetting, AppError> {
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

        var request = URLRequest(url: Defaults.URL.uConfig)
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct EhSettingRequest: Request {
    var publisher: AnyPublisher<EhSetting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct SubmitEhSettingChangesRequest: Request {
    let ehSetting: EhSetting

    var publisher: AnyPublisher<EhSetting, AppError> {
        let url = Defaults.URL.uConfig
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
        Array(0...10).forEach { index in
            params["xn_\(index + 1)"] = ehSetting.excludedNamespaces[index] ? "1" : "0"
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct FavorGalleryRequest: Request {
    let gid: String
    let token: String
    let favIndex: Int

    var publisher: AnyPublisher<Any, AppError> {
        let url = URLUtil.addFavorite(gid: gid, token: token)
        let params: [String: String] = [
            "favcat": "\(favIndex)", "favnote": "",
            "apply": "Add to Favorites", "update": "1"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct UnfavorGalleryRequest: Request {
    let gid: String

    var publisher: AnyPublisher<Any, AppError> {
        let params: [String: String] = [
            "ddact": "delete", "modifygids[]": gid, "apply": "Apply"
        ]

        var request = URLRequest(url: Defaults.URL.favorites)
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct SendDownloadCommandRequest: Request {
    let archiveURL: String
    let resolution: String

    var publisher: AnyPublisher<String, AppError> {
        let params: [String: String] = [
            "hathdl_xres": resolution
        ]

        var request = URLRequest(url: archiveURL.safeURL())
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseDownloadCommandResponse).mapError(mapAppError).eraseToAnyPublisher()
    }
}

struct RateGalleryRequest: Request {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let rating: Int

    var publisher: AnyPublisher<Any, AppError> {
        let params: [String: Any] = [
            "method": "rategallery", "apiuid": apiuid,
            "apikey": apikey, "gid": gid,
            "token": token, "rating": rating
        ]

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct CommentGalleryRequest: Request {
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

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EditGalleryCommentRequest: Request {
    let commentID: String
    let content: String
    let galleryURL: String

    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let params: [String: String] = [
            "edit_comment": commentID, "commenttext_edit": fixedContent
        ]

        var request = URLRequest(url: galleryURL.safeURL())
        request.httpMethod = "POST"
        request.httpBody = params.dictString()
            .urlEncoded().data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct VoteGalleryCommentRequest: Request {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let commentID: Int
    let commentVote: Int

    var publisher: AnyPublisher<Any, AppError> {
        let params: [String: Any] = [
            "method": "votecomment", "apiuid": apiuid,
            "apikey": apikey, "gid": gid, "token": token,
            "comment_id": commentID, "comment_vote": commentVote
        ]

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry().map { $0 }.mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
