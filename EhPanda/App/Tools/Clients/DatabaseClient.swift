//
//  DatabaseClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct DatabaseClient {
    let fetchAppEnv: () -> AppEnv
    let updateAppEnv: (String, Data?) -> Void
    let removeImageURLs: () -> Effect<Never, Never>
    let cacheGalleries: ([Gallery]) -> Effect<Never, Never>
    let fetchHistoryGalleries: () -> Effect<[Gallery], Never>
    let clearHistoryGalleries: () -> Effect<Never, Never>
}

extension DatabaseClient {
    static let live: Self = .init(
        fetchAppEnv: {
            PersistenceController.fetchAppEnvNonNil()
        },
        updateAppEnv: { key, data in
            PersistenceController.update { appEnvMO in
                appEnvMO.setValue(data, forKeyPath: key)
            }
        },
        removeImageURLs: {
            .fireAndForget {
                PersistenceController.removeImageURLs()
            }
        },
        cacheGalleries: { galleries in
            .fireAndForget {
                PersistenceController.add(galleries: galleries)
            }
        },
        fetchHistoryGalleries: {
            Future { promise in
                DispatchQueue.global().async {
                    promise(.success(PersistenceController.fetchGalleryHistory()))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
        },
        clearHistoryGalleries: {
            .fireAndForget {
                PersistenceController.clearHistoryGalleries()
            }
        }
    )

    func updateSetting(_ setting: Setting) -> Effect<Never, Never> {
        .fireAndForget {
            updateAppEnv("setting", setting.toData())
        }
    }
    func updateSearchFilter(_ filter: Filter) -> Effect<Never, Never> {
        .fireAndForget {
            updateAppEnv("searchFilter", filter.toData())
        }
    }
    func updateGlobalFilter(_ filter: Filter) -> Effect<Never, Never> {
        .fireAndForget {
            updateAppEnv("globalFilter", filter.toData())
        }
    }
    func updateWatchedFilter(_ filter: Filter) -> Effect<Never, Never> {
        .fireAndForget {
            updateAppEnv("watchedFilter", filter.toData())
        }
    }
    func updateTagTranslator(_ tagTranslator: TagTranslator) -> Effect<Never, Never> {
        .fireAndForget {
            updateAppEnv("tagTranslator", tagTranslator.toData())
        }
    }
    func updateUser(_ user: User) -> Effect<Never, Never> {
        .fireAndForget {
            updateAppEnv("user", user.toData())
        }
    }
}
