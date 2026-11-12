import AnalyticsClient
@testable import ApplicationClient
import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct AppIconReducerTests {
    // Reconciliation must persist the system's actual icon through an independent shared handle.
    @MainActor
    @Test(arguments: [AppIconType.ukiyoe.filename, nil])
    func syncAppIconTypeDonePersistsMatchedType(iconName: String?) async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = AppIconReducer.State()
            state.$setting.withLock({ $0.appIconType = .developer })
            let store = TestStore(initialState: state, reducer: AppIconReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }
            let expectedType: AppIconType = iconName == nil ? .default : .ukiyoe
            await store.send(.syncAppIconTypeDone(iconName)) {
                $0.$setting.withLock({ $0.appIconType = expectedType })
            }

            @Shared(.setting) var persisted
            #expect(persisted.appIconType == expectedType)
        }
    }

    @MainActor
    @Test(arguments: [
        (iconType: AppIconType.default, iconName: nil as String?),
        (iconType: .ukiyoe, iconName: "AppIcon_Ukiyoe"),
        (iconType: .developer, iconName: "AppIcon_Developer"),
        (iconType: .standWithUkraine2022, iconName: "AppIcon_StandWithUkraine2022"),
        (iconType: .notMyPresidnet, iconName: "AppIcon_NotMyPresident")
    ])
    func selectionAppliesSystemIcon(iconType: AppIconType, iconName: String?) async {
        let defaults = UserDefaults.inMemory
        let requestedNames = LockIsolated<[String?]>([])
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let store = TestStore(initialState: .init(), reducer: AppIconReducer.init) {
                $0.analyticsClient = .noop
                $0.applicationClient = .init(
                    openURL: { _ in },
                    hideKeyboard: {},
                    alternateIconName: { iconName },
                    setAlternateIconName: { name in
                        requestedNames.withValue({ $0.append(name) })
                        return true
                    },
                    setUserInterfaceStyle: { _ in }
                )
            }

            // Default starts selected: tapping it must still restore the primary system icon.
            if iconType == .default {
                await store.send(.appIconTypeChanged(iconType))
            } else {
                await store.send(.appIconTypeChanged(iconType)) {
                    $0.$setting.withLock({ $0.appIconType = iconType })
                }
            }
            await store.receive(.syncAppIconTypeDone(iconName))
            await store.finish()

            #expect(requestedNames.value == [iconName])
            @Shared(.setting) var persisted
            #expect(persisted.appIconType == iconType)
        }
    }

    @MainActor
    @Test(arguments: [AppIconType.default, .developer])
    func failedIconChangeRestoresSystemSelection(systemIcon: AppIconType) async {
        let defaults = UserDefaults.inMemory
        let iconName = systemIcon == .default ? nil : systemIcon.filename
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = AppIconReducer.State()
            state.$setting.withLock({ $0.appIconType = systemIcon })
            let store = TestStore(initialState: state, reducer: AppIconReducer.init) {
                $0.analyticsClient = .noop
                $0.applicationClient = .init(
                    openURL: { _ in },
                    hideKeyboard: {},
                    alternateIconName: { iconName },
                    setAlternateIconName: { _ in false },
                    setUserInterfaceStyle: { _ in }
                )
            }
            let selectedIcon: AppIconType = systemIcon == .default ? .ukiyoe : .default

            await store.send(.appIconTypeChanged(selectedIcon)) {
                $0.$setting.withLock({ $0.appIconType = selectedIcon })
            }
            await store.receive(.syncAppIconTypeDone(iconName)) {
                $0.$setting.withLock({ $0.appIconType = systemIcon })
            }
            await store.finish()

            @Shared(.setting) var persisted
            #expect(persisted.appIconType == systemIcon)
        }
    }
}
