//
//  DownloadClient+Persistence.swift
//  EhPanda
//

import CoreData
import Foundation

// MARK: - Disk Index
extension DownloadManager {
    @discardableResult
    func reloadDownloadIndex() async -> [DownloadedGallery] {
        do {
            let records = try storage.scanDownloadFolders()
            downloadIndex = deduplicatedDownloadIndex(from: records)
            return downloads(from: records)
        } catch {
            Logger.error(error)
            downloadIndex = [:]
            return []
        }
    }

    func indexedDownload(gid: String) -> DownloadedGallery? {
        guard let record = downloadIndex[gid] else { return nil }
        return downloadedGallery(from: record)
    }

    func indexedDownloads() -> [DownloadedGallery] {
        downloads(from: Array(downloadIndex.values))
    }

    private func downloads(
        from records: [DownloadFolderRecord]
    ) -> [DownloadedGallery] {
        deduplicatedDownloadIndex(from: records).values
            .map { downloadedGallery(from: $0) }
            .sorted(by: sortDownloadsByDisplayStatus)
    }

    private func deduplicatedDownloadIndex(
        from records: [DownloadFolderRecord]
    ) -> [String: DownloadFolderRecord] {
        records.reduce(into: [:]) { index, record in
            let gid = record.manifest.gid
            guard let currentRecord = index[gid] else {
                index[gid] = record
                return
            }
            if record.displayDate > currentRecord.displayDate {
                index[gid] = record
            }
        }
    }

    private func downloadedGallery(
        from record: DownloadFolderRecord
    ) -> DownloadedGallery {
        let gid = record.manifest.gid
        return DownloadedGallery(
            manifest: record.manifest,
            folderRelativePath: record.relativePath,
            modifiedAt: record.modifiedAt,
            displayStatus: displayStatus(for: record),
            lastError: downloadErrors[gid]
        )
    }

    private func displayStatus(
        for record: DownloadFolderRecord
    ) -> DownloadDisplayStatus {
        let gid = record.manifest.gid
        if record.manifest.isComplete,
           updatedGalleryIDs.contains(gid) {
            return .updateAvailable
        }
        if record.manifest.isComplete {
            return .completed
        }
        if activeGalleryID == gid {
            return .active
        }
        if queueStore.contains(gid) {
            return .queued
        }
        if downloadErrors[gid] != nil {
            return .error
        }
        return .inactive
    }

    private func sortDownloadsByDisplayStatus(
        _ lhs: DownloadedGallery,
        _ rhs: DownloadedGallery
    ) -> Bool {
        if lhs.displayStatus != rhs.displayStatus {
            return lhs.displayStatus.rawValue < rhs.displayStatus.rawValue
        }
        return (lhs.lastDownloadedAt ?? .distantPast)
            > (rhs.lastDownloadedAt ?? .distantPast)
    }
}

private extension DownloadFolderRecord {
    var displayDate: Date {
        modifiedAt ?? manifest.downloadedAt
    }
}

// MARK: - Core Data Operations
extension DownloadManager {
    func fetchDownload(
        gid: String
    ) async -> DownloadedGallery? {
        _ = await reloadDownloadIndex()
        if let indexedDownload = indexedDownload(gid: gid) {
            return indexedDownload
        }
        return await fetchDownloadFromCoreData(gid: gid)
    }

    func fetchDownloadsFromStore() async -> [DownloadedGallery] {
#if DEBUG
        if let testingFetchDownloadsFromStoreHook {
            await testingFetchDownloadsFromStoreHook()
        }
#endif
        let downloads = await reloadDownloadIndex()
        guard downloads.isEmpty else { return downloads }
        return sortDownloads(await fetchDownloadsFromCoreData())
    }

    func fetchDownloadsFromStore(
        gids: [String]
    ) async -> [DownloadedGallery] {
        let gidSet = Set(gids)
        let indexedDownloads = await reloadDownloadIndex()
            .filter { gidSet.contains($0.gid) }
        let indexedGIDs = Set(indexedDownloads.map(\.gid))
        let missingGIDs = gids.filter { !indexedGIDs.contains($0) }
        guard !missingGIDs.isEmpty else { return indexedDownloads }
        let persistedDownloads = await fetchDownloadsFromCoreData(
            gids: missingGIDs
        )
        return sortDownloads(indexedDownloads + persistedDownloads)
    }

