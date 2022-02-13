//
//  DatabaseClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import Combine
import CoreData
import ComposableArchitecture

struct DatabaseClient {
    let prepareDatabase: () -> Effect<Result<Void, AppError>, Never>
    let dropDatabase: () -> Effect<Result<Void, AppError>, Never>
    private let saveContext: () -> Void
    private let materializedObjects: (NSManagedObjectContext, NSPredicate) -> [NSManagedObject]
}

extension DatabaseClient {
    static let live: Self = .init(
        prepareDatabase: {
            Future { promise in
                PersistenceController.shared.prepare(completion: promise)
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        },
        dropDatabase: {
            Future { promise in
                PersistenceController.shared.rebuild(completion: promise)
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        },
        saveContext: {
            let context = PersistenceController.shared.container.viewContext
            AppUtil.dispatchMainSync {
                guard context.hasChanges else { return }
                do {
                    try context.save()
                } catch {
                    Logger.error(error)
                    fatalError("Unresolved error \(error)")
                }
            }
        },
        materializedObjects: { context, predicate in
            var objects = [NSManagedObject]()
            for object in context.registeredObjects where !object.isFault {
                guard object.entity.attributesByName.keys.contains("gid"),
                      predicate.evaluate(with: object)
                else { continue }
                objects.append(object)
            }
            return objects
        }
    )
}

// MARK: Foundation
extension DatabaseClient {
    private func batchFetch<MO: NSManagedObject>(
        entityType: MO.Type, fetchLimit: Int = 0, predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true, sortDescriptors: [NSSortDescriptor]? = nil
    ) -> [MO] {
        var results = [MO]()
        let context = PersistenceController.shared.container.viewContext
        AppUtil.dispatchMainSync {
            if findBeforeFetch, let predicate = predicate {
                if let objects = materializedObjects(context, predicate) as? [MO], !objects.isEmpty {
                    results = objects
                    return
                }
            }
            let request = NSFetchRequest<MO>(
                entityName: String(describing: entityType)
            )
            request.predicate = predicate
            request.fetchLimit = fetchLimit
            request.sortDescriptors = sortDescriptors
            results = (try? context.fetch(request)) ?? []
        }
        return results
    }

    private func fetch<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true, commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        let managedObject = batchFetch(
            entityType: entityType, fetchLimit: 1,
            predicate: predicate, findBeforeFetch: findBeforeFetch
        ).first
        commitChanges?(managedObject)
        return managedObject
    }

    private func fetchOrCreate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO {
        if let storedMO = fetch(
            entityType: entityType, predicate: predicate, commitChanges: commitChanges
        ) {
            return storedMO
        } else {
            let newMO = MO(context: PersistenceController.shared.container.viewContext)
            commitChanges?(newMO)
            saveContext()
            return newMO
        }
    }

    private func batchUpdate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil, commitChanges: ([MO]) -> Void
    ) {
        commitChanges(batchFetch(
            entityType: entityType,
            predicate: predicate,
            findBeforeFetch: false
        ))
        saveContext()
    }
    private func update<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil,
        createIfNil: Bool = false, commitChanges: (MO) -> Void
    ) {
        AppUtil.dispatchMainSync {
            let storedMO: MO?
            if createIfNil {
                storedMO = fetchOrCreate(entityType: entityType, predicate: predicate)
            } else {
                storedMO = fetch(entityType: entityType, predicate: predicate)
            }
            if let storedMO = storedMO {
                commitChanges(storedMO)
                saveContext()
            }
        }
    }
}

// MARK: GalleryIdentifiable
extension DatabaseClient {
    private func fetch<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String,
        findBeforeFetch: Bool = true,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        fetch(
            entityType: entityType, predicate: NSPredicate(format: "gid == %@", gid),
            findBeforeFetch: findBeforeFetch, commitChanges: commitChanges
        )
    }
    private func fetchOrCreate<MO: GalleryIdentifiable>(entityType: MO.Type, gid: String) -> MO {
        fetchOrCreate(
            entityType: entityType,
            predicate: NSPredicate(format: "gid == %@", gid),
            commitChanges: { $0?.gid = gid }
        )
    }
    private func update<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String,
        createIfNil: Bool = false,
        commitChanges: @escaping ((MO) -> Void)
    ) {
        AppUtil.dispatchMainSync {
            let storedMO: MO?
            if createIfNil {
                storedMO = fetchOrCreate(entityType: entityType, gid: gid)
            } else {
                storedMO = fetch(entityType: entityType, gid: gid)
            }
            if let storedMO = storedMO {
                commitChanges(storedMO)
                saveContext()
            }
        }
    }
}

