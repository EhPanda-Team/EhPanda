import SearchFeature
import SettingFeature
#if DEBUG
import AppModels
import Appshot
import AppshotProtocol
import AppTools
import ComposableArchitecture
import DetailFeature
import DownloadsFeature
import FiltersFeature
import Foundation
import HomeFeature
import Kingfisher
import LibraryClient
import ParserFeature
import ReadingFeature
import SwiftUI
import UIKit

/// How the app renders, as its own traits report it, with each axis named as capture
/// coordinates name it.
struct CaptureRendering: Equatable, Encodable {
    enum Appearance: String, Encodable {
        case light
        case dark
        case unspecified
    }

    enum Family: String, Encodable {
        case iphone
        case ipad
        case other
    }

    /// The localization the app resolved, such as `zh-Hant`.
    let language: String
    /// The formatting locale, such as `zh_TW`.
    let locale: String
    let appearance: Appearance
    /// The text size, such as `large`.
    let textSize: String
    let family: Family
}

/// What a capture launch shows and whether it has finished showing it, as UI tests read it.
///
/// UI tests run outside the app, so the diagnostics travel through the channel they already read:
/// the accessibility tree. ``CaptureDiagnosticsAnchor`` adds one invisible element, identified
/// ``accessibilityIdentifier``, whose value is this record as JSON. It exists only in capture
/// launches and renders nothing, so no capture shows a label of its own.
struct CaptureDiagnostics: Equatable, Encodable {
    enum Readiness: String, Encodable {
        /// The screen is still loading its content or images.
        case loading
        /// The screen shows all of its content and every image it requested.
        case ready
        /// The screen can never finish: a load failed, the replay refused a request or the screen
        /// shows something other than its configured state.
        case failed
    }

    static let accessibilityIdentifier = "capture_diagnostics"

    /// The screen a person sees, or `nil` when it is no capture screen.
    let screenID: CaptureScreen?
    let selectionID: String
    /// The selection set the scene shows, such as `nonexplicit`.
    let setID: String
    let fixtureVersion: String
    /// The galleries the screen shows, in display order.
    let galleryIDs: [String]
    /// The reader page the screen shows; `nil` outside the reader.
    let page: Int?
    /// Whether the reader shows its control panel; `nil` outside the reader.
    let showsPanel: Bool?
    let readiness: Readiness
    /// Images the replay delivered that no image cache holds yet.
    let pendingImages: Int
    /// Requests the replay refused, as `METHOD URL` in arrival order.
    let unknownRequests: [String]
    /// What the screen still waits for, and what makes it fail; empty once it is ready.
    let blockers: [String]
    let rendering: CaptureRendering
    /// The Live Text the reader shows on the capture's Live Text page; `nil` until it shows any,
    /// and in launches without Live Text.
    let liveText: CaptureLiveTextDiagnostics?
    /// The rows the Downloads screen lists, in order; `nil` on every other screen.
    let downloads: [CaptureDownloadDiagnostics]?
    /// The screenshot pixels of the sheet the screen shows in; `nil` unless a sheet is on top. A
    /// native capture compares the cold launches of a sheet only within it, as the dimmed screen
    /// around it is not what the capture shows (owner decision, 2026-10-13).
    let sheetPixels: CapturePixelRect?

    func encodedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let json = String(bytes: try encoder.encode(self), encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "not UTF-8"))
        }
        return json
    }
}

