//
//  GalleryDetailMO+CoreDataClass.swift
//  EhPanda
//

import CoreData

public class GalleryDetailMO: NSManagedObject {}

extension GalleryDetailMO: ManagedObjectProtocol {
    func toEntity() -> GalleryDetail {
        GalleryDetail(
            gid: gid, title: title, jpnTitle: jpnTitle, isFavorited: isFavorited,
            visibility: visibility?.toObject() ?? GalleryVisibility.yes,
            rating: rating, userRating: userRating, ratingCount: Int(ratingCount),
            category: Category(rawValue: category).forceUnwrapped,
            language: Language(rawValue: language).forceUnwrapped,
            uploader: uploader, postedDate: postedDate,
            coverURL: coverURL, archiveURL: archiveURL, parentURL: parentURL,
            favoritedCount: Int(favoritedCount), pageCount: Int(pageCount),
            sizeCount: sizeCount, sizeType: sizeType,
            torrentCount: Int(torrentCount)
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
