import AnalyticsClient
import AppModels
import ComposableArchitecture
import DetailFeature
import DownloadClient
import Foundation
@testable import HomeFeature
import SwiftUI
import Testing

struct HomeDuoPresentationTests {
    @Test
    func paneDividerAccountsForEachSidesOwnSafeArea() {
        #expect(HomePaneWidths(contentWidth: 868, leftInset: 0, rightInset: 84).left == 476)
        #expect(HomePaneWidths(contentWidth: 868, leftInset: 84, rightInset: 0).left == 392)
        #expect(HomePaneWidths(contentWidth: 952, leftInset: 0, rightInset: 0).left == 476)
    }

    @Test(arguments: [
        CGSize.zero,
        CGSize(width: 669, height: 951),
        CGSize(width: 669, height: 669),
        CGSize(width: 951, height: 0),
        CGSize(width: CGFloat.infinity, height: 669)
    ])
    func partialHingeDoesNotSplitWithoutAValidLandscapeViewport(_ viewport: CGSize) {
        var state = HomeReducer.State()
        state.isPartiallyOpen = true
        state.viewportSize = viewport
        #expect(!state.usesDuoSplitLayout)
    }

    @MainActor
    @Test
    func portraitPartialGalleryKeepsAppOwnedRouting() async {
        let store = homeStore(isPartiallyOpen: true) {
            $0.viewportSize = CGSize(width: 669, height: 951)
        }
        await store.send(.galleryTapped(.preview, from: .right))
        await store.receive(\.delegate.openGalleryDetail)
        await store.finish()
        #expect(store.state.sheet == nil)
        #expect(store.state.isPartiallyOpen)
    }

