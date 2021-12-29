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
    func execute(in store: DeprecatedStore)
}

struct FetchGreetingCommand: AppCommand {
    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GreetingRequest().publisher
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

struct FetchTagTranslatorCommand: AppCommand {
    let language: TranslatableLanguage
    let updatedDate: Date

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        TagTranslatorRequest(language: language, updatedDate: updatedDate)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GalleryItemReverseRequest(url: url, shouldParseGalleryURL: shouldParseGalleryURL)
            .publisher.receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    store.dispatch(.fetchGalleryItemReverseDone(carriedValue: gid, result: .failure(error)))
                case .finished:
                    store.dispatch(.fetchGalleryItemReverseDone(carriedValue: gid, result: .failure(.networkingFailed)))
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
    var pageNum: Int?

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        SearchItemsRequest(keyword: keyword, filter: filter, pageNum: pageNum)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
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
    let filter: Filter
    var pageNum: Int?

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        FrontpageItemsRequest(filter: filter, pageNum: pageNum).publisher
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
    let filter: Filter
    let lastID: String
    let pageNum: Int

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        MoreFrontpageItemsRequest(filter: filter, lastID: lastID, pageNum: pageNum)
            .publisher.receive(on: DispatchQueue.main)
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
    let filter: Filter
    var pageNum: Int?

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        PopularItemsRequest(filter: filter).publisher
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
    let filter: Filter
    var pageNum: Int?

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        WatchedItemsRequest(filter: filter, pageNum: pageNum).publisher
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
    let filter: Filter
    let lastID: String
    let pageNum: Int

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        MoreWatchedItemsRequest(filter: filter, lastID: lastID, pageNum: pageNum)
            .publisher.receive(on: DispatchQueue.main)
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

struct FetchToplistsItemsCommand: AppCommand {
    let topIndex: Int
    let catIndex: Int
    var pageNum: Int?

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        ToplistsItemsRequest(catIndex: catIndex, pageNum: pageNum)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        MoreToplistsItemsRequest(catIndex: catIndex, pageNum: pageNum)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GalleryDetailRequest(gid: gid, galleryURL: galleryURL)
            .publisher.receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryDetailDone(gid: gid, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { (detail, state, apiKey, greeting) in
                store.dispatch(.fetchGalleryDetailDone(gid: gid, result: .success((detail, state, apiKey, greeting))))
            }
            .seal(in: token)
    }
}

struct FetchGalleryArchiveFundsCommand: AppCommand {
    let gid: String
    let galleryURL: String

    func execute(in store: DeprecatedStore) {
        let sToken = SubscriptionToken()
        GalleryArchiveFundsRequest(gid: gid, galleryURL: galleryURL)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GalleryPreviewsRequest(url: url).publisher
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

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        MPVKeysRequest(mpvURL: mpvURL).publisher
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

struct FetchThumbnailsCommand: AppCommand {
    let gid: String
    let index: Int
    let url: String

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        ThumbnailsRequest(url: url).publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchThumbnailsDone(gid: gid, index: index, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { urls in
                if !urls.isEmpty {
                    store.dispatch(.fetchThumbnailsDone(gid: gid, index: index, result: .success(urls)))
                } else {
                    store.dispatch(.fetchThumbnailsDone(gid: gid, index: index, result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
}

struct FetchGalleryNormalContentsCommand: AppCommand {
    let gid: String
    let index: Int
    let thumbnails: [Int: String]

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GalleryNormalContentsRequest(thumbnails: thumbnails)
            .publisher.receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    store.dispatch(.fetchGalleryNormalContentsDone(gid: gid, index: index, result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { contents, originalContents in
                if !contents.isEmpty {
                    store.dispatch(.fetchGalleryNormalContentsDone(
                        gid: gid, index: index, result: .success((contents, originalContents))
                    ))
                } else {
                    store.dispatch(.fetchGalleryNormalContentsDone(
                        gid: gid, index: index, result: .failure(.networkingFailed))
                    )
                }
            }
            .seal(in: token)
    }
}

struct RefetchGalleryNormalContentCommand: AppCommand {
    let gid: String
    let index: Int
    let galleryURL: String
    let thumbnailURL: String?
    let storedImageURL: String
    let bypassesSNIFiltering: Bool

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GalleryNormalContentRefetchRequest(
            index: index, galleryURL: galleryURL,
            thumbnailURL: thumbnailURL,
            storedImageURL: storedImageURL,
            bypassesSNIFiltering: bypassesSNIFiltering
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .failure(let error) = completion {
                store.dispatch(.refetchGalleryNormalContentDone(gid: gid, index: index, result: .failure(error)))
            }
            token.unseal()
        } receiveValue: { content in
            if !content.isEmpty {
                store.dispatch(.refetchGalleryNormalContentDone(gid: gid, index: index, result: .success(content)))
            } else {
                store.dispatch(.refetchGalleryNormalContentDone(
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
    let reloadToken: ReloadToken?

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        GalleryMPVContentRequest(
            gid: gid, index: index, mpvKey: mpvKey, imgKey: imgKey, reloadToken: reloadToken
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
    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        IgneousRequest().publisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                token.unseal()
            } receiveValue: { _ in }
            .seal(in: token)
    }
}

struct CreateEhProfileCommand: AppCommand {
    let name: String

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        EhProfileRequest(action: .create, name: name)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
        let sToken = SubscriptionToken()
        AddFavoriteRequest(gid: gid, token: token, favIndex: favIndex)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
        let sToken = SubscriptionToken()
        DeleteFavoriteRequest(gid: gid).publisher
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

    func execute(in store: DeprecatedStore) {
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

    func execute(in store: DeprecatedStore) {
        let token = SubscriptionToken()
        CommentRequest(content: content, galleryURL: galleryURL)
            .publisher.receive(on: DispatchQueue.main)
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

    func execute(in store: DeprecatedStore) {
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

    func execute(in store: DeprecatedStore) {
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
