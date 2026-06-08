//
//  DownloadClient+Cache.swift
//  EhPanda
//

import Foundation

// MARK: - Cache Operations
extension DownloadManager {
    func cacheKeys(
        for url: URL,
        includeStableAlias: Bool
    ) -> [String] {
        url.imageCacheKeys(includeStableAlias: includeStableAlias)
    }

    func removeCachedImages(
        for urls: [URL?],
        includeStableAlias: Bool
    ) async {
        let keys = urls
            .compactMap(\.self)
            .flatMap {
                cacheKeys(for: $0, includeStableAlias: includeStableAlias)
            }

        for key in Set(keys) {
            await libraryClient.removeCachedImage(key)
        }
    }

    func pageImageCacheURLs(
        imageURL: URL?
    ) -> [URL?] {
        [imageURL]
    }

    func restorePageFromCache(
        index: Int,
        source: CacheRestoreSource,
        folderURL: URL,
        preferredRelativePath: String?,
        overwriteExistingFile: Bool = false
    ) async throws -> PageResult? {
        guard let cachedData = await validatedCachedAssetData(
            for: source.cacheURLs
        )
        else {
            return nil
        }

        let relativePath: String
        if let preferredRelativePath {
            relativePath = preferredRelativePath
        } else if let fallbackURL = source.referenceURL {
            let ext = fileExtension(
                for: fallbackURL,
                response: nil,
                prefixData: cachedData
            )
            relativePath = storage.makePageRelativePath(
                gid: source.gid,
                token: source.token,
                index: index,
                fileExtension: ext
            )
        } else {
            return nil
        }

        let fileURL = folderURL
            .appendingPathComponent(relativePath)
        if overwriteExistingFile
            || !fileManager.operate({ $0.fileExists(atPath: fileURL.path) }) {
            try write(data: cachedData, to: fileURL)
        }

        return .init(
            index: index,
            relativePath: relativePath,
            imageURL: source.imageURL
        )
    }

    func preferredPageReferenceURL(
        resolvedImageSource: ResolvedImageSource
    ) -> URL? {
        resolvedImageSource.imageURL
    }

    func preferredPageReferenceURL(
        imageURL: URL?
    ) -> URL? {
        imageURL
    }

    func clearFailedPage(
        index: Int,
        folderURL: URL
    ) throws {
        guard let failedSnapshot = try? storage
                .readFailedPages(folderURL: folderURL) else {
            return
        }
        let remainingPages = failedSnapshot.pages
            .filter { $0.index != index }
        if remainingPages.count == failedSnapshot.pages.count {
            return
        }
        if remainingPages.isEmpty {
            try? storage.removeFailedPages(folderURL: folderURL)
        } else {
            try storage.writeFailedPages(
                .init(pages: remainingPages),
                folderURL: folderURL
            )
        }
    }

    func cachedImageData(for url: URL) async -> Data? {
        await cachedImageData(
            for: [url],
            includeStableAlias: false
        )
    }

    func cachedImageData(
        for urls: [URL?],
        includeStableAlias: Bool
    ) async -> Data? {
        let allKeys = urls
            .compactMap { $0 }
            .flatMap {
                cacheKeys(
                    for: $0,
                    includeStableAlias: includeStableAlias
                )
            }
        let keys = allKeys
            .reduce(into: [String]()) { partialResult, key in
                guard !partialResult.contains(key) else {
                    return
                }
                partialResult.append(key)
            }

        for key in keys {
            if let data = await cachedImageData(forKey: key) {
                return data
            }
        }
        return nil
    }

    func cachedImageData(forKey key: String) async -> Data? {
        await libraryClient.cachedImageData(key)
    }

    func validatedCachedAssetData(
        for urls: [URL?]
    ) async -> Data? {
        guard let cachedData = await cachedImageData(
            for: urls,
            includeStableAlias: true
        ) else {
            return nil
        }
        guard detectCachedAssetError(
            data: cachedData,
            referenceURLs: urls
        ) == nil else {
            await removeCachedImages(
                for: urls,
                includeStableAlias: true
            )
            return nil
        }
        return cachedData
    }

    func detectCachedAssetError(
        data: Data,
        referenceURLs _: [URL?]
    ) -> AppError? {
        guard !data.isEmpty else { return .parseFailed }
        if isAuthenticationRequiredPlaceholderImageData(data) {
            return .authenticationRequired
        }
        if isQuotaExceededAssetData(data) {
            return .quotaExceeded
        }

        let looksLikeHTML = prefixLooksLikeHTML(
            Data(
                data.prefix(Self.responseInspectionPrefixLength)
            )
        )
        if let error = detectTextualDownloadError(
            data: data,
            looksLikeHTML: looksLikeHTML
        ) {
            return error
        }

        return isDecodableImageData(data) ? nil : .parseFailed
    }
}
