import AppComponents
@testable import AppFeature
import AppModels
import ComposableArchitecture
import Foundation
@testable import HomeFeature
import OSLog
import ReadingSettingFeature
@testable import SettingFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

// Settings, the Settings pages and the app-wide presentations (19-08).
extension ScenarioCatalog {
    static var settings: [String: ScenarioFactory] {
        [settingsRoot, settingsPages, appWide].reduce(into: [:]) { result, group in
            result.merge(group) { first, _ in first }
        }
    }

    private static var settingsRoot: [String: ScenarioFactory] {
        typealias Page = SettingsScenarios
        return [
            "settings-root": .init(make: { Page.settings([]) }),
            "settings-account-signed-in": .init(make: { Page.account(confirmingLogout: false) }),
            "settings-account-signed-out": .init(signedIn: false, make: { Page.account(confirmingLogout: false) }),
            "settings-account-logout-confirmation": .init(make: { Page.account(confirmingLogout: true) }),
            "blocked-users-filled": .init(make: { Page.blockedUsers(filled: true) }),
            "blocked-users-empty": .init(make: { Page.blockedUsers(filled: false) }),
            "settings-login-empty": .init(signedIn: false, make: { Page.login(.empty) }),
            "settings-login-filled": .init(
                signedIn: false, make: { Page.login(.filled) }, interact: LibraryScenarios.holdCaret
            ),
            "settings-login-error": .init(signedIn: false, make: { Page.login(.error) })
        ]
    }

    private static var settingsPages: [String: ScenarioFactory] {
        typealias Page = SettingsScenarios
        return [
            "settings-pages-general-minimal": .init(
                make: { Page.general(level: .minimal) }, interact: Page.scrollToBottom
            ),
            "settings-pages-general-basic": .init(make: { Page.general(level: .basic) }, interact: Page.scrollToBottom),
            "settings-pages-general-full": .init(make: { Page.general(level: .full) }, interact: Page.scrollToBottom),
            "settings-pages-general-cache-confirmation": .init(
                make: { Page.general(level: nil, action: .clearImageCacheButtonTapped) }
            ),
            "settings-pages-general-translations-confirmation": .init(
                make: { Page.general(level: nil, action: .removeCustomTranslationsButtonTapped) }
            ),
            "settings-pages-activity-logs": .init(make: { Page.activityLogs(filled: true) }),
            "settings-pages-activity-logs-empty": .init(make: { Page.activityLogs(filled: false) }),
            "settings-pages-activity-logs-run-picker": .init(
                make: { Page.activityLogs(filled: true) }, interact: Page.openRunsMenu
            ),
            "settings-pages-appearance": .init(make: { Page.settings([.appearance(.init())]) }),
            "settings-pages-app-icon": .init(make: { Page.settings([.appearance(.init()), .appIcon(.init())]) }),
            "settings-pages-download": .init(make: { Page.settings([.download(.init())]) }),
            "settings-pages-reading": .init(make: { Page.settings([.reading(.init())]) }),
            "settings-pages-laboratory": .init(
                make: { Page.settings([.laboratory(.init())]) }, interact: Page.waitForGlassShadow
            ),
            "settings-pages-about": .init(make: { Page.settings([.about(.init())]) }),
            "settings-pages-site-settings": .init(make: { Page.siteSettings(.loaded) }),
            "settings-pages-site-settings-confirmation": .init(make: { Page.siteSettings(.deleteConfirmation) }),
            "settings-pages-site-settings-error": .init(make: { Page.siteSettings(.failed) })
        ]
    }

    private static var appWide: [String: ScenarioFactory] {
        typealias Page = SettingsScenarios
        return [
            "app-wide-app-alert": .init(
                make: { Page.jumpPageAlert() }, prepare: TracerScenarios.cacheHomeArtwork,
                interact: Page.holdAlertCaret
            ),
            "app-wide-error-info": .init(make: { Page.app(.errorInfo) }),
            "app-wide-toast-success": .init(make: { Page.app(.successToast) }),
            "app-wide-toast-failure": .init(make: { Page.app(.failureToast) })
        ]
    }
}

