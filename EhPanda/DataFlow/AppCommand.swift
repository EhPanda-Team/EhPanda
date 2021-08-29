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

struct FetchGreetingCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        GreetingRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGreetingDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { greeting in
                store.dispatch(.fetchGreetingDone(result: .success(greeting)))
            }
            .seal(in: token)
    }
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

struct FetchTagTranslatorCommand: AppCommand {
    let language: TranslatableLanguage
    let updatedDate: Date

    func execute(in store: Store) {
        let token = SubscriptionToken()
        TagTranslatorRequest(language: language, updatedDate: updatedDate)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchTagTranslatorDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { translator in
                store.dispatch(.fetchTagTranslatorDone(result: .success(translator)))
            }
            .seal(in: token)
    }
}

struct FetchGalleryItemReverseCommand: AppCommand {
    let gid: String
    let url: String
    let shouldParseGalleryURL: Bool

    func execute(in store: Store) {
        let token = SubscriptionToken()
        GalleryItemReverseRequest(url: url, shouldParseGalleryURL: shouldParseGalleryURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryItemReverseDone(carriedValue: gid, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { gallery in
                if let gallery = gallery {
                    store.dispatch(.fetchGalleryItemReverseDone(carriedValue: gid, result: .success(gallery)))
                } else {
                    store.dispatch(.fetchGalleryItemReverseDone(carriedValue: gid, result: .failure(.networkingFailed)))
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
        SearchItemsRequest(keyword: keyword, filter: filter)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchSearchItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { (pageNumber, galleries) in
                if !galleries.isEmpty {
                    store.dispatch(.fetchSearchItemsDone(result: .success((pageNumber, galleries))))
                } else {
                    store.dispatch(.fetchSearchItemsDone(result: .failure(.notFound)))
                    guard pageNumber.current < pageNumber.maximum else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        store.dispatch(.fetchMoreSearchItems(keyword: keyword))
                    }
                }
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
        } receiveValue: { (pageNumber, galleries) in
            store.dispatch(.fetchMoreSearchItemsDone(result: .success((pageNumber, galleries))))

            guard galleries.isEmpty, pageNumber.current < pageNumber.maximum else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                store.dispatch(.fetchMoreSearchItems(keyword: keyword))
            }
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
            } receiveValue: { (pageNumber, galleries) in
                if !galleries.isEmpty {
                    store.dispatch(.fetchFrontpageItemsDone(result: .success((pageNumber, galleries))))
                } else {
                    store.dispatch(.fetchFrontpageItemsDone(result: .failure(.notFound)))
                    guard pageNumber.current < pageNumber.maximum else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        store.dispatch(.fetchMoreFrontpageItems)
                    }
                }
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
            } receiveValue: { (pageNumber, galleries) in
                store.dispatch(.fetchMoreFrontpageItemsDone(result: .success((pageNumber, galleries))))

                guard galleries.isEmpty, pageNumber.current < pageNumber.maximum else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    store.dispatch(.fetchMoreFrontpageItems)
                }
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
            } receiveValue: { galleries in
                if !galleries.isEmpty {
                    store.dispatch(.fetchPopularItemsDone(result: .success(galleries)))
                } else {
                    store.dispatch(.fetchPopularItemsDone(result: .failure(.notFound)))
                }
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
            } receiveValue: { (pageNumber, galleries) in
                if !galleries.isEmpty {
                    store.dispatch(.fetchWatchedItemsDone(result: .success((pageNumber, galleries))))
                } else {
                    store.dispatch(.fetchWatchedItemsDone(result: .failure(.notFound)))
                    guard pageNumber.current < pageNumber.maximum else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        store.dispatch(.fetchMoreWatchedItems)
                    }
                }
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
            } receiveValue: { (pageNumber, galleries) in
                store.dispatch(.fetchMoreWatchedItemsDone(result: .success((pageNumber, galleries))))

                guard galleries.isEmpty, pageNumber.current < pageNumber.maximum else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    store.dispatch(.fetchMoreWatchedItems)
                }
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
            } receiveValue: { (pageNumber, galleries) in
                if !galleries.isEmpty {
                    store.dispatch(.fetchFavoritesItemsDone(
                        carriedValue: favIndex, result: .success((pageNumber, galleries)))
                    )
                } else {
                    store.dispatch(.fetchFavoritesItemsDone(carriedValue: favIndex, result: .failure(.notFound)))
                    guard pageNumber.current < pageNumber.maximum else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        store.dispatch(.fetchMoreFavoritesItems)
                    }
                }
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
            } receiveValue: { (pageNumber, galleries) in
                store.dispatch(.fetchMoreFavoritesItemsDone(
                    carriedValue: favIndex, result: .success((pageNumber, galleries)))
                )
                guard galleries.isEmpty, pageNumber.current < pageNumber.maximum else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    store.dispatch(.fetchMoreFavoritesItems)
                }
            }
            .seal(in: token)
    }
}

