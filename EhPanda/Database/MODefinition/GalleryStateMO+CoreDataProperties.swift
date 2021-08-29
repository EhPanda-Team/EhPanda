//
//  GalleryStateMO+CoreDataProperties.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/09.
//

import CoreData

extension GalleryStateMO: GalleryIdentifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GalleryStateMO> {
        NSFetchRequest<GalleryStateMO>(entityName: "GalleryStateMO")
    }

    @NSManaged public var comments: Data?
    @NSManaged public var contents: Data?
    @NSManaged public var gid: String
    @NSManaged public var previews: Data?
    @NSManaged public var readingProgress: Int64
    @NSManaged public var tags: Data?
    @NSManaged public var thumbnails: Data?
}
