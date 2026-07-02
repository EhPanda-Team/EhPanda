import Foundation
import AppModels
import ComposableArchitecture
import AppTools
import HapticsClient
import DatabaseClient
import NetworkingFeature
import DownloadClient
import ReadingFeature

@Reducer
public struct PreviewsReducer: Sendable {
    @Reducer
    public enum Destination {
        case reading(ReadingReducer)
    }

    private enum CancelID {
        case fetchDatabaseInfos
        case observeDownloads
        case loadLocalPreviewURLs
        case fetchPreviewURLs
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var destination: Destination.State?

        // The gallery id this screen fetches; captured when pushed onto the host's gallery stack.
        public var gid = ""
        public var gallery: Gallery = .empty
        public var loadingState: LoadingState = .idle
        public var databaseLoadingState: LoadingState = .loading

        public var previewURLs = [Int: URL]()
        public var localPreviewURLs = [Int: URL]()
        public var previewConfig: PreviewConfig = .normal(rows: 4)
        public var localPreviewRequestID = UUID()

        public init(gid: String = "", gallery: Gallery = .empty) {
            self.gid = gid
            self.gallery = gallery
        }

        mutating func updatePreviewURLs(_ previewURLs: [Int: URL]) {
            self.previewURLs = self.previewURLs.merging(
                previewURLs, uniquingKeysWith: { stored, _ in stored }
            )
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)

        case syncPreviewURLs([Int: URL])
        case updateReadingProgress(Int)

        case fetchDatabaseInfos(String)
        case fetchDatabaseInfosDone(GalleryState)
        case observeDownloads(String)
        case observeDownloadsDone([DownloadedGallery])
        case loadLocalPreviewURLs(String)
        case loadLocalPreviewURLsDone(UUID, [Int: URL])
        case openReading(Int)
        case openReadingDone(Result<(DownloadedGallery, DownloadManifest), AppError>)
        case fetchPreviewURLs(Int)
        case fetchPreviewURLsDone(Result<[Int: URL], AppError>)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .destination(.presented(.reading(.onPerformDismiss))):
                return .send(.destination(.dismiss))

            case .destination:
                return .none

            case .syncPreviewURLs(let previewURLs):
                return .run { [state] _ in
                    await databaseClient.updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs)
                }

            case .updateReadingProgress(let progress):
                return .run { [state] _ in
                    await databaseClient.updateReadingProgress(gid: state.gallery.id, progress: progress)
                }

            case .fetchDatabaseInfos(let gid):
                guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
                state.gallery = gallery
                return .merge(
                    .run { [state] send in
                        guard let dbState = await databaseClient.fetchGalleryState(
                            gid: state.gallery.id
                        ) else { return }
                        await send(.fetchDatabaseInfosDone(dbState))
                    }
                    .cancellable(id: CancelID.fetchDatabaseInfos),
                    .send(.observeDownloads(gid)),
                    .send(.loadLocalPreviewURLs(gid))
                )

            case .fetchDatabaseInfosDone(let galleryState):
                if let previewConfig = galleryState.previewConfig {
                    state.previewConfig = previewConfig
                }
                state.previewURLs = galleryState.previewURLs
                state.databaseLoadingState = .idle
                return .none

            case .observeDownloads(let gid):
                guard gid.isValidGID else { return .none }
                return .run { send in
                    var previousRelevantDownloads = [DownloadedGallery]()
                    var hadRelevantDownloads = false
                    for await downloads in downloadClient.observeDownloads() {
                        let relevantDownloads = downloads.filter { $0.gid == gid }
                        let hasRelevantDownloads = !relevantDownloads.isEmpty
                        guard hasRelevantDownloads || hadRelevantDownloads else { continue }
                        if relevantDownloads == previousRelevantDownloads {
                            hadRelevantDownloads = hasRelevantDownloads
                            continue
                        }
                        previousRelevantDownloads = relevantDownloads
                        hadRelevantDownloads = hasRelevantDownloads
                        await send(.observeDownloadsDone(relevantDownloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone:
                return .send(.loadLocalPreviewURLs(state.gallery.id))

            case .loadLocalPreviewURLs(let gid):
                guard gid.isValidGID else {
                    state.localPreviewRequestID = UUID()
                    state.localPreviewURLs = .init()
                    return .none
                }
                let requestID = UUID()
                state.localPreviewRequestID = requestID
                return .run { send in
                    let localPreviewURLs = await downloadClient.loadLocalPageURLs(gid) ?? [:]
                    await send(.loadLocalPreviewURLsDone(requestID, localPreviewURLs))
                }
                .cancellable(id: CancelID.loadLocalPreviewURLs, cancelInFlight: true)

            case .loadLocalPreviewURLsDone(let requestID, let localPreviewURLs):
                guard state.localPreviewRequestID == requestID else { return .none }
                guard state.localPreviewURLs != localPreviewURLs else { return .none }
                state.localPreviewURLs = localPreviewURLs
                return .none

            case .openReading:
                return .run { [galleryID = state.gallery.id] send in
                    guard galleryID.isValidGID else {
                        await send(.openReadingDone(.failure(.notFound)))
                        return
                    }
                    await send(.openReadingDone(.success(try await downloadClient.loadManifest(galleryID))))
                } catch: { error, send in
                    await send(.openReadingDone(.failure(AppError(error))))
                }

            case .openReadingDone(let result):
                var readingState: ReadingReducer.State
                if case .success(let (download, manifest)) = result {
                    readingState = .init(contentSource: .local(download, manifest))
                } else {
                    readingState = .init(contentSource: .remote)
                    readingState.localPageURLs = state.localPreviewURLs
                }
                readingState.gallery = state.gallery
                state.destination = .reading(readingState)
                return .none

            case .fetchPreviewURLs(let index):
                guard state.loadingState != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.loadingState = .loading
                let pageNum = state.previewConfig.pageNumber(index: index)
                return .run { send in
                    let response = await GalleryPreviewURLsRequest(galleryURL: galleryURL, pageNum: pageNum).response()
                    await send(.fetchPreviewURLsDone(response))
                }
                .cancellable(id: CancelID.fetchPreviewURLs)

            case .fetchPreviewURLsDone(let result):
                state.loadingState = .idle

                switch result {
                case .success(let previewURLs):
                    guard !previewURLs.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.updatePreviewURLs(previewURLs)
                    return .send(.syncPreviewURLs(previewURLs))
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.reading,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
    }
}

extension PreviewsReducer.Destination.State: Equatable, Sendable {}
