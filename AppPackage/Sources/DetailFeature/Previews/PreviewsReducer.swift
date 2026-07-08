import Foundation
import AppModels
import Sharing
import ComposableArchitecture
import AppTools
import HapticsClient
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
        case observeDownloads
        case loadLocalPreviewURLs
        case fetchPreviewURLs
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @SharedReader(.setting) public var setting: Setting
        @Presents public var destination: Destination.State?

        // The gallery id this screen fetches; captured when pushed onto the host's gallery stack.
        public var gid = ""
        public var gallery: Gallery = .empty
        // Threaded from the detail context (via the `pushPreviews` delegate) so a reader opened from
        // this screen keeps the correct page math (`previewConfig`) and Live Text `language` for
        // remote sessions — Previews itself never fetches a gallery detail to re-derive them.
        public var language: Language?
        public var loadingState: LoadingState = .idle

        public var previewURLs = [Int: URL]()
        public var localPreviewURLs = [Int: URL]()
        public var previewConfig: PreviewConfig = .normal(rows: 4)
        public var localPreviewRequestID = UUID()

        public init(
            gallery: Gallery,
            previewConfig: PreviewConfig = .normal(rows: 4), language: Language? = nil
        ) {
            self.gid = gallery.id
            self.gallery = gallery
            self.previewConfig = previewConfig
            self.language = language
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

        case updateReadingProgress(Int)

        case onAppear(String)
        case observeDownloads(String)
        case observeDownloadsDone([DownloadedGallery])
        case loadLocalPreviewURLs(String)
        case loadLocalPreviewURLsDone(UUID, [Int: URL])
        case openReading(Int)
        case openReadingDone(Result<(DownloadedGallery, DownloadManifest), AppError>)
        case fetchPreviewURLs(Int)
        case fetchPreviewURLsDone(Result<[Int: URL], AppError>)
    }

    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.date) private var date

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

            case .updateReadingProgress(let progress):
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.updateReadingProgress(
                        gid: state.gallery.id, token: state.gallery.token, progress: progress, date: date.now
                    )
                }
                return .none

            case .onAppear(let gid):
                // Gallery is seeded from the pushing context; preview URLs are fetched on demand.
                return .merge(
                    .send(.observeDownloads(gid)),
                    .send(.loadLocalPreviewURLs(gid))
                )

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
                    readingState = .init(
                        gallery: state.gallery, contentSource: .local(download, manifest),
                        previewConfig: state.previewConfig, language: state.language
                    )
                } else {
                    readingState = .init(
                        gallery: state.gallery, contentSource: .remote,
                        previewConfig: state.previewConfig, language: state.language
                    )
                    readingState.localPageURLs = state.localPreviewURLs
                }
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
                    return .none
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
