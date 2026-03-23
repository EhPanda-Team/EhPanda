//
//  DownloadedGalleryMO+CoreDataProperties.swift
//  EhPanda
//

import CoreData

extension DownloadedGalleryMO: GalleryIdentifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadedGalleryMO> {
        NSFetchRequest<DownloadedGalleryMO>(entityName: "DownloadedGalleryMO")
    }

    @NSManaged public var category: String
    @NSManaged public var completedPageCount: Int64
    @NSManaged public var coverRelativePath: String?
    @NSManaged public var downloadOptionsSnapshot: Data?
    @NSManaged public var folderRelativePath: String
    @NSManaged public var gid: String
    @NSManaged public var host: String
    @NSManaged public var jpnTitle: String?
    @NSManaged public var lastDownloadedAt: Date?
    @NSManaged public var lastError: Data?
    @NSManaged public var latestRemoteVersionSignature: String?
    @NSManaged public var onlineCoverURL: URL?
    @NSManaged public var pageCount: Int64
    @NSManaged public var pendingOperation: String?
    @NSManaged public var postedDate: Date
    @NSManaged public var rating: Float
    @NSManaged public var remoteVersionSignature: String
    @NSManaged public var status: String
    @NSManaged public var tags: Data?
    @NSManaged public var title: String
    @NSManaged public var token: String
    @NSManaged public var uploader: String?
}
