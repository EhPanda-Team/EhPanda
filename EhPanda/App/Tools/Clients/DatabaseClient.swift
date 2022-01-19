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
    let fetchGallery: (String) -> Gallery
    let fetchGalleryDetail: (String) -> GalleryDetail?
    let fetchAppEnv: () -> Effect<AppEnv, Never>
    let fetchGalleryState: (String) -> Effect<GalleryState, Never>

    let updateAppEnv: (String, Any?) -> Effect<Never, Never>
    let updateGallery: (String, String, Any?) -> Effect<Never, Never>
    let updateGalleryState: (String, String, Any?) -> Effect<Never, Never>
    let cacheGalleries: ([Gallery]) -> Effect<Never, Never>
    let cacheGalleryDetail: (GalleryDetail) -> Effect<Never, Never>

    let removeImageURLs: () -> Effect<Never, Never>
    let fetchHistoryGalleries: (Int?) -> Effect<[Gallery], Never>
    let clearHistoryGalleries: () -> Effect<Never, Never>
}

extension DatabaseClient {
    static let live: Self = .init(
        fetchGallery: { gid in
            PersistenceController.fetchGalleryNonNil(gid: gid)
        },
        fetchGalleryDetail: { gid in
            PersistenceController.fetchGalleryDetail(gid: gid)
        },
        fetchAppEnv: {
            Future { promise in
                DispatchQueue.main.async {
                    promise(.success(PersistenceController.fetchAppEnvNonNil()))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
        },
        fetchGalleryState: { gid in
            Future { promise in
                DispatchQueue.main.async {
                    promise(.success(PersistenceController.fetchGalleryStateNonNil(gid: gid)))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
        },
        updateAppEnv: { key, data in
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.updateAppEnv { appEnvMO in
                        appEnvMO.setValue(data, forKeyPath: key)
                    }
                }
            }
        },
        updateGallery: { gid, key, value in
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.updateGallery(gid: gid) { galleryMO in
                        galleryMO.setValue(value, forKeyPath: key)
                    }
                }
            }
        },
        updateGalleryState: { gid, key, value in
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.update(gid: gid) { stateMO in
                        stateMO.setValue(value, forKeyPath: key)
                    }
                }
            }
        },
        cacheGalleries: { galleries in
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.add(galleries: galleries)
                }
            }
        },
        cacheGalleryDetail: { detail in
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.add(detail: detail)
                }
            }
        },
        removeImageURLs: {
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.removeImageURLs()
                }
            }
        },
        fetchHistoryGalleries: { fetchLimit in
            Future { promise in
                DispatchQueue.main.async {
                    promise(.success(PersistenceController.fetchGalleryHistory(fetchLimit: fetchLimit ?? 0)))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
        },
        clearHistoryGalleries: {
            .fireAndForget {
                DispatchQueue.main.async {
                    PersistenceController.clearHistoryGalleries()
                }
            }
        }
    )

    func checkGalleryExistence(gid: String) -> Bool {
        PersistenceController.checkExistence(
            entityType: GalleryMO.self, predicate: NSPredicate(format: "gid == %@", gid)
        )
    }

    func updateGreeting(_ greeting: Greeting) -> Effect<Never, Never> {
        fetchAppEnv().map(\.user)
            .map { (user: User) -> User in
                var user = user
                user.greeting = greeting
                return user
            }
            .flatMap(updateUser)
            .eraseToEffect()
    }
    func updateGalleryFunds(galleryPoints: String, credits: String) -> Effect<Never, Never> {
        fetchAppEnv().map(\.user)
            .map { (user: User) -> User in
                var user = user
                user.credits = credits
                user.galleryPoints = galleryPoints
                return user
            }
            .flatMap(updateUser)
            .eraseToEffect()
    }
    func fetchHistoryKeywords() -> Effect<[String], Never> {
        fetchAppEnv().map(\.historyKeywords)
    }
    func fetchGalleryPreviews(gid: String) -> Effect<[Int: String], Never> {
        fetchGalleryState(gid).map(\.previews)
    }

    func updateSetting(_ setting: Setting) -> Effect<Never, Never> {
        updateAppEnv("setting", setting.toData())
    }
    func updateSearchFilter(_ filter: Filter) -> Effect<Never, Never> {
        updateAppEnv("searchFilter", filter.toData())
    }
    func updateGlobalFilter(_ filter: Filter) -> Effect<Never, Never> {
        updateAppEnv("globalFilter", filter.toData())
    }
    func updateWatchedFilter(_ filter: Filter) -> Effect<Never, Never> {
        updateAppEnv("watchedFilter", filter.toData())
    }
    func updateTagTranslator(_ tagTranslator: TagTranslator) -> Effect<Never, Never> {
        updateAppEnv("tagTranslator", tagTranslator.toData())
    }
    func updateUser(_ user: User) -> Effect<Never, Never> {
        updateAppEnv("user", user.toData())
    }
    func updateHistoryKeywords(_ keywords: [String]) -> Effect<Never, Never> {
        updateAppEnv("historyKeywords", keywords.toData())
    }

    func updateLastOpenDate(gid: String, date: Date = .now) -> Effect<Never, Never> {
        updateGallery(gid, "lastOpenDate", date)
    }

    func updateGalleryTags(gid: String, tags: [GalleryTag]) -> Effect<Never, Never> {
        updateGalleryState(gid, "tags", tags.toData())
    }
    func updatePreviewConfig(gid: String, config: PreviewConfig) -> Effect<Never, Never> {
        updateGalleryState(gid, "previewConfig", config.toData())
    }
    func updateReadingProgress(gid: String, progress: Int) -> Effect<Never, Never> {
        updateGalleryState(gid, "readingProgress", Int64(progress))
    }
    func updateGalleryPreviews(gid: String, previews: [Int: String]) -> Effect<Never, Never> {
        .fireAndForget {
            PersistenceController.update(gid: gid) { galleryStateMO in
                if let storedPreviews = galleryStateMO.previews?.toObject() as [Int: String]? {
                    galleryStateMO.previews = storedPreviews.merging(
                        previews, uniquingKeysWith: { _, new in new }
                    ).toData()
                } else {
                    galleryStateMO.previews = previews.toData()
                }
            }
        }
    }
    func updateGalleryComments(gid: String, comments: [GalleryComment]) -> Effect<Never, Never> {
        updateGalleryState(gid, "comments", comments.toData())
    }
}
