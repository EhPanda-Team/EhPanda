import AppFeature
import SwiftUI

@main struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(appDelegate: appDelegate)
        }
    }
}
