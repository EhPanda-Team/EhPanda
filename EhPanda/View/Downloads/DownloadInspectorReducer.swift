//
//  DownloadInspectorReducer.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

@Reducer
struct DownloadInspectorReducer {
    @CasePathable
    enum Route: Equatable {
        case hud
    }

    private enum CancelID {
        case observeDownloads
        case loadInspection
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var gid = ""
        var inspection: DownloadInspection?
        var stableInspection: DownloadInspection?
        var loadingState: LoadingState = .loading
        var hudConfig: ProgressHUDConfigState = .loading()
        var inspectionRequestID = UUID()
        var retryingPageIndices = Set<Int>()
        var isValidatingImageData = false

        init(gid: String = "") {
            self.gid = gid
            loadingState = gid.isEmpty ? .idle : .loading
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
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
        case toggleDownloadPause
        case toggleDownloadPauseDone(Result<Void, AppError>)
        case validateImageData
        case validateImageDataDone(DownloadValidationState?)
    }

    @Dependency(\.downloadClient) private var downloadClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                guard !state.gid.isEmpty else { return .none }
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
                guard !state.gid.isEmpty else { return .none }
                if state.inspection == nil {
                    state.loadingState = .loading
                }
                let requestID = UUID()
                state.inspectionRequestID = requestID
                return .run { [gid = state.gid] send in
                    await send(.loadInspectionDone(requestID, .success(try await downloadClient.loadInspection(gid))))
                } catch: { error, send in
                    await send(.loadInspectionDone(requestID, .failure(error as? AppError ?? .unknown)))
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
                guard !state.gid.isEmpty else { return .none }
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
                   state.retryingPageIndices.isEmpty || state.shouldKeepRetryPending(for: latestDownload) {
                    state.inspection = state.overlayRetryingPages(in: .init(
                        download: latestDownload,
                        coverURL: inspection.coverURL,
                        pages: inspection.pages
                    ))
                }
                guard previousDownload != latestDownload else { return .none }
                return .send(.loadInspection)

            case .retryPage(let index):
                guard !state.gid.isEmpty else { return .none }
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
                        try await downloadClient.retryPages(gid, [index])
                        await send(.retryPageDone(.success(())))
                    } catch: { error, send in
                        await send(.retryPageDone(.failure(error as? AppError ?? .unknown)))
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
                        try await downloadClient.retryPages(gid, failedPageIndices)
                        await send(.retryFailedPagesDone(.success(())))
                    } catch: { error, send in
                        await send(.retryFailedPagesDone(.failure(error as? AppError ?? .unknown)))
                    }
                )

            case .retryFailedPagesDone(let result):
                if case .failure = result {
                    state.retryingPageIndices = .init()
                    return .send(.loadInspection)
                }
                return .none

            case .toggleDownloadPause:
                guard let download = state.inspection?.download,
                      download.canTogglePause
                else { return .none }
                return .run { send in
                    try await downloadClient.togglePause(download.gid)
                    await send(.toggleDownloadPauseDone(.success(())))
                } catch: { error, send in
                    await send(.toggleDownloadPauseDone(.failure(error as? AppError ?? .unknown)))
                }

            case .toggleDownloadPauseDone(let result):
                if case .failure = result {
                    return .send(.loadInspection)
                }
                return .none

            case .validateImageData:
                guard !state.gid.isEmpty,
                      state.inspection?.canValidateImageData == true,
                      !state.isValidatingImageData
                else { return .none }
                state.isValidatingImageData = true
                return .run { [gid = state.gid] send in
                    await send(.validateImageDataDone(await downloadClient.validateImageData(gid)))
                }

            case .validateImageDataDone(let validation):
                state.isValidatingImageData = false
                state.hudConfig = validation.hudConfig
                state.route = .hud
                return .send(.loadInspection)
            }
        }
    }
}

private extension Optional where Wrapped == DownloadValidationState {
    var hudConfig: ProgressHUDConfigState {
        switch self {
        case .some(.valid):
            return .success(
                caption: L10n.Localizable.DownloadsView.Inspector.Hud.imageDataValid
            )

        case .some(.missingFiles(let message)):
            return .error(caption: message)

        case nil:
            return .error(
                caption: L10n.Localizable.DownloadsView.Inspector.Hud.imageDataUnavailable
            )
        }
    }
}

extension DownloadInspectorReducer.State {
    func shouldKeepRetryPending(for download: DownloadedGallery) -> Bool {
        download.canPauseOrResume
            || download.isQueuedWorkItem
            || (
                [.inactive, .error].contains(download.displayStatus)
                    && download.isIncomplete
                    && download.lastError == nil
            )
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
