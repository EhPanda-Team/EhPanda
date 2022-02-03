//
//  GalleryStateMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/09.
//

import SwiftUI
import CoreData

public class GalleryStateMO: NSManagedObject {}

extension GalleryStateMO: ManagedObjectProtocol {
    func toEntity() -> GalleryState {
        GalleryState(
            gid: gid, tags: tags?.toObject() ?? [GalleryTag](),
            readingProgress: Int(readingProgress),
            previews: previews?.toObject() ?? [Int: String](),
            previewConfig: previewConfig?.toObject() ?? PreviewConfig.normal(rows: 4),
            comments: comments?.toObject() ?? [GalleryComment](),
            imageURLs: contents?.toObject() ?? [Int: String](),
            originalContents: originalContents?.toObject() ?? [Int: String](),
            thumbnails: thumbnails?.toObject() ?? [Int: String]()
        )
    }
}

extension GalleryState: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> GalleryStateMO {
        let galleryStateMO = GalleryStateMO(context: context)

        galleryStateMO.gid = gid
        galleryStateMO.tags = tags.toData()
        galleryStateMO.readingProgress = Int64(readingProgress)
        galleryStateMO.previewConfig = previewConfig?.toData()
        galleryStateMO.previews = previews.toData()
        galleryStateMO.comments = comments.toData()
        galleryStateMO.contents = imageURLs.toData()
        galleryStateMO.originalContents = originalContents.toData()
        galleryStateMO.thumbnails = thumbnails.toData()

        return galleryStateMO
    }
}
