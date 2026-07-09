import ComposableArchitecture
import DeviceClient
import AppDelegateClient

@Reducer
public struct ReadingSettingReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public init() {}
    }

    public enum Action: Equatable, Sendable {
        // The view writes `enablesLandscape` straight into `@Shared(.setting)`, which dispatches no
        // action, so it bridges the change here; this reducer re-locks portrait orientation when
        // landscape is turned off (phones only — iPad always allows rotation).
        case enablesLandscapeChanged(Bool)
    }

    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.appDelegateClient) private var appDelegateClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .enablesLandscapeChanged(let enablesLandscape):
                guard !enablesLandscape else { return .none }
                return .run { _ in
                    guard await !deviceClient.isPad() else { return }
                    await appDelegateClient.setPortraitOrientationMask()
                }
            }
        }
    }
}
