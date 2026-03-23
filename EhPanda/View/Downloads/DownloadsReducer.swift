//
//  DownloadsReducer.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

@Reducer
struct DownloadsReducer {
    @CasePathable
    enum Route: Equatable {
        case quickSearch(EquatableVoid = .init())
        case filters(EquatableVoid = .init())
        case inspector(String)
        case detail(String)
    }

    private enum CancelID {
        case observeDownloads
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""
        var filter: DownloadListFilter = .all
        var galleryFilter = DownloadGalleryFilter()
        var downloads = [DownloadedGallery]()
        var loadingState: LoadingState = .loading
        var hasLoadedInitialDownloads = false

        var detailState: Heap<DetailReducer.State?>
        var inspectorState = DownloadInspectorReducer.State()
        var quickSearchState = QuickSearchReducer.State()

        init() {
            detailState = .init(.init())
        }

        var filteredDownloads: [DownloadedGallery] {
            downloads.filter {
                $0.matches(filter: filter)
                && $0.matches(queryFilter: galleryFilter)
                && (
                    keyword.isEmpty
                    || $0.searchableText.caseInsensitiveContains(keyword)
                )
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case onAppear
        case teardown
        case bootstrapDownloads
        case fetchDownloads
        case fetchDownloadsDone([DownloadedGallery])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case refreshDownloads
        case refreshDownloadsDone
        case toggleDownloadPause(String)
        case toggleDownloadPauseDone(Result<Void, AppError>)
        case updateDownload(String)
        case updateDownloadDone(Result<Void, AppError>)
        case deleteDownload(String)
        case deleteDownloadDone(Result<Void, AppError>)

        case detail(DetailReducer.Action)
        case inspector(DownloadInspectorReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.downloadClient) private var downloadClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, newValue in
                Reduce { _, _ in
                    newValue == nil ? .send(.clearSubStates) : .none
                }
            }
            .onChange(of: \.galleryFilter) { _, _ in
                Reduce { state, _ in
                    state.galleryFilter.fixInvalidData()
                    return .none
                }
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                if case .detail(let gid) = route,
                   let download = state.downloads.first(where: { $0.gid == gid })
                {
                    state.detailState.wrappedValue = .init(download: download)
                } else if case .inspector(let gid) = route {
                    state.inspectorState = .init(gid: gid)
                }
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                state.inspectorState = .init()
                state.quickSearchState = .init()
                return .merge(
                    .send(.detail(.teardown)),
                    .send(.inspector(.teardown)),
                    .send(.quickSearch(.teardown))
                )

            case .onAppear:
                guard !state.hasLoadedInitialDownloads else { return .none }
                state.hasLoadedInitialDownloads = true
                return .merge(
                    .send(.fetchDownloads),
                    .send(.observeDownloads),
                    .send(.bootstrapDownloads)
                )

            case .teardown:
                return .cancel(id: CancelID.observeDownloads)

            case .bootstrapDownloads:
                return .run { send in
                    await downloadClient.refreshDownloads()
                    await send(.refreshDownloadsDone)
                }

            case .fetchDownloads:
                state.loadingState = .loading
                return .run { send in
                    await send(.fetchDownloadsDone(await downloadClient.fetchDownloads()))
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
                return .none

            case .toggleDownloadPause(let gid):
                return .run { send in
                    await send(.toggleDownloadPauseDone(await downloadClient.togglePause(gid)))
                }

            case .toggleDownloadPauseDone(let result):
                if case .failure = result {
                    return .run { _ in
                        await downloadClient.reconcileDownloads()
                    }
                }
                return .none

            case .updateDownload(let gid):
                return .run { send in
                    await send(.updateDownloadDone(await downloadClient.retry(gid, .update)))
                }

            case .updateDownloadDone:
                return .none

            case .deleteDownload(let gid):
                return .run { send in
                    await send(.deleteDownloadDone(await downloadClient.delete(gid)))
                }

            case .deleteDownloadDone:
                return .none

            case .detail:
                return .none

            case .inspector:
                return .none

            case .quickSearch:
                return .none
            }
        }

        Scope(state: \.detailState.wrappedValue!, action: \.detail) {
            DetailReducer()
        }
        Scope(state: \.inspectorState, action: \.inspector) {
            DownloadInspectorReducer()
        }
        Scope(state: \.quickSearchState, action: \.quickSearch, child: QuickSearchReducer.init)
    }
}

@Reducer
struct DownloadInspectorReducer {
    private enum CancelID {
        case observeDownloads
        case loadInspection
    }

