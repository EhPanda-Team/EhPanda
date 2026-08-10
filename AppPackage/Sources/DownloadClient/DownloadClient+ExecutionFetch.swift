import AppModels
import Foundation
import NetworkingFeature

// MARK: - Fetch & Normalize Payload
extension DownloadCoordinator {
    public func fetchLatestPayload(
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
        let detail = detailResponse.galleryDetail
        // D-G14-01, the mid-run half: a freshly parsed detail carrying no page count settles the
        // download as FAILED, never a silent no-op. It joins the missing-gallery-URL guard above at
        // one boundary because both mean "this detail cannot support a run". The throw propagates
        // through `fetchNormalizeAndDownload` to `processDownload`'s catch, then
        // `handleProcessDownloadError` → `handleProcessDownloadAppError` → `persistFailure` →
        // `settleDownloadFailure`, which records the error and clears the queue intent — a visible
        // state the user can retry. No-opping instead would leave a 0-of-0 record that reads
        // complete and fake-finishes the gallery. The guard is synchronous: nothing that did not
        // await before awaits now.
        guard detail.pageCount > 0 else { throw AppError.notFound }
        let galleryState = detailResponse.galleryState
        let components = buildGalleryComponents(
            download: download,
            detail: detail,
            galleryState: galleryState,
            galleryURL: galleryURL
        )
        let versionMetadata = await fetchOptionalVersionMetadata(
            host: download.host,
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

    public func fetchVersionMetadata(
        host: GalleryHost,
        gid: String,
        token: String
    ) async -> Result<DownloadVersionMetadata, AppError> {
        do throws(AppError) {
            return .success(
                try await GalleryVersionMetadataRequest(
                    host: host,
                    gid: gid,
                    token: token,
                    urlSession: urlSession
                )
                .response()
            )
        } catch {
            return .failure(error)
        }
    }

    private func fetchOptionalVersionMetadata(
        host: GalleryHost,
        gid: String,
        token: String
    ) async -> DownloadVersionMetadata? {
        switch await fetchVersionMetadata(
            host: host,
            gid: gid,
            token: token
        ) {
        case .success(let metadata):
            return metadata
        case .failure:
            return nil
        }
    }

    /// Refines a fetched payload's page selection against the freshly fetched page count.
    ///
    /// **Three states, and the difference between two of them is the whole contract (CR-04).**
    /// `rawPageSelection` is the coordinator's queue-intent entry for this run:
    ///
    /// - `nil` means no selection was ever made. It stays nil, and `pendingPageIndices` reads that
    ///   as no restriction — every page the record still owes.
    /// - A non-nil selection means the caller named pages, and it stays PRESENT: a `Set` that may
    ///   be empty once this second, defensive filter removes what the newly fetched count cannot
    ///   support. Collapsing that empty case to nil is what let an inadmissible narrow request
    ///   become a whole-gallery repair, because the two states then shared one value while meaning
    ///   opposite things.
    /// - `.update` discards the selection entirely, matching `retryPages`' documented whole-update
    ///   delegation: an update refreshes the gallery against a page count no earlier subset was
    ///   drawn against.
    ///
    /// The filter is defensive rather than load-bearing — the public boundary already refused an
    /// inadmissible request — but the page count it validates against is the FETCHED one, which
    /// can differ from the record's. Failing closed here is the honest answer to that drift.
    ///
    /// G-15-14, same class as the two range sites: validating a page number by comparison rather
    /// than by building `1...pageCount` means no range exists here to be invalid. The predicate is
    /// identical for every positive count; at zero it simply admits nothing, where the range form
    /// trapped the process.
    public func normalizeFetchedPayload(
        _ payload: DownloadRequestPayload,
        mode: DownloadStartMode,
        rawPageSelection: [Int]?
    ) -> DownloadRequestPayload {
        let pageCount = payload.galleryDetail.pageCount
        let pageSelection: Set<Int>? = if mode == .update {
            nil
        } else {
            rawPageSelection.map({ selection in
                Set(selection.filter({ $0 >= 1 && $0 <= pageCount }))
            })
        }

        // Compared against the payload's own selection rather than the raw array: the two are
        // different types, and this is the only comparison that answers whether a rebuild would
        // change anything.
        guard pageSelection != payload.pageSelection else {
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
            pageSelection: pageSelection
        )
    }
}
