//
//  DownloadedGalleryMO+CoreDataClass.swift
//  EhPanda
//

import CoreData

public class DownloadedGalleryMO: NSManagedObject {}

extension DownloadedGalleryMO: ManagedObjectProtocol {
    func toEntity() -> DownloadedGallery {
        DownloadedGallery(
            gid: gid,
            host: GalleryHost(rawValue: host) ?? .ehentai,
            token: token,
            title: title,
            jpnTitle: jpnTitle,
            uploader: uploader,
            category: Category(rawValue: category) ?? .private,
            tags: tags?.toObject() ?? [],
            pageCount: Int(pageCount),
            postedDate: postedDate,
            rating: rating,
            onlineCoverURL: onlineCoverURL,
            folderRelativePath: folderRelativePath,
            coverRelativePath: coverRelativePath,
            status: DownloadStatus(rawValue: status) ?? .queued,
            completedPageCount: Int(completedPageCount),
            lastDownloadedAt: lastDownloadedAt,
            lastError: lastError?.toObject(),
            downloadOptionsSnapshot: downloadOptionsSnapshot?.toObject() ?? .init(),
            remoteVersionSignature: remoteVersionSignature,
            latestRemoteVersionSignature: latestRemoteVersionSignature,
            pendingOperation: pendingOperation.flatMap(DownloadStartMode.init(rawValue:))
        )
    }
}
