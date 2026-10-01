import ApplicationClient
import AppModels
import ComposableArchitecture
import Sharing

@Reducer
public struct AppIconReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.setting) public var setting: Setting
        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case appIconTypeChanged(AppIconType)
        case syncAppIconTypeDone(String?)
    }

    @Dependency(\.applicationClient) private var applicationClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appIconTypeChanged(let iconType):
                state.$setting.withLock({ $0.appIconType = iconType })
                return .run { send in
                    _ = await applicationClient.setAlternateIconName(iconType == .default ? nil : iconType.filename)
                    await send(.syncAppIconTypeDone(await applicationClient.alternateIconName()))
                }

            case .syncAppIconTypeDone(let iconName):
                state.$setting.withLock({ $0.appIconType = .matching(alternateIconName: iconName) })
                return .none
            }
        }
    }
}
