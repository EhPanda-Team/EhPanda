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
    var manga: Manga {
        PersistenceController.fetchMangaNonNil(gid: gid)
    }
    var mangaDetail: MangaDetail? {
        PersistenceController.fetchMangaDetail(gid: gid)
    }
    var mangaState: MangaState {
        PersistenceController.fetchMangaStateNonNil(gid: gid)
    }
}

// MARK: Accessor Method
extension PersistenceController {
    static func fetchManga(gid: String) -> Manga? {
        PersistenceController.fetch(
            entityType: MangaMO.self, gid: gid
        )?.toEntity()
    }
    static func fetchMangaNonNil(gid: String) -> Manga {
        fetchManga(gid: gid) ?? Manga.empty
    }
    static func fetchMangaDetail(gid: String) -> MangaDetail? {
        PersistenceController.fetch(
            entityType: MangaDetailMO.self, gid: gid
        )?.toEntity()
    }
    static func fetchMangaStateNonNil(gid: String) -> MangaState {
        PersistenceController.fetchOrCreate(
            entityType: MangaStateMO.self, gid: gid
        ).toEntity()
    }
    static func fetchAppEnvNonNil() -> AppEnv {
        PersistenceController.fetchOrCreate(entityType: AppEnvMO.self).toEntity()
    }
    static func fetchMangaHistory() -> [Manga] {
        let predicate = NSPredicate(format: "lastOpenDate != nil")
        let sortDescriptor = NSSortDescriptor(
            keyPath: \MangaMO.lastOpenDate, ascending: false
        )
        return PersistenceController.fetch(
            entityType: MangaMO.self,
            predicate: predicate,
            findBeforeFetch: false,
            sortDescriptors: [sortDescriptor]
        ).map({ $0.toEntity() })
    }

    static func fetch<MO: NSManagedObject>(
        entityType: MO.Type, gid: String,
        findBeforeFetch: Bool = true
    ) -> MO? {
        fetch(
            entityType: entityType,
            predicate: NSPredicate(
                format: "gid == %@", gid
            ),
            findBeforeFetch: findBeforeFetch
        )
    }
    static func fetchOrCreate<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String
    ) -> MO {
        let newMO = fetchOrCreate(
            entityType: entityType,
            predicate: NSPredicate(
                format: "gid == %@", gid
            )
        )
        newMO.gid = gid
        return newMO
    }

    static func add(mangas: [Manga]) {
        for manga in mangas {
            if let storedMangaMO: MangaMO =
                fetch(entityType: MangaMO.self, gid: manga.gid)
            {
                storedMangaMO.title = manga.title
                storedMangaMO.rating = manga.rating
                storedMangaMO.language = manga.language?.rawValue
            } else {
                manga.toManagedObject(in: shared.container.viewContext)
            }
        }
        saveContext()
    }

    static func add(detail: MangaDetail) {
        if let storedMangaDetailMO: MangaDetailMO =
            fetch(entityType: MangaDetailMO.self, gid: detail.gid)
        {
            storedMangaDetailMO.isFavored = detail.isFavored
            storedMangaDetailMO.archiveURL = detail.archiveURL
            storedMangaDetailMO.jpnTitle = detail.jpnTitle
            storedMangaDetailMO.likeCount = detail.likeCount
            storedMangaDetailMO.pageCount = detail.pageCount
            storedMangaDetailMO.sizeCount = detail.sizeCount
            storedMangaDetailMO.sizeType = detail.sizeType
            storedMangaDetailMO.rating = detail.rating
            storedMangaDetailMO.ratingCount = detail.ratingCount
            storedMangaDetailMO.torrentCount = Int16(detail.torrentCount)
        } else {
            detail.toManagedObject(in: shared.container.viewContext)
        }
        saveContext()
    }

    static func mangaCached(gid: String) -> Bool {
        PersistenceController.checkExistence(
            entityType: MangaMO.self,
            predicate: NSPredicate(
                format: "gid == %@", gid
            )
        )
    }

    static func updateLastOpenDate(gid: String) {
        update(entityType: MangaMO.self, gid: gid) { mangaMO in
            mangaMO.lastOpenDate = Date()
        }
    }
    static func update(appEnvMO: ((AppEnvMO) -> Void)) {
        update(entityType: AppEnvMO.self, createIfNil: true, commitChanges: appEnvMO)
    }

    // MARK: MangaState
    static func update(gid: String, mangaStateMO: ((MangaStateMO) -> Void)) {
        update(entityType: MangaStateMO.self, gid: gid, createIfNil: true, commitChanges: mangaStateMO)
    }
    static func update(fetchedState: MangaState) {
        PersistenceController.update(gid: fetchedState.gid) { mangaStateMO in
            mangaStateMO.tags = fetchedState.tags.toData()
            mangaStateMO.previews = fetchedState.previews.toData()
            mangaStateMO.comments = fetchedState.comments.toData()
        }
    }
    static func update(gid: String, aspectBox: [Int: CGFloat]) {
        PersistenceController.update(gid: gid) { mangaStateMO in
            mangaStateMO.aspectBox = aspectBox.toData()
        }
    }
    static func update(gid: String, readingProgress: Int) {
        PersistenceController.update(gid: gid) { mangaStateMO in
            mangaStateMO.readingProgress = Int16(readingProgress)
        }
    }
    static func update(gid: String, userRating: Float) {
        PersistenceController.update(gid: gid) { mangaStateMO in
            mangaStateMO.userRating = userRating
        }
    }
    static func update(gid: String, pageNum: PageNumber, contents: [MangaContent]) {
        PersistenceController.update(gid: gid) { mangaStateMO in
            mangaStateMO.currentPageNum = Int16(pageNum.current)
            mangaStateMO.pageNumMaximum = Int16(pageNum.maximum)

            let newContents = contents.sorted(by: { $0.tag < $1.tag })
            var storedContents = mangaStateMO.contents?
                .toObject() ?? [MangaContent]()

            if storedContents.isEmpty {
                mangaStateMO.contents = newContents.toData()
            } else {
                newContents.forEach { content in
                    if !storedContents.contains(content) {
                        storedContents.append(content)
                    }
                }
                mangaStateMO.contents = storedContents.toData()
            }
        }
    }
}
