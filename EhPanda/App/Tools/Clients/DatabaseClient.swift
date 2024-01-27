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
    let prepareDatabase: () async -> AppError?
    let dropDatabase: () async -> AppError?
    private let saveContext: () -> Void
    private let materializedObjects: (NSManagedObjectContext, NSPredicate) -> [NSManagedObject]
}

extension DatabaseClient {
    static let live: Self = .init(
        prepareDatabase: {
            await PersistenceController.shared.prepare()
        },
        dropDatabase: {
            await PersistenceController.shared.rebuild()
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
private extension DatabaseClient {
    @discardableResult
    func create<MO: NSManagedObject>(
        entityType: MO.Type,
        commitChanges: ((MO, NSManagedObjectContext) -> Void)? = nil
    ) async -> MO {
        let context = PersistenceController.shared.container.newBackgroundContext()
        return await context.perform {
            let newMO = entityType.init(context: context)
            commitChanges?(newMO, context)
            context.saveIfNeeded()
            return newMO
        }
    }

    @discardableResult
    func create<Model: ManagedObjectConvertible>(
        model: Model,
        commitChanges: ((Model.ManagedObject, NSManagedObjectContext) -> Void)? = nil
    ) async -> Model.ManagedObject {
        let context = PersistenceController.shared.container.newBackgroundContext()
        return await context.perform {
            let newMO = model.toManagedObject(in: context)
            commitChanges?(newMO, context)
            context.saveIfNeeded()
            return newMO
        }
    }

    func fetch<MO: NSManagedObject>(
        entityType: MO.Type,
        fetchLimit: Int = 0,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async -> [MO] {
        let context = PersistenceController.shared.container.newBackgroundContext()
        let request = NSFetchRequest<MO>(entityName: String(describing: entityType))
        request.predicate = predicate
        request.fetchLimit = fetchLimit
        request.sortDescriptors = sortDescriptors
        return await context.perform {
            (try? context.fetch(request)) ?? []
        }
    }

    func fetchModel<MO: NSManagedObject & ModelConvertible>(
        entityType: MO.Type,
        fetchLimit: Int = 0,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async -> [MO.Model] {
        let context = PersistenceController.shared.container.newBackgroundContext()
        let request = NSFetchRequest<MO>(entityName: String(describing: entityType))
        request.predicate = predicate
        request.fetchLimit = fetchLimit
        request.sortDescriptors = sortDescriptors
        return await context.perform {
            let result = (try? context.fetch(request)) ?? []
            return result.compactMap({ $0.toModel() })
        }
    }

    func update<MO: NSManagedObject>(
        entityType: MO.Type,
        fetchLimit: Int = 0,
        predicate: NSPredicate? = nil,
        commitChanges: @escaping ([MO], NSManagedObjectContext) -> Void,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSOverwriteMergePolicy
        let request = NSFetchRequest<MO>(entityName: String(describing: entityType))
        request.predicate = predicate
        request.fetchLimit = fetchLimit
        request.sortDescriptors = sortDescriptors
        return await context.perform {
            let result = (try? context.fetch(request)) ?? []
            commitChanges(result, context)
            context.saveIfNeeded()
        }
    }

    func delete<MO: NSManagedObject>(
        entityType: MO.Type, fetchLimit: Int = 0, predicate: NSPredicate? = nil
    ) async {
        let context = PersistenceController.shared.container.viewContext

        let request = NSFetchRequest<MO>(entityName: String(describing: entityType))
        request.predicate = predicate
        request.fetchLimit = fetchLimit
        let mos = context.performAndWait {
            return (try? context.fetch(request)) ?? []
        }

        if let mo = mos.first {
            await context.perform {
                context.delete(mo)
                context.saveIfNeeded()
            }
        }
    }
}

// MARK: Accessor
private extension DatabaseClient {
    func fetchFirst<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil
    ) async -> MO? {
        await fetch(
            entityType: entityType,
            fetchLimit: 1,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )
        .first
    }

    func fetchFirstModel<MO: NSManagedObject & ModelConvertible>(
        entityType: MO.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil
    ) async -> MO.Model? {
        await fetchModel(
            entityType: entityType,
            fetchLimit: 1,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )
        .first
    }

    func updateFirst<MO: NSManagedObject>(
        entityType: MO.Type,
        predicate: NSPredicate? = nil,
        commitChanges: @escaping (MO) -> Void,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async {
        await update(
            entityType: entityType,
            fetchLimit: 1,
            predicate: predicate,
            commitChanges: { mos, _ in mos.first.map(commitChanges) },
            sortDescriptors: sortDescriptors
        )
    }

    func deleteFirst<MO: NSManagedObject>(entityType: MO.Type, predicate: NSPredicate? = nil) async {
        await delete(entityType: entityType, fetchLimit: 1, predicate: predicate)
    }
}

// MARK: GalleryIdentifiable
private extension DatabaseClient {
    func fetchFirst<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String, sortDescriptors: [NSSortDescriptor]? = nil
    ) async -> MO? {
        await fetchFirst(entityType: entityType, predicate: .init(gid: gid), sortDescriptors: sortDescriptors)
    }

    func fetchFirstModel<MO: GalleryIdentifiable & ModelConvertible>(
        entityType: MO.Type, gid: String, sortDescriptors: [NSSortDescriptor]? = nil
    ) async -> MO.Model? {
        await fetchFirstModel(entityType: entityType, predicate: .init(gid: gid), sortDescriptors: sortDescriptors)
    }

    func updateFirst<MO: GalleryIdentifiable>(
        entityType: MO.Type,
        gid: String,
        commitChanges: @escaping ((MO) -> Void),
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async {
        await updateFirst(
            entityType: entityType,
            predicate: .init(gid: gid),
            commitChanges: commitChanges,
            sortDescriptors: sortDescriptors
        )
    }
}

// MARK: Fetch
extension DatabaseClient {
    func fetchGallery(gid: String) async -> Gallery? {
        guard gid.isValidGID else { return nil }
        return await fetchFirstModel(entityType: GalleryMO.self, gid: gid)
    }

    func fetchGalleryDetail(gid: String) async -> GalleryDetail? {
        guard gid.isValidGID else { return nil }
        return await fetchFirstModel(entityType: GalleryDetailMO.self, gid: gid)
    }
    func fetchAppEnv() async -> AppEnv {
        await fetchFirstModel(entityType: AppEnvMO.self) ?? .empty
    }

    func fetchGalleryState(gid: String) async -> GalleryState {
        guard gid.isValidGID else { return .empty(gid: gid) }
        return await fetchFirstModel(entityType: GalleryStateMO.self) ?? .empty(gid: gid)
    }
    func fetchHistoryGalleries(fetchLimit: Int = 0) async -> [Gallery] {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        let sortDescriptor = NSSortDescriptor(
            keyPath: \GalleryMO.lastOpenDate, ascending: false
        )
        return await fetchModel(
            entityType: GalleryMO.self, fetchLimit: fetchLimit, predicate: predicate, sortDescriptors: [sortDescriptor]
        )
    }
}
// MARK: FetchAccessor
extension DatabaseClient {
    func fetchFilter(range: FilterRange) async -> Filter {
        switch range {
        case .search:
            return await fetchAppEnv().searchFilter
        case .global:
            return await fetchAppEnv().globalFilter
        case .watched:
            return await fetchAppEnv().watchedFilter
        }
    }
    func fetchHistoryKeywords() async -> [String] {
        await fetchAppEnv().historyKeywords
    }
    func fetchQuickSearchWords() async -> [QuickSearchWord] {
        await fetchAppEnv().quickSearchWords
    }
    func fetchGalleryPreviewURLs(gid: String) async -> [Int: URL] {
        guard gid.isValidGID else { return .init() }
        return await fetchGalleryState(gid: gid).previewURLs
    }
}

// MARK: CacheGallery
extension DatabaseClient {
    func updateGallery(gid: String, key: String, value: Any?) async {
        guard gid.isValidGID else { return }
        await updateFirst(
            entityType: GalleryMO.self, gid: gid,
            commitChanges: { $0.setValue(value, forKeyPath: key) }
        )
    }
    func updateLastOpenDate(gid: String, date: Date = .now) async {
        guard gid.isValidGID else { return }
        await updateGallery(gid: gid, key: "lastOpenDate", value: date)
    }
    func clearHistoryGalleries() async {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        await update(entityType: GalleryMO.self, predicate: predicate) { galleryMOs, _ in
            galleryMOs.forEach { galleryMO in
                galleryMO.lastOpenDate = nil
            }
        }
    }
    func cacheGalleries(_ galleries: [Gallery]) async {
        await withTaskGroup(of: Void.self) { group in
            for gallery in galleries.filter({ $0.id.isValidGID }) {
                group.addTask {
                    if await fetchGallery(gid: gallery.gid) != nil {
                        await updateFirst(
                            entityType: GalleryMO.self, gid: gallery.gid
                        ) { managedObject in
                            managedObject.category = gallery.category.rawValue
                            managedObject.coverURL = gallery.coverURL
                            managedObject.galleryURL = gallery.galleryURL
                            // managedObject.lastOpenDate = gallery.lastOpenDate
                            managedObject.pageCount = Int64(gallery.pageCount)
                            managedObject.postedDate = gallery.postedDate
                            managedObject.rating = gallery.rating
                            managedObject.tags = gallery.tags.toData()
                            managedObject.title = gallery.title
                            managedObject.token = gallery.token
                            if let uploader = gallery.uploader {
                                managedObject.uploader = uploader
                            }
                        }
                    } else {
                        await create(model: gallery)
                    }
                }
            }
        }
    }
}

// MARK: CacheGalleryDetail
extension DatabaseClient {
    func cacheGalleryDetail(_ detail: GalleryDetail) async {
        guard detail.gid.isValidGID else { return }

        if await fetchFirstModel(entityType: GalleryDetailMO.self, gid: detail.gid) != nil {
            await updateFirst(
                entityType: GalleryDetailMO.self, gid: detail.gid
            ) { managedObject in
                managedObject.archiveURL = detail.archiveURL
                managedObject.category = detail.category.rawValue
                managedObject.coverURL = detail.coverURL
                managedObject.isFavorited = detail.isFavorited
                managedObject.visibility = detail.visibility.toData()
                managedObject.jpnTitle = detail.jpnTitle
                managedObject.language = detail.language.rawValue
                managedObject.favoritedCount = .init(detail.favoritedCount)
                managedObject.pageCount = .init(detail.pageCount)
                managedObject.parentURL = detail.parentURL
                managedObject.postedDate = detail.postedDate
                managedObject.rating = detail.rating
                managedObject.userRating = detail.userRating
                managedObject.ratingCount = .init(detail.ratingCount)
                managedObject.sizeCount = detail.sizeCount
                managedObject.sizeType = detail.sizeType
                managedObject.title = detail.title
                managedObject.torrentCount = .init(detail.torrentCount)
                managedObject.uploader = detail.uploader
            }
        } else {
            await create(model: detail)
        }
    }
}

// MARK: CacheGalleryState
extension DatabaseClient {
    func updateGalleryState(gid: String, commitChanges: @escaping (GalleryStateMO) -> Void) async {
        guard gid.isValidGID else { return }
        await updateFirst(entityType: GalleryStateMO.self, gid: gid, commitChanges: commitChanges)
    }

    func cacheGalleryState(gid: String, commitChanges: @escaping (GalleryStateMO) -> Void) async {
        guard gid.isValidGID else { return }
        if await fetchFirstModel(entityType: GalleryStateMO.self, gid: gid) != nil {
            await updateFirst(entityType: GalleryStateMO.self, gid: gid, commitChanges: commitChanges)
        } else {
            await create(entityType: GalleryStateMO.self, commitChanges: { mo, _ in commitChanges(mo) })
        }
    }

    func cacheGalleryState(gid: String, key: String, value: Any?) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid) { stateMO in
            stateMO.setValue(value, forKeyPath: key)
        }
    }

    func cacheGalleryTags(gid: String, tags: [GalleryTag]) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid, key: "tags", value: tags.toData())
    }
    func cachePreviewConfig(gid: String, config: PreviewConfig) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid, key: "previewConfig", value: config.toData())
    }
    func cacheReadingProgress(gid: String, progress: Int) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid, key: "readingProgress", value: Int64(progress))
    }
    func cacheComments(gid: String, comments: [GalleryComment]) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid, key: "comments", value: comments.toData())
    }
    func cacheThumbnailURLs(gid: String, thumbnailURLs: [Int: URL]) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.thumbnailURLs, new: thumbnailURLs)
        }
    }
    func cacheImageURLs(
        gid: String, imageURLs: [Int: URL], originalImageURLs: [Int: URL]
    ) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.imageURLs, new: imageURLs)
            update(gid: gid, storedData: &galleryStateMO.originalImageURLs, new: originalImageURLs)
        }
    }
    func cachePreviewURLs(gid: String, previewURLs: [Int: URL]) async {
        guard gid.isValidGID else { return }
        await cacheGalleryState(gid: gid) { galleryStateMO in
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

    func removeImageURLs(gid: String) async {
        guard gid.isValidGID else { return }
        await updateGalleryState(gid: gid) { galleryStateMO in
            galleryStateMO.imageURLs = nil
            galleryStateMO.previewURLs = nil
            galleryStateMO.thumbnailURLs = nil
            galleryStateMO.originalImageURLs = nil
        }
    }
    func removeImageURLs() async {
        await update(entityType: GalleryStateMO.self) { galleryStateMOs, _ in
            galleryStateMOs.forEach { galleryStateMO in
                galleryStateMO.imageURLs = nil
                galleryStateMO.previewURLs = nil
                galleryStateMO.thumbnailURLs = nil
                galleryStateMO.originalImageURLs = nil
            }
        }
    }
    func removeExpiredImageURLs() async {
        let galleries = await fetchHistoryGalleries()
            .filter({ Date().timeIntervalSince($0.lastOpenDate ?? .distantPast) > .oneWeek })

        await withTaskGroup(of: Void.self) { group in
            galleries.forEach { gallery in
                group.addTask {
                    await removeImageURLs(gid: gallery.id) }
            }
        }
    }
}

// MARK: CacheAppEnv
extension DatabaseClient {
    func cacheAppEnv(key: String, value: Any?) async {
        if await fetchFirstModel(entityType: AppEnvMO.self) != nil {
            await updateFirst(
                entityType: AppEnvMO.self,
                commitChanges: { mo in mo.setValue(value, forKeyPath: key) }
            )
        } else {
            await create(entityType: AppEnvMO.self)
        }
    }

    func cacheSetting(_ setting: Setting) async {
        await cacheAppEnv(key: "setting", value: setting.toData())
    }
    func cacheFilter(_ filter: Filter, range: FilterRange) async {
        let key: String
        switch range {
        case .search:
            key = "searchFilter"
        case .global:
            key = "globalFilter"
        case .watched:
            key = "watchedFilter"
        }
        await cacheAppEnv(key: key, value: filter.toData())
    }
    func cacheTagTranslator(_ tagTranslator: TagTranslator) async {
        await cacheAppEnv(key: "tagTranslator", value: tagTranslator.toData())
    }
    func cacheUser(_ user: User) async {
        await cacheAppEnv(key: "user", value: user.toData())
    }
    func cacheHistoryKeywords(_ keywords: [String]) async {
        await cacheAppEnv(key: "historyKeywords", value: keywords.toData())
    }
    func cacheQuickSearchWords(_ words: [QuickSearchWord]) async {
        await cacheAppEnv(key: "quickSearchWords", value: words.toData())
    }

    // Update User
    func cacheUserProperty(_ commitChanges: @escaping (inout User) -> Void) async {
        var user = await fetchAppEnv().user
        commitChanges(&user)
        await cacheUser(user)
    }
    func cacheGreeting(_ greeting: Greeting) async {
        await cacheUserProperty { user in
            user.greeting = greeting
        }
    }
    func cacheGalleryFunds(galleryPoints: String, credits: String) async {
        await cacheUserProperty { user in
            user.credits = credits
            user.galleryPoints = galleryPoints
        }
    }
}

// MARK: API
enum DatabaseClientKey: DependencyKey {
    static let liveValue = DatabaseClient.live
    static let previewValue = DatabaseClient.noop
    static let testValue = DatabaseClient.unimplemented
}

extension DependencyValues {
    var databaseClient: DatabaseClient {
        get { self[DatabaseClientKey.self] }
        set { self[DatabaseClientKey.self] = newValue }
    }
}

// MARK: Test
extension DatabaseClient {
    static let noop: Self = .init(
        prepareDatabase: { .none },
        dropDatabase: { .none },
        saveContext: {},
        materializedObjects: { _, _ in .init() }
    )

    static let unimplemented: Self = .init(
        prepareDatabase: XCTestDynamicOverlay.unimplemented("\(Self.self).prepareDatabase"),
        dropDatabase: XCTestDynamicOverlay.unimplemented("\(Self.self).dropDatabase"),
        saveContext: XCTestDynamicOverlay.unimplemented("\(Self.self).saveContext"),
        materializedObjects: XCTestDynamicOverlay.unimplemented("\(Self.self).materializedObjects")
    )
}
