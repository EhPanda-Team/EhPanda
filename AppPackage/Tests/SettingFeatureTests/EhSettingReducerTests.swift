import AnalyticsClient
import AppModels
import ComposableArchitecture
import EhSettingClient
@testable import SettingFeature
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct EhSettingReducerTests {
    // MARK: Fixtures

    static func site(profileName: String = "EhPanda") -> EhSetting {
        .empty(ehProfiles: [EhProfile(value: 1, name: profileName, isSelected: true)])
    }

    // MARK: First load

    @MainActor
    @Test
    func theFirstLoadAppliesTheSiteSettings() async {
        let store = TestStore(initialState: EhSettingReducer.State(), reducer: EhSettingReducer.init) {
            $0.analyticsClient = .noop
            $0.ehSettingClient.fetchSettings = { (_: GalleryHost) async throws(AppError) -> EhSetting in
                Self.site()
            }
        }

        await store.send(.fetchEhSetting) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchEhSettingDone) {
            $0.loadingState = .idle
            $0.ehSetting = Self.site()
            $0.ehProfile = EhProfile(value: 1, name: "EhPanda", isSelected: true)
            $0.editingProfileName = "EhPanda"
        }
        await store.finish()
    }

    @MainActor
    @Test
    func aFailedFirstLoadShowsTheFailure() async {
        let store = TestStore(initialState: EhSettingReducer.State(), reducer: EhSettingReducer.init) {
            $0.analyticsClient = .noop
            $0.ehSettingClient = .failing(.networkingFailed)
        }

        await store.send(.fetchEhSetting) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchEhSettingDone) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.finish()
    }
}
