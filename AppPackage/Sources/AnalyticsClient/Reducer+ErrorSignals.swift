public import AppModels
public import ComposableArchitecture

// The error signal follows the state, not an action.
//
// `errorSurfaced` was once sent from a single toast-setting action. Commit 04b198b26 replaced that action's last
// sender with a direct `state.toast = .error(...)` assignment, and the signal went silent with nothing failing to
// show it. Observing the state instead counts every present and future write to an observed property, whichever
// path makes it, so a later direct assignment cannot bypass the signal again.
//
// One transition into a failure is one signal. A failure re-assigned with the same error while it is still shown
// is not a transition and sends nothing; a retry that goes through loading and fails again is a new transition
// and sends again.
//
// Only failure states a view renders are observed, because the signal says that an error reached the user. A
// failure state no view shows stays unobserved, with a comment at its reducer saying why.

extension Reducer {
    /// Sends `errorSurfaced` each time the projected error changes to a non-nil value.
    ///
    /// Pass the failure half of a `LoadingState` (`\.loadingState.failed`) or the error of an error toast. The
    /// signal carries the error's `AppErrorKind` and `screen`, and nothing else (D-06, D-09).
    public func signalsErrors(
        of error: @escaping (State) -> AppError?,
        on screen: ErrorScreen
    ) -> some Reducer<State, Action> {
        onChange(of: error) { _, state in
            guard let surfacedError = error(state) else { return .none }
            @Dependency(\.analyticsClient) var analyticsClient
            let kind = AppErrorKind(surfacedError)
            return .run(operation: { _ in analyticsClient.send(.errorSurfaced(kind, screen: screen)) })
        }
    }
}
