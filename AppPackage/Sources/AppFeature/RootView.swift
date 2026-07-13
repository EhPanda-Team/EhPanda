import ComposableArchitecture
import SwiftUI

// MARK: RootView
public struct RootView: View {
    private let appDelegate: AppDelegate

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    public var body: some View {
        TabBarView(store: appDelegate.store).accentColor(.primary)
    }
}
