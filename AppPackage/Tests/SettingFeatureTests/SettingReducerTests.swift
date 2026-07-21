import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
@testable import SettingFeature
import Sharing
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct SettingReducerTests {
    @MainActor
    @Test
    func selectedProfileWriteUsesOriginatingHostAfterSharedHostChanges() async {
        let cookieClient = CookieClient.testing()
        let store = makeStore(cookieClient: cookieClient)
        let response = VerifyEhProfileResponse(profileValue: 7, isProfileNotFound: false)
        store.state.$setting.withLock({ $0.galleryHost = .exhentai })

        await store.send(.fetchEhProfileIndexDone(host: .ehentai, result: .success(response)))
        await store.finish()

        #expect(cookieClient.cookies(for: GalleryHost.ehentai.url).map(\.value) == ["7"])
        #expect(cookieClient.cookies(for: GalleryHost.exhentai.url).isEmpty)
    }

    @MainActor
    @Test
    func defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges() async {
        let store = makeStore(cookieClient: .noop)
        let response = VerifyEhProfileResponse(profileValue: nil, isProfileNotFound: true)
        store.state.$setting.withLock({ $0.galleryHost = .exhentai })

        await store.send(.fetchEhProfileIndexDone(host: .ehentai, result: .success(response)))
        await store.receive(\.createDefaultEhProfile, .ehentai)
        await store.skipInFlightEffects()
    }

    @MainActor
    private func makeStore(cookieClient: CookieClient) -> TestStoreOf<SettingReducer> {
        let defaults = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = SettingReducer.State()
            state.$setting.withLock({ $0.galleryHost = .ehentai })
            return TestStore(initialState: state, reducer: SettingReducer.init) {
                $0.cookieClient = cookieClient
                $0.defaultAppStorage = defaults
            }
        }
    }
}
