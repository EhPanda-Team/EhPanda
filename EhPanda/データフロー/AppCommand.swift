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

struct FetchUserInfoCommand: AppCommand {
    let uid: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        UserInfoRequest(uid: uid)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchUserInfoDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { user in
                store.dispatch(.fetchUserInfoDone(result: .success(user)))
            }
            .seal(in: token)
    }
}

struct FetchFavoriteNamesCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        FavoriteNamesRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchFavoriteNamesDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { names in
                store.dispatch(.fetchFavoriteNamesDone(result: .success(names)))
            }
            .seal(in: token)
    }
}

struct FetchMangaItemReverseCommand: AppCommand {
    let id: String
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MangaItemReverseRequest(detailURL: detailURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaItemReverseDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { manga in
                if let manga = manga {
                    store.dispatch(.fetchMangaItemReverseDone(result: .success((id, manga))))
                } else {
                    store.dispatch(.fetchMangaItemReverseDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
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
    let pageNum: Int
    
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
            store.dispatch(.fetchMoreSearchItemsDone(result: .success((keyword, mangas.0, mangas.1))))
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
    let pageNum: Int
    
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

struct FetchWatchedItemsCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        WatchedItemsRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchWatchedItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchWatchedItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchMoreWatchedItemsCommand: AppCommand {
    let lastID: String
    let pageNum: Int
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreWatchedItemsRequest(lastID: lastID, pageNum: pageNum)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchMoreWatchedItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchMoreWatchedItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
    }
}

struct FetchFavoritesItemsCommand: AppCommand {
    let favIndex: Int
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        FavoritesItemsRequest(favIndex: favIndex)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchFavoritesItemsDone(carriedValue: favIndex, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchFavoritesItemsDone(carriedValue: favIndex, result: .success((mangas))))
            }
            .seal(in: token)
    }
}

struct FetchMoreFavoritesItemsCommand: AppCommand {
    let favIndex: Int
    let lastID: String
    let pageNum: Int
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreFavoritesItemsRequest(favIndex: favIndex, lastID: lastID, pageNum: pageNum)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchMoreFavoritesItemsDone(carriedValue: favIndex, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchMoreFavoritesItemsDone(carriedValue: favIndex, result: .success((mangas))))
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
                store.dispatch(.fetchMangaDetailDone(result: .success((id, detail.0, detail.1))))
                if detail.0.previews.isEmpty == true {
                    store.dispatch(.fetchAlterImages(id: id, doc: detail.2))
                }
            }
            .seal(in: token)
    }
}

struct FetchMangaArchiveCommand: AppCommand {
    let id: String
    let archiveURL: String
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        MangaArchiveRequest(archiveURL: archiveURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaArchiveDone(result: .failure(error)))
                }
                sToken.unseal()
            } receiveValue: { archive in
                if let arc = archive.0 {
                    store.dispatch(.fetchMangaArchiveDone(result: .success((id, arc, archive.1, archive.2))))
                    if archive.1 == nil
                        || archive.2 == nil
                    {
                        store.dispatch(.fetchMangaArchiveFunds(id: id))
                    }
                } else {
                    store.dispatch(.fetchMangaArchiveDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: sToken)
    }
}

struct FetchMangaArchiveFundsCommand: AppCommand {
    let id: String
    let detailURL: String
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        MangaArchiveFundsRequest(detailURL: detailURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaArchiveFundsDone(result: .failure(error)))
                }
                sToken.unseal()
            } receiveValue: { funds in
                if let funds = funds {
                    store.dispatch(.fetchMangaArchiveFundsDone(result: .success(funds)))
                } else {
                    store.dispatch(.fetchMangaArchiveFundsDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: sToken)
    }
}

struct FetchMangaTorrentsCommand: AppCommand {
    let id: String
    let token: String
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        MangaTorrentsRequest(id: id, token: token)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaTorrentsDone(result: .failure(error)))
                }
                sToken.unseal()
            } receiveValue: { torrents in
                if !torrents.isEmpty {
                    store.dispatch(.fetchMangaTorrentsDone(result: .success((id, torrents))))
                } else {
                    store.dispatch(.fetchMangaTorrentsDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: sToken)
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
                store.dispatch(.fetchAssociatedItemsDone(result: .success((depth, keyword, mangas.0, mangas.1))))
            }
            .seal(in: token)
    }
}

struct FetchMoreAssociatedItemsCommand: AppCommand {
    let depth: Int
    let keyword: AssociatedKeyword
    let lastID: String
    let pageNum: Int
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreAssociatedItemsRequest(keyword: keyword, lastID: lastID, pageNum: pageNum)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMoreAssociatedItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchMoreAssociatedItemsDone(result: .success((depth, keyword, mangas.0, mangas.1))))
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

struct UpdateMangaDetailCommand: AppCommand {
    let id: String
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        MangaDetailRequest(detailURL: detailURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.updateMangaDetailDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { detail in
                store.dispatch(.updateMangaDetailDone(result: .success((id, detail.0))))
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
    let detailURL: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
            MangaContentsRequest(
                detailURL: Defaults.URL
                    .contentPage(
                        url: detailURL,
                        pageNum: 0
                    ),
                pageNum: 0,
                pageCount: 0
            )
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMangaContentsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { contents in
                if !contents.1.isEmpty {
                    store.dispatch(.fetchMangaContentsDone(result: .success((id, contents.0, contents.1))))
                } else {
                    store.dispatch(.fetchMangaContentsDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
}

struct FetchMoreMangaContentsCommand: AppCommand {
    let id: String
    let detailURL: String
    let pageNum: Int
    let pageCount: Int
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
            MangaContentsRequest(
                detailURL: Defaults.URL
                    .contentPage(
                        url: detailURL,
                        pageNum: pageNum
                    ),
                pageNum: pageNum,
                pageCount: pageCount
            )
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMoreMangaContentsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { contents in
                if !contents.1.isEmpty {
                    store.dispatch(.fetchMoreMangaContentsDone(result: .success((id, contents.0, contents.1))))
                } else {
                    store.dispatch(.fetchMoreMangaContentsDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
}

struct AddFavoriteCommand: AppCommand {
    let id: String
    let token: String
    let favIndex: Int
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        AddFavoriteRequest(id: id, token: token, favIndex: favIndex)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.updateMangaDetail(id: id))
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
                    store.dispatch(.updateMangaDetail(id: id))
                }
                sToken.unseal()
            } receiveValue: { _ in }
            .seal(in: sToken)
    }
}

struct SendDownloadCommand: AppCommand {
    let id: String
    let archiveURL: String
    let resolution: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        SendDownloadCommandRequest(
            archiveURL: archiveURL,
            resolution: resolution
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .failure(let error) = completion {
                store.dispatch(.sendDownloadCommandDone(result: .failure(error)))
            }
            token.unseal()
        } receiveValue: { resp in
            store.dispatch(.sendDownloadCommandDone(result: .success(resp)))
            store.dispatch(.fetchMangaArchiveFunds(id: id))
        }
        .seal(in: token)
    }
}

struct RateCommand: AppCommand {
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let rating: Int
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        RateRequest(
            apiuid: apiuid,
            apikey: apikey,
            gid: gid,
            token: token,
            rating: rating
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .finished = completion {
                store.dispatch(.updateMangaDetail(id: String(gid)))
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
                    store.dispatch(.updateMangaDetail(id: id))
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
                store.dispatch(.updateMangaDetail(id: id))
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
                store.dispatch(.updateMangaDetail(id: String(gid)))
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
