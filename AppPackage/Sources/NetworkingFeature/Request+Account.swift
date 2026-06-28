import Kanna
import AppModels
import Combine
import Foundation
import AppTools
import ParserFeature

// MARK: Account Ops
public struct LoginRequest: Request {
    public init(
        username: String,
        password: String
    ) {
        self.username = username
        self.password = password
    }
    public let username: String
    public let password: String

    public var publisher: AnyPublisher<HTTPURLResponse?, AppError> {
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

public struct IgneousRequest: Request {
    public init() {}

    public var publisher: AnyPublisher<HTTPURLResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.exhentai)
            .genericRetry()
            .compactMap { $0.response as? HTTPURLResponse }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct VerifyEhProfileRequest: Request {
    public init() {}

    public var publisher: AnyPublisher<VerifyEhProfileResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseProfileIndex) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct EhProfileRequest: Request {
    public init(
        action: EhProfileAction? = nil,
        name: String? = nil,
        set: Int? = nil
    ) {
        self.action = action
        self.name = name
        self.set = set
    }
    public var action: EhProfileAction?
    public var name: String?
    public var set: Int?

    public var publisher: AnyPublisher<EhSetting, AppError> {
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

public struct EhSettingRequest: Request {
    public init() {}

    public var publisher: AnyPublisher<EhSetting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseEhSetting) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct SubmitEhSettingChangesRequest: Request {
    public init(
        ehSetting: EhSetting
    ) {
        self.ehSetting = ehSetting
    }
    public let ehSetting: EhSetting

    public var publisher: AnyPublisher<EhSetting, AppError> {
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

public struct FavorGalleryRequest: Request {
    public init(
        gid: String,
        token: String,
        favIndex: Int
    ) {
        self.gid = gid
        self.token = token
        self.favIndex = favIndex
    }
    public let gid: String
    public let token: String
    public let favIndex: Int

    public var publisher: AnyPublisher<Void, AppError> {
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

public struct UnfavorGalleryRequest: Request {
    public init(
        gid: String
    ) {
        self.gid = gid
    }
    public let gid: String

    public var publisher: AnyPublisher<Void, AppError> {
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

public struct SendDownloadCommandRequest: Request {
    public init(
        archiveURL: URL,
        resolution: String
    ) {
        self.archiveURL = archiveURL
        self.resolution = resolution
    }
    public let archiveURL: URL
    public let resolution: String

    public var publisher: AnyPublisher<String, AppError> {
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

public struct RateGalleryRequest: Request {
    public init(
        apiuid: Int,
        apikey: String,
        gid: Int,
        token: String,
        rating: Int
    ) {
        self.apiuid = apiuid
        self.apikey = apikey
        self.gid = gid
        self.token = token
        self.rating = rating
    }
    public let apiuid: Int
    public let apikey: String
    public let gid: Int
    public let token: String
    public let rating: Int

    public var publisher: AnyPublisher<Void, AppError> {
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

public struct CommentGalleryRequest: Request {
    public init(
        content: String,
        galleryURL: URL
    ) {
        self.content = content
        self.galleryURL = galleryURL
    }
    public let content: String
    public let galleryURL: URL

    public var publisher: AnyPublisher<Void, AppError> {
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

public struct EditGalleryCommentRequest: Request {
    public init(
        commentID: String,
        content: String,
        galleryURL: URL
    ) {
        self.commentID = commentID
        self.content = content
        self.galleryURL = galleryURL
    }
    public let commentID: String
    public let content: String
    public let galleryURL: URL

    public var publisher: AnyPublisher<Void, AppError> {
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

public struct VoteGalleryCommentRequest: Request {
    public init(
        apiuid: Int,
        apikey: String,
        gid: Int,
        token: String,
        commentID: Int,
        commentVote: Int
    ) {
        self.apiuid = apiuid
        self.apikey = apikey
        self.gid = gid
        self.token = token
        self.commentID = commentID
        self.commentVote = commentVote
    }
    public let apiuid: Int
    public let apikey: String
    public let gid: Int
    public let token: String
    public let commentID: Int
    public let commentVote: Int

    public var publisher: AnyPublisher<Void, AppError> {
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

public struct VoteGalleryTagRequest: Request {
    public init(
        apiuid: Int,
        apikey: String,
        gid: Int,
        token: String,
        tag: String,
        vote: Int
    ) {
        self.apiuid = apiuid
        self.apikey = apikey
        self.gid = gid
        self.token = token
        self.tag = tag
        self.vote = vote
    }
    public let apiuid: Int
    public let apikey: String
    public let gid: Int
    public let token: String
    public let tag: String
    public let vote: Int

    public var publisher: AnyPublisher<Void, AppError> {
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
