import AnalyticsClient
import ApplicationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DFClient
import FileClient
import Foundation
import HapticsClient
import LibraryClient
import LogsClient
import MyTagsClient
@testable import SettingFeature
import Sharing
import Testing
import TestingSupport

// The signed-in launch, the end of a login and a host change on Account read My Tags and cache it on the user (port
// of PR 462 item 10). The cache keeps the tag sets only and survives a failed read. The sets are invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagsLaunchFetchTests {
    private static let cached = MyTags(tagSets: [
        MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [
            MyTag(id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10)
        ])
    ])
    private static let fetched = MyTags(tagSets: [
        MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: []),
        MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])
    ])
    private static let response = MyTagsResponse(myTags: fetched, apiuid: 1234567, apikey: "0123456789abcdef")

    @MainActor
    @Test
    func aSignedInFetchCachesTheTagSetsFromTheSelectedHost() async {
        let hosts = LockIsolated<[GalleryHost]>([])
        let store = makeStore(signedIn: true, seeded: nil) { (host: GalleryHost) async throws(AppError) in
            hosts.withValue({ $0.append(host) })
            return Self.response
        }

        await store.send(.fetchMyTags)
        await store.receive(\.fetchMyTagsDone.success) {
            $0.$user.withLock({ $0.myTags = Self.fetched })
        }
        #expect(hosts.value == [.ehentai])
    }

    @MainActor
    @Test
    func aFailedFetchKeepsTheCache() async {
        let store = makeStore(signedIn: true, seeded: Self.cached) { (_: GalleryHost) async throws(AppError) in
            throw .networkingFailed
        }

        await store.send(.fetchMyTags)
        await store.receive(\.fetchMyTagsDone.failure)
        #expect(store.state.user.myTags == Self.cached)
    }

    @MainActor
    @Test
    func signedOutNothingIsFetched() async {
        let store = makeStore(signedIn: false, seeded: nil, fetch: MyTagsClient.unimplemented.fetchMyTags)

        await store.send(.fetchMyTags)
    }

    // The other launch fetches go to requests this test does not stub; the test network guard fails them offline.
    @MainActor
    @Test
    func theSignedInLaunchFetchesMyTags() async {
        let store = makeStore(signedIn: true, seeded: nil) { (_: GalleryHost) async throws(AppError) in
            Self.response
        }
        store.exhaustivity = .off

        await store.send(.loadUserSettings)
        await store.receive(\.fetchMyTags)
        await store.receive(\.fetchMyTagsDone.success)
        #expect(store.state.user.myTags == Self.fetched)
        await store.skipInFlightEffects(strict: false)
    }

    // The Website picker on Account switching hosts reads My Tags on the new host (design approved 2026-11-22).
    @MainActor
    @Test
    func aHostChangeOnAccountReadsMyTagsThere() async throws {
        let hosts = LockIsolated<[GalleryHost]>([])
        let fetch = { @Sendable (host: GalleryHost) async throws(AppError) -> MyTagsResponse in
            hosts.withValue({ $0.append(host) })
            return Self.response
        }
        let store = makeStore(signedIn: true, seeded: nil, opensAccount: true, fetch: fetch)
        store.exhaustivity = .off

        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .account(.galleryHostChanged(.exhentai)))))
        await store.receive(\.path[id: id].account.delegate)
        await store.receive(\.fetchMyTags)
        await store.receive(\.fetchMyTagsDone.success)
        #expect(store.state.setting.galleryHost == .exhentai)
        #expect(hosts.value == [.exhentai])
    }

    @MainActor
    private func makeStore(
        signedIn: Bool,
        seeded: MyTags?,
        opensAccount: Bool = false,
        fetch: @escaping @Sendable (_ host: GalleryHost) async throws(AppError) -> MyTagsResponse
    ) -> TestStoreOf<SettingReducer> {
        let cookieClient: CookieClient = signedIn
            ? .testing(memberID: "1234567", passHash: "0123456789abcdef0123456789abcdef")
            : .testing()
        var state = SettingReducer.State()
        state.$setting.withLock({ $0.galleryHost = .ehentai })
        state.$user.withLock({ $0.myTags = seeded })
        // Account's state is made here, so its shared setting is the store's (the case's suite).
        if opensAccount {
            state.path.append(.account(.init()))
        }
        return TestStore(initialState: state, reducer: SettingReducer.init) {
            $0.analyticsClient = .noop
            $0.applicationClient = .noop
            $0.cookieClient = cookieClient
            $0.dfClient = .noop
            $0.fileClient = .noop
            $0.hapticsClient = .noop
            $0.libraryClient = .noop
            $0.logsClient = .noop
            $0.myTagsClient.fetchMyTags = fetch
        }
    }
}
