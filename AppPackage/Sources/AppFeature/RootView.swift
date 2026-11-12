import ComposableArchitecture
public import SwiftUI
#if DEBUG
import AppComponents
#endif
#if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
import Appshot
#endif

// MARK: RootView
public struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let appDelegate: AppDelegate

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    public var body: some View {
        content
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.3), value: isFirstLaunchComplete)
            .captureDiagnostics(store: appDelegate.store)
    }

    private var store: StoreOf<AppReducer> { appDelegate.store }

    private var isFirstLaunchComplete: Bool {
        store.firstLaunch.step == .complete
    }

    /// Until both first-launch answers exist, the first launch replaces the app at the root (DD-06), so nothing of
    /// the app is rendered behind it; the app then crossfades in. While the gate shows it owns link delivery, and
    /// `AppReducer` queues a link until the age wall is answered (DD-07); it also reports the scene phase, which
    /// `AppReducer` records for the deferred launch. Once the app shows, `TabBarView` does both.
    @ViewBuilder private var content: some View {
        if isFirstLaunchComplete {
            TabBarView(store: store)
                .transition(.opacity)
        } else {
            FirstLaunchGateView(store: store.scope(\.firstLaunch, action: \.firstLaunch))
                .transition(.opacity)
                .onOpenURL { store.send(.openURL($0)) }
                .onChange(of: scenePhase) { _, newValue in
                    store.send(.onScenePhaseChange(newValue))
                }
        }
    }
}

private extension View {
    /// Capture launches expose diagnostics and hide persistent system chrome in exported screenshots.
    /// Every other launch, including Release builds, retains the screen's own visibility policy.
    @ViewBuilder
    func captureDiagnostics(store: StoreOf<AppReducer>) -> some View {
        #if DEBUG
        if let capture = CaptureScenePreparation.installed {
            background(alignment: .topLeading) {
                CaptureDiagnosticsAnchor(store: store, capture: capture)
                    .frame(width: 1, height: 1)
            }
            .environment(\.captureSystemOverlayVisibility, .hidden)
            .persistentSystemOverlays(.hidden)
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
