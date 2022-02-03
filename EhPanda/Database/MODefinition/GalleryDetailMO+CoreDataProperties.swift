//
//  GalleryDetailMO+CoreDataProperties.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/06/29.
//

import CoreData

extension GalleryDetailMO: GalleryIdentifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GalleryDetailMO> {
        NSFetchRequest<GalleryDetailMO>(entityName: "GalleryDetailMO")
    }

    @NSManaged public var archiveURL: URL?
    @NSManaged public var category: String
    @NSManaged public var coverURL: URL?
    @NSManaged public var gid: String
    @NSManaged public var isFavorited: Bool
    @NSManaged public var jpnTitle: String?
    @NSManaged public var language: String
    @NSManaged public var favoritedCount: Int64
    @NSManaged public var pageCount: Int64
    @NSManaged public var parentURL: URL?
    @NSManaged public var postedDate: Date
    @NSManaged public var rating: Float
    @NSManaged public var userRating: Float
    @NSManaged public var ratingCount: Int64
    @NSManaged public var sizeCount: Float
    @NSManaged public var sizeType: String
    @NSManaged public var title: String
    @NSManaged public var torrentCount: Int64
    @NSManaged public var uploader: String
    @NSManaged public var visibility: Data?
}
