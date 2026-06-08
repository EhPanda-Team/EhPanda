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
        failedPages: [Int: DownloadFailedPagesSnapshot.Page]
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
                    failure: failedPage.failure
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

    func buildCompletedPageURLs(
        completedFolderURL: URL?,
        download: DownloadedGallery
    ) -> [Int: URL] {
        let completedPageRelativePaths = completedFolderURL.map {
            storage.existingPageRelativePaths(
                folderURL: $0,
                expectedPageCount: download.pageCount
            )
        } ?? [:]
        return completedPageRelativePaths
            .reduce(into: [Int: URL]()) { result, entry in
                guard let folderURL = completedFolderURL else { return }
                result[entry.key] = folderURL
                    .appendingPathComponent(entry.value)
            }
    }

    func resolveLocalPageURLs(
        completedValidation: DownloadValidationState,
        completedFolderURL: URL?,
        completedPageURLs: [Int: URL]
    ) -> Result<[Int: URL], AppError> {
        if completedValidation == .valid,
           let completedFolderURL,
           fileManager.operate({ $0.fileExists(atPath: completedFolderURL.path) }),
           let manifest = try? storage.readManifest(
            folderURL: completedFolderURL
           ) {
            return .success(manifest
                .imageURLs(folderURL: completedFolderURL)
            )
        }

        return .success(completedPageURLs)
    }

    func clearSelectedFailedPages(
        selectedPageIndices: [Int],
        folderURL: URL
    ) {
        if let failedSnapshot = try? storage.readFailedPages(
            folderURL: folderURL
        ) {
            let remainingPages = failedSnapshot.pages.filter {
                !selectedPageIndices.contains($0.index)
            }
            if remainingPages.isEmpty {
                try? storage.removeFailedPages(
                    folderURL: folderURL
                )
            } else {
                try? storage.writeFailedPages(
                    .init(pages: remainingPages),
                    folderURL: folderURL
                )
            }
        }
    }
}