    private func fetchDownloadFromCoreData(
        gid: String
    ) async -> DownloadedGallery? {
        await MainActor.run {
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "gid == %@",
                gid
            )
            return try? context.fetch(request).first?.toEntity()
        }
    }

    private func fetchDownloadsFromCoreData() async -> [DownloadedGallery] {
        return await MainActor.run {
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.sortDescriptors = [
                NSSortDescriptor(
                    keyPath: \DownloadedGalleryMO
                        .lastDownloadedAt,
                    ascending: false
                )
            ]
            let objects = (try? context.fetch(request)) ?? []
            return objects.map { $0.toEntity() }
        }
    }

    private func fetchDownloadsFromCoreData(
        gids: [String]
    ) async -> [DownloadedGallery] {
        await MainActor.run {
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.predicate = NSPredicate(
                format: "gid IN %@",
                gids
            )
            request.sortDescriptors = [
                NSSortDescriptor(
                    keyPath: \DownloadedGalleryMO
                        .lastDownloadedAt,
                    ascending: false
                )
            ]
            let objects = (try? context.fetch(request)) ?? []
            return objects.map { $0.toEntity() }
        }
    }

    func updateDownloadRecord(
        gid: String,
        createIfMissing: Bool = true,
        update: @MainActor @Sendable @escaping (DownloadedGalleryMO) -> Void
    ) async throws {
        try await MainActor.run {
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "gid == %@",
                gid
            )

            let object: DownloadedGalleryMO
            if let storedObject =
                try context.fetch(request).first {
                object = storedObject
            } else if !createIfMissing {
                return
            } else {
                object = DownloadedGalleryMO(context: context)
                object.gid = gid
                object.host = GalleryHost.ehentai.rawValue
                object.token = ""
                object.title = ""
                object.category =
                    Category.private.rawValue
                object.pageCount = 0
                object.postedDate = .now
                object.rating = 0
                object.folderRelativePath = gid
                object.status =
                    DownloadStatus.queued.rawValue
                object.remoteVersionSignature = ""
                object.completedPageCount = 0
            }

            update(object)
            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                throw AppError.databaseCorrupted(
                    error.localizedDescription
                )
            }
        }
    }

    func deleteDownloadRecord(gid: String) async throws {
        try await MainActor.run {
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "gid == %@",
                gid
            )
            guard let object =
                    try context.fetch(request).first else {
                return
            }
            context.delete(object)
            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                throw AppError.databaseCorrupted(
                    error.localizedDescription
                )
            }
        }
    }
}

// MARK: - Persist Failure & Progress
extension DownloadManager {
    func persistFailure(
        error: AppError,
        context: FailureContext
    ) async {
#if DEBUG
        if let testingPersistFailureHook {
            await testingPersistFailureHook()
        }
#endif
        let workingCompletedPageCount =
            temporaryCompletedPageCount(
                gid: context.gid,
                expectedPageCount:
                    context.originalDownload.pageCount
            )
        let hasTemporaryWorkingSet = storage
            .temporaryFolderExists(gid: context.gid)
        let recoveredCompletedPageCount =
            hasTemporaryWorkingSet
            ? workingCompletedPageCount
            : max(
                context.originalDownload
                    .completedPageCount,
                workingCompletedPageCount
            )
        do {
            try await updateDownloadRecord(
                gid: context.gid,
                createIfMissing: false
            ) { record in
                record.lastError =
                    DownloadFailure(error: error).toData()
                record.pendingOperation = nil
                self.applyFailureStatus(
                    to: record,
                    context: context,
                    workingCompletedPageCount:
                        workingCompletedPageCount,
                    recoveredCompletedPageCount:
                        recoveredCompletedPageCount
                )
            }
        } catch {
            Logger.error(error)
        }
    }

    nonisolated private func applyFailureStatus(
        to record: DownloadedGalleryMO,
        context: FailureContext,
        workingCompletedPageCount: Int,
        recoveredCompletedPageCount: Int
    ) {
        if context.mode == .repair {
            applyRepairFailureStatus(to: record, context: context)
        } else if context.hadReadableFiles,
                  [.update, .redownload].contains(context.mode) {
            applyFallbackFailureStatus(to: record, context: context)
        } else if workingCompletedPageCount > 0 {
            record.status = DownloadStatus.partial.rawValue
            record.completedPageCount = Int64(workingCompletedPageCount)
            record.latestRemoteVersionSignature =
                context.latestSignature
                ?? context.originalDownload.latestRemoteVersionSignature
        } else {
            record.status = DownloadStatus.partial.rawValue
            record.completedPageCount = Int64(recoveredCompletedPageCount)
            record.latestRemoteVersionSignature =
                context.latestSignature
                ?? context.originalDownload.latestRemoteVersionSignature
        }
    }

