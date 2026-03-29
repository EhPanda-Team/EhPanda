//
//  DownloadInspectorReducer.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

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

extension DownloadInspectorReducer.State {
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
