import AppComponents
@testable import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import CustomDump
import DetailFeature
import DownloadsFeature
import FiltersFeature
import Foundation
import HomeFeature
import ParserFeature
@testable import ReadingFeature
import SearchFeature
import SettingFeature
import Sharing
import SwiftUI
import Testing
import TestingSupport
import UIKit

// Each capture screen identifies itself from the app's navigation state and reads ready only once
// it shows its configured content and every image it must show. These cases seed the state each
// route leaves, step by step, and read the diagnostics UI tests receive.
struct CaptureScreenDiagnosticsTests {
    @Test
    func darkHomeWaitsForTheCurrentCardsColors() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let cover = try #require(scene.replay.first(where: { $0.value.mimeType.hasPrefix("image/") })).key
        var state = try await loadedState(scene)

        let light = diagnostics(scene, state, cached: [cover])
        let darkAnalyzing = diagnostics(scene, state, rendering: .darkPhone, cached: [cover])
        state.homeState.rawCardColors[state.homeState.currentCardID] = [.red]
        let darkAnalyzed = diagnostics(scene, state, rendering: .darkPhone, cached: [cover])

        expectNoDifference(light.readiness, .ready)
        expectNoDifference(darkAnalyzing.readiness, .loading)
        expectNoDifference(darkAnalyzing.blockers, ["The current card's colors are not analyzed"])
        expectNoDifference(darkAnalyzed.readiness, .ready)
        expectNoDifference(darkAnalyzed.rendering, .darkPhone)
    }

    @Test
    func aPushedDetailWaitsForItsDetailCoverAndPreviews() async throws {
        let fixture = try MarketingFixtureBuilder.standard().addingPreview()
        let scene = try makeScene(fixture)
        let cover = try #require(fixture.files.first(where: { $0.kind == .cover })?.url)
        let preview = try #require(fixture.files.first(where: { $0.kind == .preview })?.url)
        let gallery = try await flowGallery(scene)
        var detail = DetailReducer.State(gallery: gallery)
        var state = AppReducer.State()
        state.homeState.path.append(.gallery(.detail(detail)))

        let loading = diagnostics(scene, state)
        detail = try loadedDetail(gallery, previewImage: preview)
        state.homeState.path = StackState([.gallery(.detail(detail))])
        let previewPending = diagnostics(scene, state, answered: [cover, preview], cached: [cover])
        let ready = diagnostics(scene, state, answered: [cover, preview], cached: [cover, preview])
        // A preview's image view caches it under the app's stable key for its URL.
        let previewKey = try #require(URL(string: preview)?.stableImageCacheKey)
        let readyUnderStableKey = diagnostics(scene, state, answered: [cover, preview], cached: [cover, previewKey])

        expectNoDifference(loading.screenID, .detail)
        expectNoDifference(loading.galleryIDs, [MarketingFixtureBuilder.flowGID])
        expectNoDifference(loading.readiness, .loading)
        expectNoDifference(loading.blockers, ["The detail is loading", "The cover is not shown"])
        expectNoDifference(previewPending.readiness, .loading)
        expectNoDifference(
            previewPending.blockers,
            ["1 preview images are not shown", "1 delivered images are not cached yet"]
        )
        expectNoDifference(ready.readiness, .ready)
        expectNoDifference(ready.blockers, [])
        expectNoDifference(readyUnderStableKey, ready)
    }

    @Test
    func aDetailSheetAlsoWaitsForTheHomeAroundIt() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let cover = try #require(scene.replay.first(where: { $0.value.mimeType.hasPrefix("image/") })).key
        let gallery = try await flowGallery(scene)
        var state = AppReducer.State()
        state.presentationState.gallery = .init(detail: try loadedDetail(gallery))

        let homeLoading = diagnostics(scene, state, cached: [cover])
        state.homeState = try await loadedState(scene).homeState
        let ready = diagnostics(scene, state, cached: [cover])

        expectNoDifference(homeLoading.screenID, .detail)
        expectNoDifference(homeLoading.readiness, .loading)
        expectNoDifference(
            homeLoading.blockers,
            ["Around the sheet: Home lists are loading", "Around the sheet: The current card's cover is not shown"]
        )
        expectNoDifference(ready.readiness, .ready)
        expectNoDifference(ready.galleryIDs, [MarketingFixtureBuilder.flowGID])
    }

    @Test
    func commentsShowFromTheTopWithNoCommentHighlighted() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let gallery = try await flowGallery(scene)
        let galleryURL = try #require(gallery.galleryURL)
        let comments = try savedPage().state.comments
        var state = AppReducer.State()

        state.homeState.path = StackState([
            .gallery(.comments(.init(gid: gallery.gid, galleryURL: galleryURL, comments: comments)))
        ])
        let readable = diagnostics(scene, state)
        state.homeState.path = StackState([
            .gallery(.comments(.init(
                gid: gallery.gid, galleryURL: galleryURL, comments: comments, scrollCommentID: comments.first?.commentID
            )))
        ])
        let highlighted = diagnostics(scene, state)
        state.homeState.path = StackState([.gallery(.comments(.init(gid: gallery.gid, galleryURL: galleryURL)))])
        let empty = diagnostics(scene, state)

        #expect(!comments.isEmpty)
        expectNoDifference(readable.screenID, .comments)
        #expect(readable.showsPanel == nil)
        expectNoDifference(readable.galleryIDs, [MarketingFixtureBuilder.flowGID])
        expectNoDifference(readable.readiness, .ready)
        expectNoDifference(highlighted.readiness, .failed)
        expectNoDifference(highlighted.blockers, ["A comment is highlighted"])
        expectNoDifference(empty.readiness, .failed)
        expectNoDifference(empty.blockers, ["The gallery shows no comments"])
    }

    @Test
    func theReaderWaitsUntilItShowsItsPageAndReportsItsPanel() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let gallery = try await flowGallery(scene)
        var reading = ReadingReducer.State(gallery: gallery)
        reading.pendingReadingProgress = 4
        var detail = try loadedDetail(gallery)
        var state = AppReducer.State()

        detail.destination = .reading(reading)
        state.homeState.path = StackState([.gallery(.detail(detail))])
        let loading = diagnostics(scene, state)
        reading.webImageLoadSuccessIndices = [4]
        reading.showsPanel = true
        detail.destination = .reading(reading)
        state.homeState.path = StackState([.gallery(.detail(detail))])
        let shown = diagnostics(scene, state)
        reading.imageURLLoadingStates[4] = .failed(.notFound)
        detail.destination = .reading(reading)
        state.presentationState.gallery = .init(detail: detail)
        let failedInASheet = diagnostics(scene, state)

        expectNoDifference(loading.screenID, .reading)
        expectNoDifference(loading.page, 4)
        expectNoDifference(loading.showsPanel, false)
        expectNoDifference(loading.blockers, ["The image of page 4 is not shown"])
        expectNoDifference(shown.readiness, .ready)
        expectNoDifference(shown.showsPanel, true)
        expectNoDifference(shown.galleryIDs, [MarketingFixtureBuilder.flowGID])
        // The reader covers everything, so the Home behind its sheet is not waited for.
        expectNoDifference(failedInASheet.screenID, .reading)
        expectNoDifference(failedInASheet.readiness, .failed)
        expectNoDifference(failedInASheet.blockers, ["The image of page 4 failed to load"])
    }

    @Test
    func aLiveTextReaderReadsAsItsScreenOnceItShowsTheRecordedGroups() async throws {
        let record = LiveTextRecordFile()
        let scene = try makeScene(
            try MarketingFixtureBuilder.standard().addingFlowPage().addingLiveTextRecord(record),
            scenarioID: CaptureScreen.readingLiveText.rawValue
        )
        let capture = try #require(scene.liveText)
        let state = try await shownReader(scene, page: MarketingFixtureBuilder.flowPage)

        let waiting = diagnostics(scene, state)
        _ = capture.decision(gid: MarketingFixtureBuilder.flowGID, page: MarketingFixtureBuilder.flowPage)
        let shown = diagnostics(scene, state)

        expectNoDifference(waiting.screenID, .reading)
        expectNoDifference(waiting.readiness, .loading)
        expectNoDifference(waiting.blockers, ["Live Text of page 1 is not shown"])
        #expect(waiting.liveText == nil)
        expectNoDifference(shown.screenID, .readingLiveText)
        expectNoDifference(shown.readiness, .ready)
        expectNoDifference(
            shown.liveText,
            CaptureLiveTextDiagnostics(
                gid: MarketingFixtureBuilder.flowGID,
                page: MarketingFixtureBuilder.flowPage,
                source: .fixture,
                recognitionLanguages: nil,
                groups: record.groups
            )
        )
    }

    @Test
    func aRecordingReportsWhatTheReadersRecognizerFound() async throws {
        let recorded = try LiveTextRecordFile().liveTextGroups()
        let found = try makeScene(
            try MarketingFixtureBuilder.standard().addingFlowPage(),
            scenarioID: CaptureScenario.liveTextRecordingID
        )
        let nothingFound = try makeScene(
            try MarketingFixtureBuilder.standard().addingFlowPage(),
            scenarioID: CaptureScenario.liveTextRecordingID
        )
        let state = try await shownReader(found, page: MarketingFixtureBuilder.flowPage)

        try #require(found.liveText).recognized(recorded, page: 1, recognitionLanguages: ["en-US"])
        try #require(nothingFound.liveText).recognized([], page: 1, recognitionLanguages: ["en-US"])
        let recognized = diagnostics(found, state)
        let empty = diagnostics(nothingFound, state)

        expectNoDifference(recognized.screenID, .readingLiveText)
        expectNoDifference(recognized.readiness, .ready)
        expectNoDifference(
            recognized.liveText,
            CaptureLiveTextDiagnostics(
                gid: MarketingFixtureBuilder.flowGID,
                page: MarketingFixtureBuilder.flowPage,
                source: .recognition,
                recognitionLanguages: ["en-US"],
                groups: recorded.map(CaptureLiveTextGroup.init)
            )
        )
        expectNoDifference(empty.readiness, .failed)
        expectNoDifference(empty.blockers, ["The reader recognized no text on page 1"])
    }

    @Test
    func liveTextOfAnotherGalleryOrPageFailsTheReader() async throws {
        let fixture = try MarketingFixtureBuilder.standard().addingFlowPage().addingLiveTextRecord(LiveTextRecordFile())
        let otherGallery = try makeScene(fixture, scenarioID: CaptureScreen.readingLiveText.rawValue)
        let otherPage = try makeScene(fixture, scenarioID: CaptureScreen.readingLiveText.rawValue)

        _ = try #require(otherGallery.liveText).decision(gid: "999", page: MarketingFixtureBuilder.flowPage)
        _ = try #require(otherPage.liveText).decision(gid: MarketingFixtureBuilder.flowGID, page: 1)
        let askedElsewhere = diagnostics(
            otherGallery,
            try await shownReader(otherGallery, page: MarketingFixtureBuilder.flowPage)
        )
        let showsAnotherPage = diagnostics(otherPage, try await shownReader(otherPage, page: 2))

        expectNoDifference(askedElsewhere.screenID, .reading)
        expectNoDifference(askedElsewhere.readiness, .failed)
        expectNoDifference(askedElsewhere.blockers, ["The reader asked for Live Text of gallery 999"])
        #expect(askedElsewhere.liveText == nil)
        expectNoDifference(showsAnotherPage.readiness, .failed)
        expectNoDifference(showsAnotherPage.blockers, ["Live Text belongs to page 1, the reader shows page 2"])
    }

    @Test
    func filtersShowTheAppDefaults() throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        var state = AppReducer.State()
        state.tabBarState.tabBarItemType = .search
        state.searchRootState.destination = .filters(FiltersReducer.State())

        let defaults = diagnostics(scene, state)
        var adjusted = FiltersReducer.State()
        adjusted.globalFilter.advanced = true
        state.searchRootState.destination = .filters(adjusted)
        let changed = diagnostics(scene, state)

        expectNoDifference(defaults.screenID, .filters)
        expectNoDifference(defaults.galleryIDs, [])
        expectNoDifference(defaults.readiness, .ready)
        expectNoDifference(changed.readiness, .failed)
        expectNoDifference(changed.blockers, ["Filters differ from the app defaults"])
    }

    @Test
    func downloadsWithoutGalleriesFail() throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        var state = AppReducer.State()
        state.tabBarState.tabBarItemType = .downloads

        let loading = diagnostics(scene, state)
        state.downloadsState.loadingState = .idle
        let empty = diagnostics(scene, state)

        expectNoDifference(loading.screenID, .downloads)
        expectNoDifference(loading.readiness, .loading)
        expectNoDifference(empty.readiness, .failed)
        expectNoDifference(empty.blockers, ["Downloads shows no galleries"])
    }

    @Test
    func theLaboratoryShowsTheNetworkBypassEnabled() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let cover = try #require(scene.replay.first(where: { $0.value.mimeType.hasPrefix("image/") })).key

        try await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = AppReducer.State()
            state.tabBarState.tabBarItemType = .setting
            state.settingState.path.append(.laboratory(.init()))
            let off = diagnostics(scene, state)
            state.settingState.$setting.withLock({ $0 = CaptureScenePreparation.sceneSetting })
            let enabled = diagnostics(scene, state)
            var sheet = try await loadedState(scene)
            sheet.presentationState.destination = .setting(.init())
            sheet.settingState = state.settingState
            let enabledInASheet = diagnostics(scene, sheet, cached: [cover])

            expectNoDifference(off.screenID, .laboratory)
            expectNoDifference(off.readiness, .failed)
            expectNoDifference(off.blockers, ["The network bypass is off"])
            expectNoDifference(enabled.readiness, .ready)
            expectNoDifference(enabledInASheet.screenID, .laboratory)
            expectNoDifference(enabledInASheet.readiness, .ready)
        }
    }

    @Test
    func anotherScreenOrAToastIsNoCaptureScreen() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let cover = try #require(scene.replay.first(where: { $0.value.mimeType.hasPrefix("image/") })).key
        var state = try await loadedState(scene)
        state.settingState.path.append(.about(.init()))
        state.tabBarState.tabBarItemType = .setting

        let about = diagnostics(scene, state)
        state.tabBarState.tabBarItemType = .home
        state.presentationState.toast = .loading()
        let toast = diagnostics(scene, state, cached: [cover])

        #expect(about.screenID == nil)
        expectNoDifference(about.readiness, .loading)
        expectNoDifference(about.blockers, ["No capture screen is shown"])
        expectNoDifference(toast.screenID, .home)
        expectNoDifference(toast.readiness, .loading)
        expectNoDifference(toast.blockers, ["A toast shows"])
    }

    @MainActor
    @Test
    func renderingNamesEachTraitAsCoordinatesDo() {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = .dark
            traits.preferredContentSizeCategory = .accessibilityMedium
            traits.userInterfaceIdiom = .pad
        }

        let rendering = CaptureRendering(traits: traits)

        expectNoDifference(rendering.appearance, .dark)
        expectNoDifference(rendering.textSize, "accessibility1")
        expectNoDifference(rendering.family, .ipad)
        expectNoDifference(rendering.language, Bundle.main.preferredLocalizations.first ?? "none")
        expectNoDifference(rendering.locale, Locale.current.identifier)
    }
}

