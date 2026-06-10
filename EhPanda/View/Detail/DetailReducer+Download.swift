//
//  DetailReducer+Download.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

// MARK: - Download Action Handlers
extension DetailReducer {
    var downloadReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchDownloadBadge:
                return handleFetchDownloadBadge(state: &state)
            case .fetchDownloadBadgeDone(let badge):
                return handleFetchDownloadBadgeDone(badge: badge, state: &state)
            case .observeDownload:
                return handleObserveDownload(state: &state)
            case .observeDownloadDone(let badge):
                return handleObserveDownloadDone(badge: badge, state: &state)
            case .loadLocalPreviewURLs:
                return handleLoadLocalPreviewURLs(state: &state)
            case .loadLocalPreviewURLsDone(let requestID, let urls):
                return handleLoadLocalPreviewURLsDone(requestID: requestID, urls: urls, state: &state)
            case .openReading:
                return handleOpenReading(state: &state)
            case .openReadingDone(let result):
                return handleOpenReadingDone(result: result, state: &state)
            case .runLaunchAutomationIfNeeded(let options):
                return handleRunLaunchAutomation(options: options, state: &state)
            case .startDownload(let options):
                return handleStartDownload(options: options, state: &state)
            case .startDownloadDone(let result):
                return handleStartDownloadDone(result: result, state: &state)
            case .toggleDownloadPause:
                return handleToggleDownloadPause(state: &state)
            case .toggleDownloadPauseDone(let result):
                return handleToggleDownloadPauseDone(result: result, state: &state)
            case .retryDownload(let mode):
                return handleRetryDownload(mode: mode, state: &state)
            case .retryDownloadDone(let result):
                return handleRetryDownloadDone(result: result, state: &state)
            case .deleteDownload:
                return handleDeleteDownload(state: state)
            case .deleteDownloadDone(let result):
                return handleDeleteDownloadDone(result: result, state: &state)
            default:
                return .none
            }
        }
    }

    private func handleFetchDownloadBadge(state: inout State) -> Effect<Action> {
        guard state.gid.isValidGID else { return .none }
        return .run { [galleryID = state.gid] send in
            let badge = await downloadClient.badges([galleryID])[galleryID] ?? .none
            await send(.fetchDownloadBadgeDone(badge))
        }
        .cancellable(id: CancelID.fetchDownloadBadge, cancelInFlight: true)
    }

    private func handleFetchDownloadBadgeDone(badge: DownloadBadge, state: inout State) -> Effect<Action> {
        _ = applyDownloadBadge(badge, state: &state)
        var effects: [Effect<Action>] = [.send(.loadLocalPreviewURLs)]
        if shouldRequestVersionMetadata(state: state) {
            effects.append(.send(.fetchVersionMetadataIfNeeded))
        }
        return .merge(effects)
    }

    private func handleObserveDownload(state: inout State) -> Effect<Action> {
        guard state.gid.isValidGID else { return .none }
        return .run { [galleryID = state.gid] send in
            for await downloads in downloadClient.observeDownloads() {
                let badge = downloads.first(where: { $0.gid == galleryID })?.badge ?? .none
                await send(.observeDownloadDone(badge))
            }
        }
        .cancellable(id: CancelID.observeDownload, cancelInFlight: true)
    }

    private func handleObserveDownloadDone(badge: DownloadBadge, state: inout State) -> Effect<Action> {
        let didChangeBadge = applyDownloadBadge(badge, state: &state)
        guard didChangeBadge else { return .none }
        var effects: [Effect<Action>] = [.send(.loadLocalPreviewURLs)]
        if shouldRequestVersionMetadata(state: state) {
            effects.append(.send(.fetchVersionMetadataIfNeeded))
        }
        return .merge(effects)
    }

    private func handleLoadLocalPreviewURLs(state: inout State) -> Effect<Action> {
        guard state.gid.isValidGID else {
            state.localPreviewRequestID = UUID()
            state.localPreviewURLs = .init()
            return .none
        }
        let requestID = UUID()
        state.localPreviewRequestID = requestID
        return .run { [galleryID = state.gid] send in
            let localPreviewURLs: [Int: URL]
            switch await downloadClient.loadLocalPageURLs(galleryID) {
            case .success(let pageURLs):
                localPreviewURLs = pageURLs
            case .failure:
                localPreviewURLs = [:]
            }
            await send(.loadLocalPreviewURLsDone(requestID, localPreviewURLs))
        }
        .cancellable(id: CancelID.loadLocalPreviewURLs, cancelInFlight: true)
    }

    private func handleLoadLocalPreviewURLsDone(
        requestID: UUID,
        urls localPreviewURLs: [Int: URL],
        state: inout State
    ) -> Effect<Action> {
        guard state.localPreviewRequestID == requestID else { return .none }
        guard state.localPreviewURLs != localPreviewURLs else { return .none }
        state.localPreviewURLs = localPreviewURLs
        return .none
    }

    private func handleOpenReading(state: inout State) -> Effect<Action> {
        state.readingState = .init(contentSource: .remote)
        return .run { [galleryID = state.gallery.id] send in
            guard galleryID.isValidGID else {
                await send(.openReadingDone(.failure(.notFound)))
                return
            }
            await send(.openReadingDone(await downloadClient.loadManifest(galleryID)))
        }
    }

    private func handleOpenReadingDone(
        result: Result<(DownloadedGallery, DownloadManifest), AppError>,
        state: inout State
    ) -> Effect<Action> {
        if case .success(let (download, manifest)) = result {
            state.readingState = .init(contentSource: .local(download, manifest))
        } else {
            state.readingState.contentSource = .remote
            state.readingState.localPageURLs = state.localPreviewURLs
        }
        state.route = .reading()
        return .none
    }

    private func handleRunLaunchAutomation(
        options: DownloadRequestOptions,
        state: inout State
    ) -> Effect<Action> {
        guard !state.didRunLaunchAutomation,
              appLaunchAutomationClient.current()?.autoDownloadGID == state.gallery.id,
              state.galleryDetail != nil,
              state.hasLoadedDownloadBadge
        else { return .none }
        state.didRunLaunchAutomation = true
        guard state.downloadBadge == .none else { return .none }
        return .send(.startDownload(options))
    }

    private func handleStartDownload(
        options: DownloadRequestOptions,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isPreparingDownload else { return .none }
        state.didRunLaunchAutomation = true
        guard let detail = state.galleryDetail else { return .none }
        state.isPreparingDownload = true
        let payload = DownloadRequestPayload(
            gallery: state.gallery,
            galleryDetail: detail,
            previewURLs: state.galleryPreviewURLs,
            previewConfig: state.previewConfig,
            host: AppUtil.galleryHost,
            versionMetadata: state.galleryVersionMetadata,
            options: options,
            mode: .initial
        )
        return .run { send in
            await send(.startDownloadDone(await downloadClient.enqueue(payload)))
        }
    }

    private func handleStartDownloadDone(
        result: Result<Void, AppError>,
        state: inout State
    ) -> Effect<Action> {
        state.isPreparingDownload = false
        if case .success = result {
            state.downloadBadge = .queued
            state.hasLoadedDownloadBadge = true
            return .merge(
                .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                .send(.fetchDownloadBadge)
            )
        }
        return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
    }

    private func handleToggleDownloadPause(state: inout State) -> Effect<Action> {
        guard !state.isPreparingDownload else { return .none }
        state.isPreparingDownload = true
        return .run { [galleryID = state.gallery.id] send in
            await send(.toggleDownloadPauseDone(await downloadClient.togglePause(galleryID)))
        }
    }

    private func handleToggleDownloadPauseDone(
        result: Result<Void, AppError>,
        state: inout State
    ) -> Effect<Action> {
        state.isPreparingDownload = false
        if case .success = result {
            switch state.downloadBadge {
            case .downloading(let completed, let total):
                state.downloadBadge = .paused(completed, total)
            case .paused:
                state.downloadBadge = .queued
            default:
                break
            }
            state.hasLoadedDownloadBadge = state.downloadBadge != .none
            return .merge(
                .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                .send(.fetchDownloadBadge)
            )
        }
        return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
    }

    private func handleRetryDownload(
        mode: DownloadStartMode,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isPreparingDownload else { return .none }
        state.isPreparingDownload = true
        return .run { [galleryID = state.gallery.id] send in
            await send(.retryDownloadDone(await downloadClient.retry(galleryID, mode)))
        }
    }

    private func handleRetryDownloadDone(
        result: Result<Void, AppError>,
        state: inout State
    ) -> Effect<Action> {
        state.isPreparingDownload = false
        if case .success = result {
            state.downloadBadge = .queued
            state.hasLoadedDownloadBadge = true
            return .merge(
                .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                .send(.fetchDownloadBadge)
            )
        }
        return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
    }

    private func handleDeleteDownload(state: State) -> Effect<Action> {
        .run { [galleryID = state.gallery.id] send in
            await send(.deleteDownloadDone(await downloadClient.delete(galleryID)))
        }
    }

    private func handleDeleteDownloadDone(
        result: Result<Void, AppError>,
        state: inout State
    ) -> Effect<Action> {
        if case .success = result {
            state.galleryVersionMetadata = nil
            state.didRequestVersionMetadata = false
            state.shouldCheckForRemoteUpdates = false
            return .merge(
                .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                .send(.fetchDownloadBadge)
            )
        }
        return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
    }
}
