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
        AppUtil.dispatchMainSync {
            entity = fetch(entityType: GalleryMO.self, gid: gid)?.toEntity()
        }
        return entity.forceUnwrapped
    }
    static func fetchGalleryNonNil(gid: String) -> Gallery {
        fetchGallery(gid: gid) ?? Gallery.preview
    }
    static func fetchGalleryDetail(gid: String) -> GalleryDetail? {
        var entity: GalleryDetail?
        AppUtil.dispatchMainSync {
            entity = fetch(entityType: GalleryDetailMO.self, gid: gid)?.toEntity()
        }
        return entity
    }
    static func fetchGalleryStateNonNil(gid: String) -> GalleryState {
        var entity: GalleryState?
        AppUtil.dispatchMainSync {
            entity = fetchOrCreate(entityType: GalleryStateMO.self, gid: gid).toEntity()
        }
        return entity.forceUnwrapped
    }
    static func fetchAppEnvNonNil() -> AppEnv {
        var entity: AppEnv?
        AppUtil.dispatchMainSync {
            entity = fetchOrCreate(entityType: AppEnvMO.self).toEntity()
        }
        return entity.forceUnwrapped
    }
    static func fetchGalleryHistory(fetchLimit: Int = 0) -> [Gallery] {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        let sortDescriptor = NSSortDescriptor(
            keyPath: \GalleryMO.lastOpenDate, ascending: false
        )
        return batchFetch(
            entityType: GalleryMO.self, fetchLimit: fetchLimit, predicate: predicate,
            findBeforeFetch: false, sortDescriptors: [sortDescriptor]
        ).map({ $0.toEntity() })
    }
    static func clearHistoryGalleries() {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        batchUpdate(entityType: GalleryMO.self, predicate: predicate) { galleryMOs in
            galleryMOs.forEach { galleryMO in
                galleryMO.lastOpenDate = nil
            }
        }
    }

    static func fetch<MO: NSManagedObject>(
        entityType: MO.Type, gid: String,
        findBeforeFetch: Bool = true,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        fetch(
            entityType: entityType, predicate: NSPredicate(format: "gid == %@", gid),
            findBeforeFetch: findBeforeFetch, commitChanges: commitChanges
        )
    }
    static func fetchOrCreate<MO: GalleryIdentifiable>(entityType: MO.Type, gid: String) -> MO {
        fetchOrCreate(
            entityType: entityType, predicate: NSPredicate(format: "gid == %@", gid)
        ) { managedObject in
            managedObject?.gid = gid
        }
    }

    static func add(galleries: [Gallery]) {
        for gallery in galleries {
            let storedMO = fetch(entityType: GalleryMO.self, gid: gallery.gid) { managedObject in
                managedObject?.category = gallery.category.rawValue
                managedObject?.coverURL = gallery.coverURL
                managedObject?.galleryURL = gallery.galleryURL
                if let language = gallery.language {
                    managedObject?.language = language.rawValue
                }
                // managedObject?.lastOpenDate = gallery.lastOpenDate
                managedObject?.pageCount = Int64(gallery.pageCount)
                managedObject?.postedDate = gallery.postedDate
                managedObject?.rating = gallery.rating
                managedObject?.tagStrings = gallery.tagStrings.toData()
                managedObject?.title = gallery.title
                managedObject?.token = gallery.token
                if let uploader = gallery.uploader {
                    managedObject?.uploader = uploader
                }
            }
            if storedMO == nil {
                gallery.toManagedObject(in: shared.container.viewContext)
            }
        }
        saveContext()
    }

    static func add(detail: GalleryDetail) {
        let storedMO = fetch(entityType: GalleryDetailMO.self, gid: detail.gid) { managedObject in
            managedObject?.archiveURL = detail.archiveURL
            managedObject?.category = detail.category.rawValue
            managedObject?.coverURL = detail.coverURL
            managedObject?.isFavored = detail.isFavored
            managedObject?.visibility = detail.visibility.toData()
            managedObject?.jpnTitle = detail.jpnTitle
            managedObject?.language = detail.language.rawValue
            managedObject?.favoredCount = Int64(detail.favoredCount)
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
            detail.toManagedObject(in: shared.container.viewContext)
        }
        saveContext()
    }

    static func galleryCached(gid: String) -> Bool {
        PersistenceController.checkExistence(
            entityType: GalleryMO.self, predicate: NSPredicate(format: "gid == %@", gid)
        )
    }

    static func updateLastOpenDate(gid: String) {
        update(entityType: GalleryMO.self, gid: gid) { galleryMO in
            galleryMO.lastOpenDate = Date()
        }
    }
    static func update(appEnvMO: (AppEnvMO) -> Void) {
        update(entityType: AppEnvMO.self, createIfNil: true, commitChanges: appEnvMO)
    }

    // MARK: GalleryState
    static func removeImageURLs() {
        batchUpdate(entityType: GalleryStateMO.self) { galleryStateMOs in
            galleryStateMOs.forEach { galleryStateMO in
                galleryStateMO.contents = nil
                galleryStateMO.previews = nil
                galleryStateMO.thumbnails = nil
            }
        }
    }
    static func update(gid: String, galleryStateMO: @escaping ((GalleryStateMO) -> Void)) {
        update(entityType: GalleryStateMO.self, gid: gid, createIfNil: true, commitChanges: galleryStateMO)
    }
    static func update(gid: String, readingProgress: Int) {
        update(gid: gid) { galleryStateMO in
            galleryStateMO.readingProgress = Int64(readingProgress)
        }
    }
    static func update(gid: String, thumbnails: [Int: String]) {
        update(gid: gid) { galleryStateMO in
            guard !thumbnails.isEmpty else { return }
            if let storedThumbnails = galleryStateMO.thumbnails?.toObject() as [Int: String]? {
                galleryStateMO.thumbnails = storedThumbnails.merging(
                    thumbnails, uniquingKeysWith: { _, new in new }
                ).toData()
            } else {
                galleryStateMO.thumbnails = thumbnails.toData()
            }
        }
    }
    static func update(gid: String, contents: [Int: String], originalContents: [Int: String]) {
        update(gid: gid) { galleryStateMO in
            guard !contents.isEmpty else { return }
            update(gid: gid, storedData: &galleryStateMO.contents, new: contents)
            guard !originalContents.isEmpty else { return }
            update(gid: gid, storedData: &galleryStateMO.originalContents, new: originalContents)
        }
    }
    private static func update<T: Codable>(
        gid: String, storedData: inout Data?, new: [Int: T]
    ) {
        guard !new.isEmpty else { return }

        if let storedDictionary = storedData?.toObject() as [Int: T]? {
            storedData = storedDictionary.merging(
                new, uniquingKeysWith: { _, new in new }
            ).toData()
        } else {
            storedData = new.toData()
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
