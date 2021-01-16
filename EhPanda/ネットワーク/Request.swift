//
//  PopularItemsRequest.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import Combine
import Foundation

struct SearchItemsRequest {
    let keyword: String
    let filter: Filter
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        return URLSession.shared
            .dataTaskPublisher(
                for: URL(string: Defaults.URL.searchList(
                    keyword: keyword,
                    filter: filter
                ))!
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MoreSearchItemsRequest {
    let keyword: String
    let filter: Filter
    let lastID: String
    let pageNum: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(
                                string: Defaults.URL
                                    .moreSearchList(
                                        keyword: keyword,
                                        filter: filter,
                                        pageNum: pageNum,
                                        lastID: lastID
                                    ))!
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct FrontpageItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: Defaults.URL.frontpageList())!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MoreFrontpageItemsRequest {
    let lastID: String
    let pageNum: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(
                                string: Defaults.URL
                                    .moreFrontpageList(
                                        pageNum: pageNum,
                                        lastID: lastID
                                    ))!
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct PopularItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: Defaults.URL.popularList())!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct FavoritesItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(
                for: URL(string: Defaults.URL.favoritesList())!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MoreFavoritesItemsRequest {
    let lastID: String
    let pageNum: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(
                                string: Defaults.URL
                                    .moreFavoritesList(
                                        pageNum: pageNum,
                                        lastID: lastID
                                    ))!
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MangaDetailRequest {
    let detailURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(MangaDetail?, User?, HTMLDocument?), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: Defaults.URL.mangaDetail(url: detailURL))!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseMangaDetail)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct AssociatedItemsRequest {
    let keyword: AssociatedKeyword
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: Defaults.URL.associatedItemsRedir(keyword: keyword))!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MoreAssociatedItemsRequest {
    let keyword: AssociatedKeyword
    let lastID: String
    let pageNum: String
    let parser = Parser()
    
    var publisher: AnyPublisher<(PageNumber, [Manga]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(
                                string: Defaults.URL
                                    .moreAssociatedItemsRedir(
                                        keyword: keyword,
                                        lastID: lastID,
                                        pageNum: pageNum
                                    ))!
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseListItems)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct AlterImagesRequest {
    let id: String
    let doc: HTMLDocument
    let parser = Parser()
    
    var alterImageURL: String {
        parser.parseAlterImagesURL(doc)
    }
    
    var publisher: AnyPublisher<(Identity, [Data]), AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: alterImageURL)!)
            .map { parser.parseAlterImages(id: id, $0.data) }
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MangaCommentsRequest {
    let detailURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<[MangaComment], AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: Defaults.URL.mangaDetail(url: detailURL))!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(parser.parseComments)
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MangaContentsRequest {
    let detailURL: String
    let pageIndex: Int
    
    let parser = Parser()
    
    var publisher: AnyPublisher<[MangaContent], AppError> {
        preContents(url: detailURL)
            .flatMap(contents)
            .eraseToAnyPublisher()
    }
    
    func preContents(url: String) -> AnyPublisher<[(Int, URL)], AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: url)!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { parser.parseImagePreContents($0, pageIndex: pageIndex) }
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
    
    func contents(pre: [(Int, URL)]) -> AnyPublisher<[MangaContent], AppError> {
        pre
            .publisher
            .flatMap { preContent in
                URLSession.shared
                    .dataTaskPublisher(for: preContent.1)
                    .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                    .compactMap { parser.parseMangaContent(doc: $0, tag: preContent.0) }
            }
            .collect()
            .mapError { _ in .networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct AddFavoriteRequest {
    let id: String
    let token: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.addFavorite(id: id, token: token)
        let parameters: [String: String] = ["favcat": "0",
                                            "favnote": "",
                                            "apply": "Add to Favorites",
                                            "update": "1"]
        
        let session = URLSession.shared
        var request = URLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError { _ in .networkingFailed}
            .eraseToAnyPublisher()
    }
}

struct DeleteFavoriteRequest {
    let id: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let url = Defaults.URL.host + Defaults.URL.favorites
        let parameters: [String: String] = ["ddact": "delete",
                                            "modifygids[]": id,
                                            "apply": "Apply"]
        
        let session = URLSession.shared
        var request = URLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError { _ in .networkingFailed}
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
        var request = URLRequest(url: URL(string: detailURL)!)
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError { _ in .networkingFailed}
            .eraseToAnyPublisher()
    }
}

struct EditCommentRequest {
    let commentID: String
    let content: String
    let detailURL: String
    
    var publisher: AnyPublisher<Any, AppError> {
        let fixedContent = content.replacingOccurrences(of: "\n", with: "%0A")
        let parameters: [String: String] = ["edit_comment": commentID,
                                            "commenttext_edit": fixedContent]
        
        let session = URLSession.shared
        var request = URLRequest(url: URL(string: detailURL)!)
        
        request.httpMethod = "POST"
        request.httpBody = parameters.jsonString().data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError { _ in .networkingFailed}
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
        let url = Defaults.URL.host + Defaults.URL.api
        let params: [String: Any] = ["method": "votecomment",
                                     "apiuid": apiuid,
                                     "apikey": apikey,
                                     "gid": gid,
                                     "token": token,
                                     "comment_id": commentID,
                                     "comment_vote": commentVote]
        
        let session = URLSession.shared
        var request = URLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization
            .data(withJSONObject: params, options: [])
        
        
        return session.dataTaskPublisher(for: request)
            .map { $0 }
            .mapError { _ in .networkingFailed}
            .eraseToAnyPublisher()
    }
}
