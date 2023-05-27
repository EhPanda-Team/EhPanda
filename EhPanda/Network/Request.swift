//
//  PopularItemsRequest.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import Combine
import Foundation
import ComposableArchitecture

protocol Request {
    associatedtype Response

    var publisher: AnyPublisher<Response, AppError> { get }
}
extension Request {
    var effect: EffectTask<Result<Response, AppError>> {
        publisher.receive(on: DispatchQueue.main).catchToEffect()
    }

    func mapAppError(error: Error) -> AppError {
        switch error {
        case is ParseError:
            return .parseFailed

        case is URLError:
            return .networkingFailed

        case is DecodingError:
            return .parseFailed

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
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
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
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseGreeting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct UserInfoRequest: Request {
    let uid: String

    var publisher: AnyPublisher<User, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.userInfo(uid: uid))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseUserInfo)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavoriteCategoriesRequest: Request {
    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseFavoriteCategories)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
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
                        let response = try JSONDecoder().decode(EhTagTranslationDatabaseResponse.self, from: data)
                        var translations = response.tagTranslations
                        guard !translations.isEmpty else { throw AppError.parseFailed }
                        if language == .traditionalChinese {
                            translations = translations.chtConverted
                        }
                        return TagTranslator(language: language, updatedDate: date, translations: translations)
                    }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

// MARK: Fetch ListItems
struct SearchGalleriesRequest: Request {
    let keyword: String
    let filter: Filter

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.searchList(keyword: keyword, filter: filter)
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct MoreSearchGalleriesRequest: Request {
    let keyword: String
    let filter: Filter
    let lastID: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreSearchList(keyword: keyword, filter: filter, lastID: lastID)
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct FrontpageGalleriesRequest: Request {
    let filter: Filter

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.frontpageList(filter: filter))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreFrontpageGalleriesRequest: Request {
    let filter: Filter
    let lastID: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreFrontpageList(filter: filter, lastID: lastID))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct PopularGalleriesRequest: Request {
    let filter: Filter

    var publisher: AnyPublisher<[Gallery], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.popularList(filter: filter))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseGalleries)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct WatchedGalleriesRequest: Request {
    let filter: Filter
    let keyword: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.watchedList(filter: filter, keyword: keyword))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreWatchedGalleriesRequest: Request {
    let filter: Filter
    let lastID: String
    let keyword: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreWatchedList(filter: filter, lastID: lastID, keyword: keyword)
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct FavoritesGalleriesRequest: Request {
    let favIndex: Int
    let keyword: String
    var sortOrder: FavoritesSortOrder?

    var publisher: AnyPublisher<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.favoritesList(favIndex: favIndex, keyword: keyword, sortOrder: sortOrder)
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap {
            (
                Parser.parsePageNum(doc: $0),
                Parser.parseFavoritesSortOrder(doc: $0),
                try Parser.parseGalleries(doc: $0)
            )
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct MoreFavoritesGalleriesRequest: Request {
    let favIndex: Int
    let lastID: String
    var lastTimestamp: String
    let keyword: String

    var publisher: AnyPublisher<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreFavoritesList(
                favIndex: favIndex, lastID: lastID, lastTimestamp: lastTimestamp, keyword: keyword
            )
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap {
            (
                Parser.parsePageNum(doc: $0),
                Parser.parseFavoritesSortOrder(doc: $0),
                try Parser.parseGalleries(doc: $0)
            )
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct ToplistsGalleriesRequest: Request {
    let catIndex: Int
    var pageNum: Int?

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.toplistsList(catIndex: catIndex, pageNum: pageNum)
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct MoreToplistsGalleriesRequest: Request {
    let catIndex: Int
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreToplistsList(
                catIndex: catIndex, pageNum: pageNum
            )
        )
        .genericRetry()
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .tryMap { (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0)) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

// MARK: Fetch others
struct GalleryDetailRequest: Request {
    let gid: String
    let galleryURL: URL

    var publisher: AnyPublisher<(GalleryDetail, GalleryState, String, Greeting?), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.galleryDetail(url: galleryURL))
            .genericRetry()
            .compactMap { resp -> HTMLDocument? in
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
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryReverseRequest: Request {
    let url: URL
    let isGalleryImageURL: Bool

    func getGallery(from detail: GalleryDetail?, and url: URL) -> Gallery? {
        if let detail = detail {
            return Gallery(
                gid: url.pathComponents[2],
                token: url.pathComponents[3],
                title: detail.title,
                rating: detail.rating,
                tags: [],
                category: detail.category,
                uploader: detail.uploader,
                pageCount: detail.pageCount,
                postedDate: detail.postedDate,
                coverURL: detail.coverURL,
                galleryURL: url
            )
        } else {
            return nil
        }
    }

    var publisher: AnyPublisher<Gallery, AppError> {
        galleryURL(url: url)
            .genericRetry()
            .flatMap(gallery)
            .eraseToAnyPublisher()
    }

    func galleryURL(url: URL) -> AnyPublisher<URL, AppError> {
        switch isGalleryImageURL {
        case true:
            return URLSession.shared.dataTaskPublisher(for: url)
                .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                .tryMap(Parser.parseGalleryURL)
                .mapError(mapAppError)
                .eraseToAnyPublisher()

        case false:
            return Just(url)
                .setFailureType(to: AppError.self)
                .eraseToAnyPublisher()
        }
    }

    func gallery(url: URL) -> AnyPublisher<Gallery, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap {
                guard let (detail, _) = try? Parser.parseGalleryDetail(doc: $0, gid: url.pathComponents[2])
                else { return nil }

                return getGallery(from: detail, and: url)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryArchiveRequest: Request {
    let archiveURL: URL

    var publisher: AnyPublisher<(GalleryArchive, String?, String?), AppError> {
        URLSession.shared.dataTaskPublisher(for: archiveURL)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (html: HTMLDocument) -> (HTMLDocument, GalleryArchive) in
                let archive = try Parser.parseGalleryArchive(doc: html)
                return (html, archive)
            }
            .map { html, archive in
                guard let (currentGP, currentCredits) = try? Parser.parseCurrentFunds(doc: html)
                else { return (archive, nil, nil) }
                return (archive, currentGP, currentCredits)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryArchiveFundsRequest: Request {
    let gid: String
    let galleryURL: URL

    var publisher: AnyPublisher<(String, String), AppError> {
        archiveURL(url: galleryURL)
            .genericRetry()
            .flatMap(funds)
            .eraseToAnyPublisher()
    }

    func archiveURL(url: URL) -> AnyPublisher<URL, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap { try? Parser.parseGalleryDetail(doc: $0, gid: gid).0.archiveURL }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    func funds(url: URL) -> AnyPublisher<(String, String), AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseCurrentFunds)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryTorrentsRequest: Request {
    let gid: String
    let token: String

    var publisher: AnyPublisher<[GalleryTorrent], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.galleryTorrents(gid: gid, token: token))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(Parser.parseGalleryTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryPreviewURLsRequest: Request {
    let galleryURL: URL
    let pageNum: Int

    var publisher: AnyPublisher<[Int: URL], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.detailPage(url: galleryURL, pageNum: pageNum))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parsePreviewURLs)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MPVKeysRequest: Request {
    let mpvURL: URL

    var publisher: AnyPublisher<(String, [Int: String]), AppError> {
        URLSession.shared.dataTaskPublisher(for: mpvURL)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseMPVKeys)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct ThumbnailURLsRequest: Request {
    let galleryURL: URL
    let pageNum: Int

    var publisher: AnyPublisher<[Int: URL], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.detailPage(url: galleryURL, pageNum: pageNum))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseThumbnailURLs)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryNormalImageURLsRequest: Request {
    let thumbnailURLs: [Int: URL]

    var publisher: AnyPublisher<([Int: URL], [Int: URL]), AppError> {
        thumbnailURLs.publisher
            .flatMap { index, url in
                URLSession.shared.dataTaskPublisher(for: url)
                    .genericRetry()
                    .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                    .tryMap { try Parser.parseGalleryNormalImageURL(doc: $0, index: index) }
            }
            .collect()
            .map { tuples in
                var imageURLs = [Int: URL]()
                var originalImageURLs = [Int: URL]()
                for (index, imageURL, originalImageURL) in tuples {
                    imageURLs[index] = imageURL
                    originalImageURLs[index] = originalImageURL
                }
                return (imageURLs, originalImageURLs)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryNormalImageURLRefetchRequest: Request {
    let index: Int
    let pageNum: Int
    let galleryURL: URL
    let thumbnailURL: URL?
    let storedImageURL: URL

    var publisher: AnyPublisher<([Int: URL], HTTPURLResponse?), AppError> {
        storedThumbnailURL()
            .flatMap(renewThumbnailURL)
            .flatMap(imageURL)
            .genericRetry()
            .map { imageURL1, imageURL2, response in
                ([index: imageURL1 != storedImageURL ? imageURL1 : imageURL2], response)
            }
            .eraseToAnyPublisher()
    }

    func storedThumbnailURL() -> AnyPublisher<URL, AppError> {
        if let thumbnailURL = thumbnailURL {
            return Just(thumbnailURL)
                .setFailureType(to: AppError.self)
                .eraseToAnyPublisher()
        } else {
            return URLSession.shared.dataTaskPublisher(for: URLUtil.detailPage(url: galleryURL, pageNum: pageNum))
                .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                .tryMap(Parser.parseThumbnailURLs)
                .compactMap({ thumbnailURLs in thumbnailURLs[index] })
                .mapError(mapAppError)
                .eraseToAnyPublisher()
        }
    }

    func renewThumbnailURL(stored: URL) -> AnyPublisher<(URL, URL), AppError> {
        URLSession.shared.dataTaskPublisher(for: stored)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap {
                let identifier = try Parser.parseSkipServerIdentifier(doc: $0)
                let imageURL = try Parser.parseGalleryNormalImageURL(doc: $0, index: index).1
                return (stored.appending(queryItems: [.skipServerIdentifier: identifier]), imageURL)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    func imageURL(thumbnailURL: URL, anotherImageURL: URL)
    -> AnyPublisher<(URL, URL, HTTPURLResponse?), AppError> {
        URLSession.shared.dataTaskPublisher(for: thumbnailURL)
            .tryMap {
                (try Kanna.HTML(html: $0.data, encoding: .utf8), $0.response as? HTTPURLResponse)
            }
            .tryMap { html, response in
                (try Parser.parseGalleryNormalImageURL(doc: html, index: index), response)
            }
            .map { imageURL, response in
                (anotherImageURL, imageURL.1, response)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryMPVImageURLRequest: Request {
    let gid: Int
    let index: Int
    let mpvKey: String
    let mpvImageKey: String
    let skipServerIdentifier: Int?

    var publisher: AnyPublisher<(URL, URL?, Int), AppError> {
        var params: [String: Any] = [
            "method": "imagedispatch",
            "gid": gid,
            "page": index,
            "imgkey": mpvImageKey,
            "mpvkey": mpvKey
        ]
        if let skipServerIdentifier = skipServerIdentifier {
            params["nl"] = skipServerIdentifier
        }

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map(\.data)
            .tryMap { data in
                guard let dict = try JSONSerialization
                        .jsonObject(with: data) as? [String: Any],
                      let imageURLString = dict["i"] as? String,
                      let imageURL = URL(string: imageURLString),
                      let skipServerIdentifier = dict["s"] as? Int
                else { throw AppError.parseFailed }

                if let originalImageURLStringSlice = dict["lf"] as? String {
                    let originalImageURL = Defaults.URL.host.appendingPathComponent(originalImageURLStringSlice)
                    return (imageURL, originalImageURL, skipServerIdentifier)
                } else {
                    return (imageURL, nil, skipServerIdentifier)
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

// MARK: Tool
struct DataRequest: Request {
    let url: URL

    var publisher: AnyPublisher<Data, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .genericRetry()
            .map(\.data)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

// MARK: Account Ops
struct LoginRequest: Request {
    let username: String
    let password: String

    var publisher: AnyPublisher<HTTPURLResponse?, AppError> {
        let params: [String: String] = [
            "b": "d",
            "bt": "1-1",
            "CookieDate": "1",
            "UserName": username,
            "PassWord": password,
            "ipb_login_submit": "Login!"
        ]

        var request = URLRequest(url: Defaults.URL.login)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0.response as? HTTPURLResponse }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct IgneousRequest: Request {
    var publisher: AnyPublisher<HTTPURLResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.exhentai)
            .genericRetry()
            .compactMap { $0.response as? HTTPURLResponse }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct VerifyEhProfileResponse: Equatable {
    let profileValue: Int?
    let isProfileNotFound: Bool
}
struct VerifyEhProfileRequest: Request {
    var publisher: AnyPublisher<VerifyEhProfileResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseProfileIndex)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
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
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EhSettingRequest: Request {
    var publisher: AnyPublisher<EhSetting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
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
            "pp": ehSetting.showSearchRangeIndicator ? "0" : "1",
            "fs": String(ehSetting.favoritesSortOrder.rawValue),
            "ru": ehSetting.ratingsColor,
            "ft": String(Int(ehSetting.tagFilteringThreshold)),
            "wt": String(Int(ehSetting.tagWatchingThreshold)),
            "tf": ehSetting.showFilteredRemovalCount ? "0" : "1",
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
            "apply": "Apply"
        ]

        EhSetting.categoryNames.enumerated().forEach { index, name in
            params["ct_\(name)"] = ehSetting.disabledCategories[index] ? "1" : "0"
        }
        Array(0...9).forEach { index in
            params["favorite_\(index)"] = ehSetting.favoriteCategories[index]
        }
        ehSetting.excludedLanguages.enumerated().forEach { index, value in
            if value {
                params["xl_\(EhSetting.languageValues[index])"] = "on"
            }
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
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseEhSetting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavorGalleryRequest: Request {
    let gid: String
    let token: String
    let favIndex: Int

    var publisher: AnyPublisher<Any, AppError> {
        let url = URLUtil.addFavorite(gid: gid, token: token)
        let params: [String: String] = [
            "favcat": "\(favIndex)",
            "favnote": "",
            "apply": "Add to Favorites",
            "update": "1"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct UnfavorGalleryRequest: Request {
    let gid: String

    var publisher: AnyPublisher<Any, AppError> {
        let params: [String: String] = [
            "ddact": "delete",
            "modifygids[]": gid,
            "apply": "Apply"
        ]

        var request = URLRequest(url: Defaults.URL.favorites)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct SendDownloadCommandRequest: Request {
    let archiveURL: URL
    let resolution: String

    var publisher: AnyPublisher<String, AppError> {
        let params: [String: String] = [
            "hathdl_xres": resolution
        ]

        var request = URLRequest(url: archiveURL)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseDownloadCommandResponse)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
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
            "method": "rategallery",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "rating": rating
        ]

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct CommentGalleryRequest: Request {
    let content: String
    let galleryURL: URL

    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let params: [String: String] = [
            "commenttext_new": fixedContent
        ]

        var request = URLRequest(url: galleryURL)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EditGalleryCommentRequest: Request {
    let commentID: String
    let content: String
    let galleryURL: URL

    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let params: [String: String] = [
            "edit_comment": commentID,
            "commenttext_edit": fixedContent
        ]

        var request = URLRequest(url: galleryURL)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
        request.setURLEncodedContentType()

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
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
            "method": "votecomment",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "comment_id": commentID,
            "comment_vote": commentVote
        ]

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct VoteGalleryTagRequest: Request {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let tag: String
    let vote: Int

    var publisher: AnyPublisher<Any, AppError> {
        let params: [String: Any] = [
            "method": "taggallery",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "tags": tag,
            "vote": vote
        ]

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .genericRetry()
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