    nonisolated private func applyRepairFailureStatus(
        to record: DownloadedGalleryMO,
        context: FailureContext
    ) {
        record.status = DownloadStatus.missingFiles.rawValue
        record.completedPageCount = Int64(
            context.originalDownload.completedPageCount
        )
        record.folderRelativePath =
            context.originalDownload.folderRelativePath
        record.coverRelativePath =
            context.originalDownload.coverRelativePath
        record.remoteVersionSignature =
            context.originalDownload.remoteVersionSignature
        record.latestRemoteVersionSignature =
            context.latestSignature
            ?? context.originalDownload.latestRemoteVersionSignature
    }

    nonisolated private func applyFallbackFailureStatus(
        to record: DownloadedGalleryMO,
        context: FailureContext
    ) {
        record.status = self.fallbackStatus(
            for: context.originalDownload,
            mode: context.mode,
            latestSignature: context.latestSignature
        ).rawValue
        record.completedPageCount = Int64(
            context.originalDownload.pageCount
        )
        record.folderRelativePath =
            context.originalDownload.folderRelativePath
        record.coverRelativePath =
            context.originalDownload.coverRelativePath
        record.remoteVersionSignature =
            context.originalDownload.remoteVersionSignature
        record.latestRemoteVersionSignature =
            context.latestSignature
            ?? context.originalDownload.latestRemoteVersionSignature
    }

    func flushDownloadProgress(
        gid: String,
        pendingResolvedPages: inout [PageResult],
        completedCount: Int,
        lastFlushDate: inout Date,
        force: Bool
    ) async throws {
        let shouldFlush = force
            || pendingResolvedPages.count
            >= Self.progressFlushPageInterval
            || Date().timeIntervalSince(lastFlushDate)
            >= Self.progressFlushMinimumInterval
        guard shouldFlush else { return }

        let resolvedPages = pendingResolvedPages
        pendingResolvedPages
            .removeAll(keepingCapacity: true)
        await persistResolvedImageURLs(
            gid: gid,
            entries: resolvedPages
        )
        try await updateDownloadRecord(
            gid: gid,
            createIfMissing: false
        ) { record in
            record.completedPageCount =
                Int64(completedCount)
        }
        lastFlushDate = Date()
        await notifyObservers()
    }

    func persistResolvedImageURLs(
        gid: String,
        index: Int,
        imageURL: URL?
    ) async {
        await persistResolvedImageURLs(
            gid: gid,
            entries: [
                .init(
                    index: index,
                    relativePath: "",
                    imageURL: imageURL
                )
            ]
        )
    }

    func persistResolvedImageURLs(
        gid: String,
        entries: [PageResult]
    ) async {
        guard gid.isValidGID else { return }
        let validEntries = entries
            .filter { $0.imageURL != nil }
        guard !validEntries.isEmpty else { return }

        await MainActor.run {
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<GalleryStateMO>(
                entityName: "GalleryStateMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "gid == %@",
                gid
            )

            let object: GalleryStateMO
            if let stored =
                try? context.fetch(request).first {
                object = stored
            } else {
                object = GalleryStateMO(context: context)
                object.gid = gid
            }

            var imageURLs = (object.imageURLs?.toObject()
                                as [Int: URL]?) ?? [:]
            var hasChanges = false

            for entry in validEntries {
                if let imageURL = entry.imageURL,
                   imageURLs[entry.index] != imageURL {
                    imageURLs[entry.index] = imageURL
                    hasChanges = true
                }
            }

            guard hasChanges else {
                return
            }

            object.imageURLs = imageURLs.toData()

            guard context.hasChanges else { return }
            try? context.save()
        }
    }

    func fetchCachedGalleryImageState(
        gid: String
    ) async -> CachedGalleryImageState? {
        await MainActor.run {
            guard gid.isValidGID else { return nil }
            let context = persistenceContainer.viewContext
            let request = NSFetchRequest<GalleryStateMO>(
                entityName: "GalleryStateMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "gid == %@",
                gid
            )
            guard let object =
                    try? context.fetch(request).first else {
                return nil
            }
            let state = object.toEntity()
            return .init(
                previewURLs: state.previewURLs,
                imageURLs: state.imageURLs
            )
        }
    }
}
