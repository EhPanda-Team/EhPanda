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

    /// Sends `errorSurfaced` for every key whose state turned into a failure.
    ///
    /// A dictionary holds one list's states per key (a toplists type, a favorites category, a reader page), and each
    /// key's transition counts on its own: a key whose new value is `.failed` and differs from its old value sends one
    /// signal, and a key that had no value before counts as different. The signals go out ordered by kind, so the
    /// effect is deterministic.
    public func signalsErrors<Key: Hashable>(
        of loadingStates: @escaping (State) -> [Key: LoadingState],
        on screen: ErrorScreen
    ) -> some Reducer<State, Action> {
        onChange(of: loadingStates) { oldStates, state in
            let kinds = newlyFailedKinds(from: oldStates, to: loadingStates(state))
            guard !kinds.isEmpty else { return .none }
            @Dependency(\.analyticsClient) var analyticsClient
            return .run(operation: { _ in
                for kind in kinds {
                    analyticsClient.send(.errorSurfaced(kind, screen: screen))
                }
            })
        }
    }

    /// Sends `errorSurfaced` once per kind for the keys whose state turned into a failure, remembering the kinds sent
    /// in `surfacedKinds`.
    ///
    /// It exists for the reader, where one network or host failure can fail every page of a gallery, and the owner
    /// chose one signal per kind per reading session (2026-11-21). A kind already in the set is skipped; every other
    /// kind is sent once and inserted into the set in the same reduce. Emptying the set starts counting afresh.
    public func signalsErrors<Key: Hashable>(
        of loadingStates: @escaping (State) -> [Key: LoadingState],
        on screen: ErrorScreen,
        oncePerKindIn surfacedKinds: WritableKeyPath<State, Set<AppErrorKind>>
    ) -> some Reducer<State, Action> {
        onChange(of: loadingStates) { oldStates, state in
            var kinds = [AppErrorKind]()
            for kind in newlyFailedKinds(from: oldStates, to: loadingStates(state)) {
                guard state[keyPath: surfacedKinds].insert(kind).inserted else { continue }
                kinds.append(kind)
            }
            guard !kinds.isEmpty else { return .none }
            @Dependency(\.analyticsClient) var analyticsClient
            return .run(operation: { [kinds] _ in
                for kind in kinds {
                    analyticsClient.send(.errorSurfaced(kind, screen: screen))
                }
            })
        }
    }
}

/// The kind of every key whose state turned into a failure, ordered by spelling, one entry per key.
private func newlyFailedKinds<Key: Hashable>(
    from oldStates: [Key: LoadingState],
    to newStates: [Key: LoadingState]
) -> [AppErrorKind] {
    newStates
        .compactMap({ key, newState in
            guard let error = newState.failed, oldStates[key] != newState else { return nil }
            return AppErrorKind(error)
        })
        .sorted(by: { $0.rawValue < $1.rawValue })
}