// MARK: Fetch
extension DatabaseClient {
    func fetchGallery(gid: String) -> Gallery? {
        guard gid.isValidGID else { return nil }
        var entity: Gallery?
        AppUtil.dispatchMainSync {
            entity = fetch(entityType: GalleryMO.self, gid: gid)?.toEntity()
        }
        return entity
    }
    func fetchGalleryDetail(gid: String) -> GalleryDetail? {
        guard gid.isValidGID else { return nil }
        var entity: GalleryDetail?
        AppUtil.dispatchMainSync {
            entity = fetch(entityType: GalleryDetailMO.self, gid: gid)?.toEntity()
        }
        return entity
    }
    func fetchAppEnv() -> Effect<AppEnv, Never> {
        Future { promise in
            DispatchQueue.main.async {
                promise(.success(fetchOrCreate(entityType: AppEnvMO.self).toEntity()))
            }
        }
        .eraseToAnyPublisher()
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
    }
    func fetchAppEnvSynchronously() -> AppEnv {
        fetchOrCreate(entityType: AppEnvMO.self).toEntity()
    }
    func fetchGalleryState(gid: String) -> Effect<GalleryState, Never> {
        guard gid.isValidGID else { return .none }
        return Future { promise in
            DispatchQueue.main.async {
                promise(.success(
                    fetchOrCreate(entityType: GalleryStateMO.self, gid: gid).toEntity()
                ))
            }
        }
        .eraseToAnyPublisher()
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
    }
    func fetchHistoryGalleries(fetchLimit: Int = 0) -> Effect<[Gallery], Never> {
        Future { promise in
            DispatchQueue.main.async {
                let predicate = NSPredicate(format: "lastOpenDate != nil")
                let sortDescriptor = NSSortDescriptor(
                    keyPath: \GalleryMO.lastOpenDate, ascending: false
                )
                let galleries = batchFetch(
                    entityType: GalleryMO.self, fetchLimit: fetchLimit, predicate: predicate,
                    findBeforeFetch: false, sortDescriptors: [sortDescriptor]
                )
                .map { $0.toEntity() }
                promise(.success(galleries))
            }
        }
        .eraseToAnyPublisher()
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
    }
}
// MARK: FetchAccessor
extension DatabaseClient {
    func fetchFilterSynchronously(range: FilterRange) -> Filter {
        switch range {
        case .search:
            return fetchAppEnvSynchronously().searchFilter
        case .global:
            return fetchAppEnvSynchronously().globalFilter
        case .watched:
            return fetchAppEnvSynchronously().watchedFilter
        }
    }
    func fetchHistoryKeywords() -> Effect<[String], Never> {
        fetchAppEnv().map(\.historyKeywords)
    }
    func fetchQuickSearchWords() -> Effect<[QuickSearchWord], Never> {
        fetchAppEnv().map(\.quickSearchWords)
    }
    func fetchGalleryPreviewURLs(gid: String) -> Effect<[Int: URL], Never> {
        guard gid.isValidGID else { return .none }
        return fetchGalleryState(gid: gid).map(\.previewURLs)
    }
}