extension CaptureRendering {
    static let lightPhone = Self(
        language: "en", locale: "en_US", appearance: .light, textSize: "large", family: .iphone
    )
    static let darkPhone = Self(
        language: "en", locale: "en_US", appearance: .dark, textSize: "large", family: .iphone
    )
}

private func diagnostics(
    _ scene: CaptureScene,
    _ state: AppReducer.State,
    rendering: CaptureRendering = .lightPhone,
    answered: Set<String> = [],
    cached: Set<String> = []
) -> CaptureDiagnostics {
    CaptureDiagnostics(
        scene: scene,
        state: state,
        rendering: rendering,
        sheetPixels: nil,
        answeredURLs: answered,
        unknownRequests: [],
        isCached: cached.contains
    )
}

/// The app state once the reader shows the image of `page` of `scene`'s flow gallery.
private func shownReader(_ scene: CaptureScene, page: Int) async throws -> AppReducer.State {
    let gallery = try await flowGallery(scene)
    var reading = ReadingReducer.State(gallery: gallery)
    reading.pendingReadingProgress = page
    reading.webImageLoadSuccessIndices = [page]
    var detail = try loadedDetail(gallery)
    detail.destination = .reading(reading)
    var state = AppReducer.State()
    state.homeState.path = StackState([.gallery(.detail(detail))])
    return state
}

