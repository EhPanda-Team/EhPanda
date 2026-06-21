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
                guard state.gid.isValidGID else { return .none }
                return .run { [galleryID = state.gid] send in
                    let download = await downloadClient.fetchDownload(galleryID)
                    await send(.fetchDownloadBadgeDone(download))
                }
                .cancellable(id: CancelID.fetchDownloadBadge(state.cancellationGalleryID), cancelInFlight: true)

            case .fetchDownloadBadgeDone(let download):
                _ = applyDownload(download, state: &state)
                var effects: [Effect<Action>] = [.send(.loadLocalPreviewURLs)]
                if shouldRequestVersionMetadata(state: state) {
                    effects.append(.send(.fetchVersionMetadataIfNeeded))
                }
                return .merge(effects)

            case .fetchDownloadFolders:
                let cancellationID = CancelID.fetchDownloadFolders(state.cancellationGalleryID)
                return .run { send in
                    await send(.fetchDownloadFoldersDone(try await downloadClient.fetchFolders()))
                }
                .cancellable(id: cancellationID, cancelInFlight: true)

            case .fetchDownloadFoldersDone(let folders):
                state.downloadFolders = folders
                return .none

            case .createDefaultFolder:
                return .run { send in
                    try await downloadClient.createFolder(Defaults.FilePath.defaultDownloadFolder)
                    await send(.createDefaultFolderDone(.success(())))
                } catch: { error, send in
                    await send(.createDefaultFolderDone(.failure(AppError(error))))
                }

            case .createDefaultFolderDone(let result):
                if case .success = result {
                    return .merge(
                        .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadFolders)
                    )
                }
                return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })

            case .folderManager(.createFolderDone),
                 .folderManager(.renameFolderDone),
                 .folderManager(.deleteFolderDone):
                return .send(.fetchDownloadFolders)

            case .observeDownload:
                guard state.gid.isValidGID else { return .none }
                return .run { [galleryID = state.gid] send in
                    for await downloads in downloadClient.observeDownloads() {
                        let download = downloads.first(where: { $0.gid == galleryID })
                        await send(.observeDownloadDone(download))
                    }
                }
                .cancellable(id: CancelID.observeDownload(state.cancellationGalleryID), cancelInFlight: true)

            case .observeDownloadDone(let download):
                let didChangeBadge = applyDownload(download, state: &state)
                guard didChangeBadge else { return .none }
                var effects: [Effect<Action>] = [.send(.loadLocalPreviewURLs)]
                if shouldRequestVersionMetadata(state: state) {
                    effects.append(.send(.fetchVersionMetadataIfNeeded))
                }
                return .merge(effects)

            case .loadLocalPreviewURLs:
                guard state.gid.isValidGID else {
                    state.localPreviewRequestID = UUID()
                    state.localPreviewURLs = .init()
                    return .none
                }
                let requestID = UUID()
                state.localPreviewRequestID = requestID
                return .run { [galleryID = state.gid] send in
                    let localPreviewURLs = await downloadClient.loadLocalPageURLs(galleryID) ?? [:]
                    await send(.loadLocalPreviewURLsDone(requestID, localPreviewURLs))
                }
                .cancellable(id: CancelID.loadLocalPreviewURLs(state.cancellationGalleryID), cancelInFlight: true)

            case .loadLocalPreviewURLsDone(let requestID, let localPreviewURLs):
                guard state.localPreviewRequestID == requestID else { return .none }
                guard state.localPreviewURLs != localPreviewURLs else { return .none }
                state.localPreviewURLs = localPreviewURLs
                return .none

            case .openReading:
                state.readingState = .init(contentSource: .remote)
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
                if case .success(let (download, manifest)) = result {
                    state.readingState = .init(contentSource: .local(download, manifest))
                } else {
                    state.readingState.contentSource = .remote
                    state.readingState.localPageURLs = state.localPreviewURLs
                }
                state.route = .reading()
                return .none

            case .runLaunchAutomationIfNeeded:
                guard !state.didRunLaunchAutomation,
                      let automation = appLaunchAutomationClient.current(),
                      automation.autoDownloadGID == state.gallery.id,
                      state.galleryDetail != nil,
                      state.hasLoadedDownloadBadge
                else { return .none }
                state.didRunLaunchAutomation = true
                guard state.downloadBadge == nil else { return .none }
                return .send(
                    .startDownload(automation.downloadFolderName ?? Defaults.FilePath.automationDownloadFolder)
                )

            case .startDownload(let folderName):
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
                    folderName: folderName,
                    versionMetadata: state.galleryVersionMetadata,
                    mode: .initial
                )
                return .run { send in
                    try await downloadClient.enqueue(payload)
                    await send(.startDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.startDownloadDone(.failure(AppError(error))))
                }

            case .startDownloadDone(let result):
                state.isPreparingDownload = false
                if case .success = result {
                    state.downloadBadge = DownloadBadge(
                        status: .queued,
                        progress: DownloadProgress(
                            completedPageCount: 0,
                            pageCount: state.galleryDetail?.pageCount ?? 0
                        )
                    )
                    state.downloadFailureCode = nil
                    state.hasLoadedDownloadBadge = true
                    return .merge(
                        .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })

            case .toggleDownloadPause:
                guard !state.isPreparingDownload else { return .none }
                state.isPreparingDownload = true
                return .run { [galleryID = state.gallery.id] send in
                    try await downloadClient.togglePause(galleryID)
                    await send(.toggleDownloadPauseDone(.success(())))
                } catch: { error, send in
                    await send(.toggleDownloadPauseDone(.failure(AppError(error))))
                }

            case .toggleDownloadPauseDone(let result):
                state.isPreparingDownload = false
                if case .success = result {
                    switch state.downloadBadge?.status {
                    case .active:
                        if let badge = state.downloadBadge {
                            state.downloadBadge = DownloadBadge(status: .inactive, progress: badge.progress)
                        }
                    case .inactive:
                        if let badge = state.downloadBadge {
                            state.downloadBadge = DownloadBadge(status: .queued, progress: badge.progress)
                        }
                    default:
                        break
                    }
                    state.hasLoadedDownloadBadge = state.downloadBadge != nil
                    return .merge(
                        .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })

            case .retryDownload(let mode):
                guard !state.isPreparingDownload else { return .none }
                state.isPreparingDownload = true
                return .run { [galleryID = state.gallery.id] send in
                    try await downloadClient.retry(galleryID, mode)
                    await send(.retryDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.retryDownloadDone(.failure(AppError(error))))
                }

            case .retryDownloadDone(let result):
                state.isPreparingDownload = false
                if case .success = result {
                    state.downloadBadge = DownloadBadge(
                        status: .queued,
                        progress: state.downloadBadge?.progress ?? DownloadProgress(
                            completedPageCount: 0,
                            pageCount: state.galleryDetail?.pageCount ?? 0
                        )
                    )
                    state.downloadFailureCode = nil
                    state.hasLoadedDownloadBadge = true
                    return .merge(
                        .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })

            case .deleteDownload:
                return .run { [galleryID = state.gallery.id] send in
                    try await downloadClient.delete(galleryID)
                    await send(.deleteDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.deleteDownloadDone(.failure(AppError(error))))
                }

            case .deleteDownloadDone(let result):
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

            default:
                return .none
            }
        }
    }
}
