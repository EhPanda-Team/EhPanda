import Foundation
import AppModels
import Sharing
import Resources
import ComposableArchitecture
import AppTools
import HapticsClient
import NetworkingFeature
import CookieClient
import AppComponents

@Reducer
public struct ArchivesReducer: Sendable {
    private enum CancelID {
        case fetchArchive, fetchArchiveFunds, fetchDownloadResponse
    }

    @ObservableState
    public struct State: Equatable {
        @Shared(.user) public var user: User
        @Presents public var toast: AppAlertState<Never>?
        public var selectedArchive: GalleryArchive.HathArchive?

        public var loadingState: LoadingState = .idle
        public var hathArchives = [GalleryArchive.HathArchive]()
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)

        case syncGalleryFunds(String, String)

        case fetchArchive(String, URL, URL)
        case fetchArchiveDone(String, URL, Result<GalleryArchiveResponse, AppError>)
        case fetchArchiveFunds(String, URL)
        case fetchArchiveFundsDone(Result<(String, String), AppError>)
        case fetchDownloadResponse(URL)
        case fetchDownloadResponseDone(Result<String, AppError>)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .toast:
                return .none

            case .syncGalleryFunds(let galleryPoints, let credits):
                state.$user.withLock {
                    $0.galleryPoints = galleryPoints
                    $0.credits = credits
                }
                return .none

            case .fetchArchive(let gid, let galleryURL, let archiveURL):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    do throws(AppError) {
                        let response = try await GalleryArchiveRequest(archiveURL: archiveURL)
                            .response()
                        await send(.fetchArchiveDone(gid, galleryURL, .success(response)))
                    } catch {
                        await send(.fetchArchiveDone(gid, galleryURL, .failure(error)))
                    }
                }
                .cancellable(id: CancelID.fetchArchive)

            case .fetchArchiveDone(let gid, let galleryURL, let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    guard !response.archive.hathArchives.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.hathArchives = response.archive.hathArchives
                    if let galleryPoints = response.galleryPoints, let credits = response.credits {
                        return .send(.syncGalleryFunds(galleryPoints, credits))
                    } else if cookieClient.isSameAccount {
                        return .send(.fetchArchiveFunds(gid, galleryURL))
                    } else {
                        return .none
                    }
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchArchiveFunds(let gid, let galleryURL):
                guard let galleryURL = galleryURL.replaceHost(to: Defaults.URL.ehentai.host) else { return .none }
                return .run { send in
                    do throws(AppError) {
                        let funds = try await GalleryArchiveFundsRequest(
                            gid: gid,
                            galleryURL: galleryURL
                        )
                        .response()
                        await send(.fetchArchiveFundsDone(.success(funds)))
                    } catch {
                        await send(.fetchArchiveFundsDone(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.fetchArchiveFunds)

            case .fetchArchiveFundsDone(let result):
                if case .success(let (galleryPoints, credits)) = result {
                    return .send(.syncGalleryFunds(galleryPoints, credits))
                }
                return .none

            case .fetchDownloadResponse(let archiveURL):
                guard let selectedArchive = state.selectedArchive,
                      state.toast != .communicating
                else { return .none }
                state.toast = .communicating
                return .run {send in
                    do throws(AppError) {
                        let response = try await SendDownloadCommandRequest(
                            archiveURL: archiveURL,
                            resolution: selectedArchive.resolution.parameter
                        )
                        .response()
                        await send(.fetchDownloadResponseDone(.success(response)))
                    } catch {
                        await send(.fetchDownloadResponseDone(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.fetchDownloadResponse)

            case .fetchDownloadResponseDone(let result):
                let isSuccess: Bool
                switch result {
                case .success(let response):
                    switch response {
                    case String(localized: .Constant.responseHathClientNotFound):
                        state.toast = .error(caption: .hathClientNotFound)
                        isSuccess = false
                    case String(localized: .Constant.responseHathClientNotOnline):
                        state.toast = .error(caption: .hathClientNotOnline)
                        isSuccess = false
                    case String(localized: .Constant.responseInvalidResolution):
                        state.toast = .error(caption: .invalidResolution)
                        isSuccess = false
                    default:
                        state.toast = .success(caption: response)
                        isSuccess = true
                    }
                case .failure:
                    state.toast = .error()
                    isSuccess = false
                }
                return .run { _ in
                    await hapticsClient.generateNotificationFeedback(isSuccess ? .success : .error)
                }
            }
        }
        .ifLet(\.$toast, action: \.toast)
    }
}
