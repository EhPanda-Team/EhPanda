import SwiftUI
import ComposableArchitecture
import SwiftUINavigationExt

extension Reducer {
    public func haptics<Enum: Sendable, Case: Sendable>(
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