struct FetchToplistsItemsCommand: AppCommand {
    let topIndex: Int
    let catIndex: Int

    func execute(in store: Store) {
        let token = SubscriptionToken()
        ToplistsItemsRequest(catIndex: catIndex)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchToplistsItemsDone(carriedValue: topIndex, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { (pageNumber, galleries) in
                if !galleries.isEmpty {
                    store.dispatch(.fetchToplistsItemsDone(
                        carriedValue: topIndex, result: .success((pageNumber, galleries)))
                    )
                } else {
                    store.dispatch(.fetchToplistsItemsDone(carriedValue: topIndex, result: .failure(.notFound)))
                    guard pageNumber.current < pageNumber.maximum else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        store.dispatch(.fetchMoreToplistsItems)
                    }
                }
            }
            .seal(in: token)
    }
}

struct FetchMoreToplistsItemsCommand: AppCommand {
    let topIndex: Int
    let catIndex: Int
    let pageNum: Int

    func execute(in store: Store) {
        let token = SubscriptionToken()
        MoreToplistsItemsRequest(catIndex: catIndex, pageNum: pageNum)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error)  = completion {
                    store.dispatch(.fetchMoreToplistsItemsDone(carriedValue: topIndex, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { (pageNumber, galleries) in
                store.dispatch(.fetchMoreToplistsItemsDone(
                    carriedValue: topIndex, result: .success((pageNumber, galleries)))
                )
                guard galleries.isEmpty, pageNumber.current < pageNumber.maximum else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    store.dispatch(.fetchMoreToplistsItems)
                }
            }
            .seal(in: token)
    }
}

struct FetchGalleryDetailCommand: AppCommand {
    let gid: String
    let galleryURL: String

    func execute(in store: Store) {
        let token = SubscriptionToken()
        GalleryDetailRequest(gid: gid, galleryURL: galleryURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryDetailDone(gid: gid, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { (detail, state, apiKey) in
                store.dispatch(.fetchGalleryDetailDone(gid: gid, result: .success((detail, state, apiKey))))
            }
            .seal(in: token)
    }
}

struct FetchGalleryArchiveFundsCommand: AppCommand {
    let gid: String
    let galleryURL: String

    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        GalleryArchiveFundsRequest(gid: gid, galleryURL: galleryURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryArchiveFundsDone(result: .failure(error)))
                }
                sToken.unseal()
            } receiveValue: { funds in
                if let funds = funds {
                    store.dispatch(.fetchGalleryArchiveFundsDone(result: .success(funds)))
                } else {
                    store.dispatch(.fetchGalleryArchiveFundsDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: sToken)
    }
}

struct FetchGalleryPreviewsCommand: AppCommand {
    let gid: String
    let url: String
    let pageNumber: Int

    func execute(in store: Store) {
        let token = SubscriptionToken()
        GalleryPreviewsRequest(url: url)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryPreviewsDone(
                        gid: gid, pageNumber: pageNumber, result: .failure(error)
                    ))
                }
                token.unseal()
            } receiveValue: { previews in
                store.dispatch(.fetchGalleryPreviewsDone(
                    gid: gid, pageNumber: pageNumber, result: .success(previews)
                ))
            }
            .seal(in: token)
    }
}

struct FetchMPVKeysCommand: AppCommand {
    let gid: String
    let mpvURL: String
    let pageCount: Int
    let index: Int

