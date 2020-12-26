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

struct FetchSearchItemsCommand: AppCommand {
    let keyword: String
    
    func execute(in store: Store) {
        let token = SubscriptionToken()
        SearchItemsRequest(keyword: keyword)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { complete in
                if case .failure(let error)  = complete {
                    store.dispatch(.fetchSearchItemsDone(result: .failure(error)))
                }
                token.unseal()
            } receiveValue: { mangas in
                store.dispatch(.fetchSearchItemsDone(result: .success(mangas)))
            }
            .seal(in: token)
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