@MainActor
enum SettingsScenarios {
    // MARK: Settings stack

    /// The Settings tab: its root, with `pages` pushed on its stack as the root's rows and the pages' own links push
    /// them. Each `actions` entry is sent to the page at its index once the stack is built, as the page's own
    /// presentation or a user's tap on it would send it.
    static func settings(_ pages: [SettingPath.State], actions: [(Int, SettingPath.Action)] = []) -> AnyView {
        var state = SettingReducer.State()
        state.path = StackState(pages)
        let store = Store(initialState: state, reducer: SettingReducer.init)
        let ids = Array(store.withState(\.path.ids))
        for (index, action) in actions {
            guard let id = ids.dropFirst(index).first else { continue }
            store.send(.path(.element(id: id, action: action)))
        }
        return AnyView(SettingView(store: store))
    }

    /// Account, loaded as the Settings stack loads it when the row is tapped; signed in or out follows the
    /// scenario's cookie client. With `confirmingLogout`, Log Out has been tapped.
    static func account(confirmingLogout: Bool) -> AnyView {
        var actions: [(Int, SettingPath.Action)] = [(0, .account(.onPresented))]
        if confirmingLogout {
            actions.append((0, .account(.logoutButtonTapped)))
        }
        return settings([.account(.init())], actions: actions)
    }

    /// Blocked Users over Account, with the synthetic members blocked or with none.
    static func blockedUsers(filled: Bool) -> AnyView {
        if filled {
            @Shared(.blockedCommentUsers) var blockedUsers
            $blockedUsers.withLock { users in
                for member in SettingsFixtures.blockedMembers {
                    users.block(memberID: member.memberID, name: member.name)
                }
            }
        }
        return settings([.account(.init()), .blockedUsers(.init())], actions: [(0, .account(.onPresented))])
    }

    enum LoginState {
        case empty, filled, error
    }

    /// Login over Account, signed out. Filled: the synthetic name and password, with the name field focused. Error:
    /// the same form after the site refused it, as the reducer answers a refused sign-in (its error toast).
    ///
    /// The page's backdrop is two waves drawn in `TimelineView(.animation)` from the wall clock; the matrix runs with
    /// Reduce Motion on, under which `WaveForm` pauses its timeline at a fixed phase (19-10), so the page settles.
    static func login(_ kind: LoginState) -> AnyView {
        var login = LoginReducer.State()
        if kind != .empty {
            login.username = SettingsFixtures.loginUsername
            login.password = SettingsFixtures.loginPassword
        }
        if kind == .filled {
            login.focusedField = .username
        }
        var actions: [(Int, SettingPath.Action)] = [(0, .account(.onPresented))]
        if kind == .error {
            actions.append((1, .login(.loginDone(.failure(.loginRejected(nil))))))
        }
        return settings([.account(.init()), .login(login)], actions: actions)
    }

    // MARK: Settings pages

    /// General, with the analytics level chosen (or none). `action`, if any, is the user's tap on the page. The
    /// cache size is the one the preview library client reports; removing translations needs a custom table, which
    /// the synthetic translations stand in for.
    static func general(level: AnalyticsLevel?, action: GeneralSettingReducer.Action? = nil) -> AnyView {
        @Shared(.setting) var setting
        $setting.withLock({ $0.analyticsLevel = level })
        if action == .removeCustomTranslationsButtonTapped {
            $setting.withLock({ $0.enableTagsExtension = true })
            @Shared(.tagTranslator) var tagTranslator
            $tagTranslator.withLock {
                $0 = TagTranslator(hasCustomTranslations: true, translations: LibraryScenarios.translator.translations)
            }
        }
        var actions: [(Int, SettingPath.Action)] = [(0, .general(.calculateWebImageDiskCache))]
        if let action {
            actions.append((0, .general(action)))
        }
        return settings([.general(.init())], actions: actions)
    }