// MARK: UpdateGallery
extension DatabaseClient {
    func updateGallery(gid: String, key: String, value: Any?) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return .fireAndForget {
            DispatchQueue.main.async {
                update(
                    entityType: GalleryMO.self, gid: gid, createIfNil: true,
                    commitChanges: { $0.setValue(value, forKeyPath: key) }
                )
            }
        }
    }
    func updateLastOpenDate(gid: String, date: Date = .now) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGallery(gid: gid, key: "lastOpenDate", value: date)
    }
    func clearHistoryGalleries() -> Effect<Never, Never> {
        .fireAndForget {
            DispatchQueue.main.async {
                let predicate = NSPredicate(format: "lastOpenDate != nil")
                batchUpdate(entityType: GalleryMO.self, predicate: predicate) { galleryMOs in
                    galleryMOs.forEach { galleryMO in
                        galleryMO.lastOpenDate = nil
                    }
                }
            }
        }
    }
    func cacheGalleries(_ galleries: [Gallery]) -> Effect<Never, Never> {
        .fireAndForget {
            DispatchQueue.main.async {
                for gallery in galleries.filter({ $0.id.isValidGID }) {
                    let storedMO = fetch(
                        entityType: GalleryMO.self, gid: gallery.gid
                    ) { managedObject in
                        managedObject?.category = gallery.category.rawValue
                        managedObject?.coverURL = gallery.coverURL
                        managedObject?.galleryURL = gallery.galleryURL
                        // managedObject?.lastOpenDate = gallery.lastOpenDate
                        managedObject?.pageCount = Int64(gallery.pageCount)
                        managedObject?.postedDate = gallery.postedDate
                        managedObject?.rating = gallery.rating
                        managedObject?.tags = gallery.tags.toData()
                        managedObject?.title = gallery.title
                        managedObject?.token = gallery.token
                        if let uploader = gallery.uploader {
                            managedObject?.uploader = uploader
                        }
                    }
                    if storedMO == nil {
                        gallery.toManagedObject(in: PersistenceController.shared.container.viewContext)
                    }
                }
                saveContext()
            }
        }
    }
}

// MARK: UpdateGalleryDetail
extension DatabaseClient {
    func cacheGalleryDetail(_ detail: GalleryDetail) -> Effect<Never, Never> {
        guard detail.gid.isValidGID else { return .none }
        return .fireAndForget {
            DispatchQueue.main.async {
                let storedMO = fetch(
                    entityType: GalleryDetailMO.self, gid: detail.gid
                ) { managedObject in
                    managedObject?.archiveURL = detail.archiveURL
                    managedObject?.category = detail.category.rawValue
                    managedObject?.coverURL = detail.coverURL
                    managedObject?.isFavorited = detail.isFavorited
                    managedObject?.visibility = detail.visibility.toData()
                    managedObject?.jpnTitle = detail.jpnTitle
                    managedObject?.language = detail.language.rawValue
                    managedObject?.favoritedCount = Int64(detail.favoritedCount)
                    managedObject?.pageCount = Int64(detail.pageCount)
                    managedObject?.parentURL = detail.parentURL
                    managedObject?.postedDate = detail.postedDate
                    managedObject?.rating = detail.rating
                    managedObject?.userRating = detail.userRating
                    managedObject?.ratingCount = Int64(detail.ratingCount)
                    managedObject?.sizeCount = detail.sizeCount
                    managedObject?.sizeType = detail.sizeType
                    managedObject?.title = detail.title
                    managedObject?.torrentCount = Int64(detail.torrentCount)
                    managedObject?.uploader = detail.uploader
                }
                if storedMO == nil {
                    detail.toManagedObject(in: PersistenceController.shared.container.viewContext)
                }
                saveContext()
            }
        }
    }
}

