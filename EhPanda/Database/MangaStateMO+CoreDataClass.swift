//
//  MangaStateMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/09.
//

import CoreData

public class MangaStateMO: NSManagedObject {}

extension MangaStateMO: ManagedObjectProtocol {
    func toEntity() -> MangaState {
        MangaState(
            gid: gid, tags: tags?.toArray() ?? [MangaTag](),
            userRating: userRating, currentPageNum: Int(currentPageNum),
            pageNumMaximum: Int(pageNumMaximum), readingProgress: Int(readingProgress),
            previews: previews?.toArray() ?? [MangaPreview](),
            comments: comments?.toArray() ?? [MangaComment](),
            contents: contents?.toArray() ?? [MangaContent](),
            aspectBox: aspectBox?.toAspectBox() ?? [:]
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
        mangaMO.comments = comments.toData()
        mangaMO.contents = contents.toData()
        mangaMO.aspectBox = aspectBox.toData()

        return mangaMO
    }
}
