import AnalyticsClient
import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import DetailFeature
import DeviceClient
import DownloadClient
import Foundation
import ReadingFeature
import Resources

/// The downloads list.
///
/// **Failure-reporting policy: the observed record is this screen's feedback, so its mutation
/// failures are silent — deliberately, and enumerated (DES-3).** Unlike the inspector, which owns a
/// toast surface and reports every refusal (see ``DownloadInspectorReducer``), the list's only
/// presentation surfaces are confirmation prompts rather than outcome channels:
/// a refused mutation leaves the row exactly as the record still describes it, and the write-through
/// index re-renders that row through `observeDownloads`. The enumeration below is the complete set
/// of result-carrying actions and is meant to be checked against `Action` when one is added — a new
/// result-carrying action with no stated disposition contradicts this doc.
///
/// The confirmation surface named above is the per-row dialog owned by ``DownloadRowFeature``,
/// plus this reducer's own move-to-folder dialog. Neither is an outcome channel, so the argument
/// is unchanged by where the confirmation lives:
///
/// - `moveDownloadDone` — **deliberately silent** on failure: the row keeps its current folder, so
///   the screen already says the move did not happen.
/// - `updateDownloadDone` — **deliberately silent** on failure: the update badge stays put, which
///   is the same statement.
/// - `deleteDownloadDone` — **deliberately silent** on failure: the row is still there.
/// - `openReadingDone` — **reports by behaviour**: a failed local load falls back to the remote
///   reader, and bails without presenting only when the record itself vanished mid-flight, since
///   there is then nothing to seed a reader with.
/// - `toggleDownloadPauseDone` — **silent, and it is the weakest of these**: it is the same refusal
///   the inspector now reports (WR-05), seen from this screen, and the record-says-so argument is
///   thinner here because a refused toggle moves nothing at all. It stays silent in this round
///   because reporting it needs a toast surface this reducer does not have — a presentation
///   addition, not a branch fix. Recorded so it reads as an open item rather than a considered
///   no-report.
@Reducer
public struct DownloadsReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case presentGalleryDetail(gallery: Gallery, downloaded: DownloadedGallery?)
    }

    @Reducer
    public enum Destination {
        case inspector(DownloadInspectorReducer)
        case reading(ReadingReducer)
        case folderManager(FolderManagerReducer)
    }

    public enum Dialog: Equatable, Sendable {
        case move(gid: String, folderName: String)
    }

    private enum CancelID {
        case observeDownloads
        case fetchFolders
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.setting) public var setting: Setting
        public var path = StackState<GalleryPath.State>()
        @Presents public var destination: Destination.State?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var keyword = ""
        public var folderFilter: DownloadFolderFilter = .all
        public var folders = [String]()
        public var rows = IdentifiedArrayOf<DownloadRowFeature.State>()
        /// Only `.loading` (until the first snapshot lands) and `.idle` ever occur: the list reads
        /// the coordinator's in-memory index, which cannot fail (DEF-15-06), so the view carries no
        /// error state for it.
        public var loadingState: LoadingState = .loading
        public var hasLoadedInitialDownloads = false

        /// The observed snapshot, stored one row at a time.
        ///
        /// The rows are the storage because each carries its own delete confirmation
        /// (see ``DownloadRowFeature``); this projection keeps the snapshot the shape the rest of
        /// the reducer reads and writes it in. The setter matches incoming galleries onto existing
        /// rows by id rather than rebuilding the array, which is what lets a presented dialog
        /// survive an `observeDownloads` tick — and those tick constantly while a download runs, so
        /// rebuilding would tear the dialog down mid-decision.
        ///
        /// Ids are uniqued rather than assumed unique: a duplicate gid in a snapshot is not
        /// expected, and every lookup here already treats the first match as the row, but
        /// `uniqueElements:` would trap on one instead of resolving it the same way.
        public var downloads: [DownloadedGallery] {
            get { rows.map(\.download) }
            set {
                rows = IdentifiedArrayOf<DownloadRowFeature.State>(
                    newValue.map({ download in
                        guard var row = rows[id: download.id] else { return .init(download: download) }
                        row.download = download
                        return row
                    }),
                    uniquingIDsWith: { first, _ in first }
                )
            }
        }

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
        case pushGalleryDetail(DownloadedGallery)
        case path(StackActionOf<GalleryPath>)
        case destination(PresentationAction<Destination.Action>)
        case inspectorButtonTapped(String)
        case folderManagerButtonTapped
        case confirmationDialog(PresentationAction<Dialog>)
        case rows(IdentifiedActionOf<DownloadRowFeature>)
        case moveButtonTapped(DownloadedGallery)

        case onPresented
        case fetchDownloads
        case fetchDownloadsDone([DownloadedGallery])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case refreshDownloads
        case refreshDownloadsDone
        case fetchFolders
        case fetchFoldersDone([String])
        case moveDownload(gid: String, folderName: String)
        case moveDownloadDone(Result<Void, AppError>)
        case openReading(String)
        case openReadingDone(
            requestID: UUID,
            gid: String,
            result: Result<(download: DownloadedGallery, manifest: DownloadManifest), AppError>
        )
        case toggleDownloadPause(String)
        case toggleDownloadPauseDone(Result<Void, AppError>)
        case updateDownload(String)
        case updateDownloadDone(Result<Void, AppError>)
        case deleteDownload(String)
        case deleteDownloadDone(Result<Void, AppError>)
    }

    @Dependency(\.analyticsClient) private var analyticsClient
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
                // Bail if the download vanished between the observation update and this tap; routing to
                // detail with `.empty` would write an unresolvable (random-gid) history entry.
                guard let download = state.downloads.first(where: { $0.gid == gid }) else { return .none }
                return GalleryNavigation.routeGalleryDetail(
                    deviceType: deviceClient.deviceType,
                    present: { .delegate(.presentGalleryDetail(gallery: download.gallery, downloaded: download)) },
                    push: { .pushGalleryDetail(download) }
                )

            case .pushGalleryDetail(let download):
                // Seed the detail with the locally downloaded gallery/badge so it renders offline.
                // The download is carried through the action, so there is no re-lookup by gid.
                let screen = GalleryPath.State.detail(.init(seededFrom: download))
                // Same derivation as the other four gallery-detail entry paths, taken from the
                // download's gallery projection so all five produce an identical payload shape.
                let sourceGallery = download.gallery
                return .merge(
                    .run(operation: { _ in
                        analyticsClient.send(.galleryDetailOpened(
                            category: sourceGallery.category,
                            tagNamespaces: TagNamespaceCounts(tags: sourceGallery.tags)
                        ))
                    }),
                    GalleryNavigation.presentationEffect(
                        id: state.path.appendGuardingDuplicate(screen),
                        screen: screen,
                        embed: { .path(.element(id: $0, action: $1)) }
                    )
                )

            case .delegate:
                return .none

            case .inspectorButtonTapped(let gid):
                state.destination = .inspector(.init(gid: gid))
                // Presenting the inspector starts its inspection load and download observation,
                // replacing the sheet view's former `onAppear`.
                return .send(.destination(.presented(.inspector(.onPresented))))

            case .folderManagerButtonTapped:
                state.destination = .folderManager(.init())
                // Presenting the sheet is what loads its folders, replacing the sheet view's former
                // `onAppear` (the view is shared with DetailFeature, which does the same).
                return .send(.destination(.presented(.folderManager(.fetchFolders))))

            case .moveButtonTapped(let download):
                let destinations = state.folders.filter({ $0 != download.folderName })
                state.confirmationDialog = ConfirmationDialogState {
                    TextState(localized: .moveToFolder)
                } actions: {
                    for folder in destinations {
                        ButtonState(action: .move(gid: download.gid, folderName: folder)) {
                            TextState(folder)
                        }
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                }
                return .none

            // The row confirmed its own dialog; the deletion itself is a list-level effect.
            case .rows(.element(id: let gid, action: .delegate(.confirmDelete))):
                return .send(.deleteDownload(gid))

            case .rows:
                return .none

            case .confirmationDialog(.presented(.move(let gid, let folder))):
                return .send(.moveDownload(gid: gid, folderName: folder))

            case .confirmationDialog:
                return .none

            // Sent by `AppReducer` when the Downloads tab becomes the visible one — the tab root's
            // replacement for its former view `onAppear`. Guarded, so re-activating a populated tab
            // only refreshes the folder list.
            case .onPresented:
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
                    await send(.fetchDownloadsDone(await downloadClient.fetchDownloads()))
                }

            case .fetchDownloadsDone(let downloads), .observeDownloadsDone(let downloads):
                guard state.downloads != downloads || state.loadingState != .idle else {
                    return .none
                }
                // Taken before the assignment below — `state.downloads` is still the previous
                // snapshot at this point, and it is the only copy of it that exists.
                let outcomes = Self.outcomeTransitions(from: state.downloads, to: downloads)
                state.downloads = downloads
                state.loadingState = .idle
                guard !outcomes.isEmpty else { return .none }
                return .merge(outcomes.map({ outcome in
                    .run(operation: { _ in analyticsClient.send(.downloadStateChanged(outcome)) })
                }))

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
                    await send(.fetchFoldersDone(await downloadClient.fetchFolders()))
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
                    // Outcome only. The destination folder name is user-authored text and never
                    // crosses the boundary; the signal says a move happened, not where to.
                    return .merge(
                        .run(operation: { _ in analyticsClient.send(.downloadStateChanged(.moved)) }),
                        .send(.fetchFolders)
                    )
                }
                // Disposition (list-level policy on `DownloadsReducer`): deliberately silent. A
                // failed move is not a move, and the row still shows the folder it never left.
                return .none

            case .openReading(let gid):
                let requestID = UUID()
                state.readingRequestID = requestID
                return .run { send in
                    await send(
                        .openReadingDone(
                            requestID: requestID,
                            gid: gid,
                            result: .success(try await downloadClient.loadManifest(gid))
                        )
                    )
                } catch: { error, send in
                    await send(.openReadingDone(requestID: requestID, gid: gid, result: .failure(AppError(error))))
                }

            case .openReadingDone(let requestID, let gid, let result):
                guard state.readingRequestID == requestID else { return .none }
                var readingState: ReadingReducer.State
                if case .success(let (download, manifest)) = result {
                    readingState = .init(
                        gallery: download.gallery, contentSource: .local(download: download, manifest: manifest)
                    )
                } else {
                    // Disposition (list-level policy on `DownloadsReducer`): reports by behaviour.
                    // Local load failed; fall back to remote — but only if the download record is still
                    // around to seed the reader. If it vanished mid-flight there's nothing to open, so
                    // bail rather than push a blank (`.empty`) reader. The fallback IS the report: the
                    // user asked to read and gets a reader, from the only source left.
                    guard let download = state.downloads.first(where: { $0.gid == gid }) else { return .none }
                    readingState = .init(gallery: download.gallery, contentSource: .remote)
                    // A downloaded gallery has no persisted detail, so fall back to a language-agnostic
                    // Live Text hint rather than leaving it unset.
                    readingState.language = .other
                }
                state.destination = .reading(readingState)
                return .send(.destination(.presented(.reading(.onPresented))))

            case .toggleDownloadPause(let gid):
                // Direction is read here, at request time, because the `Done` action carries no gid
                // and the snapshot may have moved on by then. `.active` is being paused,
                // `.inactive` resumed; any other status is not a user-meaningful toggle and stays
                // silent rather than guessing a direction (D-20).
                let pauseOutcome: DownloadOutcome? = switch
                    state.downloads.first(where: { $0.id == gid })?.displayStatus {
                case .active: .paused
                case .inactive: .resumed
                default: nil
                }
                return .run { send in
                    try await downloadClient.togglePause(gid)
                    if let pauseOutcome {
                        analyticsClient.send(.downloadStateChanged(pauseOutcome))
                    }
                    await send(.toggleDownloadPauseDone(.success(())))
                } catch: { error, send in
                    await send(.toggleDownloadPauseDone(.failure(AppError(error))))
                }

            case .toggleDownloadPauseDone:
                // Disposition (list-level policy on `DownloadsReducer`): silent, and flagged there
                // as the weakest of the five — this is the inspector's WR-05 refusal seen from the
                // list, and reporting it needs a toast surface this reducer does not own. The
                // success arm is silent for the same reason the inspector's is: `observeDownloads`
                // re-renders the row with its new status.
                return .none

            case .updateDownload(let gid):
                return .run { send in
                    try await downloadClient.retry(gid, .update)
                    await send(.updateDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.updateDownloadDone(.failure(AppError(error))))
                }

            // The DES-3 write-through index is what keeps the silence honest: failures leave the
            // current observed state in place, and the download client performs any targeted
            // surprise repair. The policy this serves is stated once, on `DownloadsReducer`.
            case .updateDownloadDone(let result):
                // `.updated`, not `.retried` or `.completed`: an update is its own queue-time
                // outcome (D-21), and the detail screen's update path reports the same name.
                // Disposition: deliberately silent on failure — a failed update is not an update,
                // and the update badge the user tapped is still there to say so.
                guard case .success = result else { return .none }
                return .run(operation: { _ in analyticsClient.send(.downloadStateChanged(.updated)) })

            case .deleteDownload(let gid):
                return .run { send in
                    try await downloadClient.delete(gid)
                    await send(.deleteDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.deleteDownloadDone(.failure(AppError(error))))
                }

            case .deleteDownloadDone(let result):
                // A delete from the detail screen is a different user path in another module and
                // emits on its own completion action, so neither site double-counts the other.
                // Disposition: deliberately silent on failure — the row the user tried to delete is
                // still on screen, which is the outcome.
                guard case .success = result else { return .none }
                return .run(operation: { _ in analyticsClient.send(.downloadStateChanged(.deleted)) })

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
                guard let next = GalleryNavigation.nextScreen(for: elementAction) else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(next),
                    screen: next,
                    embed: { .path(.element(id: $0, action: $1)) }
                )

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
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
        .forEach(\.rows, action: \.rows, element: DownloadRowFeature.init)
        .forEach(\.path, action: \.path)
    }
}

