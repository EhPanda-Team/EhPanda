import AppModels
import ComposableArchitecture
import Sharing

/// The two first-launch screens, in order: the age wall, then the analytics choice (D-03).
///
/// The step is derived from the stored answers, never kept separately, so a relaunch in the middle
/// resumes at the screen still unanswered and an upgrader with neither answer starts at the wall.
/// Answers are written to `@Shared(.setting)` and reported to `AppReducer` through `Delegate`:
/// `AppReducer` runs the deferred launch work when the age is confirmed (D-04, DD-06). This reducer
/// calls no client itself; the analytics level is applied by `AppReducer` (18-03).
@Reducer
struct FirstLaunchReducer {
    enum Step: Equatable {
        case ageWall
        case analyticsChoice
        case complete
    }

    @CasePathable
    enum Delegate: Equatable {
        /// The current age declaration was confirmed and stored.
        case ageConfirmed
        /// A level was chosen and stored; the first launch is complete.
        case levelChosen(AnalyticsLevel)
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.setting) var setting: Setting
        /// The age wall's checkbox. Continue does nothing until it is ticked (D-04).
        var isDeclarationTicked = false
        /// The analytics choice's selection. No level is selected until the user taps one (D-06a).
        var selectedLevel: AnalyticsLevel?

        var step: Step {
            if !AgeDeclaration.isConfirmed(setting.ageDeclarationVersion) {
                .ageWall
            } else if setting.analyticsLevel == nil {
                .analyticsChoice
            } else {
                .complete
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case ageWallContinue
        case analyticsContinue(AnalyticsLevel)
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .ageWallContinue:
                guard state.step == .ageWall, state.isDeclarationTicked else { return .none }
                state.$setting.withLock({ $0.ageDeclarationVersion = AgeDeclaration.currentVersion })
                return .send(.delegate(.ageConfirmed))

            case .analyticsContinue(let level):
                // Only once the age is confirmed: the choice is never reachable before the wall.
                guard state.step == .analyticsChoice else { return .none }
                state.selectedLevel = level
                state.$setting.withLock({ $0.analyticsLevel = level })
                return .send(.delegate(.levelChosen(level)))

            case .delegate:
                return .none
            }
        }
    }
}
