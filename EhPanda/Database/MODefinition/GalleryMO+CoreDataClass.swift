//
//  GalleryMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

public class GalleryMO: NSManagedObject {}

extension GalleryMO: ManagedObjectProtocol {
    func toEntity() -> Gallery {
        Gallery(
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
extension Gallery: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> GalleryMO {
        let galleryMO = GalleryMO(context: context)

        galleryMO.gid = gid
        galleryMO.category = category.rawValue
        galleryMO.coverURL = coverURL
        galleryMO.galleryURL = galleryURL
        galleryMO.language = language?.rawValue
        galleryMO.lastOpenDate = lastOpenDate
        galleryMO.pageCount = Int64(pageCount)
        galleryMO.postedDate = postedDate
        galleryMO.rating = rating
        galleryMO.title = title
        galleryMO.token = token
        galleryMO.uploader = uploader

        return galleryMO
    }
}
