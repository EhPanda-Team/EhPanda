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
            isFavored: isFavored, archiveURL: archiveURL,
            alterImagesURL: nil, alterImages: [], torrents: [],
            comments: [], previews: [], gid: gid, title: title,
            rating: rating, ratingCount: ratingCount, detailTags: [],
            category: Category(rawValue: category)!,
            language: Language(rawValue: language)!,
            uploader: uploader, publishedDate: publishedDate,
            coverURL: coverURL, likeCount: likeCount,
            pageCount: pageCount, sizeCount: sizeCount,
            sizeType: sizeType, torrentCount: Int(torrentCount)
        )
    }
}
extension MangaDetail: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> MangaDetailMO {
        let mangaDetailMO = MangaDetailMO(context: context)
//        let mangaDetailMO = MangaDetailMO.getOrCreateSingle(
//            with: "gid", from: context
//        )
        mangaDetailMO.gid = gid
        mangaDetailMO.archiveURL = archiveURL
        mangaDetailMO.category = category.rawValue
        mangaDetailMO.coverURL = coverURL
        mangaDetailMO.isFavored = isFavored
        mangaDetailMO.jpnTitle = jpnTitle
        mangaDetailMO.language = language.rawValue
        mangaDetailMO.likeCount = likeCount
        mangaDetailMO.pageCount = pageCount
        mangaDetailMO.publishedDate = publishedDate
        mangaDetailMO.rating = rating
        mangaDetailMO.ratingCount = ratingCount
        mangaDetailMO.sizeCount = sizeCount
        mangaDetailMO.sizeType = sizeType
        mangaDetailMO.title = title
        mangaDetailMO.torrentCount = Int64(torrentCount)
        mangaDetailMO.uploader = uploader
        mangaDetailMO.userRating = userRating ?? 0.0

        return mangaDetailMO
    }
}
