import SwiftUI
import AppModels
import ComposableArchitecture

extension Reducer {
    func haptics<Enum: Sendable, Case: Sendable>(
        unwrapping enum: @escaping (State) -> Enum?,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        hapticsClient: HapticsClient,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some Reducer<State, Action> {
        onBecomeNonNil(unwrapping: `enum`, case: caseKeyPath) { _, _ in
            .run(operation: { _ in await hapticsClient.generateFeedback(style) })
        }
    }

    private func onBecomeNonNil<Enum: Sendable, Case: Sendable>(
        unwrapping enum: @escaping (State) -> Enum?,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        perform additionalEffects: @escaping (inout State, Action) -> Effect<Action>
    ) -> some Reducer<State, Action> {
        Reduce { state, action in
            let previousCase = Binding.constant(`enum`(state)).case(caseKeyPath).wrappedValue
            let effects = _reduce(into: &state, action: action)
            let currentCase = Binding.constant(`enum`(state)).case(caseKeyPath).wrappedValue

            return previousCase == nil && currentCase != nil
                ? .merge(effects, additionalEffects(&state, action))
                : effects
        }
    }
}

// MARK: Recurse
struct RecurseReducer<State, Action, Base: Reducer>: Reducer
where State == Base.State, Action == Base.Action {
    let base: (Reduce<State, Action>) -> Base

    public init(@ReducerBuilder<State, Action> base: @escaping (Reduce<State, Action>) -> Base) {
        self.base = base
    }

    public var body: some Reducer<State, Action> {
        var `self`: Reduce<State, Action>!
        self = Reduce { state, action in
            base(self)._reduce(into: &state, action: action)
        }
        return self
    }
}

// MARK: Logging
struct LoggingReducer<State, Action, Base: Reducer>: Reducer
where State == Base.State, Action == Base.Action {
    let base: Base

    init(@ReducerBuilder<State, Action> base: () -> Base) {
        self.base = base()
    }

    @ReducerBuilder<State, Action>
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            Logger.info(action)
            return base._reduce(into: &state, action: action)
        }
    }
}
