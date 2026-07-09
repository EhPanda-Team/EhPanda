import ComposableArchitecture
import HapticsClient
import DFClient

@Reducer
public struct LaboratorySettingReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public init() {}
    }

    public enum Action: Equatable, Sendable {
        // Sent by the view when the SNI-filtering toggle changes. The write itself lands directly in
        // `@Shared(.setting)`, which dispatches no action, so the view bridges the change here and this
        // reducer owns the side effect the write can't trigger.
        case bypassesSNIFilteringChanged(Bool)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.dfClient) private var dfClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .bypassesSNIFilteringChanged(let value):
                return .merge(
                    .run { _ in await hapticsClient.generateFeedback(.soft) },
                    .run { _ in dfClient.setActive(value) }
                )
            }
        }
    }
}
