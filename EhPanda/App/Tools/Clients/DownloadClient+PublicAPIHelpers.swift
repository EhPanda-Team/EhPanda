//
//  DownloadClient+PublicAPIHelpers.swift
//  EhPanda
//

import Foundation

// MARK: - Private helpers for public API
extension DownloadManager {
    func buildInspectionPages(
        download: DownloadedGallery,
        activeFolderURL: URL?,
        existingRelativePaths: [Int: String],
        failedPages: [Int: PageFailure]
    ) -> [DownloadPageInspection] {
        (1...download.pageCount).map { index -> DownloadPageInspection in
            if let relativePath = existingRelativePaths[index],
               let folderURL = activeFolderURL {
                let fileURL = folderURL
                    .appendingPathComponent(relativePath)
                if fileManager.operate({ $0.fileExists(atPath: fileURL.path) }) {
                    return .init(
                        index: index,
                        status: .downloaded,
                        relativePath: relativePath,
                        fileURL: fileURL,
                        failure: nil
                    )
                }
            }

            if let failedPage = failedPages[index] {
                    return .init(
                        index: index,
                        status: .failed,
                        relativePath: failedPage.relativePath,
                        fileURL: nil,
                        failure: .init(error: failedPage.error)
                    )
            }

            return .init(
                index: index,
                status: .pending,
                relativePath: nil,
                fileURL: nil,
                failure: nil
            )
        }
    }

    func clearSelectedFailedPages(
        gid: String,
        selectedPageIndices: [Int],
    ) {
        for index in selectedPageIndices {
            failedPageErrors[gid]?[index] = nil
        }
        if failedPageErrors[gid]?.isEmpty == true {
            failedPageErrors[gid] = nil
        }
    }
}
