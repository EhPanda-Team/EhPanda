import SwiftUI
import Combine
import CoreData
import ComposableArchitecture

struct DatabaseClient: Sendable {
    let prepareDatabase: @Sendable () async -> Result<Void, AppError>
    let dropDatabase: @Sendable () async -> Result<Void, AppError>
    private let viewContext: @Sendable () -> NSManagedObjectContext
    private let saveContext: @Sendable () -> Void
    private let materializedObjects:
        @Sendable (NSManagedObjectContext, NSPredicate) -> [NSManagedObject]
}

extension DatabaseClient {
    static let live: Self = .init(
        prepareDatabase: {
            await withCheckedContinuation { continuation in
                PersistenceController.shared.prepare { result in
                    continuation.resume(returning: result)
                }
            }
        },
        dropDatabase: {
            await withCheckedContinuation { continuation in
                PersistenceController.shared.rebuild { result in
                    continuation.resume(returning: result)
                }
            }
        },
        viewContext: {
            PersistenceController.shared.container.viewContext
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
        materializedObjects: materializedObjectsFromContext
    )

    static func live(persistenceContainer container: NSPersistentContainer) -> Self {
        .init(
            prepareDatabase: { .success(()) },
            dropDatabase: { .success(()) },
            viewContext: {
                container.viewContext
            },
            saveContext: {
                let context = container.viewContext
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
            materializedObjects: materializedObjectsFromContext
        )
    }

    private static let materializedObjectsFromContext:
        @Sendable (NSManagedObjectContext, NSPredicate) -> [NSManagedObject] = { context, predicate in
        var objects = [NSManagedObject]()
        for object in context.registeredObjects where !object.isFault {
            guard object.entity.attributesByName.keys.contains("gid"),
                  predicate.evaluate(with: object)
            else { continue }
            objects.append(object)
        }
        return objects
    }
}

// MARK: Foundation
extension DatabaseClient {
    func batchFetch<MO: NSManagedObject>(
        entityType: MO.Type, fetchLimit: Int = 0, predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true, sortDescriptors: [NSSortDescriptor]? = nil
    ) -> [MO] {
        var results = [MO]()
        let context = viewContext()
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

    func fetch<MO: NSManagedObject>(
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

    func fetchOrCreate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO {
        if let storedMO = fetch(
            entityType: entityType, predicate: predicate, commitChanges: commitChanges
        ) {
            return storedMO
        } else {
            let newMO = MO(context: viewContext())
            commitChanges?(newMO)
            saveContext()
            return newMO
        }
    }

    func batchUpdate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil, commitChanges: ([MO]) -> Void
    ) {
        commitChanges(batchFetch(
            entityType: entityType,
            predicate: predicate,
            findBeforeFetch: false
        ))
        saveContext()
    }
    func update<MO: NSManagedObject>(
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
    func fetch<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String,
        findBeforeFetch: Bool = true,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        fetch(
            entityType: entityType, predicate: NSPredicate(format: "gid == %@", gid),
            findBeforeFetch: findBeforeFetch, commitChanges: commitChanges
        )
    }
    func fetchOrCreate<MO: GalleryIdentifiable>(entityType: MO.Type, gid: String) -> MO {
        fetchOrCreate(
            entityType: entityType,
            predicate: NSPredicate(format: "gid == %@", gid),
            commitChanges: { $0?.gid = gid }
        )
    }
    func update<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String,
        createIfNil: Bool = false,
        commitChanges: @escaping @Sendable ((MO) -> Void)
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

// MARK: GalleryState Helpers
extension DatabaseClient {
    func update<T: Codable>(gid: String, storedData: inout Data?, new: [Int: T]) {
        guard !new.isEmpty, gid.isValidGID else { return }
        storedData = ((storedData?.toObject() as [Int: T]?) ?? [:])
            .merging(new, uniquingKeysWith: { _, new in new })
            .toData()
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
    @MainActor func fetchAppEnv() -> AppEnv {
        fetchOrCreate(entityType: AppEnvMO.self).toEntity()
    }
    func fetchAppEnvSynchronously() -> AppEnv {
        fetchOrCreate(entityType: AppEnvMO.self).toEntity()
    }
    @MainActor func fetchGalleryState(gid: String) async -> GalleryState? {
        guard gid.isValidGID else { return nil }
        return fetchOrCreate(entityType: GalleryStateMO.self, gid: gid).toEntity()
    }
    @MainActor func fetchHistoryGalleries(fetchLimit: Int = 0) -> [Gallery] {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        let sortDescriptor = NSSortDescriptor(
            keyPath: \GalleryMO.lastOpenDate, ascending: false
        )
        let galleries = batchFetch(
            entityType: GalleryMO.self, fetchLimit: fetchLimit, predicate: predicate,
            findBeforeFetch: false, sortDescriptors: [sortDescriptor]
        )
        .map { $0.toEntity() }
        return galleries
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
    @MainActor func fetchHistoryKeywords() -> [String] {
        fetchAppEnv().historyKeywords
    }
    @MainActor func fetchQuickSearchWords() -> [QuickSearchWord] {
        fetchAppEnv().quickSearchWords
    }
    @MainActor func fetchGalleryPreviewURLs(gid: String) async -> [Int: URL]? {
        guard gid.isValidGID else { return nil }
        return await fetchGalleryState(gid: gid).map(\.previewURLs)
    }
}

// MARK: UpdateGallery
extension DatabaseClient {
    @MainActor func updateGallery(gid: String, key: String, value: Any?) {
        guard gid.isValidGID else { return }
        update(
            entityType: GalleryMO.self, gid: gid, createIfNil: true,
            commitChanges: { $0.setValue(value, forKeyPath: key) }
        )
    }
    @MainActor func updateLastOpenDate(gid: String, date: Date = .now) {
        guard gid.isValidGID else { return }
        updateGallery(gid: gid, key: "lastOpenDate", value: date)
    }
    @MainActor func clearHistoryGalleries() {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        batchUpdate(entityType: GalleryMO.self, predicate: predicate) { galleryMOs in
            galleryMOs.forEach { galleryMO in
                galleryMO.lastOpenDate = nil
            }
        }
    }
    @MainActor func cacheGalleries(_ galleries: [Gallery]) {
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
                gallery.toManagedObject(in: viewContext())
            }
        }
        saveContext()
    }
}

// MARK: UpdateGalleryDetail
extension DatabaseClient {
    @MainActor func cacheGalleryDetail(_ detail: GalleryDetail) {
        guard detail.gid.isValidGID else { return }
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
            detail.toManagedObject(in: viewContext())
        }
        saveContext()
    }
}

// UpdateGalleryState and UpdateAppEnv are in DatabaseClient+Updates.swift

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
        prepareDatabase: { .success(()) },
        dropDatabase: { .success(()) },
        viewContext: {
            PersistenceController.shared.container.viewContext
        },
        saveContext: {},
        materializedObjects: { _, _ in .init() }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        prepareDatabase: IssueReporting.unimplemented(placeholder: placeholder()),
        dropDatabase: IssueReporting.unimplemented(placeholder: placeholder()),
        viewContext: IssueReporting.unimplemented(placeholder: placeholder()),
        saveContext: IssueReporting.unimplemented(placeholder: placeholder()),
        materializedObjects: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