extension CaptureDiagnostics {
    /// The diagnostics of `state` in a launch of `scene`, rendered as `rendering` describes, with
    /// the top sheet where UIKit shows it, as `sheetPixels`.
    ///
    /// The screen comes from the app's navigation state, never from the configuration, so a
    /// route that lands elsewhere reads as that other screen. It is ready once its content has
    /// arrived, every image it must show is cached, no delivered image waits for the cache and
    /// nothing failed. A sheet that leaves its tab visible around it also waits for that tab.
    init(
        scene: CaptureScene,
        state: AppReducer.State,
        rendering: CaptureRendering,
        sheetPixels: CapturePixelRect?,
        answeredURLs: Set<String>,
        unknownRequests: [String],
        isCached: @escaping (String) -> Bool
    ) {
        // The image views cache an image under the app's stable key for its URL, such as a
        // preview's, or under the URL itself; either one holds it. A local file, such as a
        // downloaded cover, is cached under Kingfisher's key for its path.
        let holdsImage: (String) -> Bool = { url in
            guard let imageURL = URL(string: url) else {
                return isCached(url)
            }
            return (imageURL.imageCacheKeys + [imageURL.cacheKey]).contains(where: isCached)
        }
        let pendingImages = answeredURLs.count(where: { url in
            scene.replay[url]?.mimeType.hasPrefix("image/") == true && !holdsImage(url)
        })
        let shown = ShownScreens(state: state)
        // Read once, so the screen, its readiness and the reported groups agree.
        let liveText = scene.liveText.map({ ReaderLiveText(capture: $0, outcome: $0.outcome) })
        let inspector = ScreenInspector(
            replay: scene.replay,
            rendering: rendering,
            liveText: liveText,
            holdsImage: holdsImage
        )
        var report = shown.top.map(inspector.report) ?? ScreenReport(blockers: ["No capture screen is shown"])
        if let backdrop = shown.backdrop {
            let around = inspector.report(backdrop)
            report.blockers += around.blockers.map({ "Around the sheet: \($0)" })
            report.failures += around.failures.map({ "Around the sheet: \($0)" })
        }
        if state.presentationState.toast != nil {
            report.blockers.append("A toast shows")
        }
        if pendingImages > 0 {
            report.blockers.append("\(pendingImages) delivered images are not cached yet")
        }

        let readiness: Readiness
        if !unknownRequests.isEmpty || !report.failures.isEmpty {
            readiness = .failed
        } else if report.blockers.isEmpty {
            readiness = .ready
        } else {
            readiness = .loading
        }
        self.init(
            screenID: shown.top?.id(liveText: liveText),
            selectionID: scene.selectionID,
            setID: scene.configuration.fixtureID,
            fixtureVersion: scene.fixtureVersion,
            galleryIDs: report.galleryIDs,
            page: report.page,
            showsPanel: report.showsPanel,
            readiness: readiness,
            pendingImages: pendingImages,
            unknownRequests: unknownRequests,
            blockers: report.failures + report.blockers,
            rendering: rendering,
            liveText: liveText.flatMap({ CaptureLiveTextDiagnostics(capture: $0.capture, outcome: $0.outcome) }),
            downloads: report.downloads,
            sheetPixels: sheetPixels
        )
    }
}

/// A rectangle of a screenshot, in whole pixels from its top-left corner.
struct CapturePixelRect: Equatable, Encodable {
    let left: Int
    let top: Int
    let width: Int
    let height: Int
}

extension CapturePixelRect {
    /// Every pixel `rect` covers, even in part, on a screen with `scale` pixels to the point.
    init(points rect: CGRect, scale: CGFloat) {
        let pixels = rect.applying(CGAffineTransform(scaleX: scale, y: scale)).integral
        self.init(left: Int(pixels.minX), top: Int(pixels.minY), width: Int(pixels.width), height: Int(pixels.height))
    }
}

extension CaptureRendering {
    /// The rendering `traits` describe, in the app's resolved localization and current locale.
    init(traits: UITraitCollection) {
        self.init(
            language: Bundle.main.preferredLocalizations.first ?? "none",
            locale: Locale.current.identifier,
            appearance: Appearance(traits.userInterfaceStyle),
            textSize: Self.textSize(traits.preferredContentSizeCategory),
            family: Family(traits.userInterfaceIdiom)
        )
    }

    private static func textSize(_ category: UIContentSizeCategory) -> String {
        switch category {
        case .extraSmall:
            "xSmall"
        case .small:
            "small"
        case .medium:
            "medium"
        case .large:
            "large"
        case .extraLarge:
            "xLarge"
        case .extraExtraLarge:
            "xxLarge"
        case .extraExtraExtraLarge:
            "xxxLarge"
        case .accessibilityMedium:
            "accessibility1"
        case .accessibilityLarge:
            "accessibility2"
        case .accessibilityExtraLarge:
            "accessibility3"
        case .accessibilityExtraExtraLarge:
            "accessibility4"
        case .accessibilityExtraExtraExtraLarge:
            "accessibility5"
        default:
            category.rawValue
        }
    }
}

