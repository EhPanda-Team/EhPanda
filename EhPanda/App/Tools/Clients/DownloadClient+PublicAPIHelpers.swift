//
//  DownloadClient+PublicAPIHelpers.swift
//  EhPanda
//

import CoreData
import Foundation

// MARK: - Private helpers for public API
extension DownloadManager {
    func manifestVersionSignature(
        for gallery: Gallery,
        versionMetadata: DownloadVersionMetadata?
    ) -> String {
        let gid = versionMetadata?.resolvedCurrentGID ?? gallery.gid
        let token = versionMetadata?.resolvedCurrentKey ?? gallery.token
        guard !gid.isEmpty, !token.isEmpty else { return "" }
        return "chain:\(gid):\(token)"
    }

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

    func buildTemporaryPageURLs(
        hasTemporaryFolder: Bool,
        temporaryFolderURL: URL,
        download: DownloadedGallery
    ) -> [Int: URL] {
        let temporaryPageRelativePaths = hasTemporaryFolder
            ? storage.existingPageRelativePaths(
                folderURL: temporaryFolderURL,
                expectedPageCount: download.pageCount
            )
            : [:]
        return temporaryPageRelativePaths
            .reduce(into: [Int: URL]()) { result, entry in
                result[entry.key] = temporaryFolderURL
                    .appendingPathComponent(entry.value)
            }
    }

    func resolveLocalPageURLs(
        completedValidation: DownloadValidationState,
        completedFolderURL: URL?,
        completedPageURLs: [Int: URL],
        temporaryPageURLs: [Int: URL],
        shouldExposeTemp: Bool
    ) -> Result<[Int: URL], AppError> {
        if completedValidation == .valid,
           let completedFolderURL,
           fileManager.operate({ $0.fileExists(atPath: completedFolderURL.path) }),
           let manifest = try? storage.readManifest(
            folderURL: completedFolderURL
           ) {
            let completedManifestPageURLs = manifest
                .imageURLs(folderURL: completedFolderURL)
            guard shouldExposeTemp else {
                return .success(completedManifestPageURLs)
            }
            return .success(
                completedManifestPageURLs.merging(
                    temporaryPageURLs,
                    uniquingKeysWith: { _, temporary in temporary }
                )
            )
        }

        guard shouldExposeTemp else {
            return .success(completedPageURLs)
        }

        if !completedPageURLs.isEmpty, !temporaryPageURLs.isEmpty {
            return .success(
                completedPageURLs.merging(
                    temporaryPageURLs,
                    uniquingKeysWith: { _, temporary in temporary }
                )
            )
        }

        if !temporaryPageURLs.isEmpty {
            return .success(temporaryPageURLs)
        }

        return .success(completedPageURLs)
    }

    struct RetryParams {
        let shouldResumeExistingWork: Bool
        let resumedStatus: DownloadStatus
        let completedPageCount: Int
        let pendingOperation: DownloadStartMode?
    }

    func computeRetryParams(
        download: DownloadedGallery,
        resolvedMode: DownloadStartMode,
        existingResumeState: DownloadResumeState?,
        gid: String
    ) -> RetryParams {
        let shouldResumeExisting = shouldResumeExistingWorkingSet(
            for: download,
            mode: resolvedMode,
            resumeState: existingResumeState
        )
        let shouldStartImmediately =
            activeTask == nil || activeGalleryID == gid
        let resumedStatus: DownloadStatus
        let completedPageCount: Int
        let pendingOperation: DownloadStartMode?

        if shouldResumeExisting {
            resumedStatus = shouldStartImmediately
                ? .downloading : .queued
            completedPageCount = download.completedPageCount
            pendingOperation = nil
        } else if shouldStartImmediately {
            resumedStatus = .downloading
            completedPageCount = validatedCompletedPageCount(download)
            pendingOperation = nil
        } else {
            resumedStatus = download.status
            completedPageCount = validatedCompletedPageCount(download)
            pendingOperation = resolvedMode
        }

        return RetryParams(
            shouldResumeExistingWork: shouldResumeExisting,
            resumedStatus: resumedStatus,
            completedPageCount: completedPageCount,
            pendingOperation: pendingOperation
        )
    }

    func writeRetryResumeState(
        download: DownloadedGallery,
        resolvedMode: DownloadStartMode,
        existingResumeState: DownloadResumeState?,
        temporaryFolderURL: URL
    ) {
        let downloadOptions = download.downloadOptionsSnapshot
        let versionSignature = preferredVersionSignature(
            for: download,
            mode: resolvedMode,
            resumeState: existingResumeState
        )
        let pageCount = preferredWorkingPageCount(
            for: download,
            mode: resolvedMode,
            versionSignature: versionSignature,
            resumeState: existingResumeState
        )
        try? storage.writeResumeState(
            .init(
                mode: resolvedMode,
                versionSignature: versionSignature,
                pageCount: pageCount,
                downloadOptions: downloadOptions
            ),
            folderURL: temporaryFolderURL
        )
    }

    func clearSelectedFailedPages(
        selectedPageIndices: [Int],
        temporaryFolderURL: URL
    ) {
        if let failedSnapshot = try? storage.readFailedPages(
            folderURL: temporaryFolderURL
        ) {
            let remainingPages = failedSnapshot.pages.filter {
                !selectedPageIndices.contains($0.index)
            }
            if remainingPages.isEmpty {
                try? storage.removeFailedPages(
                    folderURL: temporaryFolderURL
                )
            } else {
                try? storage.writeFailedPages(
                    .init(pages: remainingPages),
                    folderURL: temporaryFolderURL
                )
            }
        }
    }
}
