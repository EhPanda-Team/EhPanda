import ComposableArchitecture

extension ReadingReducer {
    var layoutReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .layoutChanged(isLandscape, supportsAutomaticLayout):
                guard state.layoutIsLandscape != isLandscape
                    || state.supportsAutomaticLayout != supportsAutomaticLayout else { return .none }
                state.layoutIsLandscape = isLandscape
                state.supportsAutomaticLayout = supportsAutomaticLayout
                applyReadingOrientation(to: &state)
                return .none

            case .readingOrientationPreferencesChanged:
                applyReadingOrientation(to: &state)
                return .none

            default:
                return .none
            }
        }
    }

    private func applyReadingOrientation(to state: inout State) {
        guard state.supportsAutomaticLayout, let isLandscape = state.layoutIsLandscape,
              state.setting.readingOrientation.isEnabled else { return }
        state.$setting.withLock { setting in
            let preferences = setting.readingOrientation
            setting.readingDirection = isLandscape
                ? preferences.landscapeDirection.readingDirection : preferences.portraitDirection
            setting.enableDualPageMode = isLandscape
        }
    }
}
