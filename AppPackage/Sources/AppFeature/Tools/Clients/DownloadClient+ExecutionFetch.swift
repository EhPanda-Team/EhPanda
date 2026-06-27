import Foundation
import AppModels

// MARK: - Fetch & Normalize Payload
extension DownloadCoordinator {
    func fetchLatestPayload(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        options: DownloadRequestOptions,
        pageSelection: [Int]?
    ) async throws -> DownloadRequestPayload {
        let galleryURL = download.gallery.galleryURL
        guard let galleryURL else { throw AppError.notFound }
        let detailResponse = try await GalleryDetailRequest(
            gid: download.gid,
            galleryURL: galleryURL,
            urlSession: urlSession,
            allowsCellular: options.allowCellular
        )
        .response()
        .get()
        let detail = detailResponse.galleryDetail
        let galleryState = detailResponse.galleryState
        let components = buildGalleryComponents(
            download: download,
            detail: detail,
            galleryState: galleryState,
            galleryURL: galleryURL
        )
        let versionMetadata = await fetchOptionalVersionMetadata(
            gid: download.gid,
            token: download.token
        )
        let fetchedData = FetchedGalleryData(
            download: download,
            detail: detail,
            versionMetadata: versionMetadata
        )
        return buildPayload(
            fetchedData: fetchedData,
            components: components,
            mode: mode,
            pageSelection: pageSelection
        )
    }

    private struct FetchedGalleryData {
        let download: DownloadedGallery
        let detail: GalleryDetail
        let versionMetadata: DownloadVersionMetadata?
    }

    private func buildPayload(
        fetchedData: FetchedGalleryData,
        components: GalleryComponents,
        mode: DownloadStartMode,
        pageSelection: [Int]?
    ) -> DownloadRequestPayload {
        let download = fetchedData.download
        let detail = fetchedData.detail
        let versionMetadata = fetchedData.versionMetadata
        return .init(
            gallery: components.gallery,
            galleryDetail: detail,
            previewURLs: components.previewURLs,
            previewConfig: components.previewConfig,
            host: download.host,
            folderName: download.folderName,
            versionMetadata: versionMetadata,
            mode: mode,
            pageSelection: pageSelection.map(Set.init)
        )
    }

    private struct GalleryComponents {
        let gallery: Gallery
        let previewURLs: [Int: URL]
        let previewConfig: PreviewConfig
    }

    private func buildGalleryComponents(
        download: DownloadedGallery,
        detail: GalleryDetail,
        galleryState: GalleryState,
        galleryURL: URL
    ) -> GalleryComponents {
        let gallery = Gallery(
            gid: download.gid,
            token: download.token,
            title: detail.title,
            rating: detail.rating,
            tags: galleryState.tags,
            category: detail.category,
            uploader: detail.uploader,
            pageCount: detail.pageCount,
            postedDate: detail.postedDate,
            coverURL: detail.coverURL ?? download.onlineCoverURL,
            galleryURL: galleryURL
        )
        return GalleryComponents(
            gallery: gallery,
            previewURLs: galleryState.previewURLs,
            previewConfig: galleryState.previewConfig ?? .normal(rows: 4)
        )
    }

    func fetchVersionMetadata(
        gid: String,
        token: String
    ) async -> Result<DownloadVersionMetadata, AppError> {
        await GalleryVersionMetadataRequest(
            gid: gid,
            token: token,
            urlSession: urlSession
        ).response()
    }

    private func fetchOptionalVersionMetadata(
        gid: String,
        token: String
    ) async -> DownloadVersionMetadata? {
        switch await fetchVersionMetadata(
            gid: gid,
            token: token
        ) {
        case .success(let metadata):
            return metadata
        case .failure:
            return nil
        }
    }

    func normalizeFetchedPayload(
        _ payload: DownloadRequestPayload,
        mode: DownloadStartMode,
        rawPageSelection: [Int]?
    ) -> DownloadRequestPayload {
        let validPageSelection = rawPageSelection?
            .filter { (1...payload.galleryDetail.pageCount).contains($0) }
        let pageSelection = validPageSelection?.isEmpty == false && mode != .update
            ? validPageSelection
            : nil

        guard pageSelection != rawPageSelection else {
            return payload
        }

        return .init(
            gallery: payload.gallery,
            galleryDetail: payload.galleryDetail,
            previewURLs: payload.previewURLs,
            previewConfig: payload.previewConfig,
            host: payload.host,
            folderName: payload.folderName,
            versionMetadata: payload.versionMetadata,
            mode: payload.mode,
            pageSelection: pageSelection.map(Set.init)
        )
    }
}