/// The selection's flow gallery, as Home's card shows it.
private func flowGallery(_ scene: CaptureScene) async throws -> Gallery {
    try #require(
        try await scene.homeClient
            .fetchPopularGalleries(.ehentai, Filter())
            .first(where: { $0.gid == MarketingFixtureBuilder.flowGID })
    )
}

/// A detail of `gallery` once its page has loaded; its previews show `previewImage` when given.
private func loadedDetail(_ gallery: Gallery, previewImage: String? = nil) throws -> DetailReducer.State {
    let page = try savedPage()
    var detail = DetailReducer.State(gallery: gallery)
    detail.galleryDetail = page.detail
    detail.galleryComments = page.state.comments
    detail.galleryPreviewURLs = [:]
    if let previewImage {
        let image = try #require(URL(string: previewImage))
        detail.galleryPreviewURLs = [
            1: URLUtil.combinedPreviewURL(plainURL: image, width: "200", height: "280", offset: "0"),
            2: URLUtil.combinedPreviewURL(plainURL: image, width: "200", height: "280", offset: "200")
        ]
    }
    return detail
}

private func savedPage() throws -> (detail: GalleryDetail, state: GalleryState) {
    try Parser.parseGalleryDetail(
        doc: ScreenPages().htmlDocument(filename: .galleryDetail),
        gid: MarketingFixtureBuilder.flowGID
    )
}

private struct ScreenPages: TestHelper {}