extension CaptureRendering.Appearance {
    init(_ style: UIUserInterfaceStyle) {
        switch style {
        case .light:
            self = .light
        case .dark:
            self = .dark
        case .unspecified:
            self = .unspecified
        @unknown default:
            self = .unspecified
        }
    }
}

extension CaptureRendering.Family {
    init(_ idiom: UIUserInterfaceIdiom) {
        switch idiom {
        case .phone:
            self = .iphone
        case .pad:
            self = .ipad
        default:
            self = .other
        }
    }
}

/// A row the Downloads screen lists, as the diagnostics report it.
struct CaptureDownloadDiagnostics: Equatable, Encodable {
    let gid: String
    let status: CaptureSelection.DownloadStatus
    /// The pages the row's badge counts as downloaded.
    let completedPages: Int
    let pageCount: Int
    /// The page files the gallery's folder holds.
    let pageFiles: Int
}

extension CaptureDownloadDiagnostics {
    init(_ download: DownloadedGallery) {
        self.init(
            gid: download.gid,
            status: .init(download.displayStatus),
            completedPages: download.badge.progress.completedPageCount,
            pageCount: download.badge.progress.pageCount,
            pageFiles: download.localPageURLs.count
        )
    }
}

extension CaptureSelection.DownloadStatus {
    /// The selection's name for `status`.
    init(_ status: DownloadDisplayStatus) {
        self = switch status {
        case .active:
            .active
        case .queued:
            .queued
        case .updateAvailable:
            .updateAvailable
        case .error:
            .error
        case .inactive:
            .inactive
        case .completed:
            .completed
        }
    }
}

// MARK: Screens

/// A capture screen, as the app state holds it.
private enum ShownScreen {
    case home(HomeReducer.State)
    case detail(DetailReducer.State)
    case comments(CommentsReducer.State)
    case reading(ReadingReducer.State)
    case filters(FiltersReducer.State)
    case downloads(DownloadsReducer.State)
    case laboratory(Setting)

    /// The screen's ID, given the Live Text the capture's reader page shows.
    ///
    /// A reader reads as `reading-live-text` once it shows the capture's Live Text, the fixture's
    /// groups or its own recognition's; until then, and in launches without Live Text, it reads as
    /// `reading`.
    func id(liveText: ReaderLiveText?) -> CaptureScreen {
        switch self {
        case .home:
            .home
        case .detail:
            .detail
        case .comments:
            .comments
        case .reading:
            liveText?.isShown == true ? .readingLiveText : .reading
        case .filters:
            .filters
        case .downloads:
            .downloads
        case .laboratory:
            .laboratory
        }
    }

    /// Whether the screen covers everything beneath it, as the reader's full-screen cover does.
    var coversEverything: Bool {
        switch self {
        case .reading:
            true
        case .home, .detail, .comments, .filters, .downloads, .laboratory:
            false
        }
    }
}

/// The capture screen on top of the navigation, and the tab root a sheet leaves visible around it.
private struct ShownScreens {
    let top: ShownScreen?
    let backdrop: ShownScreen?

    init(state: AppReducer.State) {
        let presentation = state.presentationState
        if let detail = presentation.detail {
            // The modal detail roots its own gallery stack.
            let top = Self.screen(for: presentation.path.last ?? .detail(detail))
            self.init(top: top, backdrop: top?.coversEverything == true ? nil : Self.tabRoot(of: state))
        } else if let destination = presentation.destination {
            // Of the app's sheets, only Setting hosts a capture screen.
            let top = destination.is(\.setting) ? Self.settingScreen(of: state) : nil
            self.init(top: top, backdrop: Self.tabRoot(of: state))
        } else {
            self.init(top: Self.tabScreen(of: state), backdrop: nil)
        }
    }

    private init(top: ShownScreen?, backdrop: ShownScreen?) {
        self.top = top
        self.backdrop = backdrop
    }

