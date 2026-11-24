import AppComponents
@testable import AppFeature
import AppModels
import ComposableArchitecture
import Foundation
import Sharing
import SwiftUI
import SystemNotification
import Testing
import UIKit

/// A toast clears a tab bar only where there is one.
///
/// The toast capsule kept a fixed 88 pt above the bottom safe area on every screen, to stay clear of the tab bar on
/// the app root. A screen without a tab bar (the sign-in page, a pushed page) then showed the toast floating far above
/// the home indicator (the owner's C3 item, 19-13: the offset belongs to the tab bar's height and must not apply to
/// every screen). The capsule now keeps the standard spacing above its host's bottom safe area, and the app root adds
/// the height of the tab bar it sits over, measured from the selected tab's own safe area.
@MainActor
struct ToastPlacementTests {
    /// The standard spacing is 16 pt; this is the most a toast may float above the safe area of a screen that has no
    /// tab bar at the bottom.
    private static let largestGapAboveSafeArea: CGFloat = 20
    /// The room the capsule keeps above a tab bar: the standard spacing, with a little tolerance either way.
    private static let gapAboveTabBar: ClosedRange<CGFloat> = 8...24

    /// On a plain screen, at the scene's size so the window has the device's bottom safe area, the capsule's bottom is
    /// no more than 20 pt above the safe area's bottom edge.
    @Test
    func aToastOnAScreenWithoutATabBarSitsJustAboveTheSafeArea() throws {
        try AccessibilityElements.read(of: Self.plainScreen(), size: HostedView.sceneSize()) { elements in
            let root = try #require(elements.first as? UIView, "The first element is not the hosted root view.")
            #expect(root.safeAreaInsets.bottom > 0, "The window has no bottom safe area, so the test shows nothing.")
            let capsule = try Self.toastFrame(among: elements, in: root)
            let gap = root.safeAreaLayoutGuide.layoutFrame.maxY - capsule.maxY
            #expect(
                gap <= Self.largestGapAboveSafeArea,
                "The capsule is \(gap) pt above the safe area's edge; it may be \(Self.largestGapAboveSafeArea)."
            )
        }
    }

    /// On the app root, the toast clears the tab bar where the tab bar is at the bottom, and only there (owner decision
    /// C3: the toast avoids a tab bar only where there is one).
    ///
    /// The window's horizontal size class says where the tab bar is. At compact width (the iPhone) it floats over the
    /// bottom of the screen, and the capsule's bottom is the standard spacing above its top. At regular width (the
    /// iPad) it is the top tab bar, nothing lies over the bottom of the screen, the clearance is 0 and the capsule sits
    /// as on a plain screen. The branch is not keyed on whether a `UITabBar` is found: the iPhone case requires one, so
    /// a tab bar that goes missing there fails the test instead of passing it.
    @Test
    func aToastOnTheTabRootClearsTheTabBarOnlyWhereItLiesOverTheBottom() throws {
        try AccessibilityElements.read(of: Self.appRoot(), size: HostedView.sceneSize()) { elements in
            let root = try #require(elements.first as? UIView, "The first element is not the hosted root view.")
            let capsule = try Self.toastFrame(among: elements, in: root)
            if root.traitCollection.horizontalSizeClass == .compact {
                let tabBar = try #require(Self.tabBars(in: root).first, "The app root has no tab bar.")
                let tabBarTop = tabBar.convert(tabBar.bounds, to: root).minY
                let gap = tabBarTop - capsule.maxY
                #expect(
                    Self.gapAboveTabBar.contains(gap),
                    "The capsule is \(gap) pt above the tab bar's top \(tabBarTop); it may be \(Self.gapAboveTabBar)."
                )
            } else {
                let gap = root.safeAreaLayoutGuide.layoutFrame.maxY - capsule.maxY
                #expect(
                    gap <= Self.largestGapAboveSafeArea,
                    "With the tab bar on top, the capsule is \(gap) pt above the edge (at most 20)."
                )
            }
        }
    }

    // MARK: Hosts

    /// A plain screen with a success toast on show. The toast stays (no hide timer), as in the app's own captures.
    private static func plainScreen() -> some View {
        var state = ToastScreenFeature.State()
        state.toast = successToast
        let store = withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            Store(initialState: state, reducer: ToastScreenFeature.init)
        }
        return ToastScreen(store: store)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// The app root over the Search tab with the same toast, built as the visual matrix builds it.
    private static func appRoot() -> some View {
        var state = AppReducer.State()
        state.tabBarState.tabBarItemType = .search
        state.presentationState.toast = successToast
        let store = withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            Store(initialState: state, reducer: AppReducer.init)
        }
        return TabBarView(store: store)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    private static var successToast: AppAlertState<Never> {
        var toast = AppAlertState<Never>.copiedToClipboardSucceeded
        toast.style = .toast(icon: .success, autoHide: false)
        return toast
    }

    // MARK: Measuring

    /// The toast capsule's frame in the root view's coordinates.
    private static func toastFrame(among elements: [NSObject], in root: UIView) throws -> CGRect {
        let toast = try #require(
            elements.first(where: { AccessibilityElements.identifier(of: $0) == "toast_message" }),
            "The screen has no element identified toast_message."
        )
        return try #require(root.window?.screen.coordinateSpace.convert(toast.accessibilityFrame, to: root))
    }

    private static func tabBars(in view: UIView) -> [UITabBar] {
        ((view as? UITabBar).map({ [$0] }) ?? []) + view.subviews.flatMap(tabBars(in:))
    }
}

/// A reducer that holds only a toast: a screen that has no tab bar.
@Reducer
private struct ToastScreenFeature {
    @ObservableState
    struct State {
        @Presents var toast: AppAlertState<Never>?
    }

    enum Action {
        case toast(PresentationAction<Never>)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
            .ifLet(\.$toast, action: \.toast)
    }
}

private struct ToastScreen: View {
    @Bindable var store: StoreOf<ToastScreenFeature>

    var body: some View {
        Color.clear
            .toast($store.scope(state: \.toast, action: \.toast))
    }
}
