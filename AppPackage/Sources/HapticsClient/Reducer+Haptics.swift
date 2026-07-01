import SwiftUI
import ComposableArchitecture

extension Reducer {
    public func haptics<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        hapticsClient: HapticsClient,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some Reducer<State, Action> {
        onBecomeNonNil(unwrapping: `enum`, case: caseKeyPath) { _, _ in
            .run(operation: { _ in await hapticsClient.generateFeedback(style) })
        }
    }

    private func onBecomeNonNil<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        perform additionalEffects: @escaping (inout State, Action) -> Effect<Action>
    ) -> some Reducer<State, Action> {
        Reduce { state, action in
            let casePath = AnyCasePath(caseKeyPath)
            let previousCase = `enum`(state).flatMap(casePath.extract(from:))
            let effects = _reduce(into: &state, action: action)
            let currentCase = `enum`(state).flatMap(casePath.extract(from:))

            return previousCase == nil && currentCase != nil
                ? .merge(effects, additionalEffects(&state, action))
                : effects
        }
    }
}
