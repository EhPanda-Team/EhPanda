//
//  Persistence.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData
import SwiftyBeaver

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")
        container.loadPersistentStores {
            if let error = $1 {
                SwiftyBeaver.error(error as Any)
            }
        }
        return container
    }()

    static func saveContext() {
        let context = shared.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                SwiftyBeaver.error(error)
                fatalError("Unresolved error \(error)")
            }
        }
    }

    static func checkExistence(entityName: String, gid: String) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "gid == %@", gid)
        return (try? shared.container.viewContext.count(for: request)) ?? 0 > 0
    }

    static func fetch<E: NSFetchRequestResult>(entityName: String, gid: String) -> E? {
        let request = NSFetchRequest<E>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "gid == %@", gid)
        return try? shared.container.viewContext.fetch(request).first
    }

    static func add(mangas: [Manga]) {
        for manga in mangas {
            if let storedMangaMO: MangaMO =
                fetch(entityName: "MangaMO", gid: manga.gid)
            {
                storedMangaMO.title = manga.title
                storedMangaMO.rating = manga.rating
//                storedMangaMO.tags = manga.tags
                storedMangaMO.language = manga.language?.rawValue
            } else {
                manga.toManagedObject(in: shared.container.viewContext)
            }
        }
        saveContext()
    }

    static func add(detail: MangaDetail) {
        if let storedMangaDetailMO: MangaDetailMO =
            fetch(entityName: "MangaDetailMO", gid: detail.gid)
        {
            storedMangaDetailMO.isFavored = detail.isFavored
            storedMangaDetailMO.archiveURL = detail.archiveURL
//            storedMangaDetailMO.detailTags = detail.detailTags
//            storedMangaDetailMO.comments = detail.comments
            storedMangaDetailMO.jpnTitle = detail.jpnTitle
            storedMangaDetailMO.likeCount = detail.likeCount
            storedMangaDetailMO.pageCount = detail.pageCount
            storedMangaDetailMO.sizeCount = detail.sizeCount
            storedMangaDetailMO.sizeType = detail.sizeType
            storedMangaDetailMO.rating = detail.rating
            storedMangaDetailMO.ratingCount = detail.ratingCount
            storedMangaDetailMO.torrentCount = Int64(detail.torrentCount)
        } else {
            detail.toManagedObject(in: shared.container.viewContext)
        }
        saveContext()
    }
}

extension PersistenceController {
    static func fetchManga(gid: String) -> Manga? {
        let mangaMO: MangaMO? = PersistenceController.fetch(
            entityName: "MangaMO", gid: gid
        )
        return mangaMO?.toEntity()
    }
    static func fetchMangaNonNil(gid: String) -> Manga {
        fetchManga(gid: gid) ?? Manga.empty
    }
    static func fetchMangaDetail(gid: String) -> MangaDetail? {
        let mangaDetailMO: MangaDetailMO? = PersistenceController.fetch(
            entityName: "MangaDetailMO", gid: gid
        )
        return mangaDetailMO?.toEntity()
    }
}

// MARK: Protocol Definition
protocol ManagedObjectProtocol {
    associatedtype Entity
    func toEntity() -> Entity
}

protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject, ManagedObjectProtocol

    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> ManagedObject
}
