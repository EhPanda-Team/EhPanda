import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
@testable import SettingFeature
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct AccountSettingReducerTests {
    @MainActor
    @Test
    func onPresentedLoadsCookiesAndObservesJarChanges() async {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        var client = CookieClient.testing(memberID: "member-fixture", passHash: "pass-fixture")
        client.cookiesDidChange = { stream }
        let store = makeStore(cookieClient: client)

        await store.send(.onPresented)
        await store.receive(\.loadCookies) {
            $0.ehCookiesState = client.loadCookiesState(host: .ehentai)
            $0.exCookiesState = client.loadCookiesState(host: .exhentai)
        }

        client.clearAll()
        continuation.yield(())
        await store.receive(\.loadCookies, timeout: .seconds(1)) {
            $0.ehCookiesState = client.loadCookiesState(host: .ehentai)
            $0.exCookiesState = client.loadCookiesState(host: .exhentai)
        }

        continuation.finish()
        await store.finish()
    }

    @MainActor
    @Test
    func logoutConfirmDoesNotEagerlyReloadCookies() async {
        let store = makeStore(
            cookieClient: .testing(memberID: "member-fixture", passHash: "pass-fixture")
        )

        // Exhaustive store: receiving anything here would fail. The reload happens through the
        // cookiesDidChange subscription after the parent's clearAll lands, never eagerly (the old
        // eager reload raced the parent's clear effect and snapshotted pre-logout cookies).
        await store.send(.onLogoutConfirmButtonTapped)
    }

    @MainActor
    @Test
    func keystrokeEchoKeepsEditingBufferIntact() async {
        let client = CookieClient.testing(memberID: "member-fixture", passHash: "pass-fixture")
        let store = makeStore(cookieClient: client)

        await store.send(.loadCookies) {
            $0.ehCookiesState = client.loadCookiesState(host: .ehentai)
            $0.exCookiesState = client.loadCookiesState(host: .exhentai)
        }

        var edited = store.state.ehCookiesState
        edited.memberID.editingText = "member-fixture "
        await store.send(.binding(.set(\.ehCookiesState, edited))) {
            $0.ehCookiesState = edited
        }

        // The write-back committed the trimmed text to the jar; the notification-driven reload
        // must not replace the buffer, or the focused TextField would lose its trailing space.
        await store.send(.loadCookies)
        #expect(store.state.ehCookiesState.memberID.editingText == "member-fixture ")
        await store.finish()
    }

    @MainActor
    @Test
    func externalIgneousUpdateReplacesOnlyIgneousBuffer() async {
        let client = CookieClient.testing(memberID: "member-fixture", passHash: "pass-fixture")
        let store = makeStore(cookieClient: client)

        await store.send(.loadCookies) {
            $0.ehCookiesState = client.loadCookiesState(host: .ehentai)
            $0.exCookiesState = client.loadCookiesState(host: .exhentai)
        }

        var edited = store.state.exCookiesState
        edited.memberID.editingText = "member-fixture "
        await store.send(.binding(.set(\.exCookiesState, edited))) {
            $0.exCookiesState = edited
        }

        client.setOrEditCookie(
            for: GalleryHost.exhentai.url, key: "igneous", value: "igneous-updated"
        )
        await store.send(.loadCookies) {
            $0.exCookiesState.igneous = client.loadCookiesState(host: .exhentai).igneous
        }
        #expect(store.state.exCookiesState.memberID.editingText == "member-fixture ")
        await store.finish()
    }

    @MainActor
    private func makeStore(cookieClient: CookieClient) -> TestStoreOf<AccountSettingReducer> {
        TestStore(initialState: AccountSettingReducer.State(), reducer: AccountSettingReducer.init) {
            $0.cookieClient = cookieClient
        }
    }
}