    /// Brings the page's form to rest at its bottom, where General's analytics section and its footer are.
    static func scrollToBottom(_ window: UIWindow) async throws {
        _ = await HostedWindowCapture.settle(window)
        let root = try XCTUnwrap(window.rootViewController?.view)
        for list in scrollViews(in: root) {
            let bottom = list.contentSize.height - list.bounds.height + list.adjustedContentInset.bottom
            guard bottom > list.contentOffset.y else { continue }
            list.setContentOffset(CGPoint(x: list.contentOffset.x, y: bottom), animated: false)
        }
        root.layoutIfNeeded()
    }

    /// Laboratory's cell is interactive glass. On the phone in landscape its shadow can still step after the window
    /// has looked still for the settle's 500 ms, so a first capture sometimes holds the earlier shadow. The page
    /// settles once, rests a second, and the capture's own settle then reads the final shadow.
    static func waitForGlassShadow(_ window: UIWindow) async throws {
        _ = await HostedWindowCapture.settle(window)
        try await Task.sleep(for: .seconds(1))
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        guard !view.isHidden else { return [] }
        return ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }

    /// Activity Logs over General: the current run's synthetic entries and four earlier runs, or a run with nothing
    /// logged and no earlier runs. No log file is read.
    static func activityLogs(filled: Bool) -> AnyView {
        let now = PublicVisualFixtures.fixedDate
        @Shared(.inMemory("appActivityLogs.currentRun")) var currentRun: RunLogFile?
        $currentRun.withLock({ $0 = runFile(date: now, runCount: SettingsFixtures.currentRunCount) })
        var logs = AppActivityLogsReducer.State()
        if filled {
            @Shared(.inMemory("appActivityLogs.currentRunLogs")) var entries: [AppActivityLog] = []
            $entries.withLock {
                $0 = SettingsFixtures.logEntries.map { entry in
                    AppActivityLog(
                        date: now.addingTimeInterval(entry.offset), category: entry.category,
                        level: level(entry.level), message: entry.message
                    )
                }
            }
            logs.previousRuns = SettingsFixtures.previousRuns.map { run in
                runFile(date: now.addingTimeInterval(-3600 * Double(run.hoursBefore)), runCount: run.runCount)
            }
        }
        return settings([.general(.init()), .appActivityLogs(logs)])
    }

    private static func runFile(date: Date, runCount: Int) -> RunLogFile {
        RunLogFile(
            url: URL(filePath: "/visual-fixture/run-\(Int(date.timeIntervalSince1970))-\(runCount).jsonl"),
            date: date, runCount: runCount
        )
    }

    private static func level(_ level: LogEntryFixture.Level) -> OSLogEntryLog.Level {
        switch level {
        case .debug: .debug
        case .info: .info
        case .notice: .notice
        case .error: .error
        case .fault: .fault
        }
    }