    @ObservableState
    struct State: Equatable {
        var gid = ""
        var inspection: DownloadInspection?
        var stableInspection: DownloadInspection?
        var loadingState: LoadingState = .loading
        var inspectionRequestID = UUID()
        var retryingPageIndices = Set<Int>()

        init(gid: String = "") {
            self.gid = gid
            loadingState = gid.isEmpty ? .idle : .loading
        }
    }

    enum Action {
        case onAppear
        case teardown
        case loadInspection
        case loadInspectionDone(UUID, Result<DownloadInspection, AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case retryPage(Int)
        case retryPageDone(Result<Void, AppError>)
        case retryFailedPages
        case retryFailedPagesDone(Result<Void, AppError>)
        case updateDownload
        case updateDownloadDone(Result<Void, AppError>)
    }

    @Dependency(\.downloadClient) private var downloadClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.gid.notEmpty else { return .none }
                return .merge(
                    .send(.loadInspection),
                    .send(.observeDownloads)
                )

            case .teardown:
                return .merge(
                    .cancel(id: CancelID.observeDownloads),
                    .cancel(id: CancelID.loadInspection)
                )

            case .loadInspection:
                guard state.gid.notEmpty else { return .none }
                if state.inspection == nil {
                    state.loadingState = .loading
                }
                let requestID = UUID()
                state.inspectionRequestID = requestID
                return .run { [gid = state.gid] send in
                    await send(.loadInspectionDone(requestID, await downloadClient.loadInspection(gid)))
                }
                .cancellable(id: CancelID.loadInspection, cancelInFlight: true)

            case .loadInspectionDone(let requestID, let result):
                guard state.inspectionRequestID == requestID else { return .none }
                switch result {
                case .success(let inspection):
                    state.stableInspection = inspection
                    let inspection = state.overlayRetryingPages(in: inspection)
                    state.inspection = inspection
                    state.loadingState = .idle
                    state.retryingPageIndices = state.reconciledRetryingPageIndices(
                        for: inspection
                    )
                case .failure(let error):
                    state.retryingPageIndices = .init()
                    if let stableInspection = state.stableInspection {
                        state.inspection = stableInspection
                    }
                    state.loadingState = .failed(error)
                }
                return .none

