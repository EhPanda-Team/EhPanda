//
//  PersistenceAccessor.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/05.
//

import SwiftUI
import CoreData

protocol PersistenceAccessor {
    var gid: String { get }
}

extension PersistenceAccessor {
    var gallery: Gallery {
        PersistenceController.fetchGalleryNonNil(gid: gid)
    }
    var galleryDetail: GalleryDetail? {
        PersistenceController.fetchGalleryDetail(gid: gid)
    }
    var galleryState: GalleryState {
        PersistenceController.fetchGalleryStateNonNil(gid: gid)
    }
}

// MARK: Accessor Method
extension PersistenceController {
    static func fetchGallery(gid: String) -> Gallery? {
        var entity: Gallery?
        dispatchMainSync {
            entity = fetch(entityType: GalleryMO.self, gid: gid)?.toEntity()
        }
        return entity.forceUnwrapped
    }
    static func fetchGalleryNonNil(gid: String) -> Gallery {
        fetchGallery(gid: gid) ?? Gallery.preview
    }
    static func fetchGalleryDetail(gid: String) -> GalleryDetail? {
        var entity: GalleryDetail?
        dispatchMainSync {
            entity = fetch(entityType: GalleryDetailMO.self, gid: gid)?.toEntity()
        }
        return entity
    }
    static func fetchGalleryStateNonNil(gid: String) -> GalleryState {
        var entity: GalleryState?
        dispatchMainSync {
            entity = fetchOrCreate(entityType: GalleryStateMO.self, gid: gid).toEntity()
        }
        return entity.forceUnwrapped
    }
    static func fetchAppEnvNonNil() -> AppEnv {
        var entity: AppEnv?
        dispatchMainSync {
            entity = fetchOrCreate(entityType: AppEnvMO.self).toEntity()
        }
        return entity.forceUnwrapped
    }
    static func fetchGalleryHistory() -> [Gallery] {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        let sortDescriptor = NSSortDescriptor(
            keyPath: \GalleryMO.lastOpenDate, ascending: false
        )
        return fetch(
            entityType: GalleryMO.self,
            predicate: predicate,
            findBeforeFetch: false,
            sortDescriptors: [sortDescriptor]
        ).map({ $0.toEntity() })
    }

    static func fetch<MO: NSManagedObject>(
        entityType: MO.Type, gid: String,
        findBeforeFetch: Bool = true,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        fetch(
            entityType: entityType,
            predicate: NSPredicate(
                format: "gid == %@", gid
            ),
            findBeforeFetch: findBeforeFetch,
            commitChanges: commitChanges
        )
    }
    static func fetchOrCreate<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String
    ) -> MO {
        fetchOrCreate(
            entityType: entityType,
            predicate: NSPredicate(
                format: "gid == %@", gid
            )
        ) { managedObject in
            managedObject?.gid = gid
        }
    }

    static func add(galleries: [Gallery]) {
        for gallery in galleries {
            let storedMO = fetch(
                entityType: GalleryMO.self,
                gid: gallery.gid
            ) { managedObject in
                managedObject?.title = gallery.title
                managedObject?.rating = gallery.rating
                managedObject?.language = gallery.language?.rawValue
                managedObject?.pageCount = Int64(gallery.pageCount)
            }
            if storedMO == nil {
                gallery.toManagedObject(in: shared.container.viewContext)
            }
        }
        saveContext()
    }

    static func add(detail: GalleryDetail) {
        let storedMO = fetch(
            entityType: GalleryDetailMO.self,
            gid: detail.gid
        ) { managedObject in
            managedObject?.title = detail.title
            managedObject?.jpnTitle = detail.jpnTitle
            managedObject?.isFavored = detail.isFavored
            managedObject?.visibility = detail.visibility.toData()
            managedObject?.rating = detail.rating
            managedObject?.userRating = detail.userRating
            managedObject?.ratingCount = Int64(detail.ratingCount)
            managedObject?.archiveURL = detail.archiveURL
            managedObject?.parentURL = detail.parentURL
            managedObject?.favoredCount = Int64(detail.favoredCount)
            managedObject?.pageCount = Int64(detail.pageCount)
            managedObject?.sizeCount = detail.sizeCount
            managedObject?.sizeType = detail.sizeType
            managedObject?.torrentCount = Int64(detail.torrentCount)
        }
        if storedMO == nil {
            detail.toManagedObject(in: shared.container.viewContext)
        }
        saveContext()
    }

    static func galleryCached(gid: String) -> Bool {
        PersistenceController.checkExistence(
            entityType: GalleryMO.self,
            predicate: NSPredicate(
                format: "gid == %@", gid
            )
        )
    }

    static func updateLastOpenDate(gid: String) {
        update(entityType: GalleryMO.self, gid: gid) { galleryMO in
            galleryMO.lastOpenDate = Date()
        }
    }
    static func update(appEnvMO: ((AppEnvMO) -> Void)) {
        update(entityType: AppEnvMO.self, createIfNil: true, commitChanges: appEnvMO)
    }

    // MARK: GalleryState
    static func update(gid: String, galleryStateMO: @escaping ((GalleryStateMO) -> Void)) {
        update(entityType: GalleryStateMO.self, gid: gid, createIfNil: true, commitChanges: galleryStateMO)
    }
    static func update(gid: String, readingProgress: Int) {
        update(gid: gid) { galleryStateMO in
            galleryStateMO.readingProgress = Int64(readingProgress)
        }
    }
    static func update(gid: String, thumbnails: [Int: URL]) {
        update(gid: gid) { galleryStateMO in
            if !thumbnails.isEmpty {
                if let storedThumbnails = galleryStateMO.thumbnails?.toObject() as [Int: URL]? {
                    galleryStateMO.thumbnails = storedThumbnails.merging(
                        thumbnails, uniquingKeysWith: { _, new in new }
                    ).toData()
                } else {
                    galleryStateMO.thumbnails = thumbnails.toData()
                }
            }
        }
    }
    static func update(gid: String, contents: [Int: String]) {
        update(gid: gid) { galleryStateMO in
            if !contents.isEmpty {
                if let storedContents = galleryStateMO.contents?.toObject() as [Int: String]? {
                    galleryStateMO.contents = storedContents.merging(
                        contents, uniquingKeysWith: { _, new in new }
                    ).toData()
                } else {
                    galleryStateMO.contents = contents.toData()
                }
            }
        }
    }
    static func update(fetchedState: GalleryState) {
        update(gid: fetchedState.gid) { galleryStateMO in
            if !fetchedState.tags.isEmpty {
                galleryStateMO.tags = fetchedState.tags.toData()
            }
            if !fetchedState.comments.isEmpty {
                galleryStateMO.comments = fetchedState.comments.toData()
            }
            if !fetchedState.previews.isEmpty {
                if let storedPreviews = galleryStateMO.previews?.toObject() as [Int: String]? {
                    galleryStateMO.previews = storedPreviews.merging(
                        fetchedState.previews, uniquingKeysWith: { stored, _ in stored }
                    ).toData()
                } else {
                    galleryStateMO.previews = fetchedState.previews.toData()
                }
            }
        }
    }
}
