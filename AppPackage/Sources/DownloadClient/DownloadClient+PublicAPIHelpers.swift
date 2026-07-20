import Foundation
import AppModels

// MARK: - Private helpers for public API
extension DownloadCoordinator {
    public func buildInspectionPages(
        download: DownloadedGallery,
        activeFolderURL: URL?,
        existingRelativePaths: [Int: String],
        failedPages: [Int: PageFailure]
    ) -> [DownloadPageInspection] {
        (1...download.pageCount).map { page -> DownloadPageInspection in
            if let relativePath = existingRelativePaths[page],
               let folderURL = activeFolderURL {
                let fileURL = folderURL
                    .appendingPathComponent(relativePath)
                if fileManager.operate({ $0.fileExists(atPath: fileURL.path) }) {
                    return .init(
                        index: page,
                        status: .downloaded,
                        relativePath: relativePath,
                        fileURL: fileURL,
                        failure: nil
                    )
                }
            }

            if let failedPage = failedPages[page] {
                    return .init(
                        index: page,
                        status: .failed,
                        relativePath: failedPage.relativePath,
                        fileURL: nil,
                        failure: .init(error: failedPage.error)
                    )
            }

            return .init(
                index: page,
                status: .pending,
                relativePath: nil,
                fileURL: nil,
                failure: nil
            )
        }
    }

    public func clearSelectedFailedPages(
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
