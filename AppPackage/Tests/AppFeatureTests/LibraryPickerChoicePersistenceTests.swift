import AnalyticsClient
import AppComponents
@testable import AppFeature
import AppModels
import ComposableArchitecture
import CookieClient
import CoreGraphics
import DownloadClient
import DownloadsFeature
import FavoritesFeature
import Foundation
import HapticsClient
import HomeFeature
import LogsClient
import Testing
import UserDefaultsClient

/// What the Library remembers across launches (261117-tyj, owner decisions A-1 and A-2): the group last chosen on the
/// compact layout's title-menu picker, restored when the compact layout has no selection, and never written from the
/// sidebar layout.
///
/// Every case holds ONE in-memory defaults suite, used both while building the state and as the store's storage, so
/// the remembered record never leaks between cases.
@Suite
struct LibraryPickerChoicePersistenceTests {
    /// A layout that shows the Library sidebar.
    enum SidebarLayout: CaseIterable {
        case pad
        case duoWithPanes

        var device: WindowDevice {
            switch self {
            case .pad: .pad
            case .duoWithPanes: .duo(.fullyOpen)
            }
        }

        var viewport: CGSize { CGSize(width: 1000, height: 700) }
    }

    // MARK: Restore

    @MainActor
    @Test
    func aCompactColdLaunchRestoresTheRememberedDownloadFolder() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(
            remembered: .downloads(.folder("Reading")), folders: ["Reading"], appStorage: appStorage
        )

