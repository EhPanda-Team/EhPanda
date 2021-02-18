//
//  PopularItemsRequest.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import Combine
import Foundation

func mapAppError(_ error: Error) -> AppError {
    switch error {
    case is ParseError:
        return .parseFailed
    case is URLError:
        return .networkingFailed
    default:
        return error as? AppError ?? .unknown
    }
}

struct UserInfoRequest {
    let uid: String
    let parser = Parser()
    
    var publisher: AnyPublisher<User, AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL.userInfo(uid: uid).safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(parser.parseUserInfo)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaItemReverseRequest {
    let detailURL: String
    let parser = Parser()
    
    var id: String {
        if detailURL.safeURL().pathComponents.count >= 4 {
            return detailURL.safeURL().pathComponents[2]
        } else {
            return ""
        }
    }
    var token: String {
        if detailURL.safeURL().pathComponents.count >= 4 {
            return detailURL.safeURL().pathComponents[3]
        } else {
            return ""
        }
    }
    
    var publisher: AnyPublisher<Manga?, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: detailURL.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap {
                if let mangaDetail = try? parser.parseMangaDetail($0).0 {
                    return Manga(
                        detail: mangaDetail,
                        id: id,
                        token: token,
                        title: mangaDetail.title,
                        rating: mangaDetail.rating,
                        tags: [],
                        category: mangaDetail.category,
                        language: mangaDetail.language,
                        uploader: mangaDetail.uploader,
                        publishedTime: mangaDetail.publishedTime,
                        coverURL: mangaDetail.coverURL,
                        detailURL: detailURL
                    )
                } else {
                    return nil
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
    
}

struct SearchItemsRequest {
    let keyword: String
    let filter: Filter
    let parser = Parser()
    
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
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreSearchItemsRequest {
    let keyword: String
    let filter: Filter
    let lastID: String
    let pageNum: Int
    let parser = Parser()
    
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
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FrontpageItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.frontpageList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreFrontpageItemsRequest {
    let lastID: String
    let pageNum: Int
    let parser = Parser()
    
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
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct PopularItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.popularList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct WatchedItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.watchedList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreWatchedItemsRequest {
    let lastID: String
    let pageNum: Int
    let parser = Parser()
    
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
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavoritesItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: Defaults.URL.favoritesList().safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MoreFavoritesItemsRequest {
    let lastID: String
    let pageNum: Int
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreFavoritesList(
                        pageNum: "\(pageNum)",
                        lastID: lastID
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaDetailRequest {
    let detailURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(MangaDetail, APIKey, HTMLDocument), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .mangaDetail(
                        url: detailURL
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(parser.parseMangaDetail)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct AssociatedItemsRequest {
    let keyword: AssociatedKeyword
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: Defaults.URL
                .associatedItemsRedir(
                    keyword: keyword
                )
                .safeURL()
        )
        .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
        .map(parser.parseListItems)
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct MoreAssociatedItemsRequest {
    let keyword: AssociatedKeyword
    let lastID: String
    let pageNum: Int
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .moreAssociatedItemsRedir(
                        keyword: keyword,
                        lastID: lastID,
                        pageNum: "\(pageNum)"
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct AlterImagesRequest {
    let id: String
    let doc: HTMLDocument
    let parser = Parser()
    
    var alterImageURL: String {
        if let url = try? parser
            .parseAlterImagesURL(doc)
        {
            return url
        } else {
            return ""
        }
    }
    
    var publisher: AnyPublisher<(Identity, [MangaAlterData]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: alterImageURL.safeURL())
            .map { parser.parseAlterImages(id: id, $0.data) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaArchiveRequest {
    let archiveURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(MangaArchive?, CurrentGP?, CurrentCredits?), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: archiveURL.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(parser.parseMangaArchive)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaArchiveFundsRequest {
    let detailURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(CurrentGP, CurrentCredits)?, AppError> {
        archiveURL(url: detailURL)
            .flatMap(funds)
            .eraseToAnyPublisher()
    }
    
    func archiveURL(url: String) -> AnyPublisher<String, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: detailURL.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap {
                if let url = try? parser
                    .parseMangaDetail($0)
                    .0.archiveURL
                {
                    return url
                } else {
                    return nil
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
    
    func funds(url: String) -> AnyPublisher<(CurrentGP, CurrentCredits)?, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseCurrentFunds)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaTorrentsRequest {
    let id: String
    let token: String
    let parser = Parser()
    
    var publisher: AnyPublisher<[MangaTorrent], AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .mangaTorrents(
                        id: id,
                        token: token
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseMangaTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaCommentsRequest {
    let detailURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<[MangaComment], AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: Defaults.URL
                    .mangaDetail(
                        url: detailURL
                    )
                    .safeURL()
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseComments)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct MangaContentsRequest {
    let detailURL: String
    let pageNum: Int
    let pageCount: Int
    
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [MangaContent]), AppError> {
        preContents(
            url: Defaults.URL
                .mangaContents(
                    detailURL: detailURL
                )
        )
        .flatMap(contents)
        .eraseToAnyPublisher()
    }
    
    func preContents(url: String) -> AnyPublisher<(PageNumber, [(Int, URL)]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: url.safeURL())
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { try parser.parseImagePreContents($0, pageCount: pageCount) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
    
    func contents(pageNum: PageNumber, preContents: [(Int, URL)])
    -> AnyPublisher<(PageNumber, [MangaContent]), AppError>
    {
        preContents
            .publisher
            .flatMap { preContent in
                URLSession.shared
                    .dataTaskPublisher(for: preContent.1)
                    .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                    .tryMap { try parser.parseMangaContent(doc: $0, tag: preContent.0) }
            }
            .collect()
            .map { (pageNum, $0) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

// MARK: POST
struct AddFavoriteRequest {
    let id: String
    let token: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.addFavorite(id: id, token: token)
        let parameters: [String: String] = [
            "favcat": "0",
            "favnote": "",
            "apply": "Add to Favorites",
            "update": "1"
        ]
        
        let session = URLSession.shared
        var request = URLRequest(url: url.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct DeleteFavoriteRequest {
    let id: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.ehFavorites()
        let parameters: [String: String] = [
            "ddact": "delete",
            "modifygids[]": id,
            "apply": "Apply"
        ]
        
        let session = URLSession.shared
        var request = URLRequest(url: url.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct SendDownloadCommandRequest {
    let archiveURL: String
    let resolution: String
    let parser = Parser()
    
    var publisher: AnyPublisher<Resp?, AppError> {
        let parameters: [String: String] = [
            "hathdl_xres": resolution
        ]
        
        let session = URLSession.shared
        var request = URLRequest(url: archiveURL.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(parser.parseDownloadCommandResponse)
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
        
        let session = URLSession.shared
        var request = URLRequest(url: url.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])
        
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct CommentRequest {
    let content: String
    let detailURL: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let parameters: [String: String] = ["commenttext_new": fixedContent]
        
        let session = URLSession.shared
        var request = URLRequest(url: detailURL.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct EditCommentRequest {
    let commentID: String
    let content: String
    let detailURL: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let parameters: [String: String] = [
            "edit_comment": commentID,
            "commenttext_edit": fixedContent
        ]
        
        let session = URLSession.shared
        var request = URLRequest(url: detailURL.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError(mapAppError)
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
        
        let session = URLSession.shared
        var request = URLRequest(url: url.safeURL())
        
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])
        
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
