//
//  GalleryMO+CoreDataClass.swift
//  EhPanda
//

import CoreData

public class GalleryMO: NSManagedObject {}

extension GalleryMO: ManagedObjectProtocol {
    func toEntity() -> Gallery {
        Gallery(
            gid: gid, token: token,
            title: title, rating: rating,
            tags: tags?.toObject() ?? [GalleryTag](),
            category: Category(rawValue: category) ?? .private,
            uploader: uploader, pageCount: Int(pageCount),
            postedDate: postedDate,
            coverURL: coverURL, galleryURL: galleryURL,
            lastOpenDate: lastOpenDate
        )
    }
}
extension Gallery: ManagedObjectConvertible {
    @discardableResult func toManagedObject(in context: NSManagedObjectContext) -> GalleryMO {
        let galleryMO = GalleryMO(context: context)

        galleryMO.gid = gid
        galleryMO.category = category.rawValue
        galleryMO.coverURL = coverURL
        galleryMO.galleryURL = galleryURL
        galleryMO.lastOpenDate = lastOpenDate
        galleryMO.pageCount = Int64(pageCount)
        galleryMO.postedDate = postedDate
        galleryMO.rating = rating
        galleryMO.tags = tags.toData()
        galleryMO.title = title
        galleryMO.token = token
        galleryMO.uploader = uploader

        return galleryMO
    }
}
