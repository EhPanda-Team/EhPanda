import ComposableArchitecture
import SwiftUI
import UIKit
import Utilities
import MigrationFeature

// MARK: RootView
public struct RootView: View {
    private let appDelegate: AppDelegate

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    public var body: some View {
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

    private func addTouchHandler() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let tapGesture = UITapGestureRecognizer(target: TouchHandler.shared, action: nil)
            tapGesture.delegate = TouchHandler.shared
            DeviceUtil.keyWindow?.addGestureRecognizer(tapGesture)
        }
    }
}
