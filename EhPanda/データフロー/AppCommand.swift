//
//  AppCommand.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import Combine
import Foundation

protocol AppCommand {
    func execute(in store: Store)
}

struct FetchSearchItemsCommand: AppCommand {
    let keyword: String
    let filter: Filter
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        SearchItemsRequest(keyword: keyword, filter:  filter)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchSearchItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchSearchItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchMoreSearchItemsCommand: AppCommand {
    let keyword: String
    let filter: Filter
    let lastID: String
    let pageNum: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreSearchItemsRequest(
            keyword: keyword,
            filter: filter,
            lastID: lastID,
            pageNum: pageNum
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .failure(let error)  = completion {
                store.dispatch(.fetchMoreSearchItemsDone(result: .failure(error)))
            }
            token.unseal()
        } receiveValue: { mangas in
            store.dispatch(.fetchMoreSearchItemsDone(result: .success((mangas.0, mangas.1, keyword))))
        }
        .seal(in: token)
    }
}

struct FetchFrontpageItemsCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        FrontpageItemsRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchFrontpageItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchFrontpageItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchMoreFrontpageItemsCommand: AppCommand {
    let lastID: String
    let pageNum: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreFrontpageItemsRequest(lastID: lastID, pageNum: pageNum)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchMoreFrontpageItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchMoreFrontpageItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchPopularItemsCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        PopularItemsRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchPopularItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchPopularItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchFavoritesItemsCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        FavoritesItemsRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchFavoritesItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchFavoritesItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchMoreFavoritesItemsCommand: AppCommand {
    let lastID: String
    let pageNum: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreFavoritesItemsRequest(lastID: lastID, pageNum: pageNum)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchMoreFavoritesItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchMoreFavoritesItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchMangaDetailCommand: AppCommand {
    let id: String
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MangaDetailRequest(detailURL: detailURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaDetailDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { detail in
                if let mangaDetail = detail.0, let user = detail.1 {
                    store.dispatch(.updateUser(user: user))
                    store.dispatch(.fetchMangaDetailDone(result: .success((id, mangaDetail))))
                } else {
                    store.dispatch(.fetchMangaDetailDone(result: .failure(.networkingFailed)))
                }
                if let doc = detail.2,
                   detail.0?.previews.isEmpty == true {
                    store.dispatch(.fetchAlterImages(id: id, doc: doc))
                }
            }
            .seal(in: token)
    }
}

struct FetchAssociatedItemsCommand: AppCommand {
    let depth: Int
    let keyword: AssociatedKeyword
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        AssociatedItemsRequest(keyword: keyword)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchAssociatedItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchAssociatedItemsDone(result: .success((depth, keyword, mangas.1))))
            }
            .seal(in: token)
    }
}

struct FetchAlterImagesCommand: AppCommand {
    let id: String
    let doc: HTMLDocument
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        AlterImagesRequest(id: id, doc: doc)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchAlterImagesDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { images in
                store.dispatch(.fetchAlterImagesDone(result: .success(images)))
            }
            .seal(in: token)
    }
}

struct UpdateMangaCommentsCommand: AppCommand {
    let id: String
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MangaCommentsRequest(detailURL: detailURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.updateMangaCommentsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { comments in
                store.dispatch(.updateMangaCommentsDone(result: .success((id, comments))))
            }
            .seal(in: token)
    }
}

struct FetchMangaContentsCommand: AppCommand {
    let id: String
    let pages: Int
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        let ehPageCount = Int(floor(Double(pages)/20))
        let publishers = (0...ehPageCount)
            .map {
                MangaContentsRequest(
                    detailURL: Defaults.URL.contentPage(
                        url: detailURL, page: $0),
                    pageIndex: $0)
                    .publisher
            }
        
        Publishers.MergeMany(publishers)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaContentsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { contents in
                if !contents.isEmpty {
                    store.dispatch(.fetchMangaContentsDone(result: .success((id, contents))))
                } else {
                    store.dispatch(.fetchMangaContentsDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
}

struct AddFavoriteCommand: AppCommand {
    let id: String
    let token: String
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        AddFavoriteRequest(id: id, token: token)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.fetchFavoritesItems)
                }
                sToken.unseal()
            } receiveValue: { _ in }
            .seal(in: sToken)
    }
}

struct DeleteFavoriteCommand: AppCommand {
    let id: String
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        DeleteFavoriteRequest(id: id)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.fetchFavoritesItems)
                }
                sToken.unseal()
            } receiveValue: { _ in }
            .seal(in: sToken)
    }
}

struct CommentCommand: AppCommand {
    let id: String
    let content: String
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        CommentRequest(content: content, detailURL: detailURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.updateMangaComments(id: id))
                }
                token.unseal()
            } receiveValue: { _ in }
            .seal(in: token)
    }
}

struct EditCommentCommand: AppCommand {
    let id: String
    let commentID: String
    let content: String
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        EditCommentRequest(
            commentID: commentID,
            content: content,
            detailURL: detailURL
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .finished = completion {
                store.dispatch(.updateMangaComments(id: id))
            }
            token.unseal()
        } receiveValue: { _ in }
        .seal(in: token)
    }
}

struct VoteCommentCommand: AppCommand {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let commentID: Int
    let commentVote: Int
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        VoteCommentRequest(
            apiuid: apiuid,
            apikey: apikey,
            gid: gid,
            token: token,
            commentID: commentID,
            commentVote: commentVote
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .finished = completion {
                store.dispatch(.updateMangaComments(id: String(gid)))
            }
            sToken.unseal()
        } receiveValue: { _ in }
        .seal(in: sToken)
    }
}

class SubscriptionToken {
    var cancellable: AnyCancellable?
    func unseal() { cancellable = nil }
}

extension AnyCancellable {
    func seal(in token: SubscriptionToken) {
        token.cancellable = self
    }
}
