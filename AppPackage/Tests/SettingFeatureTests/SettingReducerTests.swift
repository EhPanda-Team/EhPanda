import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Sharing
import Testing
@testable import SettingFeature

@MainActor
struct SettingReducerTests {
    @Test
    func selectedProfileWriteUsesOriginatingHostAfterSharedHostChanges() async {
        let cookieClient = CookieClient.testing()
        let store = makeStore(cookieClient: cookieClient)
        let response = VerifyEhProfileResponse(profileValue: 7, isProfileNotFound: false)
        store.state.$setting.withLock { $0.galleryHost = .exhentai }

        await store.send(.fetchEhProfileIndexDone(.ehentai, .success(response)))
        await store.finish()

        #expect(cookieClient.cookies(for: GalleryHost.ehentai.url).map(\.value) == ["7"])
        #expect(cookieClient.cookies(for: GalleryHost.exhentai.url).isEmpty)
    }

    @Test
    func defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges() async {
        let store = makeStore(cookieClient: .noop)
        let response = VerifyEhProfileResponse(profileValue: nil, isProfileNotFound: true)
        store.state.$setting.withLock { $0.galleryHost = .exhentai }

        await store.send(.fetchEhProfileIndexDone(.ehentai, .success(response)))
        await store.receive(\.createDefaultEhProfile, .ehentai)
        await store.skipInFlightEffects()
    }

    private func makeStore(cookieClient: CookieClient) -> TestStoreOf<SettingReducer> {
        let defaults = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = SettingReducer.State()
            state.$setting.withLock { $0.galleryHost = .ehentai }
            return TestStore(initialState: state, reducer: SettingReducer.init) {
                $0.cookieClient = cookieClient
                $0.defaultAppStorage = defaults
            }
        }
    }
}
