//
//  MangaMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

public class MangaMO: NSManagedObject {}

extension MangaMO: ManagedObjectProtocol {
    func toEntity() -> Manga {
        Manga(
            gid: gid, token: token,
            title: title, rating: rating, tags: [],
            category: Category(rawValue: category).forceUnwrapped,
            language: Language(rawValue: language ?? ""),
            uploader: uploader, pageCount: Int(pageCount),
            postedDate: postedDate,
            coverURL: coverURL, galleryURL: galleryURL,
            lastOpenDate: lastOpenDate
        )
    }
}
extension Manga: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> MangaMO {
        let mangaMO = MangaMO(context: context)

        mangaMO.gid = gid
        mangaMO.category = category.rawValue
        mangaMO.coverURL = coverURL
        mangaMO.galleryURL = galleryURL
        mangaMO.language = language?.rawValue
        mangaMO.lastOpenDate = lastOpenDate
        mangaMO.pageCount = Int64(pageCount ?? 0)
        mangaMO.postedDate = postedDate
        mangaMO.rating = rating
        mangaMO.title = title
        mangaMO.token = token
        mangaMO.uploader = uploader

        return mangaMO
    }
}
