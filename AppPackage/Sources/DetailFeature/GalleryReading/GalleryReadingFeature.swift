public import AppComponents
public import AppModels
public import ComposableArchitecture
import DownloadClient
public import Foundation
import GalleryClient
import NetworkingFeature
public import ReadingFeature

/// Opens the reader straight from a gallery list or grid, with no Detail beneath it (owner decisions
/// D89 and D146: a double tap, a tap on the cover, or the Read action).
///
/// A list gallery carries no detail, so the reader's source is resolved before it is presented: the
/// download when the gallery has a readable manifest, which needs no network, and otherwise the
/// remote gallery's own preview configuration, language and first preview URLs. While that runs,
/// `isOpening` lets the host show its loading state. A route the user takes meanwhile wins: the host
/// calls `cancelOpening()` and the late result is dropped. A failure shows as this feature's toast.
///
/// Every host is registered with the app's scene-phase router through `flushAction`, so a background
/// force-quit keeps the presented reader's last page.
@Reducer
public struct GalleryReadingFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var reader: ReadingReducer.State?
        @Presents public var toast: AppAlertState<Never>?
        /// The open in flight, if any. Only its own result may present the reader.
        var requestID: UUID?

        public var isOpening: Bool { requestID != nil }

        /// The action that saves the presented reader's progress, or `nil` while none is presented.
        public var flushAction: Action? {
            reader == nil ? nil : .reader(.presented(.flushReadingProgress))
        }

        public init() {}

        /// Drops the open in flight because the user took another route, which its late result must not override.
        public mutating func cancelOpening() {
            requestID = nil
        }
    }

    public enum Action {
        case open(Gallery)
        case openDone(requestID: UUID, Result<ReadingReducer.State, AppError>)
        case reader(PresentationAction<ReadingReducer.Action>)
        case toast(PresentationAction<Never>)
    }

    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.galleryClient) private var galleryClient
    @Dependency(\.uuid) private var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .open(let gallery):
                let requestID = uuid()
                state.requestID = requestID
                return .run { send in
                    let reader = try await readerState(for: gallery)
                    await send(.openDone(requestID: requestID, .success(reader)))
                } catch: { error, send in
                    await send(.openDone(requestID: requestID, .failure(AppError(error))))
                }

            case .openDone(let requestID, let result):
                guard state.requestID == requestID else { return .none }
                state.requestID = nil
                switch result {
                case .success(let reader):
                    state.reader = reader
                    return .send(.reader(.presented(.onPresented)))
                case .failure(let error):
                    state.toast = .error(caption: error.alertText)
                    return .none
                }

            case .reader(.presented(.onPerformDismiss)):
                return .send(.reader(.dismiss))

            case .reader, .toast:
                return .none
            }
        }
        .ifLet(\.$reader, action: \.reader, destination: ReadingReducer.init)
        .ifLet(\.$toast, action: \.toast)
    }

    private func readerState(for gallery: Gallery) async throws -> ReadingReducer.State {
        let local: (download: DownloadedGallery, manifest: DownloadManifest)?
        do {
            local = try await downloadClient.loadManifest(gallery.id)
        } catch {
            // Most list galleries are not downloaded: a missing or unreadable manifest reads the remote gallery.
            local = nil
        }
        if let local {
            return .init(gallery: gallery, contentSource: .local(download: local.download, manifest: local.manifest))
        }
        guard let galleryURL = gallery.galleryURL else { throw AppError.notFound }
        let response = try await galleryClient.fetchGalleryDetail(gallery.id, galleryURL)
        var remote = ReadingReducer.State(
            gallery: gallery,
            previewConfig: response.galleryState.previewConfig ?? .normal(rows: 4),
            language: response.galleryDetail.language
        )
        remote.previewURLs = response.galleryState.previewURLs
        remote.thumbnailURLs = response.galleryState.thumbnailURLs
        return remote
    }
}
