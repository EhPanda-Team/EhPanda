//
//  GalleryDetailMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

public class GalleryDetailMO: NSManagedObject {}

extension GalleryDetailMO: ModelConvertible {
    func toModel() -> GalleryDetail {
        .init(
            gid: gid,
            title: title,
            jpnTitle: jpnTitle,
            isFavorited: isFavorited,
            visibility: visibility?.toObject() ?? .yes,
            rating: rating,
            userRating: userRating,
            ratingCount: .init(ratingCount),
            category: .init(rawValue: category).forceUnwrapped,
            language: .init(rawValue: language).forceUnwrapped,
            uploader: uploader,
            postedDate: postedDate,
            coverURL: coverURL,
            archiveURL: archiveURL,
            parentURL: parentURL,
            favoritedCount: .init(favoritedCount),
            pageCount: .init(pageCount),
            sizeCount: sizeCount,
            sizeType: sizeType,
            torrentCount: .init(torrentCount)
        )
    }
}
extension GalleryDetail: ManagedObjectConvertible {
    @discardableResult func toManagedObject(in context: NSManagedObjectContext) -> GalleryDetailMO {
        let galleryDetailMO = GalleryDetailMO(context: context)

        galleryDetailMO.gid = gid
        galleryDetailMO.archiveURL = archiveURL
        galleryDetailMO.category = category.rawValue
        galleryDetailMO.coverURL = coverURL
        galleryDetailMO.isFavorited = isFavorited
        galleryDetailMO.visibility = visibility.toData()
        galleryDetailMO.jpnTitle = jpnTitle
        galleryDetailMO.language = language.rawValue
        galleryDetailMO.favoritedCount = Int64(favoritedCount)
        galleryDetailMO.pageCount = Int64(pageCount)
        galleryDetailMO.parentURL = parentURL
        galleryDetailMO.postedDate = postedDate
        galleryDetailMO.rating = rating
        galleryDetailMO.userRating = userRating
        galleryDetailMO.ratingCount = Int64(ratingCount)
        galleryDetailMO.sizeCount = sizeCount
        galleryDetailMO.sizeType = sizeType
        galleryDetailMO.title = title
        galleryDetailMO.torrentCount = Int64(torrentCount)
        galleryDetailMO.uploader = uploader

        return galleryDetailMO
    }
}
