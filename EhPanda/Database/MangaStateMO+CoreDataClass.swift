//
//  MangaStateMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/09.
//

import SwiftUI
import CoreData

public class MangaStateMO: NSManagedObject {}

extension MangaStateMO: ManagedObjectProtocol {
    func toEntity() -> MangaState {
        MangaState(
            gid: gid, tags: tags?.toObject() ?? [MangaTag](),
            userRating: userRating, currentPageNum: Int(currentPageNum),
            pageNumMaximum: Int(pageNumMaximum), readingProgress: Int(readingProgress),
            previews: previews?.toObject() ?? [Int: String](),
            previewsLoading: previewsLoading?.toObject() ?? [Int: Bool](),
            previewsLoadFailed: previewsLoadFailed?.toObject() ?? [Int: Bool](),
            comments: comments?.toObject() ?? [MangaComment](),
            contents: contents?.toObject() ?? [MangaContent](),
            aspectBox: aspectBox?.toObject() ?? [Int: CGFloat]()
        )
    }
}

extension MangaState: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> MangaStateMO {
        let mangaMO = MangaStateMO(context: context)

        mangaMO.gid = gid
        mangaMO.tags = tags.toData()
        mangaMO.userRating = userRating
        mangaMO.currentPageNum = Int16(currentPageNum)
        mangaMO.pageNumMaximum = Int16(pageNumMaximum)
        mangaMO.readingProgress = Int16(readingProgress)
        mangaMO.previews = previews.toData()
        mangaMO.previewsLoading = previewsLoading.toData()
        mangaMO.previewsLoadFailed = previewsLoadFailed.toData()
        mangaMO.comments = comments.toData()
        mangaMO.contents = contents.toData()
        mangaMO.aspectBox = aspectBox.toData()

        return mangaMO
    }
}
