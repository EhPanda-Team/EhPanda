//
//  GalleryStateMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/09.
//

import SwiftUI
import CoreData

public class GalleryStateMO: NSManagedObject {}

extension GalleryStateMO: ModelConvertible {
    func toModel() -> GalleryState {
        GalleryState(
            gid: gid, tags: tags?.toObject() ?? .init(),
            readingProgress: .init(readingProgress),
            previewURLs: previewURLs?.toObject() ?? .init(),
            previewConfig: previewConfig?.toObject() ?? .normal(rows: 4),
            comments: comments?.toObject() ?? .init(),
            imageURLs: imageURLs?.toObject() ?? .init(),
            originalImageURLs: originalImageURLs?.toObject() ?? .init(),
            thumbnailURLs: thumbnailURLs?.toObject() ?? .init()
        )
    }
}

extension GalleryState: ManagedObjectConvertible {
    @discardableResult func toManagedObject(in context: NSManagedObjectContext) -> GalleryStateMO {
        let galleryStateMO = GalleryStateMO(context: context)

        galleryStateMO.gid = gid
        galleryStateMO.tags = tags.toData()
        galleryStateMO.readingProgress = Int64(readingProgress)
        galleryStateMO.previewConfig = previewConfig?.toData()
        galleryStateMO.previewURLs = previewURLs.toData()
        galleryStateMO.comments = comments.toData()
        galleryStateMO.imageURLs = imageURLs.toData()
        galleryStateMO.originalImageURLs = originalImageURLs.toData()
        galleryStateMO.thumbnailURLs = thumbnailURLs.toData()

        return galleryStateMO
    }
}