    /// Opens the Runs menu in the bar once the page has settled, as VoiceOver's activation of it does, and holds the
    /// menu's scroll indicator hidden. A menu too tall for the screen (ja-accessibility5 in landscape) builds its
    /// lists over its opening animation and flashes the indicator of a later one, so every menu list is held hidden
    /// for a second after the first appears.
    static func openRunsMenu(_ window: UIWindow) async throws {
        _ = await HostedWindowCapture.settle(window)
        let root = try XCTUnwrap(window.rootViewController?.view)
        try await BrowsingScenarios.activate(String(localized: .appActivityLogsViewRuns), in: window)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        var holdUntil: ContinuousClock.Instant?
        while true {
            let menuLists = scrollViews(in: window).filter({ !$0.isDescendant(of: root) })
            menuLists.forEach({ $0.showsVerticalScrollIndicator = false })
            if !menuLists.isEmpty, holdUntil == nil {
                holdUntil = clock.now.advanced(by: .seconds(1))
            }
            if let holdUntil, clock.now >= holdUntil {
                return
            }
            guard holdUntil != nil || clock.now < deadline else {
                throw AccessibilityActionDriver.Failure.notFound("menu")
            }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    enum SiteSettingsState {
        case loaded, deleteConfirmation, failed
    }

    /// The site settings over Account, as the site answered them: two profiles with the app's own selected, and
    /// synthetic favorite names. Failed is the page's answer to a request that failed. Nothing is fetched.
    static func siteSettings(_ kind: SiteSettingsState) -> AnyView {
        var site = EhSettingReducer.State()
        if kind == .failed {
            site.loadingState = .failed(.networkingFailed)
        } else {
            var ehSetting = EhSetting.empty(ehProfiles: SettingsFixtures.profiles.map { profile in
                EhProfile(
                    value: profile.value, name: profile.name,
                    isSelected: profile.value == SettingsFixtures.selectedProfile
                )
            })
            ehSetting.favoriteCategories = SettingsFixtures.favoriteCategories
            site.setEhSetting(ehSetting)
        }
        let actions: [(Int, SettingPath.Action)] = kind == .deleteConfirmation
            ? [(1, .ehSetting(.deleteProfileButtonTapped))] : []
        return settings([.account(.init()), .ehSetting(site)], actions: actions)
    }

    // MARK: App-wide

    /// Toplists with its jump-page alert open, its page field focused. The keyboard is a separate window and is not
    /// drawn.
    static func jumpPageAlert() -> AnyView {
        let content = BrowsingScenarios.ListContent.loaded(.row)
        content.storeDisplayMode(.toplists)
        var state = ToplistsReducer.State()
        state.rawGalleries[state.type] = content.galleries(3)
        state.rawLoadingState[state.type] = content.loadingState
        state.rawPageNumber[state.type] = PageNumber(current: 0, maximum: SettingsFixtures.toplistsLastPage)
        let store = Store(initialState: state, reducer: ToplistsReducer.init)
        store.send(.presentJumpPageAlert)
        return AnyView(NavigationStack {
            ToplistsView(store: store)
        })
    }

    /// Lets the alert's page field take focus and the alert finish moving, then holds the field's caret still. The
    /// alert is presented over the hosted root, outside the root view, so the presented view's layers are held.
    static func holdAlertCaret(_ window: UIWindow) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        var presented = window.rootViewController
        while true {
            while let next = presented?.presentedViewController {
                presented = next
            }
            if let view = presented?.view, view !== window.rootViewController?.view,
               textFields(in: view).contains(where: \.isFirstResponder) {
                try await clock.sleep(for: .milliseconds(1500))
                view.layer.speed = 0
                view.layer.timeOffset = 0
                return
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("alert field") }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    private static func textFields(in view: UIView) -> [UITextField] {
        ((view as? UITextField).map({ [$0] }) ?? []) + view.subviews.flatMap(textFields(in:))
    }

    enum AppPresentation {
        case errorInfo, successToast, failureToast
    }

    /// The app's own presentations over the Search tab: the Error Info sheet for a failed request, or a toast. The
    /// success toast is the app's Copied toast held by its state (no hide timer); the failure toast carries its
    /// error, so it stays until tapped.
    static func app(_ presentation: AppPresentation) -> AnyView {
        var app = AppReducer.State()
        app.tabBarState.tabBarItemType = .search
        let error = ErrorInfo(error: .networkingFailed)
        switch presentation {
        case .errorInfo:
            app.presentationState.destination = .errorInfo(error)
        case .successToast:
            var toast = AppAlertState<Never>.copiedToClipboardSucceeded
            toast.style = .toast(icon: .success, autoHide: false)
            app.presentationState.toast = toast
        case .failureToast:
            app.presentationState.toast = .error(error)
        }
        return AnyView(TabBarView(store: Store(initialState: app, reducer: AppReducer.init)))
    }
}