// MARK: UpdateGalleryState
extension DatabaseClient {
    func updateGalleryState(gid: String, commitChanges: @escaping (GalleryStateMO) -> Void) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return .fireAndForget {
            DispatchQueue.main.async {
                update(
                    entityType: GalleryStateMO.self, gid: gid, createIfNil: true,
                    commitChanges: commitChanges
                )
            }
        }
    }
    func updateGalleryState(gid: String, key: String, value: Any?) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid) { stateMO in
            stateMO.setValue(value, forKeyPath: key)
        }
    }
    func updateGalleryTags(gid: String, tags: [GalleryTag]) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid, key: "tags", value: tags.toData())
    }
    func updatePreviewConfig(gid: String, config: PreviewConfig) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid, key: "previewConfig", value: config.toData())
    }
    func updateReadingProgress(gid: String, progress: Int) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid, key: "readingProgress", value: Int64(progress))
    }
    func updateComments(gid: String, comments: [GalleryComment]) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid, key: "comments", value: comments.toData())
    }

    func removeImageURLs(gid: String) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid) { galleryStateMO in
            galleryStateMO.imageURLs = nil
            galleryStateMO.previewURLs = nil
            galleryStateMO.thumbnailURLs = nil
            galleryStateMO.originalImageURLs = nil
        }
    }
    func removeImageURLs() -> Effect<Never, Never> {
        .fireAndForget {
            DispatchQueue.main.async {
                batchUpdate(entityType: GalleryStateMO.self) { galleryStateMOs in
                    galleryStateMOs.forEach { galleryStateMO in
                        galleryStateMO.imageURLs = nil
                        galleryStateMO.previewURLs = nil
                        galleryStateMO.thumbnailURLs = nil
                        galleryStateMO.originalImageURLs = nil
                    }
                }
            }
        }
    }
    func removeExpiredImageURLs() -> Effect<Never, Never> {
        fetchHistoryGalleries()
            .map { $0.filter { Date().timeIntervalSince($0.lastOpenDate ?? .distantPast) > .oneWeek } }
            .map { $0.map { removeImageURLs(gid: $0.id) } }
            .map(Effect<Never, Never>.merge)
            .fireAndForget()
    }
    func updateThumbnailURLs(gid: String, thumbnailURLs: [Int: URL]) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.thumbnailURLs, new: thumbnailURLs)
        }
    }
    func updateImageURLs(
        gid: String, imageURLs: [Int: URL], originalImageURLs: [Int: URL]
    ) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.imageURLs, new: imageURLs)
            update(gid: gid, storedData: &galleryStateMO.originalImageURLs, new: originalImageURLs)
        }
    }
    func updatePreviewURLs(gid: String, previewURLs: [Int: URL]) -> Effect<Never, Never> {
        guard gid.isValidGID else { return .none }
        return updateGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.previewURLs, new: previewURLs)
        }
    }

    private func update<T: Codable>(
        gid: String, storedData: inout Data?, new: [Int: T]
    ) {
        guard !new.isEmpty, gid.isValidGID else { return }

        if let storedDictionary = storedData?.toObject() as [Int: T]? {
            storedData = storedDictionary.merging(
                new, uniquingKeysWith: { _, new in new }
            ).toData()
        } else {
            storedData = new.toData()
        }
    }
}

// MARK: UpdateAppEnv
extension DatabaseClient {
    func updateAppEnv(key: String, value: Any?) -> Effect<Never, Never> {
        .fireAndForget {
            DispatchQueue.main.async {
                update(
                    entityType: AppEnvMO.self, createIfNil: true,
                    commitChanges: { $0.setValue(value, forKeyPath: key) }
                )
            }
        }
    }
    func updateSetting(_ setting: Setting) -> Effect<Never, Never> {
        updateAppEnv(key: "setting", value: setting.toData())
    }
    func updateFilter(_ filter: Filter, range: FilterRange) -> Effect<Never, Never> {
        let key: String
        switch range {
        case .search:
            key = "searchFilter"
        case .global:
            key = "globalFilter"
        case .watched:
            key = "watchedFilter"
        }
        return updateAppEnv(key: key, value: filter.toData())
    }
    func updateTagTranslator(_ tagTranslator: TagTranslator) -> Effect<Never, Never> {
        updateAppEnv(key: "tagTranslator", value: tagTranslator.toData())
    }
    func updateUser(_ user: User) -> Effect<Never, Never> {
        updateAppEnv(key: "user", value: user.toData())
    }
    func updateHistoryKeywords(_ keywords: [String]) -> Effect<Never, Never> {
        updateAppEnv(key: "historyKeywords", value: keywords.toData())
    }
    func updateQuickSearchWords(_ words: [QuickSearchWord]) -> Effect<Never, Never> {
        updateAppEnv(key: "quickSearchWords", value: words.toData())
    }

    // Update User
    func updateUserProperty(_ commitChanges: @escaping (inout User) -> Void) -> Effect<Never, Never> {
        fetchAppEnv().map(\.user)
            .map { (user: User) -> User in
                var user = user
                commitChanges(&user)
                return user
            }
            .flatMap(updateUser)
            .eraseToEffect()
    }
    func updateGreeting(_ greeting: Greeting) -> Effect<Never, Never> {
        updateUserProperty { user in
            user.greeting = greeting
        }
    }
    func updateGalleryFunds(galleryPoints: String, credits: String) -> Effect<Never, Never> {
        updateUserProperty { user in
            user.credits = credits
            user.galleryPoints = galleryPoints
        }
    }
}
