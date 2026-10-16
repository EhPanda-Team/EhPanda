import AppComponents
import AppModels
import ComposableArchitecture
import DownloadClient
import Foundation
import NetworkingFeature
import ReadingFeature

extension FavoritesReducer {
    var readingReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .openReading(let gallery):
                let requestID = UUID()
                state.readingRequestID = requestID
                return .run { send in
                    @Dependency(\.downloadClient) var downloadClient
                    let local: (download: DownloadedGallery, manifest: DownloadManifest)?
                    do {
                        local = try await downloadClient.loadManifest(gallery.id)
                    } catch {
                        // Favorites need not be downloaded. A missing/unreadable manifest uses the remote source.
                        local = nil
                    }
                    let reading: ReadingReducer.State
                    if let local {
                        reading = .init(
                            gallery: gallery,
                            contentSource: .local(download: local.download, manifest: local.manifest)
                        )
                    } else {
                        guard let galleryURL = gallery.galleryURL else { throw AppError.notFound }
                        let response = try await GalleryDetailRequest(gid: gallery.id, galleryURL: galleryURL)
                            .response()
                        var remote = ReadingReducer.State(
                            gallery: gallery,
                            previewConfig: response.galleryState.previewConfig ?? .normal(rows: 4),
                            language: response.galleryDetail.language
                        )
                        remote.previewURLs = response.galleryState.previewURLs
                        remote.thumbnailURLs = response.galleryState.thumbnailURLs
                        reading = remote
                    }
                    await send(.openReadingDone(requestID: requestID, .success(reading)))
                } catch: { error, send in
                    await send(.openReadingDone(requestID: requestID, .failure(AppError(error))))
                }

            case .openReadingDone(let requestID, let result):
                guard state.readingRequestID == requestID else { return .none }
                state.readingRequestID = nil
                switch result {
                case .success(let reading):
                    state.destination = .reading(reading)
                    return .send(.destination(.presented(.reading(.onPresented))))
                case .failure(let error):
                    state.toast = .error(caption: error.alertText)
                    return .none
                }

            case .destination(.presented(.reading(.onPerformDismiss))):
                return .send(.destination(.dismiss))

            default:
                return .none
            }
        }
    }
}
