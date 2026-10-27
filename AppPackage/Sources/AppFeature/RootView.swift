import ComposableArchitecture
public import SwiftUI
#if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
import Appshot
#endif

// MARK: RootView
public struct RootView: View {
    private let appDelegate: AppDelegate

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    public var body: some View {
        TabBarView(store: appDelegate.store)
            .captureDiagnostics(store: appDelegate.store)
    }
}

private extension View {
    /// In a capture launch, adds the invisible element UI tests read the capture's diagnostics
    /// from; any other launch, and every Release build, shows the view unchanged.
    @ViewBuilder
    func captureDiagnostics(store: StoreOf<AppReducer>) -> some View {
        #if DEBUG
        if let capture = CaptureScenePreparation.installed {
            background(alignment: .topLeading) {
                CaptureDiagnosticsAnchor(store: store, capture: capture)
                    .frame(width: 1, height: 1)
            }
        } else {
            #if canImport(Appshot) && canImport(AppshotProtocol)
            if let scene = AppshotCapture.launchedScene {
                appshotState(for: scene) {
                    ScreenState(screen: "unknown", failures: ["No capture content was installed"])
                }
            } else {
                self
            }
            #else
            self
            #endif
        }
        #else
        self
        #endif
    }
}
