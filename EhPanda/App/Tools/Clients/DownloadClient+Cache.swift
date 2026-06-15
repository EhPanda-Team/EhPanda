//
//  DownloadClient+Cache.swift
//  EhPanda
//

import Foundation

// MARK: - Cache Operations
extension DownloadCoordinator {
    func removeCachedImages(
        for urls: [URL?]
    ) async {
        let keys = urls
            .compactMap(\.self)
            .flatMap(\.imageCacheKeys)

        let uniqueKeys = Array(Set(keys))
        try? await DataCache.shared.removeData(forKeys: uniqueKeys)
        for key in uniqueKeys {
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

    func cachedImageData(
        for urls: [URL?]
    ) async -> Data? {
        let keys = urls
            .compactMap { $0 }
            .flatMap(\.imageCacheKeys)
        return await DataCache.shared.data(forKeys: keys)
    }

    func validatedCachedAssetData(
        for urls: [URL?]
    ) async -> Data? {
        guard let cachedData = await cachedImageData(for: urls) else {
            return nil
        }
        guard detectCachedAssetError(
            data: cachedData,
            referenceURLs: urls
        ) == nil else {
            await removeCachedImages(for: urls)
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
