import Foundation
import AppModels
import Resources
import ComposableArchitecture
import AppComponents
import AppTools
import DeviceClient
import DownloadClient
import ReadingFeature
import DetailFeature

@Reducer
public struct DownloadsReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case presentGalleryDetail(String, DownloadedGallery?)
    }

    @Reducer
    public enum Destination {
        case inspector(DownloadInspectorReducer)
        case reading(ReadingReducer)
        case folderManager(FolderManagerReducer)
    }

    public enum Alert: Equatable, Sendable {
        case confirmDelete(String)
    }

    public enum Dialog: Equatable, Sendable {
        case move(String, String)
    }

    private enum CancelID {
        case observeDownloads
        case fetchFolders
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<GalleryPath.State>()
        @Presents public var destination: Destination.State?
        @Presents public var alert: AppAlertState<Alert>?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var keyword = ""
        public var folderFilter: DownloadFolderFilter = .all
        public var folders = [String]()
        public var downloads = [DownloadedGallery]()
        public var loadingState: LoadingState = .loading
        public var hasLoadedInitialDownloads = false

        public var readingRequestID = UUID()

        public init() {}

        var filteredDownloads: [DownloadedGallery] {
            downloads.filter {
                $0.matches(folderFilter: folderFilter)
                    && (
                        keyword.isEmpty
                            || $0.searchableText.caseInsensitiveContains(keyword)
                    )
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case galleryTapped(String)
        case pushGalleryDetail(String)
        case path(StackActionOf<GalleryPath>)
        case destination(PresentationAction<Destination.Action>)
        case inspectorButtonTapped(String)
        case folderManagerButtonTapped
        case alert(PresentationAction<Alert>)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteDownloadButtonTapped(DownloadedGallery)
        case moveButtonTapped(DownloadedGallery)

        case onAppear
        case fetchDownloads
        case fetchDownloadsDone([DownloadedGallery])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case refreshDownloads
        case refreshDownloadsDone
        case fetchFolders
        case fetchFoldersDone([String])
        case moveDownload(String, String)
        case moveDownloadDone(Result<Void, AppError>)
        case openReading(String)
        case openReadingDone(UUID, String, Result<(DownloadedGallery, DownloadManifest), AppError>)
        case toggleDownloadPause(String)
        case toggleDownloadPauseDone(Result<Void, AppError>)
        case updateDownload(String)
        case updateDownloadDone(Result<Void, AppError>)
        case deleteDownload(String)
        case deleteDownloadDone(Result<Void, AppError>)
    }

    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.deviceClient) private var deviceClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .galleryTapped(let gid):
                let download = state.downloads.first(where: { $0.gid == gid })
                return GalleryNavigation.routeGalleryDetail(
                    isPad: deviceClient.isPad,
                    present: { .delegate(.presentGalleryDetail(gid, download)) },
                    push: { .pushGalleryDetail(gid) }
                )

            case .pushGalleryDetail(let gid):
                // Seed the detail with the locally downloaded gallery/badge so it renders offline.
                state.path.appendGuardingDuplicate(.detail(.init(
                    gid: gid,
                    seededFrom: state.downloads.first(where: { $0.gid == gid })
                )))
                return .none

            case .delegate:
                return .none

            case .inspectorButtonTapped(let gid):
                state.destination = .inspector(.init(gid: gid))
                return .none

            case .folderManagerButtonTapped:
                state.destination = .folderManager(.init())
                return .none

            case .deleteDownloadButtonTapped(let download):
                state.alert = AppAlertState {
                    TextState(L10n.Localizable.DownloadsView.Dialog.Title.deleteDownload)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete(download.gid)) {
                        TextState(L10n.Localizable.ConfirmationDialog.Button.delete)
                    }
                    ButtonState(role: .cancel) {
                        TextState(L10n.Localizable.Common.Button.cancel)
                    }
                } message: {
                    TextState(
                        download.canTogglePause
                            ? L10n.Localizable.DownloadsView.Dialog.Message.deleteActiveDownload
                            : L10n.Localizable.DownloadsView.Dialog.Message.deleteDownloadedGallery
                    )
                }
                return .none

            case .moveButtonTapped(let download):
                let destinations = state.folders.filter { $0 != download.folderName }
                state.confirmationDialog = ConfirmationDialogState {
                    TextState(L10n.Localizable.DownloadsView.Menu.Button.moveToFolder)
                } actions: {
                    for folder in destinations {
                        ButtonState(action: .move(download.gid, folder)) {
                            TextState(folder)
                        }
                    }
                    ButtonState(role: .cancel) {
                        TextState(L10n.Localizable.Common.Button.cancel)
                    }
                }
                return .none

            case .alert(.presented(.confirmDelete(let gid))):
                return .send(.deleteDownload(gid))

            case .alert:
                return .none

            case .confirmationDialog(.presented(.move(let gid, let folder))):
                return .send(.moveDownload(gid, folder))

            case .confirmationDialog:
                return .none

            case .onAppear:
                guard !state.hasLoadedInitialDownloads else { return .send(.fetchFolders) }
                state.hasLoadedInitialDownloads = true
                return .merge(
                    .send(.fetchDownloads),
                    .send(.observeDownloads),
                    .send(.fetchFolders)
                )

            case .fetchDownloads:
                state.loadingState = .loading
                return .run { send in
                    await send(.fetchDownloadsDone(try await downloadClient.fetchDownloads()))
                }

            case .fetchDownloadsDone(let downloads), .observeDownloadsDone(let downloads):
                guard state.downloads != downloads || state.loadingState != .idle else {
                    return .none
                }
                state.downloads = downloads
                state.loadingState = .idle
                return .none

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .refreshDownloads:
                return .run { send in
                    await downloadClient.refreshDownloads()
                    await send(.refreshDownloadsDone)
                }

            case .refreshDownloadsDone:
                return .send(.fetchFolders)

            case .fetchFolders:
                return .run { send in
                    await send(.fetchFoldersDone(try await downloadClient.fetchFolders()))
                }
                .cancellable(id: CancelID.fetchFolders, cancelInFlight: true)

            case .fetchFoldersDone(let folders):
                state.folders = folders
                if case .folder(let name) = state.folderFilter,
                   !folders.contains(name) {
                    state.folderFilter = .all
                }
                return .none

            case .moveDownload(let gid, let folderName):
                return .run { send in
                    try await downloadClient.moveDownload(gid, folderName)
                    await send(.moveDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.moveDownloadDone(.failure(AppError(error))))
                }

            case .moveDownloadDone(let result):
                if case .success = result {
                    return .send(.fetchFolders)
                }
                return .none

            case .openReading(let gid):
                let requestID = UUID()
                state.readingRequestID = requestID
                return .run { send in
                    await send(
                        .openReadingDone(
                            requestID,
                            gid,
                            .success(try await downloadClient.loadManifest(gid))
                        )
                    )
                } catch: { error, send in
                    await send(.openReadingDone(requestID, gid, .failure(AppError(error))))
                }

            case .openReadingDone(let requestID, let gid, let result):
                guard state.readingRequestID == requestID else { return .none }
                var readingState: ReadingReducer.State
                if case .success(let (download, manifest)) = result {
                    readingState = .init(contentSource: .local(download, manifest))
                    readingState.gallery = download.gallery
                } else {
                    readingState = .init(contentSource: .remote)
                    if let download = state.downloads.first(where: { $0.gid == gid }) {
                        readingState.applyDownloadFallback(download)
                    }
                }
                state.destination = .reading(readingState)
                return .none

            case .toggleDownloadPause(let gid):
                return .run { send in
                    try await downloadClient.togglePause(gid)
                    await send(.toggleDownloadPauseDone(.success(())))
                } catch: { error, send in
                    await send(.toggleDownloadPauseDone(.failure(AppError(error))))
                }

            case .toggleDownloadPauseDone:
                return .none

            case .updateDownload(let gid):
                return .run { send in
                    try await downloadClient.retry(gid, .update)
                    await send(.updateDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.updateDownloadDone(.failure(AppError(error))))
                }

            // List-level mutations don't surface a per-op HUD: the `observeDownloads` stream is the
            // user-facing feedback from the DES-3 write-through index. Failures leave the current
            // observed state in place; the download client performs any targeted surprise repair.
            case .updateDownloadDone:
                return .none

            case .deleteDownload(let gid):
                return .run { send in
                    try await downloadClient.delete(gid)
                    await send(.deleteDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.deleteDownloadDone(.failure(AppError(error))))
                }

            case .deleteDownloadDone:
                return .none

            case let .path(.element(id: _, action: .detail(.destination(.presented(.folderManager(action)))))):
                switch action {
                case .createFolderDone, .renameFolderDone, .deleteFolderDone:
                    return .send(.fetchFolders)
                default:
                    return .none
                }

            case let .path(.element(id: _, action: .comments(.delegate(.performedCommentAction(gid))))):
                guard let id = state.path.detailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .detail(.fetchGalleryDetail))))

            case let .path(.element(id: _, action: elementAction)):
                if let next = GalleryNavigation.nextScreen(for: elementAction) {
                    state.path.appendGuardingDuplicate(next)
                }
                return .none

            case .path:
                return .none

            case .destination(.presented(.reading(.onPerformDismiss))):
                return .send(.destination(.dismiss))

            case .destination(.presented(.folderManager(.createFolderDone))),
                 .destination(.presented(.folderManager(.renameFolderDone))),
                 .destination(.presented(.folderManager(.deleteFolderDone))):
                return .send(.fetchFolders)

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
        .forEach(\.path, action: \.path)
    }
}

extension DownloadsReducer.Destination.State: Equatable {}

private extension ReadingReducer.State {
    mutating func applyDownloadFallback(_ download: DownloadedGallery) {
        gallery = download.gallery
        language = .other
    }
}