    private static func tabScreen(of state: AppReducer.State) -> ShownScreen? {
        switch state.tabBarState.tabBarItemType {
        case .home:
            guard let element = state.homeState.path.last else {
                return .home(state.homeState)
            }
            return element.gallery.flatMap(screen(for:))
        case .search:
            guard state.searchRootState.path.isEmpty, let filters = state.searchRootState.destination?.filters
            else {
                return nil
            }
            return .filters(filters)
        case .downloads:
            guard state.downloadsState.path.isEmpty, state.downloadsState.destination == nil else {
                return nil
            }
            return .downloads(state.downloadsState)
        case .setting:
            return settingScreen(of: state)
        case .favorites:
            return nil
        }
    }

    /// The selected tab's root, when it is a capture screen with nothing pushed over it.
    private static func tabRoot(of state: AppReducer.State) -> ShownScreen? {
        switch state.tabBarState.tabBarItemType {
        case .home:
            state.homeState.path.isEmpty ? .home(state.homeState) : nil
        case .downloads:
            state.downloadsState.path.isEmpty ? .downloads(state.downloadsState) : nil
        case .favorites, .search, .setting:
            nil
        }
    }

    private static func settingScreen(of state: AppReducer.State) -> ShownScreen? {
        state.settingState.path.last?.is(\.laboratory) == true ? .laboratory(state.settingState.setting) : nil
    }

    private static func screen(for element: GalleryPath.State) -> ShownScreen? {
        switch element {
        case .detail(let detail):
            // The reader covers the detail that presents it.
            detail.destination?.reading.map(ShownScreen.reading) ?? .detail(detail)
        case .comments(let comments):
            .comments(comments)
        case .previews, .detailSearch, .galleryInfos:
            nil
        }
    }
}

// MARK: Readiness

/// What the reader did with the capture's Live Text page, as one diagnostics read sees it.
private struct ReaderLiveText {
    let capture: LiveTextCapture
    let outcome: LiveTextCapture.Outcome?

    /// Whether the page shows the capture's groups or the reader's recognition of it.
    var isShown: Bool {
        switch outcome {
        case .replayed, .recognized:
            true
        case .otherGallery, nil:
            false
        }
    }
}

/// What one screen shows, what it still waits for and what makes it fail.
private struct ScreenReport {
    var galleryIDs = [String]()
    var page: Int?
    var showsPanel: Bool?
    var downloads: [CaptureDownloadDiagnostics]?
    var blockers = [String]()
    var failures = [String]()
}

private struct ScreenInspector {
    let replay: [String: CaptureReplay.Response]
    let rendering: CaptureRendering
    let liveText: ReaderLiveText?
    let holdsImage: (String) -> Bool

    func report(_ screen: ShownScreen) -> ScreenReport {
        switch screen {
        case .home(let home):
            homeReport(home)
        case .detail(let detail):
            detailReport(detail)
        case .comments(let comments):
            commentsReport(comments)
        case .reading(let reading):
            readingReport(reading)
        case .filters(let filters):
            filtersReport(filters)
        case .downloads(let downloads):
            downloadsReport(downloads)
        case .laboratory(let setting):
            laboratoryReport(setting)
        }
    }

    /// Home waits for all of its lists and for the current card's cover: the current card is
    /// always on screen, so its cover proves the first render requested every visible image;
    /// without it, the moment between the lists arriving and their covers being requested would
    /// read as ready. In dark appearance the card's gradient shows its cover's colors, so the card
    /// also waits for their analysis.
    private func homeReport(_ home: HomeReducer.State) -> ScreenReport {
        let toplists = ToplistsType.allCases.map({ home.toplistsGalleries[$0.categoryIndex] ?? [] })
        let lists = [home.popularGalleries, home.frontpageGalleries] + toplists
        let loadingStates = [home.popularLoadingState, home.frontpageLoadingState]
            + ToplistsType.allCases.compactMap({ home.toplistsLoadingState[$0.categoryIndex] })
        var report = ScreenReport(galleryIDs: lists.flatMap({ $0.map(\.gid) }))
        if loadingStates.contains(where: Self.isFailure) {
            report.failures.append("A Home list failed to load")
        }
        if lists.contains(where: \.isEmpty) || loadingStates.contains(.loading) {
            report.blockers.append("Home lists are loading")
        }
        let currentCard = home.popularGalleries.first(where: { $0.gid == home.currentCardID })
        if !shows(currentCard?.coverURL) {
            report.blockers.append("The current card's cover is not shown")
        }
        if rendering.appearance == .dark, !home.rawCardColors.keys.contains(home.currentCardID) {
            report.blockers.append("The current card's colors are not analyzed")
        }
        return report
    }