        await store.send(.library(.deviceChanged(.other))) {
            $0.libraryState.device = .other
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == .downloads(.folder("Reading")))
        #expect(store.state.downloadsState.folderFilter == .folder("Reading"))
        #expect(try Self.stored(in: appStorage)?.group == .downloads(.folder("Reading")))
    }

    @MainActor
    @Test
    func aCompactColdLaunchRestoresTheRememberedFavoritesCategory() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(remembered: .favorites(3), appStorage: appStorage)

        await store.send(.library(.deviceChanged(.other))) {
            $0.libraryState.device = .other
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == .favorites(3))
        #expect(store.state.favoritesState.favoritesIndex == 3)
        #expect(try Self.stored(in: appStorage)?.group == .favorites(3))
    }

    @MainActor
    @Test
    func aFoldedDuoColdLaunchRestoresTheRememberedChoice() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(remembered: .downloads(.all), appStorage: appStorage)

        await store.send(.library(.deviceChanged(.duo(.closed)))) {
            $0.libraryState.device = .duo(.closed)
        }
        await store.send(.library(.viewportChanged(CGSize(width: 390, height: 844)))) {
            $0.libraryState.viewport = CGSize(width: 390, height: 844)
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == .downloads(.all))
        #expect(try Self.stored(in: appStorage)?.group == .downloads(.all))
    }

    @MainActor
    @Test(arguments: SidebarLayout.allCases)
    func aSidebarLaunchRestoresNothing(layout: SidebarLayout) async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(remembered: .favorites(3), appStorage: appStorage)

        await store.send(.library(.deviceChanged(layout.device))) {
            $0.libraryState.device = layout.device
        }
        await store.send(.library(.viewportChanged(layout.viewport))) {
            $0.libraryState.viewport = layout.viewport
        }
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == nil)
        #expect(try Self.stored(in: appStorage)?.group == .favorites(3))
    }

    // MARK: Persist

    @MainActor
    @Test(arguments: SidebarLayout.allCases, [LibraryGroup.favorites(-1), nil])
    func sidebarChangesNeverPersist(layout: SidebarLayout, remembered: LibraryGroup?) async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(
            remembered: remembered,
            device: layout.device,
            viewport: layout.viewport,
            folders: ["Inbox", "Reading"],
            appStorage: appStorage
        )

        await store.send(.library(.select(.downloads(.folder("Reading"))))) {
            $0.libraryState.selection = .downloads(.folder("Reading"))
        }
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(store.state.libraryState.selection == .downloads(.folder("Reading")))
        #expect(try Self.stored(in: appStorage)?.group == remembered)

        await store.send(.downloads(.binding(.set(\.folderFilter, .folder("Inbox")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(store.state.libraryState.selection == .downloads(.folder("Inbox")))
        #expect(try Self.stored(in: appStorage)?.group == remembered)

        await store.send(.library(.select(.favorites(-1))))
        await store.send(.favorites(.setFavoritesIndex(3)))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(store.state.libraryState.selection == .favorites(3))
        #expect(try Self.stored(in: appStorage)?.group == remembered)
    }

    @MainActor
    @Test
    func compactChangesPersist() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(device: .other, folders: ["Inbox", "Reading"], appStorage: appStorage)
        #expect(try Self.stored(in: appStorage) == nil)

        await store.send(.library(.select(.downloads(.folder("Reading")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(try Self.stored(in: appStorage)?.group == .downloads(.folder("Reading")))

        await store.send(.downloads(.binding(.set(\.folderFilter, .folder("Inbox")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(try Self.stored(in: appStorage)?.group == .downloads(.folder("Inbox")))

        await store.send(.library(.select(.favorites(-1))))
        await store.send(.favorites(.setFavoritesIndex(3)))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(try Self.stored(in: appStorage)?.group == .favorites(3))
    }

    // MARK: Fallback

    @MainActor
    @Test
    func aVanishedRememberedFolderOpensAsAllAndIsRememberedAsAll() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(remembered: .downloads(.folder("Gone")), folders: ["Inbox"], appStorage: appStorage)

        await store.send(.library(.deviceChanged(.other))) {
            $0.libraryState.device = .other
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.downloadsState.folderFilter == .all)
        #expect(store.state.libraryState.selection == .downloads(.all))
        #expect(try Self.stored(in: appStorage)?.group == .downloads(.all))
    }

    // MARK: Layout changes

    @MainActor
    @Test
    func aCarriedOverSelectionIsShownAndNotPersistedByTheFold() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(
            remembered: .favorites(-1),
            device: .duo(.fullyOpen),
            viewport: CGSize(width: 1000, height: 700),
            folders: ["Reading"],
            appStorage: appStorage
        )
        await store.send(.library(.select(.downloads(.folder("Reading")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        // Exhaustive from here: the fold may run nothing beyond the viewport change.
        store.exhaustivity = .on
        await store.send(.library(.viewportChanged(CGSize(width: 700, height: 1000)))) {
            $0.libraryState.viewport = CGSize(width: 700, height: 1000)
        }
        await store.finish()

        #expect(!store.state.libraryState.usesSidebar)
        #expect(store.state.libraryState.selection == .downloads(.folder("Reading")))
        #expect(try Self.stored(in: appStorage)?.group == .favorites(-1))
    }

    @MainActor
    @Test
    func aFoldWithNothingSelectedOpensTheRememberedChoice() async throws {
        let appStorage = UserDefaults.inMemory
        let store = makeStore(
            remembered: .downloads(.all),
            device: .duo(.fullyOpen),
            viewport: CGSize(width: 1000, height: 700),
            appStorage: appStorage
        )

        await store.send(.library(.viewportChanged(CGSize(width: 700, height: 1000)))) {
            $0.libraryState.viewport = CGSize(width: 700, height: 1000)
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == .downloads(.all))
    }
}

private extension LibraryPickerChoicePersistenceTests {
    /// The record decoded from the suite's stored data; `nil` when nothing is stored or a cleared key stored `null`.
    static func stored(in appStorage: UserDefaults) throws -> LibraryPickerChoice? {
        guard let data = appStorage.data(forKey: "libraryPickerChoice") else { return nil }
        return try JSONDecoder().decode(LibraryPickerChoice?.self, from: data)
    }

    /// A store whose remembered choice, layout and folder list are preset, all on `appStorage`.
    @MainActor
    func makeStore(
        remembered: LibraryGroup? = nil,
        device: WindowDevice? = nil,
        viewport: CGSize = .zero,
        folders: [String] = [],
        appStorage: UserDefaults
    ) -> TestStoreOf<AppReducer> {
        withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            @Shared(.libraryPickerChoice) var choice
            $choice.withLock({ $0 = remembered.map({ LibraryPickerChoice(group: $0) }) })

            var initialState = AppReducer.State()
            initialState.libraryState.device = device
            initialState.libraryState.viewport = viewport
            let store = TestStore(
                initialState: initialState,
                reducer: AppReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.cookieClient = .noop
                    $0.defaultAppStorage = appStorage
                    $0.downloadClient = {
                        var client = DownloadClient.noop
                        client.fetchFolders = { folders }
                        return client
                    }()
                    $0.hapticsClient = .noop
                    $0.homeClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
            store.exhaustivity = .off(showSkippedAssertions: false)
            return store
        }
    }
}
