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
/// Every case holds ONE defaults suite, used both while building the state and as the store's storage, so the
/// remembered record never leaks between cases.
///
/// The suite is a plain-named one, not Sharing's `UserDefaults.inMemory`: these cases read the stored record straight
/// from the suite, and `inMemory` names its suite by a path under the temporary directory, which makes it file-backed.
/// In the simulator test process, under parallel load, every file-backed suite at once can stop reflecting new writes,
/// so a raw read returns an earlier value although the shared reference holds the new one. A plain-named suite stays
/// read-after-write consistent; Swift Testing builds one suite instance per case, and `deinit` removes its domain.
@MainActor
final class LibraryPickerChoicePersistenceTests {
    private let suiteName = "library-picker-choice-\(UUID().uuidString)"
    private let appStorage: UserDefaults

    init() throws {
        appStorage = try #require(UserDefaults(suiteName: suiteName))
    }

    isolated deinit {
        appStorage.removePersistentDomain(forName: suiteName)
    }

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

    @Test
    func aCompactColdLaunchRestoresTheRememberedDownloadFolder() async throws {
        let store = makeStore(remembered: .downloads(.folder("Reading")), folders: ["Reading"])

        await store.send(.library(.deviceChanged(.other))) {
            $0.libraryState.device = .other
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == .downloads(.folder("Reading")))
        #expect(store.state.downloadsState.folderFilter == .folder("Reading"))
        #expect(try stored()?.group == .downloads(.folder("Reading")))
    }

    @Test
    func aCompactColdLaunchRestoresTheRememberedFavoritesCategory() async throws {
        let store = makeStore(remembered: .favorites(3))

        await store.send(.library(.deviceChanged(.other))) {
            $0.libraryState.device = .other
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == .favorites(3))
        #expect(store.state.favoritesState.favoritesIndex == 3)
        #expect(try stored()?.group == .favorites(3))
    }

    @Test
    func aFoldedDuoColdLaunchRestoresTheRememberedChoice() async throws {
        let store = makeStore(remembered: .downloads(.all))

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
        #expect(try stored()?.group == .downloads(.all))
    }

    @Test(arguments: SidebarLayout.allCases)
    func aSidebarLaunchRestoresNothing(layout: SidebarLayout) async throws {
        let store = makeStore(remembered: .favorites(3))

        await store.send(.library(.deviceChanged(layout.device))) {
            $0.libraryState.device = layout.device
        }
        await store.send(.library(.viewportChanged(layout.viewport))) {
            $0.libraryState.viewport = layout.viewport
        }
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.libraryState.selection == nil)
        #expect(try stored()?.group == .favorites(3))
    }

    // MARK: Persist

    @Test(arguments: SidebarLayout.allCases, [LibraryGroup.favorites(-1), nil])
    func sidebarChangesNeverPersist(layout: SidebarLayout, remembered: LibraryGroup?) async throws {
        let store = makeStore(
            remembered: remembered,
            device: layout.device,
            viewport: layout.viewport,
            folders: ["Inbox", "Reading"]
        )

        await store.send(.library(.select(.downloads(.folder("Reading"))))) {
            $0.libraryState.selection = .downloads(.folder("Reading"))
        }
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(store.state.libraryState.selection == .downloads(.folder("Reading")))
        #expect(try stored()?.group == remembered)

        await store.send(.downloads(.binding(.set(\.folderFilter, .folder("Inbox")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(store.state.libraryState.selection == .downloads(.folder("Inbox")))
        #expect(try stored()?.group == remembered)

        await store.send(.library(.select(.favorites(-1))))
        await store.send(.favorites(.setFavoritesIndex(3)))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(store.state.libraryState.selection == .favorites(3))
        #expect(try stored()?.group == remembered)
    }

    @Test
    func compactChangesPersist() async throws {
        let store = makeStore(device: .other, folders: ["Inbox", "Reading"])
        #expect(try stored() == nil)

        await store.send(.library(.select(.downloads(.folder("Reading")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(try stored()?.group == .downloads(.folder("Reading")))

        await store.send(.downloads(.binding(.set(\.folderFilter, .folder("Inbox")))))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(try stored()?.group == .downloads(.folder("Inbox")))

        await store.send(.library(.select(.favorites(-1))))
        await store.send(.favorites(.setFavoritesIndex(3)))
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(try stored()?.group == .favorites(3))
    }

    // MARK: Fallback

    @Test
    func aVanishedRememberedFolderOpensAsAllAndIsRememberedAsAll() async throws {
        let store = makeStore(remembered: .downloads(.folder("Gone")), folders: ["Inbox"])

        await store.send(.library(.deviceChanged(.other))) {
            $0.libraryState.device = .other
        }
        await store.receive(\.library.showInitialSelection)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.downloadsState.folderFilter == .all)
        #expect(store.state.libraryState.selection == .downloads(.all))
        #expect(try stored()?.group == .downloads(.all))
    }

    // MARK: Layout changes

    @Test
    func aCarriedOverSelectionIsShownAndNotPersistedByTheFold() async throws {
        let store = makeStore(
            remembered: .favorites(-1),
            device: .duo(.fullyOpen),
            viewport: CGSize(width: 1000, height: 700),
            folders: ["Reading"]
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
        #expect(try stored()?.group == .favorites(-1))
    }

    @Test
    func aFoldWithNothingSelectedOpensTheRememberedChoice() async throws {
        let store = makeStore(
            remembered: .downloads(.all),
            device: .duo(.fullyOpen),
            viewport: CGSize(width: 1000, height: 700)
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
    func stored() throws -> LibraryPickerChoice? {
        guard let data = appStorage.data(forKey: "libraryPickerChoice") else { return nil }
        return try JSONDecoder().decode(LibraryPickerChoice?.self, from: data)
    }

    /// A store whose remembered choice, layout and folder list are preset, all on the case's suite.
    func makeStore(
        remembered: LibraryGroup? = nil,
        device: WindowDevice? = nil,
        viewport: CGSize = .zero,
        folders: [String] = []
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