    func execute(in store: Store) {
        let token = SubscriptionToken()
        MPVKeysRequest(mpvURL: mpvURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchMPVKeysDone(gid: gid, index: index, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { (mpvKey, imgKeys) in
                if imgKeys.keys.count == pageCount {
                    store.dispatch(.fetchMPVKeysDone(gid: gid, index: index, result: .success((mpvKey, imgKeys))))
                } else {
                    store.dispatch(.fetchMPVKeysDone(gid: gid, index: index, result: .failure(.parseFailed)))
                }
            }
            .seal(in: token)
    }
}

struct FetchThumbnailURLsCommand: AppCommand {
    let gid: String
    let url: String
    let index: Int

    func execute(in store: Store) {
        let token = SubscriptionToken()
        ThumbnailURLsRequest(url: url)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchThumbnailURLsDone(gid: gid, index: index, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { urls in
                if !urls.isEmpty {
                    store.dispatch(.fetchThumbnailURLsDone(gid: gid, index: index, result: .success(urls)))
                } else {
                    store.dispatch(.fetchThumbnailURLsDone(gid: gid, index: index, result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
}

struct FetchGalleryNormalContentsCommand: AppCommand {
    let gid: String
    let index: Int
    let thumbnailURLs: [(Int, URL)]

    func execute(in store: Store) {
        let token = SubscriptionToken()
        GalleryNormalContentsRequest(thumbnailURLs: thumbnailURLs)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryNormalContentsDone(gid: gid, index: index, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { contents in
                if !contents.isEmpty {
                    store.dispatch(.fetchGalleryNormalContentsDone(gid: gid, index: index, result: .success(contents)))
                } else {
                    store.dispatch(.fetchGalleryNormalContentsDone(
                        gid: gid, index: index, result: .failure(.networkingFailed))
                    )
                }
            }
            .seal(in: token)
    }
}

struct FetchGalleryMPVContentCommand: AppCommand {
    let gid: Int
    let index: Int
    let mpvKey: String
    let imgKey: String

    func execute(in store: Store) {
        let token = SubscriptionToken()
        GalleryMPVContentRequest(
            gid: gid, index: index,
            mpvKey: mpvKey, imgKey: imgKey
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .failure(let error) = completion {
                store.dispatch(.fetchGalleryMPVContentDone(
                    gid: "\(gid)", index: index, result: .failure(error)
                ))
            }
            token.unseal()
        } receiveValue: { content in
            store.dispatch(.fetchGalleryMPVContentDone(
                gid: "\(gid)", index: index, result: .success(content)
            ))
        }
        .seal(in: token)
    }
}

struct FetchIgneousCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        IgneousRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                token.unseal()
            } receiveValue: { _ in }
            .seal(in: token)
    }
}

struct VerifyEhProfileCommand: AppCommand {
    func execute(in store: Store) {
        let token = SubscriptionToken()
        VerifyEhProfileRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.verifyEhProfileDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: {
                store.dispatch(.verifyEhProfileDone(result: .success($0)))
            }
            .seal(in: token)
    }
}

struct CreateEhProfileCommand: AppCommand {
    let name: String

    func execute(in store: Store) {
        let token = SubscriptionToken()
        EhProfileRequest(action: .create, name: name)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                token.unseal()
            } receiveValue: { _ in }
            .seal(in: token)
    }
}

struct AddFavoriteCommand: AppCommand {
    let gid: String
    let token: String
    let favIndex: Int

    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        AddFavoriteRequest(gid: gid, token: token, favIndex: favIndex)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.fetchGalleryDetail(gid: gid))
                }
                sToken.unseal()
            } receiveValue: { _ in }
            .seal(in: sToken)
    }
}

struct DeleteFavoriteCommand: AppCommand {
    let gid: String

    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        DeleteFavoriteRequest(gid: gid)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.fetchGalleryDetail(gid: gid))
                }
                sToken.unseal()
            } receiveValue: { _ in }
            .seal(in: sToken)
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
                store.dispatch(.fetchGalleryDetail(gid: String(gid)))
            }
            sToken.unseal()
        } receiveValue: { _ in }
        .seal(in: sToken)
    }
}

struct CommentCommand: AppCommand {
    let gid: String
    let content: String
    let galleryURL: String

    func execute(in store: Store) {
        let token = SubscriptionToken()
        CommentRequest(content: content, galleryURL: galleryURL)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .finished = completion {
                    store.dispatch(.fetchGalleryDetail(gid: gid))
                }
                token.unseal()
            } receiveValue: { _ in }
            .seal(in: token)
    }
}

struct EditCommentCommand: AppCommand {
    let gid: String
    let commentID: String
    let content: String
    let galleryURL: String

    func execute(in store: Store) {
        let token = SubscriptionToken()
        EditCommentRequest(
            commentID: commentID,
            content: content,
            galleryURL: galleryURL
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .finished = completion {
                store.dispatch(.fetchGalleryDetail(gid: gid))
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
                store.dispatch(.fetchGalleryDetail(gid: String(gid)))
            }
            sToken.unseal()
        } receiveValue: { _ in }
        .seal(in: sToken)
    }
}

final class SubscriptionToken {
    var cancellable: AnyCancellable?
    func unseal() { cancellable = nil }
}

extension AnyCancellable {
    func seal(in token: SubscriptionToken) {
        token.cancellable = self
    }
}
