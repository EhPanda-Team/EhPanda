import AppTools
import Foundation
import AppModels
import Resources
import ComposableArchitecture
import ApplicationClient
import HapticsClient
import NetworkingFeature
import CookieClient
import AppComponents

@Reducer
public struct EhSettingReducer: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case webView(URL)
    }

    public enum Dialog: Equatable, Sendable {
        case confirmDeleteProfile
    }

    private enum CancelID {
        case fetchEhSetting, submitChanges, performAction
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var destination: Destination.State?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var editingProfileName = ""
        public var ehSetting: EhSetting?
        public var ehProfile: EhProfile?
        public var loadingState: LoadingState = .idle
        public var submittingState: LoadingState = .idle

        mutating func setEhSetting(_ ehSetting: EhSetting) {
            let ehProfile: EhProfile = ehSetting.ehProfiles
                .filter(\.isSelected).first.forceUnwrapped
            self.ehSetting = ehSetting
            self.ehProfile = ehProfile
            editingProfileName = ehProfile.name
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case presentWebView(URL)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteProfileButtonTapped
        case setKeyboardHidden
        case setDefaultProfile(Int)

        case fetchEhSetting
        case fetchEhSettingDone(Result<EhSetting, AppError>)
        case submitChanges
        case submitChangesDone(Result<EhSetting, AppError>)
        case performAction(action: EhProfileAction?, name: String?, set: Int)
        case performActionDone(Result<EhSetting, AppError>)
    }

    @Dependency(\.applicationClient) private var applicationClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .destination:
                return .none

            case .presentWebView(let url):
                state.destination = .webView(url)
                return .none

            case .deleteProfileButtonTapped:
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDeleteProfile) {
                        TextState(localized: .RLocalizable.delete)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .RLocalizable.deleteDescription)
                }
                return .none

            case .confirmationDialog(.presented(.confirmDeleteProfile)):
                guard let value = state.ehProfile?.value else { return .none }
                return .send(.performAction(action: .delete, name: nil, set: value))

            case .confirmationDialog:
                return .none

            case .setKeyboardHidden:
                return .run(operation: { _ in await applicationClient.hideKeyboard() })

            case .setDefaultProfile(let profileSet):
                return .run { _ in
                    cookieClient.setOrEditCookie(
                        for: Defaults.URL.host, key: Defaults.Cookie.selectedProfile, value: String(profileSet)
                    )
                }

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
            unwrapping: \.destination,
            case: \.webView,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}

extension EhSettingReducer.Destination.State: Equatable, Sendable {}
extension EhSettingReducer.Destination.Action: Equatable, Sendable {}
