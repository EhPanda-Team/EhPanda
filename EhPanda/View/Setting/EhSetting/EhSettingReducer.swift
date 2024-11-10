//
//  EhSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import Foundation
import ComposableArchitecture

@Reducer
struct EhSettingReducer {
    @CasePathable
    enum Route: Equatable {
        case webView(URL)
        case deleteProfile
    }

    private enum CancelID: CaseIterable {
        case fetchEhSetting, submitChanges, performAction
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var editingProfileName = ""
        var ehSetting: EhSetting?
        var ehProfile: EhProfile?
        var loadingState: LoadingState = .idle
        var submittingState: LoadingState = .idle

        mutating func setEhSetting(_ ehSetting: EhSetting) {
            let ehProfile: EhProfile = ehSetting.ehProfiles
                .filter(\.isSelected).first.forceUnwrapped
            self.ehSetting = ehSetting
            self.ehProfile = ehProfile
            editingProfileName = ehProfile.name
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case setKeyboardHidden
        case setDefaultProfile(Int)

        case teardown
        case fetchEhSetting
        case fetchEhSettingDone(Result<EhSetting, AppError>)
        case submitChanges
        case submitChangesDone(Result<EhSetting, AppError>)
        case performAction(action: EhProfileAction?, name: String?, set: Int)
        case performActionDone(Result<EhSetting, AppError>)
    }

    @Dependency(\.uiApplicationClient) private var uiApplicationClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .setKeyboardHidden:
                return .run(operation: { _ in await uiApplicationClient.hideKeyboard() })

            case .setDefaultProfile(let profileSet):
                return .run { _ in
                    cookieClient.setOrEditCookie(
                        for: Defaults.URL.host, key: Defaults.Cookie.selectedProfile, value: String(profileSet)
                    )
                }

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchEhSetting:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let response = await EhSettingRequest().response()
                    await send(.fetchEhSettingDone(response))
                }
                .cancellable(id: CancelID.fetchEhSetting)

            case .fetchEhSettingDone(let result):
                state.loadingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting)
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .submitChanges:
                guard state.submittingState != .loading,
                      let ehSetting = state.ehSetting
                else { return .none }

                state.submittingState = .loading
                return .run { send in
                    let response = await SubmitEhSettingChangesRequest(ehSetting: ehSetting).response()
                    await send(.submitChangesDone(response))
                }
                .cancellable(id: CancelID.submitChanges)

            case .submitChangesDone(let result):
                state.submittingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting)
                case .failure(let error):
                    state.submittingState = .failed(error)
                }
                return .none

            case .performAction(let action, let name, let set):
                guard state.submittingState != .loading else { return .none }
                state.submittingState = .loading
                return .run { send in
                    let response = await EhProfileRequest(action: action, name: name, set: set).response()
                    await send(.performActionDone(response))
                }
                .cancellable(id: CancelID.performAction)

            case .performActionDone(let result):
                state.submittingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting)
                case .failure(let error):
                    state.submittingState = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.webView,
            hapticsClient: hapticsClient
        )
    }
}
