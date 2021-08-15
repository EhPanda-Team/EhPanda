//
//  MangaDetailMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

public class MangaDetailMO: NSManagedObject {}

extension MangaDetailMO: ManagedObjectProtocol {
    func toEntity() -> MangaDetail {
        MangaDetail(
            gid: gid, title: title, isFavored: isFavored, isVisible: isVisible,
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
extension MangaDetail: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> MangaDetailMO {
        let mangaDetailMO = MangaDetailMO(context: context)

        mangaDetailMO.gid = gid
        mangaDetailMO.archiveURL = archiveURL
        mangaDetailMO.category = category.rawValue
        mangaDetailMO.coverURL = coverURL
        mangaDetailMO.isFavored = isFavored
        mangaDetailMO.isVisible = isVisible
        mangaDetailMO.jpnTitle = jpnTitle
        mangaDetailMO.language = language.rawValue
        mangaDetailMO.favoredCount = Int64(favoredCount)
        mangaDetailMO.pageCount = Int64(pageCount)
        mangaDetailMO.parentURL = parentURL
        mangaDetailMO.postedDate = postedDate
        mangaDetailMO.rating = rating
        mangaDetailMO.userRating = userRating
        mangaDetailMO.ratingCount = Int64(ratingCount)
        mangaDetailMO.sizeCount = sizeCount
        mangaDetailMO.sizeType = sizeType
        mangaDetailMO.title = title
        mangaDetailMO.torrentCount = Int64(torrentCount)
        mangaDetailMO.uploader = uploader

        return mangaDetailMO
    }
}
