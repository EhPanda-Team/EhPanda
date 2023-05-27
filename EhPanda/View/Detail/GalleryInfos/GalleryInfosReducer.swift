//
//  GalleryInfosReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/23.
//

import TTProgressHUD
import ComposableArchitecture

struct GalleryInfosReducer: ReducerProtocol {
    enum Route {
        case hud
    }

    struct State: Equatable {
        @BindingState var route: Route?
        var hudConfig: TTProgressHUDConfig = .copiedToClipboardSucceeded
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case copyText(String)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .copyText(let text):
                state.route = .hud
                return .merge(
                    clipboardClient.saveText(text).fireAndForget(),
                    .fireAndForget({ hapticsClient.generateNotificationFeedback(.success) })
                )
            }
        }
    }
}