            case .observeDownloads:
                guard state.gid.notEmpty else { return .none }
                return .run { [gid = state.gid] send in
                    var hadRelevantDownloads = false
                    for await downloads in downloadClient.observeDownloads() {
                        let relevantDownloads = downloads.filter { $0.gid == gid }
                        let hasRelevantDownloads = !relevantDownloads.isEmpty
                        guard hasRelevantDownloads || hadRelevantDownloads else { continue }
                        hadRelevantDownloads = hasRelevantDownloads
                        await send(.observeDownloadsDone(relevantDownloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone(let downloads):
                guard !downloads.isEmpty else {
                    state.inspection = nil
                    state.stableInspection = nil
                    state.retryingPageIndices = .init()
                    state.loadingState = .idle
                    return .none
                }
                guard let latestDownload = downloads.first else { return .none }
                let previousDownload = state.inspection?.download
                if let inspection = state.inspection,
                   state.retryingPageIndices.isEmpty || state.shouldKeepRetryPending(for: latestDownload)
                {
                    state.inspection = state.overlayRetryingPages(in: .init(
                        download: latestDownload,
                        coverURL: inspection.coverURL,
                        pages: inspection.pages
                    ))
                }
                guard previousDownload != latestDownload else { return .none }
                return .send(.loadInspection)

            case .retryPage(let index):
                guard state.gid.notEmpty else { return .none }
                state.inspectionRequestID = UUID()
                state.retryingPageIndices.insert(index)
                state.stableInspection = state.inspection ?? state.stableInspection
                if let inspection = state.inspection {
                    state.inspection = .init(
                        download: inspection.download,
                        coverURL: inspection.coverURL,
                        pages: inspection.pages.map { page in
                            guard page.index == index else { return page }
                            return .init(
                                index: index,
                                status: .pending,
                                relativePath: page.relativePath,
                                fileURL: nil,
                                failure: nil
                            )
                        }
                    )
                }
                return .merge(
                    .cancel(id: CancelID.loadInspection),
                    .run { [gid = state.gid] send in
                        await send(.retryPageDone(await downloadClient.retryPages(gid, [index])))
                    }
                )

            case .retryPageDone(let result):
                if case .failure = result {
                    state.retryingPageIndices = .init()
                    return .send(.loadInspection)
                }
                return .none

            case .retryFailedPages:
                guard let failedPageIndices = state.inspection?.failedPageIndices,
                      let gid = state.inspection?.download.gid,
                      !failedPageIndices.isEmpty
                else {
                    return .none
                }
                state.inspectionRequestID = UUID()
                state.retryingPageIndices.formUnion(failedPageIndices)
                state.stableInspection = state.inspection ?? state.stableInspection
                if let inspection = state.inspection {
                    state.inspection = .init(
                        download: inspection.download,
                        coverURL: inspection.coverURL,
                        pages: inspection.pages.map { page in
                            guard failedPageIndices.contains(page.index) else { return page }
                            return .init(
                                index: page.index,
                                status: .pending,
                                relativePath: page.relativePath,
                                fileURL: nil,
                                failure: nil
                            )
                        }
                    )
                }
                return .merge(
                    .cancel(id: CancelID.loadInspection),
                    .run { send in
                        await send(.retryFailedPagesDone(await downloadClient.retryPages(gid, failedPageIndices)))
                    }
                )

            case .retryFailedPagesDone(let result):
                if case .failure = result {
                    state.retryingPageIndices = .init()
                    return .send(.loadInspection)
                }
                return .none

            case .updateDownload:
                guard let gid = state.inspection?.download.gid else { return .none }
                return .run { send in
                    await send(.updateDownloadDone(await downloadClient.retry(gid, .update)))
                }

            case .updateDownloadDone(let result):
                if case .failure = result {
                    return .send(.loadInspection)
                }
                return .none
            }
        }
    }
}

private extension DownloadInspectorReducer.State {
    func shouldKeepRetryPending(for download: DownloadedGallery) -> Bool {
        download.canPauseOrResume
            || download.isPendingQueue
            || (download.status == .partial && download.lastError == nil)
    }

    func overlayRetryingPages(in inspection: DownloadInspection) -> DownloadInspection {
        guard !retryingPageIndices.isEmpty else { return inspection }

        guard shouldKeepRetryPending(for: inspection.download) else { return inspection }

        return .init(
            download: inspection.download,
            coverURL: inspection.coverURL,
            pages: inspection.pages.map { page in
                guard retryingPageIndices.contains(page.index),
                      page.status != .downloaded
                else {
                    return page
                }
                return .init(
                    index: page.index,
                    status: .pending,
                    relativePath: page.relativePath,
                    fileURL: page.fileURL,
                    failure: nil
                )
            }
        )
    }

    func reconciledRetryingPageIndices(for inspection: DownloadInspection) -> Set<Int> {
        guard !retryingPageIndices.isEmpty else { return .init() }

        guard shouldKeepRetryPending(for: inspection.download) else { return .init() }

        return retryingPageIndices.filter { index in
            inspection.pages.first(where: { $0.index == index })?.status != .downloaded
        }
    }
}