    /// Detail waits for its detail, its cover and every preview the fixture holds: the previews
    /// render once the detail arrives, after the cover was already requested.
    private func detailReport(_ detail: DetailReducer.State) -> ScreenReport {
        var report = ScreenReport(galleryIDs: [detail.gallery.gid])
        if Self.isFailure(detail.loadingState) {
            report.failures.append("The detail failed to load")
        }
        if detail.galleryDetail == nil {
            report.blockers.append("The detail is loading")
        }
        if !shows(detail.gallery.coverURL) {
            report.blockers.append("The cover is not shown")
        }
        // A combined preview names its image and the region it shows of it.
        let previewImages = Set(detail.galleryPreviewURLs.values.map({ url in
            Parser.parsePreviewConfigs(url: url)?.plainURL ?? url
        }))
        let pendingPreviews = previewImages.filter({ replay[$0.absoluteString] != nil && !shows($0) })
        if !pendingPreviews.isEmpty {
            report.blockers.append("\(pendingPreviews.count) preview images are not shown")
        }
        return report
    }

    /// Comments are readable at once: the detail hands them over loaded. They show from the top,
    /// with no comment highlighted.
    private func commentsReport(_ comments: CommentsReducer.State) -> ScreenReport {
        var report = ScreenReport(galleryIDs: [comments.gid])
        if comments.comments.isEmpty {
            report.failures.append("The gallery shows no comments")
        }
        if comments.scrollCommentID != nil {
            report.failures.append("A comment is highlighted")
        }
        return report
    }

    /// The reader waits until it shows its current page's image and, in a launch with Live Text,
    /// that page's Live Text. Live Text the reader asked for on another gallery, on a page other
    /// than the one it shows, or a recognition that found no text fails.
    private func readingReport(_ reading: ReadingReducer.State) -> ScreenReport {
        let page = reading.pendingReadingProgress
        var report = ScreenReport(galleryIDs: [reading.gallery.gid], page: page, showsPanel: reading.showsPanel)
        if let loadingState = reading.imageURLLoadingStates[page], Self.isFailure(loadingState) {
            report.failures.append("The image of page \(page) failed to load")
        }
        if !reading.webImageLoadSuccessIndices.contains(page) {
            report.blockers.append("The image of page \(page) is not shown")
        }
        guard let liveText else {
            return report
        }
        let liveTextPage = liveText.capture.page
        switch liveText.outcome {
        case nil:
            report.blockers.append("Live Text of page \(liveTextPage) is not shown")
        case .otherGallery(let gid):
            report.failures.append("The reader asked for Live Text of gallery \(gid)")
        case .replayed, .recognized:
            if liveTextPage != page {
                report.failures.append("Live Text belongs to page \(liveTextPage), the reader shows page \(page)")
            }
        }
        if case .recognized(let groups, _) = liveText.outcome, groups.isEmpty {
            report.failures.append("The reader recognized no text on page \(liveTextPage)")
        }
        return report
    }

    /// Filters show the app's defaults, from the first filter range.
    private func filtersReport(_ filters: FiltersReducer.State) -> ScreenReport {
        var report = ScreenReport()
        let shown = [filters.searchFilter, filters.globalFilter, filters.watchedFilter]
        if filters.filterRange != FiltersReducer.State().filterRange || shown.contains(where: { $0 != Filter() }) {
            report.failures.append("Filters differ from the app defaults")
        }
        return report
    }

