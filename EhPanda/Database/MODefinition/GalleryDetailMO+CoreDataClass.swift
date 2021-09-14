//
//  GalleryDetailMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

public class GalleryDetailMO: NSManagedObject {}

extension GalleryDetailMO: ManagedObjectProtocol {
    func toEntity() -> GalleryDetail {
        GalleryDetail(
            gid: gid, title: title, jpnTitle: jpnTitle, isFavored: isFavored,
            visibility: visibility?.toObject() ?? GalleryVisibility.yes,
            rating: rating, userRating: userRating, ratingCount: Int(ratingCount),
            category: Category(rawValue: category).forceUnwrapped,
            language: Language(rawValue: language).forceUnwrapped,
            uploader: uploader, postedDate: postedDate,
            coverURL: coverURL, archiveURL: archiveURL, parentURL: parentURL,
            favoredCount: Int(favoredCount), pageCount: Int(pageCount),
            sizeCount: sizeCount, sizeType: sizeType,
            torrentCount: Int(torrentCount)
        )
    }
}
extension GalleryDetail: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> GalleryDetailMO {
        let galleryDetailMO = GalleryDetailMO(context: context)

        galleryDetailMO.gid = gid
        galleryDetailMO.archiveURL = archiveURL
        galleryDetailMO.category = category.rawValue
        galleryDetailMO.coverURL = coverURL
        galleryDetailMO.isFavored = isFavored
        galleryDetailMO.visibility = visibility.toData()
        galleryDetailMO.jpnTitle = jpnTitle
        galleryDetailMO.language = language.rawValue
        galleryDetailMO.favoredCount = Int64(favoredCount)
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
