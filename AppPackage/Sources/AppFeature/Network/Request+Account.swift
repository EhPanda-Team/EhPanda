import Kanna
import AppModels
import Combine
import Foundation

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
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseProfileIndex) }
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
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseEhSetting) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EhSettingRequest: Request {
    var publisher: AnyPublisher<EhSetting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseEhSetting) }
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
            "tr": String(ehSetting.thumbnailConfigRows.rawValue),
            "tp": String(Int(ehSetting.coverScaleFactor)),
            "vp": String(Int(ehSetting.viewportVirtualWidth)),
            "cs": String(ehSetting.commentsSortOrder.rawValue),
            "sc": String(ehSetting.commentVotesShowTiming.rawValue),
            "tb": String(ehSetting.tagsSortOrder.rawValue),
            "pn": String(ehSetting.galleryPageNumbering.rawValue),
            "apply": "Apply"
        ]

        if ehSetting.enableGalleryThumbnailSelector {
            params["xn_0"] = "on"
        }

        switch ehSetting.thumbnailConfigSize {
        case .auto: params["ts"] = "0"
        case .normal: params["ts"] = "1"
        case .small: params["ts"] = "2"
        default: break
        }

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
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseEhSetting) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavorGalleryRequest: Request {
    let gid: String
    let token: String
    let favIndex: Int

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct UnfavorGalleryRequest: Request {
    let gid: String

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
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
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap {
                try parseResponse(doc: $0, Parser.parseDownloadCommandResponse)
            }
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

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct CommentGalleryRequest: Request {
    let content: String
    let galleryURL: URL

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EditGalleryCommentRequest: Request {
    let commentID: String
    let content: String
    let galleryURL: URL

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
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

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
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

    var publisher: AnyPublisher<Void, AppError> {
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
            .map { _ in () }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
