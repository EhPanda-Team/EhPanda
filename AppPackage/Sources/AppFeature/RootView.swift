import ComposableArchitecture
import SwiftUI
import UIKit
import AppTools

// MARK: RootView
public struct RootView: View {
    private let appDelegate: AppDelegate

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    public var body: some View {
        // No database to prepare anymore: the tab bar is the root view from launch.
        TabBarView(store: appDelegate.store).onAppear(perform: addTouchHandler).accentColor(.primary)
    }

    private func addTouchHandler() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let tapGesture = UITapGestureRecognizer(target: TouchHandler.shared, action: nil)
            tapGesture.delegate = TouchHandler.shared
            DeviceUtil.keyWindow?.addGestureRecognizer(tapGesture)
        }
    }
}
