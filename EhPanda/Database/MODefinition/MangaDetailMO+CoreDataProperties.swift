//
//  MangaDetailMO+CoreDataProperties.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/06/29.
//

import CoreData

extension MangaDetailMO: Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MangaDetailMO> {
        NSFetchRequest<MangaDetailMO>(entityName: "MangaDetailMO")
    }

    @NSManaged public var archiveURL: String?
    @NSManaged public var category: String
    @NSManaged public var coverURL: String
    @NSManaged public var gid: String
    @NSManaged public var isFavored: Bool
    @NSManaged public var jpnTitle: String?
    @NSManaged public var language: String
    @NSManaged public var likeCount: Int64
    @NSManaged public var pageCount: Int64
    @NSManaged public var publishedDate: Date
    @NSManaged public var rating: Float
    @NSManaged public var userRating: Float
    @NSManaged public var ratingCount: Int64
    @NSManaged public var sizeCount: Float
    @NSManaged public var sizeType: String
    @NSManaged public var title: String
    @NSManaged public var torrentCount: Int64
    @NSManaged public var uploader: String
}
