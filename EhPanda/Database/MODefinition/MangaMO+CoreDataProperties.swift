//
//  MangaMO+CoreDataProperties.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/06/29.
//

import CoreData

extension MangaMO: Identifiable, GalleryIdentifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MangaMO> {
        NSFetchRequest<MangaMO>(entityName: "MangaMO")
    }

    @NSManaged public var category: String
    @NSManaged public var coverURL: String
    @NSManaged public var galleryURL: String
    @NSManaged public var gid: String
    @NSManaged public var language: String?
    @NSManaged public var lastOpenDate: Date?
    @NSManaged public var pageCount: Int64
    @NSManaged public var postedDate: Date
    @NSManaged public var rating: Float
    @NSManaged public var title: String
    @NSManaged public var token: String
    @NSManaged public var uploader: String?
}
