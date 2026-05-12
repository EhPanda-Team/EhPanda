//
//  GalleryInfosReducer.swift
//  EhPanda
//

import ComposableArchitecture

@Reducer
struct GalleryInfosReducer {
    @CasePathable
    enum Route {
        case hud
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var hudConfig: ProgressHUDConfigState = .copiedToClipboardSucceeded
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case copyText(String)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .copyText(let text):
                state.route = .hud
                return .merge(
                    .run(operation: { _ in clipboardClient.saveText(text) }),
                    .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                )
            }
        }
    }
}
