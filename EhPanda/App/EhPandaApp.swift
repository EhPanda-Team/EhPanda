//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import ComposableArchitecture

@main
struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var tabType: TabType = .favorites

    // MARK: EhPandaApp.body
    var body: some Scene {
        WindowGroup {
            TabView {
                FavoritesView(store: appDelegate.store.scope(state: \.favoritesState, action: AltAppAction.favorites))
                    .tabItem(TabType.favorites.label).tag(TabType.favorites)
            }
//            TabView(selection: $tabType) {
//                ForEach(TabType.allCases) { type in
//                    type.view.tabItem(type.label).tag(type)//.accentColor(accentColor)
//                }
//            }
//            .onChange(of: scenePhase) { newValue in
//                <#code#>
//            }
//            .preferredColorScheme(preferredColorScheme)
            .accentColor(.primary).navigationViewStyle(.stack)
            .onAppear(perform: addTouchHandler)
        }
    }
}
// MARK: TabType.view
private extension TabType {
//    var view: some View {
//        Group {
//            switch self {
//            case .home:
//                HomeView()
//            case .favorites:
//                FavoritesView()
//            case .search:
//                Text("Hello")
//            case .setting:
//                SettingView()
//            }
//        }
//    }
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

// MARK: TabType
private enum TabType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

//    case home = "Home"
    case favorites = "Favorites"
//    case search = "Search"
//    case setting = "Setting"
}

private extension TabType {
    var symbolName: String {
        switch self {
//        case .home:
//            return "house.circle"
        case .favorites:
            return "heart.circle"
//        case .search:
//            return "magnifyingglass.circle"
//        case .setting:
//            return "gearshape.circle"
        }
    }
    func label() -> Label<Text, Image> {
        Label(rawValue.localized, systemImage: symbolName)
    }
}