extension DownloadsReducer.Destination.State: Equatable {}

// MARK: Outcome transitions

extension DownloadsReducer {
    /// The outcome signals implied by moving from one downloads snapshot to the next.
    ///
    /// The observation stream delivers **full snapshots**, not events, so the obvious instrumentation
    /// — emit whenever a download reads as completed — reports one finished download again on every
    /// tick, hundreds of times. Only the *edge* is a real event, so a status is compared against the
    /// same gallery's previous status and emits only when it changed into a terminal one.
    ///
    /// Galleries absent from `previous` are excluded rather than treated as fresh transitions. On the
    /// first observation after launch the previous snapshot is empty, so without that exclusion every
    /// already-finished download in the library would look like a completion that just happened — a
    /// phantom burst on every cold start, proportional to how much the user has downloaded.
    ///
    /// A pure function of its two arguments: no state, no dependencies, so the edge semantics are
    /// unit-testable directly rather than only through a store.
    static func outcomeTransitions(
        from previous: [DownloadedGallery],
        to incoming: [DownloadedGallery]
    ) -> [DownloadOutcome] {
        let previousStatuses = Dictionary(
            previous.map({ ($0.id, $0.displayStatus) }),
            uniquingKeysWith: { first, _ in first }
        )

        // Driven by `incoming`'s order so the emitted sequence is deterministic when several
        // galleries transition in one snapshot.
        return incoming.compactMap({ download in
            // Absent from the previous snapshot: no edge was observed, so nothing is emitted.
            guard let previousStatus = previousStatuses[download.id] else { return nil }
            guard previousStatus != download.displayStatus else { return nil }

            switch download.displayStatus {
            case .completed:
                return .completed
            case .error:
                return .failed
            // Every other status change is an intermediate step, not an outcome. `.deleted` and
            // `.moved` are owned by their explicit actions, and a gallery leaving the snapshot is
            // deletion — observed there, not inferred here.
            case .active, .queued, .updateAvailable, .inactive:
                return nil
            }
        })
    }
}
