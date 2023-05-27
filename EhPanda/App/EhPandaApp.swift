//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import ComposableArchitecture

@main struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            WithViewStore(
                appDelegate.store, observe: \.appDelegateState.migrationState.databaseState
            ) { viewStore in
                ZStack {
                    if viewStore.state == .idle {
                        TabBarView(store: appDelegate.store).onAppear(perform: addTouchHandler).accentColor(.primary)
                    }
                    MigrationView(
                        store: appDelegate.store.scope(
                            state: \.appDelegateState.migrationState,
                            action: { AppReducer.Action.appDelegate(.migration($0)) }
                        )
                    )
                    .opacity(viewStore.state != .idle ? 1 : 0)
                    .animation(.linear(duration: 0.5), value: viewStore.state)
                }
                .navigationViewStyle(.stack)
            }
        }
    }
}

// MARK: TouchHandler
final class TouchHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = TouchHandler()
    var currentPoint: CGPoint?

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        currentPoint = touch.location(in: touch.window)
        return false
    }
}
private extension EhPandaApp {
    func addTouchHandler() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let tapGesture = UITapGestureRecognizer(
                target: self, action: nil
            )
            tapGesture.delegate = TouchHandler.shared
            DeviceUtil.keyWindow?.addGestureRecognizer(tapGesture)
        }
    }
}
