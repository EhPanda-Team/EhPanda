//
//  AppCommand.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Combine
import Foundation

protocol AppCommand {
    func execute(in store: Store)
}

struct FetchSearchItemsCommand: AppCommand {
    let keyword: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        SearchItemsRequest(keyword: keyword)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { complete in
                if case .failure(let error) = complete {
                    store.dispatch(.fetchSearchItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchSearchItemsDone(result: .success(mangas)))
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
            .sink { complete in
                if case .failure(let error)  = complete {
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
            .sink { complete in
                if case .failure(let error)  = complete {
                    store.dispatch(.fetchFavoritesItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchFavoritesItemsDone(result: .success(mangas)))
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
            .sink { complete in
                if case .failure(let error) = complete {
                    store.dispatch(.fetchMangaDetailDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { detail in
                if let detail = detail {
                    store.dispatch(.fetchMangaDetailDone(result: .success((detail, id))))
                } else {
                    store.dispatch(.fetchMangaDetailDone(result: .failure(.networkingFailed)))
                }
            }
            .seal(in: token)
    }
}

//struct FetchMangaContentsCommand: AppCommand {
//    let id: String
//    let pages: Int
//    let detailURL: String
//    
//    func execute(in store: Store) {
//        let token = SubscriptionToken()
//        MangaContentsRequest(pages: pages, detailURL: detailURL)
//            .publisher
//            .receive(on: DispatchQueue.main)
//            .sink { complete in
//                if case .failure(let error) = complete {
//                    store.dispatch(.fetchMangaContentsDone(result: .failure(error)))
//                }
//                token.unseal()
//            } receiveValue: { contents in
//                if let contents = contents {
//                    store.dispatch(.fetchMangaContentsDone(result: .success((contents, id))))
//                } else {
//                    store.dispatch(.fetchMangaContentsDone(result: .failure(.networkingFailed)))
//                }
//            }
//            .seal(in: token)
//    }
//}

struct AddFavoriteCommand: AppCommand {
    let id: String
    let token: String
    
    func execute(in store: Store) {
        let sToken = SubscriptionToken()
        AddFavoriteRequest(id: id, token: token)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { complete in
                if case .finished = complete {
                    store.dispatch(.fetchFavoritesItems)
                }
                sToken.unseal()
            } receiveValue: { value in
                print(value)
            }
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
            .sink { complete in
                if case .finished = complete {
                    store.dispatch(.fetchFavoritesItems)
                }
                sToken.unseal()
            } receiveValue: { value in
                print(value)
            }
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