    @MainActor
    @Test(arguments: HomeSectionType.allCases)
    func portraitPartialSectionKeepsStackRouting(_ section: HomeSectionType) async {
        let store = homeStore(isPartiallyOpen: true) {
            $0.viewportSize = CGSize(width: 669, height: 951)
        }
        store.exhaustivity = .off
        await store.send(.sectionTapped(section))
        #expect(store.state.sheet == nil)
        switch section {
        case .frontpage: #expect(store.state.path.last?.frontpage != nil)
        case .toplists: #expect(store.state.path.last?.toplists != nil)
        }
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test(arguments: HomeMiscGridType.allCases)
    func portraitPartialOtherListsKeepStackRouting(_ section: HomeMiscGridType) async {
        let store = homeStore(isPartiallyOpen: true) {
            $0.viewportSize = CGSize(width: 669, height: 951)
        }
        store.exhaustivity = .off
        await store.send(.miscTapped(section))
        #expect(store.state.sheet == nil)
        switch section {
        case .popular: #expect(store.state.path.last?.popular != nil)
        case .watched: #expect(store.state.path.last?.watched != nil)
        case .history: #expect(store.state.path.last?.history != nil)
        }
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func rotationChangesSplitPolicyWithoutReplacingNavigation() async {
        let store = homeStore(isPartiallyOpen: true) {
            $0.sheet = .init(root: .history(.init()), side: .right)
            $0.path.append(.popular(.init()))
        }
        #expect(store.state.usesDuoSplitLayout)
        await store.send(.viewportChanged(CGSize(width: 669, height: 951))) {
            $0.viewportSize = CGSize(width: 669, height: 951)
        }
        #expect(!store.state.usesDuoSplitLayout)
        #expect(store.state.isPartiallyOpen)
        await store.send(.viewportChanged(CGSize(width: 951, height: 669))) {
            $0.viewportSize = CGSize(width: 951, height: 669)
        }
        #expect(store.state.usesDuoSplitLayout)
        await store.finish()
    }

    @MainActor
    @Test(arguments: [HomePane.left, .right])
    func partiallyOpenGalleryUsesTheOppositeSide(_ source: HomePane) async throws {
        let store = homeStore(isPartiallyOpen: true)
        store.exhaustivity = .off

        await store.send(.galleryTapped(.preview, from: source))
        let sheet = try #require(store.state.sheet)
        #expect(sheet.side == source.opposite)
        #expect(sheet.root.gallery?.detail.gallery == .preview)
        #expect(store.state.path.isEmpty)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test(arguments: [HomePane.left, .right])
    func otherPosturesKeepAppOwnedGalleryRouting(_ source: HomePane) async {
        let store = homeStore(isPartiallyOpen: false)

        await store.send(.galleryTapped(.preview, from: source))
        await store.receive(\.delegate.openGalleryDetail)
        await store.finish()
        #expect(store.state.sheet == nil)
    }

    @MainActor
    @Test(arguments: HomeSectionType.allCases)
    func sectionListsPresentOnTheOppositeSide(_ section: HomeSectionType) async throws {
        let store = homeStore(isPartiallyOpen: true)
        store.exhaustivity = .off

        await store.send(.sectionTapped(section))
        let sheet = try #require(store.state.sheet)
        switch section {
        case .frontpage:
            #expect(sheet.side == .right)
            #expect(sheet.root.frontpage != nil)
        case .toplists:
            #expect(sheet.side == .left)
            #expect(sheet.root.toplists != nil)
        }
        #expect(store.state.path.isEmpty)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test(arguments: HomeMiscGridType.allCases)
    func otherListsPresentOnTheRight(_ section: HomeMiscGridType) async throws {
        let store = homeStore(isPartiallyOpen: true)
        store.exhaustivity = .off

        await store.send(.miscTapped(section))
        let sheet = try #require(store.state.sheet)
        #expect(sheet.side == .right)
        switch section {
        case .popular: #expect(sheet.root.popular != nil)
        case .watched: #expect(sheet.root.watched != nil)
        case .history: #expect(sheet.root.history != nil)
        }
        #expect(store.state.path.isEmpty)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func foldingKeepsThePresentedListAndExistingStack() async {
        let store = homeStore(isPartiallyOpen: true) {
            var history = HistoryReducer.State()
            history.galleries = [.preview]
            $0.sheet = .init(root: .history(history), side: .right)
            $0.path.append(.popular(.init()))
        }

        await store.send(.hingeChanged(isPartiallyOpen: false)) {
            $0.isPartiallyOpen = false
        }
        await store.send(.hingeChanged(isPartiallyOpen: true)) {
            $0.isPartiallyOpen = true
        }
        await store.send(.hingeChanged(isPartiallyOpen: true))
        await store.finish()
    }

    @MainActor
    @Test
    func anotherTapCannotReplaceThePresentedList() async {
        let store = homeStore(isPartiallyOpen: true) {
            $0.sheet = .init(root: .history(.init()), side: .right)
        }

        await store.send(.galleryTapped(.preview, from: .right))
        await store.finish()
    }

    @MainActor
    @Test
    func accountNavigationWaitsForTheListToFinishDismissing() async {
        let store = homeStore(isPartiallyOpen: true) {
            $0.sheet = .init(root: .watched(.init()), side: .right)
        }

        await store.send(.sheet(.presented(.root(.watched(.onNotLoginViewButtonTapped))))) {
            $0.sheet = nil
            $0.opensAccountAfterSheetDismissal = true
        }
        await store.send(.sheetDismissed) {
            $0.opensAccountAfterSheetDismissal = false
        }
        await store.receive(\.delegate.openAccount)
        await store.send(.sheetDismissed)
        await store.finish()
    }

    @MainActor
    @Test(arguments: [HomePane.left, .right])
    func listOwnsDetailAndRetainsItsContentsAfterDismissal(_ side: HomePane) async {
        let defaults = UserDefaults.inMemory
        let store = withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            var list = HistoryReducer.State()
            list.galleries = [.preview]
            return TestStore(
                initialState: HomeSheetFeature.State(root: .history(list), side: side),
                reducer: HomeSheetFeature.init
            ) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
                $0.date = .constant(.init(timeIntervalSince1970: 0))
                $0.downloadClient = .noop
            }
        }
        store.exhaustivity = .off

        await store.send(.root(.history(.delegate(.pushDetail(.preview)))))
        #expect(store.state.gallery?.detail.gallery == .preview)
        #expect(store.state.side == side)
        await store.skipInFlightEffects(strict: false)
        await store.send(.gallery(.dismiss))
        #expect(store.state.gallery == nil)
        #expect(store.state.root.history?.galleries == [.preview])
    }

    @Test
    func physicalPresentationSidesRespectRightToLeftText() {
        #expect(HomePane.left.placement(layoutDirection: .leftToRight) == .leading)
        #expect(HomePane.left.placement(layoutDirection: .rightToLeft) == .trailing)
        #expect(HomePane.right.placement(layoutDirection: .leftToRight) == .trailing)
        #expect(HomePane.right.placement(layoutDirection: .rightToLeft) == .leading)
    }

    @MainActor
    private func homeStore(
        isPartiallyOpen: Bool,
        configure: (inout HomeReducer.State) -> Void = { _ in }
    ) -> TestStoreOf<HomeReducer> {
        let defaults = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            var state = HomeReducer.State()
            state.popularGalleries = [.preview]
            state.isPartiallyOpen = isPartiallyOpen
            state.viewportSize = CGSize(width: 951, height: 669)
            configure(&state)
            return TestStore(initialState: state, reducer: HomeReducer.init) {
                $0.analyticsClient = .noop
                $0.cookieClient = .noop
                $0.defaultAppStorage = defaults
                $0.date = .constant(.init(timeIntervalSince1970: 0))
                $0.downloadClient = .noop
            }
        }
    }
}