    /// Downloads waits for its rows and every row's cover, which a seeded folder holds. The install
    /// preloads each cover into the image cache, so a row shows it on its first render, even a row
    /// the list renders only once scrolled to; the check proves the preload.
    private func downloadsReport(_ downloads: DownloadsReducer.State) -> ScreenReport {
        var report = ScreenReport(
            galleryIDs: downloads.downloads.map(\.gid),
            downloads: downloads.downloads.map(CaptureDownloadDiagnostics.init)
        )
        switch downloads.loadingState {
        case .loading:
            report.blockers.append("Downloads are loading")
        case .failed:
            report.failures.append("Downloads failed to load")
        case .idle:
            if downloads.downloads.isEmpty {
                report.failures.append("Downloads shows no galleries")
            }
        }
        let pendingCovers = downloads.downloads.count(where: { !shows($0.coverURL) })
        if pendingCovers > 0 {
            report.blockers.append("\(pendingCovers) download covers are not shown")
        }
        return report
    }

    private func laboratoryReport(_ setting: Setting) -> ScreenReport {
        var report = ScreenReport()
        if !setting.bypassSNIFiltering {
            report.failures.append("The network bypass is off")
        }
        return report
    }

    private func shows(_ url: URL?) -> Bool {
        url.map({ holdsImage($0.absoluteString) }) ?? false
    }

    private static func isFailure(_ state: LoadingState) -> Bool {
        guard case .failed = state else {
            return false
        }
        return true
    }
}

// MARK: Anchor

/// The invisible element that carries ``CaptureDiagnostics`` to UI tests.
struct CaptureDiagnosticsAnchor: UIViewRepresentable {
    let store: StoreOf<AppReducer>
    let capture: InstalledCapture

    func makeUIView(context: Self.Context) -> CaptureDiagnosticsElement {
        CaptureDiagnosticsElement(store: store, capture: capture, scene: AppshotCapture.launchedScene)
    }

    func updateUIView(_ uiView: CaptureDiagnosticsElement, context: Self.Context) {}
}

/// Computes its accessibility value each time a test reads it, from the store, the replay, the
/// image caches and its own traits, so the value is never stale and the app needs no observation or
/// timer for it.
final class CaptureDiagnosticsElement: UIView {
    private let store: StoreOf<AppReducer>
    private let capture: InstalledCapture
    @Dependency(\.libraryClient) private var libraryClient

    init(
        store: StoreOf<AppReducer>,
        capture: InstalledCapture,
        scene: AppshotProtocol.CaptureScene? = nil
    ) {
        self.store = store
        self.capture = capture
        super.init(frame: .zero)
        isAccessibilityElement = true
        isUserInteractionEnabled = false
        accessibilityIdentifier = CaptureDiagnostics.accessibilityIdentifier
        if let scene {
            isAccessibilityElement = false
            let element = AppshotStateView(scene: scene) { [weak self] in
                guard let self else {
                    return ScreenState(screen: "unknown", failures: ["The app diagnostics element disappeared"])
                }
                return diagnostics.appshotState
            }
            element.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            addSubview(element)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    private var diagnostics: CaptureDiagnostics {
        CaptureDiagnostics(
            scene: capture.scene,
            state: store.state,
            rendering: .init(traits: traitCollection),
            sheetPixels: topSheetPixels,
            answeredURLs: capture.replay.answeredURLs,
            unknownRequests: capture.replay.unknownRequestDescriptions,
            isCached: libraryClient.isCached
        )
    }

    override var accessibilityValue: String? {
        get {
            do {
                return try diagnostics.encodedJSON()
            } catch {
                // A test that cannot decode the value fails and reports this text.
                return "Capture diagnostics cannot be encoded: \(error)"
            }
        }
        // The value is derived on every read; there is nothing to store.
        set {}
    }

    /// Where the screen shows the top of the window's presentations, when that is a sheet. A cover
    /// over a sheet, such as the reader's over the detail, is no sheet, and hides the one beneath.
    private var topSheetPixels: CapturePixelRect? {
        guard var top = window?.rootViewController?.presentedViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        guard top.presentationController is UISheetPresentationController,
              let sheet = top.viewIfLoaded,
              let screen = window?.windowScene?.screen
        else {
            return nil
        }
        return CapturePixelRect(
            points: sheet.convert(sheet.bounds, to: screen.coordinateSpace),
            scale: traitCollection.displayScale
        )
    }
}
#endif
