//
//  EhPandaApp.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

@main struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ZStack {
                let databaseState = appDelegate.store.appDelegateState.migrationState.databaseState

                if databaseState == .idle {
                    TabBarView(store: appDelegate.store).onAppear(perform: addTouchHandler).accentColor(.primary)
                }
                MigrationView(
                    store: appDelegate.store.scope(
                        state: \.appDelegateState.migrationState,
                        action: \.appDelegate.migration
                    )
                )
                .opacity(databaseState != .idle ? 1 : 0)
                .animation(.linear(duration: 0.5), value: databaseState)
            }
            .navigationViewStyle(.stack)
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
