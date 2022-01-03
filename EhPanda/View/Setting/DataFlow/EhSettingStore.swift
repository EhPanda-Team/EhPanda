//
//  EhSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import ComposableArchitecture

struct EhSettingState: Equatable {
    @BindableState var webViewSheetPresented = false
    @BindableState var deleteDialogPresented = false
    @BindableState var editingProfileName = ""
    @BindableState var ehSetting: EhSetting?
    @BindableState var ehProfile: EhProfile?
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

enum EhSettingAction: BindableAction {
    case binding(BindingAction<EhSettingState>)
    case setKeyboardHidden
    case setWebViewSheet(Bool)
    case setDeleteDialog(Bool)
    case setDefaultProfile(Int)
    case fetchEhSetting
    case fetchEhSettingDone(Result<EhSetting, AppError>)
    case submitChanges
    case submitChangesDone(Result<EhSetting, AppError>)
    case performAction(EhProfileAction?, String?, Int)
    case performActionDone(Result<EhSetting, AppError>)
}

struct EhSettingEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let uiApplicationClient: UIApplicationClient
}

let ehSettingReducer = Reducer<EhSettingState, EhSettingAction, EhSettingEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setKeyboardHidden:
        return environment.uiApplicationClient.hideKeyboard().fireAndForget()

    case .setWebViewSheet(let isPresented):
        state.webViewSheetPresented = isPresented
        return environment.hapticClient.generateFeedback(.light).fireAndForget()

    case .setDeleteDialog(let isPresented):
        state.deleteDialogPresented = isPresented
        return .none

    case .setDefaultProfile(let profileSet):
        return environment.cookiesClient.setCookie(
            Defaults.URL.host, Defaults.Cookie.selectedProfile, String(profileSet)
        )
        .fireAndForget()

    case .fetchEhSetting:
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        return EhSettingRequest().effect.map(EhSettingAction.fetchEhSettingDone)

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
        return SubmitEhSettingChangesRequest(ehSetting: ehSetting)
            .effect.map(EhSettingAction.submitChangesDone)

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
        return EhProfileRequest(action: action, name: name, set: set)
            .effect.map(EhSettingAction.performActionDone)

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
.binding()
