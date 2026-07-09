import AppModels
import Sharing
import ComposableArchitecture
import ApplicationClient

@Reducer
public struct AppIconReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.setting) public var setting: Setting
        public init() {}
    }

    public enum Action: Equatable, Sendable {
        // The view writes `appIconType` straight into `@Shared(.setting)`, which dispatches no action,
        // so it bridges the change here; this reducer applies it to the system icon and reconciles the
        // stored value back from whatever icon actually took effect.
        case appIconTypeChanged(AppIconType)
        case syncAppIconType
        case syncAppIconTypeDone(String?)
    }

    @Dependency(\.applicationClient) private var applicationClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appIconTypeChanged(let iconType):
                return .run { send in
                    _ = await applicationClient.setAlternateIconName(iconType.filename)
                    await send(.syncAppIconType)
                }

            case .syncAppIconType:
                return .run { send in
                    await send(.syncAppIconTypeDone(await applicationClient.alternateIconName()))
                }

            case .syncAppIconTypeDone(let iconName):
                if let iconName {
                    state.$setting.withLock { $0.appIconType = .matching(alternateIconName: iconName) }
                }
                return .none
            }
        }
    }
}
