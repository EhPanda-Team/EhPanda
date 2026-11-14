@testable import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import ReadingFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

// The detail pages, Comments, the Report form and the Reader (19-07).
extension ScenarioCatalog {
    static var gallery: [String: ScenarioFactory] {
        [comments, reportForm, detailPages, reader].reduce(into: [:]) { result, group in
            result.merge(group) { first, _ in first }
        }
    }

    private static var comments: [String: ScenarioFactory] {
        typealias Page = GalleryScenarios
        return [
            "comments-list": .init(make: { try Page.comments(.list) }),
            "comments-menu": .init(make: { try Page.comments(.list) }, interact: Page.openFirstRowMenu),
            "comments-block-confirmation": .init(
                make: { try TracerScenarios.comments() }, interact: TracerScenarios.chooseBlock
            ),
            "comments-blocked-row-collapsed": .init(make: { try Page.comments(.blocked) }),
            "comments-blocked-row-shown": .init(make: { try Page.comments(.blockedShown) }),
            "comments-post-empty": .init(
                make: { try Page.comments(.postEmpty) }, interact: Page.holdStillOverKeyboard
            ),
            "comments-post-filled": .init(
                make: { try Page.comments(.postFilled) }, interact: Page.holdStillOverKeyboard
            ),
            "comments-posting-warning": .init(
                make: { try Page.comments(.postingWarning) }, interact: Page.holdStillOverKeyboard
            )
        ]
    }

    private static var reportForm: [String: ScenarioFactory] {
        typealias Page = GalleryScenarios
        return [
            "report-form-loading": .init(make: { try Page.reportForm(.loading) }, interact: Page.holdStill),
            "report-form-ready": .init(make: { try Page.reportForm(.ready) }),
            "report-form-filled": .init(make: { try Page.reportForm(.filled) }),
            "report-form-sending": .init(make: { try Page.reportForm(.sending) }, interact: Page.holdStill),
            "report-form-sent": .init(make: { try Page.reportForm(.sent) }),
            "report-form-unavailable": .init(make: { try Page.reportForm(.unavailable) }),
            "report-form-error-alert": .init(make: { try Page.reportForm(.errorAlert) })
        ]
    }

    private static var detailPages: [String: ScenarioFactory] {
        typealias Page = GalleryScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "detail-pages-previews": .init(
                make: { try Page.previews(loaded: true) }, prepare: Page.cachePreviewArtwork
            ),
            "detail-pages-previews-loading": .init(
                make: { try Page.previews(loaded: false) }, prepare: artwork, interact: Page.holdStill
            ),
            "detail-pages-gallery-info": .init(make: { try Page.galleryInfo() }),
            "detail-pages-detail-search-list": .init(
                make: { Page.detailSearch(.loaded(.row)) }, prepare: artwork
            ),
            "detail-pages-detail-search-grid": .init(
                make: { Page.detailSearch(.loaded(.grid)) }, prepare: artwork
            ),
            "detail-pages-archives": .init(make: { try Page.archives(lowFunds: false) }, prepare: artwork),
            // At accessibility5 the balances are below the fold (run 43403534542): the sheet is scrolled to them.
            "detail-pages-archives-insufficient-funds": .init(
                make: { try Page.archives(lowFunds: true) }, prepare: artwork,
                interact: RevealStep.reveal(.label(Page.lowGalleryPointsLabel))
            ),
            "detail-pages-torrents": .init(make: { try Page.torrents(empty: false) }, prepare: artwork),
            "detail-pages-torrents-empty": .init(make: { try Page.torrents(empty: true) }, prepare: artwork),
            "detail-pages-tag-detail": .init(make: { try Page.tagDetail() }, prepare: Page.cacheTagArtwork),
            "detail-pages-new-dawn": .init(make: { try Page.newDawn() }, prepare: artwork),
            "detail-pages-folder-manager": .init(make: { try Page.folderManager(confirmingDelete: false) },
                                                 prepare: artwork),
            "detail-pages-folder-delete-confirmation": .init(
                make: { try Page.folderManager(confirmingDelete: true) }, prepare: artwork
            )
        ]
    }

    private static var reader: [String: ScenarioFactory] {
        typealias Page = GalleryScenarios
        let pages = Page.prepareReaderPages
        return [
            "reader-vertical": .init(make: { try Page.reader(.vertical) }, prepare: pages),
            "reader-horizontal": .init(make: { try Page.reader(.horizontal) }, prepare: pages),
            "reader-two-page-spread": .init(make: { try Page.reader(.spread) }, prepare: pages),
            "reader-controls": .init(make: { try Page.reader(.controls) }, prepare: pages),
            "reader-slider-scrub": .init(make: { try Page.reader(.scrub) }, prepare: pages),
            "reader-page-failed": .init(make: { try Page.reader(.pageFailed) }, prepare: pages),
            "reader-loading": .init(
                make: { try Page.reader(.loading) }, prepare: pages, interact: Page.holdStill
            ),
            "reader-live-text": .init(make: { try Page.reader(.liveText) }, prepare: Page.prepareLiveText),
            "reader-settings-sheet": .init(make: { try Page.reader(.settings) }, prepare: pages)
        ]
    }
}

@MainActor
enum GalleryScenarios {
    // MARK: Comments

    /// The synthetic gallery's page. Its token is letters and digits, as the site's are, so the gallery has a report
    /// target and a comment's menu offers Report as well as Block.
    static let galleryURL = URL(string: "https://e-hentai.org/g/1/visualtoken/")

    enum CommentsState {
        case list, blocked, blockedShown, postEmpty, postFilled, postingWarning
    }

    /// The synthetic comments on the real `CommentsView` and `CommentsReducer`. A blocked author is matched by member
    /// ID (owner msg 1918); the editor and its posting warning are the reducer's own: Post Comment is presented
    /// through its action, and the warning comes from Post over a draft that the scenario's filter list matches.
    static func comments(_ kind: CommentsState) throws -> AnyView {
        let url = try XCTUnwrap(galleryURL)
        let comments = TracerScenarios.commentFixtures()
        var state = CommentsReducer.State(gid: "1", token: "visualtoken", galleryURL: url, comments: comments)
        state.moderation.$blockedUsers.withLock { users in
            users = []
            if kind == .blocked || kind == .blockedShown {
                users.block(memberID: GalleryFixtures.blockedMemberID, name: GalleryFixtures.blockedMemberName)
            }
        }
        if kind == .blockedShown, let first = comments.first {
            state.moderation.revealedCommentIDs.insert(first.commentID)
        }
        let store = Store(initialState: state, reducer: CommentsReducer.init) {
            $0.commentFilterTerms = CommentFilterTerms(groups: ["visual": [GalleryFixtures.filteredTerm]])
        }
        switch kind {
        case .postEmpty:
            store.send(.presentPostComment(commentID: ""))
        case .postFilled:
            store.send(.presentPostComment(commentID: ""))
            store.send(.binding(.set(\.commentContent, GalleryFixtures.commentDraft)))
        case .postingWarning:
            store.send(.presentPostComment(commentID: ""))
            store.send(.binding(.set(\.commentContent, GalleryFixtures.filteredDraft)))
            store.send(.postTapped)
        case .list, .blocked, .blockedShown:
            break
        }
        return AnyView(NavigationStack {
            CommentsView(
                store: store, gid: "1", token: "visualtoken", apiKey: "", galleryURL: url, comments: comments
            )
        })
    }

    // MARK: Report form

    enum ReportFormState {
        case loading, ready, filled, sending, sent, unavailable, errorAlert
    }

    /// The Report form for the first synthetic comment, as Comments presents it from the comment's Report. Its phase
    /// and fields are the form reducer's own state; the failed alert is the reducer's own. The site is never asked:
    /// the form's load waits for good, which is the loading state, and nothing sends.
    static func reportForm(_ kind: ReportFormState) throws -> AnyView {
        let url = try XCTUnwrap(galleryURL)
        let comments = TracerScenarios.commentFixtures()
        let comment = try XCTUnwrap(comments.first)
        var form = try XCTUnwrap(ReportFormFeature.State(comment: comment, galleryURL: url))
        switch kind {
        case .loading:
            form.phase = .loading
            form.showsSpinner = true
        case .ready:
            form.phase = .ready
        case .filled, .sending, .errorAlert:
            form.phase = kind == .sending ? .sending : .ready
            form.reason = .child
            form.email = GalleryFixtures.reportEmail
            form.details = form.prefill + "\n\n" + GalleryFixtures.reportDetails
            if kind == .errorAlert {
                form.presentFailedAlert()
            }
        case .sent:
            form.phase = .sent
            form.reason = .child
            form.email = GalleryFixtures.reportEmail
            form.details = form.prefill + "\n\n" + GalleryFixtures.reportDetails
        case .unavailable:
            form.phase = .unavailable
        }
        var state = CommentsReducer.State(gid: "1", token: "visualtoken", galleryURL: url, comments: comments)
        state.moderation.$blockedUsers.withLock({ $0 = [] })
        state.destination = .reportForm(form)
        let store = Store(initialState: state, reducer: CommentsReducer.init) {
            $0.reportFormClient.load = { _ in
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            }
            $0.reportFormClient.send = { _, _, _, _ in
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            }
        }
        return AnyView(NavigationStack {
            CommentsView(
                store: store, gid: "1", token: "visualtoken", apiKey: "", galleryURL: url, comments: comments
            )
        })
    }

    // MARK: User steps

    /// Lets a sheet, its focus and any alert over it finish presenting, then holds the caret and any spinner still:
    /// the layer clock of the hosted view and of every controller presented over it is stopped. Every attempt hosts
    /// a fresh controller, so no clock stays stopped. The keyboard is a separate window and is not drawn.
    static func holdStill(_ window: UIWindow) async throws {
        try await ContinuousClock().sleep(for: .milliseconds(1500))
        try freeze(window)
    }

    private static func freeze(_ window: UIWindow) throws {
        var controller = try XCTUnwrap(window.rootViewController)
        while true {
            controller.view.layer.speed = 0
            controller.view.layer.timeOffset = 0
            guard let presented = controller.presentedViewController else { return }
            controller = presented
        }
    }

    /// Post Comment's step: once its editor's keyboard is up and the window has come to rest
    /// twice in a row, the caret is drawn solid (``BrowsingScenarios/stopCaretBlink(in:)``) and the page is held
    /// still as in ``holdStill(_:)``; a step that has not got there by ``keyboardDeadline`` fails, and the capture
    /// retries it.
    ///
    /// The fixed 1.5 s of ``holdStill(_:)`` was not always enough for the keyboard on the hosted runner. The
    /// keyboard shrinks the posting warning to fit above it and scrolls the editor's text to the caret, and run
    /// 43451019962 held what came before it: the warning half presented (iPhone ja and zh-Hant accessibility5), the
    /// filled draft scrolled and clipped (iPhone zh-Hant accessibility5 landscape), the iPad sheet in another place.
    /// The 1.5 s stays as the shortest wait, so what a picture held after it is unchanged.
    static func holdStillOverKeyboard(_ window: UIWindow) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: keyboardDeadline)
        try await clock.sleep(for: .milliseconds(1500))
        var held = 0
        while held < 2 {
            let focused = focusedEditor(in: window) != nil
            guard clock.now < deadline else {
                throw BrowsingScenarios.StepFailure(reason: focused ? "no-keyboard" : "editor-not-focused")
            }
            held = keyboardIsUp(over: window) ? held + 1 : 0
            try await clock.sleep(for: .milliseconds(300))
            try await BrowsingScenarios.waitForRest(window)
        }
        BrowsingScenarios.stopCaretBlink(in: window)
        try freeze(window)
    }

    /// How long ``holdStillOverKeyboard(_:)`` may take before it fails the attempt with `interaction`.
    static let keyboardDeadline: Duration = .seconds(30)

    /// The text view or field that holds the focus in `view`, if any.
    static func focusedEditor(in view: UIView) -> UIView? {
        if view is UITextView || view is UITextField, view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = focusedEditor(in: subview) { return found }
        }
        return nil
    }

    /// Whether the keyboard covers the bottom of `window`'s screen, as UIKit last announced its frame
    /// (``KeyboardWatch``).
    static func keyboardIsUp(over window: UIWindow) -> Bool {
        KeyboardWatch.start()
        let frame = KeyboardWatch.frame
        return frame.height > 0 && frame.minY < window.screen.bounds.maxY - 1
    }

    /// Opens the first comment's `…` moderation menu, as a tap on it does. The button is hidden from VoiceOver (its
    /// items are the row's own actions), so it is found as the first menu control of the list.
    static func openFirstRowMenu(_ window: UIWindow) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            if let control = menuControls(in: root).min(by: {
                $0.convert($0.bounds, to: nil).minY < $1.convert($1.bounds, to: nil).minY
            }) {
                control.performPrimaryAction()
                return
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("comment menu") }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    private static func menuControls(in view: UIView) -> [UIControl] {
        if view.isHidden || view is UINavigationBar { return [] }
        var found: [UIControl] = []
        if let control = view as? UIControl,
           control.showsMenuAsPrimaryAction || control.isContextMenuInteractionEnabled {
            found.append(control)
        }
        return found + view.subviews.flatMap(menuControls(in:))
    }
}

// MARK: - Detail pages

@MainActor
extension GalleryScenarios {
    /// The synthetic preview of `page`. Its key is the one the preview image reads from Kingfisher's cache.
    static func previewURL(_ page: Int) -> URL? {
        URL(string: "https://visual-fixture.invalid/previews/\(page).png")
    }

    static func cachePreviewArtwork() async throws {
        let gallery = try XCTUnwrap(TracerScenarios.homeGalleries().first)
        for page in 1...gallery.pageCount {
            guard let url = previewURL(page) else { continue }
            let image = PublicVisualFixtures.artwork(marker: "VP\(page)", colorIndex: (page - 1) % 6)
            try await TracerScenarios.cacheArtwork(image, forKey: url.stableImageCacheKey ?? url.absoluteString)
        }
    }

    /// The Previews page of the first synthetic gallery: every page's preview, or none yet, as while they load.
    static func previews(loaded: Bool) throws -> AnyView {
        let gallery = try XCTUnwrap(TracerScenarios.homeGalleries().first)
        var state = PreviewsReducer.State(gallery: gallery)
        if loaded {
            state.previewURLs = Dictionary(uniqueKeysWithValues: (1...gallery.pageCount).compactMap { page in
                previewURL(page).map({ (page, $0) })
            })
        } else {
            state.loadingState = .loading
        }
        return AnyView(NavigationStack {
            PreviewsView(store: Store(initialState: state, reducer: PreviewsReducer.init))
        })
    }

    /// The first synthetic gallery with a page on the site, which the archives, the torrents and the gallery's
    /// information read.
    static func pageGallery() throws -> Gallery {
        let base = try XCTUnwrap(TracerScenarios.homeGalleries().first)
        return Gallery(
            gid: base.gid, token: base.token, title: base.title, rating: base.rating, tags: [],
            category: base.category, uploader: base.uploader, pageCount: base.pageCount, postedDate: base.postedDate,
            coverURL: base.coverURL, galleryURL: galleryURL
        )
    }

    /// The gallery's detail with invented counts, an archive page and the synthetic torrents.
    static func pageDetail(_ gallery: Gallery) -> GalleryDetail {
        GalleryDetail(
            gid: gallery.gid, title: gallery.title, isFavorited: false, visibility: .yes, rating: gallery.rating,
            userRating: 0, ratingCount: 120, category: gallery.category, language: .english,
            uploader: gallery.uploader ?? "", postedDate: gallery.postedDate, coverURL: gallery.coverURL,
            archiveURL: URL(string: "https://e-hentai.org/archiver.php?gid=1&token=visualtoken"),
            favoritedCount: 42, pageCount: gallery.pageCount, sizeCount: 26.2, sizeType: "MiB",
            torrentCount: GalleryFixtures.torrents.count
        )
    }

    static func galleryInfo() throws -> AnyView {
        let gallery = try pageGallery()
        let detail = pageDetail(gallery)
        let store = Store(
            initialState: GalleryInfoReducer.State(gallery: gallery, galleryDetail: detail),
            reducer: GalleryInfoReducer.init
        )
        return AnyView(NavigationStack {
            GalleryInfoView(store: store, gallery: gallery, galleryDetail: detail)
        })
    }

    /// Detail Search over the synthetic galleries, for a tag of the gallery.
    static func detailSearch(_ content: BrowsingScenarios.ListContent) -> AnyView {
        content.storeDisplayMode(.search)
        var state = DetailSearchReducer.State(keyword: GalleryFixtures.detailSearchKeyword)
        state.galleries = content.galleries()
        state.loadingState = content.loadingState
        return AnyView(NavigationStack {
            DetailSearchView(store: Store(initialState: state, reducer: DetailSearchReducer.init))
        })
    }

    /// The gallery page with one of its sheets presented, as the reducer presents it; `then` is a user step the
    /// sheet's own reducer answers, such as a folder's Delete.
    static func detailPage(
        presenting destination: DetailReducer.Destination.State, then action: DetailReducer.Action? = nil
    ) throws -> AnyView {
        let gallery = try pageGallery()
        var state = DetailReducer.State(gallery: gallery)
        state.galleryDetail = pageDetail(gallery)
        state.galleryTags = LibraryScenarios.detailTags
        state.downloadFolders = LibraryFixtures.downloadFolders
        state.hasLoadedDownloadBadge = true
        state.destination = destination
        let store = Store(initialState: state, reducer: DetailReducer.init)
        if let action {
            store.send(action)
        }
        return AnyView(NavigationStack {
            DetailView(store: store, gid: state.gid)
        })
    }

    /// Archives with the user's balances. With low funds the balances are below every archive's price and the
    /// 1280x archive is chosen: the app has no state of its own for a balance that cannot pay (see 19-07 summary).
    /// The low gallery points balance as VoiceOver reads it, the funds row of the archives without enough funds.
    nonisolated static var lowGalleryPointsLabel: String {
        let balance = Int(GalleryFixtures.lowFunds.galleryPoints) ?? 0
        return String(localized: .accessibilityGalleryPointsBalance(balance: balance))
    }

    static func archives(lowFunds: Bool) throws -> AnyView {
        let resolutions: [ArchiveResolution] = [.x780, .x980, .x1280, .x1600, .x2400, .original]
        var archives = ArchivesReducer.State()
        archives.hathArchives = zip(resolutions, GalleryFixtures.archives).map { resolution, fixture in
            GalleryArchive.HathArchive(resolution: resolution, fileSize: fixture.fileSize, gpPrice: fixture.price)
        }
        let funds = lowFunds ? GalleryFixtures.lowFunds : GalleryFixtures.funds
        archives.$user.withLock { user in
            user.galleryPoints = funds.galleryPoints
            user.credits = funds.credits
        }
        if lowFunds {
            archives.selectedArchive = archives.hathArchives.first(where: { $0.resolution == .x1280 })
        }
        return try detailPage(presenting: .archives(archives))
    }

    static func torrents(empty: Bool) throws -> AnyView {
        var torrents = TorrentsReducer.State()
        if empty {
            // The reducer's answer to a gallery with no torrents.
            torrents.loadingState = .failed(.notFound)
        } else {
            torrents.torrents = GalleryFixtures.torrents.enumerated().map { index, fixture in
                GalleryTorrent(
                    postedDate: PublicVisualFixtures.fixedDate, fileSize: fixture.fileSize, seedCount: fixture.seeds,
                    peerCount: fixture.peers, downloadCount: fixture.downloads,
                    uploader: GalleryFixtures.torrentUploader, fileName: fixture.fileName,
                    hash: String(repeating: "\(index)", count: 40),
                    torrentURL: URL(filePath: "/visual-fixture/torrents/\(index).torrent")
                )
            }
        }
        return try detailPage(presenting: .torrents(torrents))
    }

    static func tagImageURL(_ index: Int) -> URL? {
        URL(string: "https://visual-fixture.invalid/tag/\(index).png")
    }

    static func cacheTagArtwork() async throws {
        try await TracerScenarios.cacheHomeArtwork()
        for index in 0..<GalleryFixtures.tagImageCount {
            guard let url = tagImageURL(index) else { continue }
            let image = PublicVisualFixtures.artwork(marker: "VT\(index + 1)", colorIndex: index + 2)
            try await TracerScenarios.cacheArtwork(image, forKey: url.absoluteString)
        }
    }

    static func tagDetail() throws -> AnyView {
        let detail = TagDetail(
            title: GalleryFixtures.tagTitle, description: GalleryFixtures.tagDescription,
            imageURLs: (0..<GalleryFixtures.tagImageCount).compactMap(tagImageURL),
            links: [try XCTUnwrap(URL(string: "https://example.com/visual-fixture"))]
        )
        return try detailPage(presenting: .tagDetail(detail))
    }

    static func newDawn() throws -> AnyView {
        let gained = GalleryFixtures.greeting
        let greeting = Greeting(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000001907")),
            gainedEXP: gained.exp, gainedCredits: gained.credits, gainedGP: gained.galleryPoints,
            gainedHath: gained.hath, updateTime: PublicVisualFixtures.fixedDate
        )
        return try detailPage(presenting: .newDawn(greeting))
    }

    /// The Folder Manager over the three synthetic folders; the confirmation is the one Delete on the second
    /// folder asks for.
    static func folderManager(confirmingDelete: Bool) throws -> AnyView {
        var folders = FolderManagerReducer.State()
        folders.folders = LibraryFixtures.downloadFolders
        let folder = LibraryFixtures.downloadFolders.dropFirst().first ?? ""
        return try detailPage(
            presenting: .folderManager(folders),
            then: confirmingDelete ? .destination(.presented(.folderManager(.deleteButtonTapped(folder)))) : nil
        )
    }
}

// MARK: - Reader

@MainActor
extension GalleryScenarios {
    enum ReaderState {
        case vertical, horizontal, spread, controls, scrub, pageFailed, loading, liveText, settings
    }

    /// The pages' width in pixels: the portrait window's, so the vertical reader shows a page 1:1.
    static func readerPagePixelWidth() throws -> Int {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }))
        let bounds = scene.effectiveGeometry.coordinateSpace.bounds
        return Int(min(bounds.width, bounds.height) * scene.screen.scale)
    }

    static func readerPageURL(_ page: Int, width: Int) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "visual-reader-\(width)/\(page).png", directoryHint: .notDirectory)
    }

    static func readerPageURLs() throws -> [Int: URL] {
        let width = try readerPagePixelWidth()
        return Dictionary(uniqueKeysWithValues: PublicVisualFixtures.readerPageMarkers.indices.map { index in
            (index + 1, readerPageURL(index + 1, width: width))
        })
    }

    /// Writes the `reader-vertical-finite` pages as the downloaded files the reader opens, once per width.
    static func prepareReaderPages() async throws {
        let width = try readerPagePixelWidth()
        let size = CGSize(width: Double(width), height: (Double(width) * 11 / 8).rounded())
        for (index, marker) in PublicVisualFixtures.readerPageMarkers.enumerated() {
            let url = readerPageURL(index + 1, width: width)
            guard !FileManager.default.fileExists(atPath: url.path()) else { continue }
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let image = PublicVisualFixtures.artwork(marker: marker, colorIndex: index % 6, size: size)
            try XCTUnwrap(image.pngData()).write(to: url, options: .atomic)
        }
    }

    /// The first `downloads-finite` gallery, downloaded with every page.
    static func readerDownload() throws -> DownloadedGallery {
        let fixture = try XCTUnwrap(PublicVisualFixtures.downloadGalleries.first)
        let pages = try readerPageURLs()
        let manifest = DownloadManifest(
            gid: fixture.gid, host: .ehentai, token: fixture.token, title: fixture.title, jpnTitle: nil,
            category: .doujinshi, language: .english, remoteCoverURL: nil, uploader: "Visual Fixture", tags: [],
            postedDate: PublicVisualFixtures.fixedDate, rating: 4.5,
            pages: Dictionary(uniqueKeysWithValues: pages.keys.map({ ($0, "public-page-hash-\($0)") }))
        )
        let folder = LibraryFixtures.downloadFolders.first ?? ""
        return DownloadedGallery(
            manifest: manifest, folderURL: URL(filePath: "/visual-fixture/\(folder)/\(fixture.gid)"),
            folderName: folder, localCoverURL: nil, localPageURLs: pages,
            modificationDate: PublicVisualFixtures.fixedDate, displayStatus: .completed
        )
    }

    /// The recorded Live Text of the page: one line over the marker the artwork draws, never recognized live.
    static func liveTextGroups() throws -> [LiveTextGroup] {
        let box = GalleryFixtures.liveTextBounds
        let bounds = LiveTextBounds(
            topLeft: .init(x: box.minX, y: box.minY), topRight: .init(x: box.maxX, y: box.minY),
            bottomLeft: .init(x: box.minX, y: box.maxY), bottomRight: .init(x: box.maxX, y: box.maxY)
        )
        let marker = PublicVisualFixtures.readerPageMarkers[GalleryFixtures.liveTextPage - 1]
        let block = LiveTextBlock(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-0000000019B1")), text: marker, bounds: bounds
        )
        var group = try XCTUnwrap(LiveTextGroup(blocks: [block]))
        group.id = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-0000000019A1"))
        return [group]
    }

    /// The reader over the downloaded gallery, as Downloads opens it. Direction and spread are the persisted
    /// reading settings; the panel, the slider's drag and a page's load are the reducer's state, and the
    /// settings sheet is its action. Live Text replays its recorded line through the reader's capture seam
    /// (`prepareLiveText`).
    static func reader(_ kind: ReaderState) throws -> AnyView {
        @Shared(.setting) var setting
        $setting.withLock { setting in
            setting.readingDirection = kind == .horizontal || kind == .spread ? .leftToRight : .vertical
            setting.enableDualPageMode = kind == .spread
            // A fixed direction: the iPad's automatic layout would choose one by orientation.
            setting.readingOrientation.isEnabled = kind != .horizontal && kind != .spread
        }
        let download = try readerDownload()
        var state = ReadingReducer.State(
            gallery: download.gallery, contentSource: .local(download: download, manifest: download.manifest)
        )
        switch kind {
        case .controls:
            state.showsPanel = true
        case .scrub:
            state.showsPanel = true
            state.showsSliderPreview = true
            state.sliderValue = Float(GalleryFixtures.scrubPage)
        case .pageFailed:
            state.imageURLLoadingStates = [1: .failed(.webImageFailed)]
        case .loading:
            state.imageURLLoadingStates = [1: .loading]
        case .vertical, .horizontal, .spread, .liveText, .settings:
            break
        }
        let store = Store(initialState: state, reducer: ReadingReducer.init)
        if kind == .settings {
            // The toolbar's Reading Settings, which presents the sheet through the reducer.
            store.send(.presentReadingSetting)
        }
        return AnyView(ReadingView(store: store))
    }

    /// Installs the recorded Live Text for this test method. The reader's Live Text handler is observable state,
    /// which SwiftUI creates when it first lays the reader out, outside any scope the factory could open; so the
    /// capture is prepared for the test process, in both contexts a view can read it in (the scenario's preview
    /// context and the process's own). The dependency cache is reset before every test method, so no other
    /// scenario sees it.
    static func prepareLiveText() async throws {
        try await prepareReaderPages()
        let download = try readerDownload()
        let capture = LiveTextCapture(
            gid: download.gallery.gid, page: GalleryFixtures.liveTextPage, source: .replay(try liveTextGroups())
        )
        prepareDependencies { $0.liveTextCapture = capture }
        withDependencies {
            $0.context = .preview
        } operation: {
            prepareDependencies { $0.liveTextCapture = capture }
        }
    }
}

/// The keyboard's frame on its screen as UIKit last announced it, watched from the first matrix case on
/// (SnapshotMatrixCase), so a keyboard that came up before a step looks is known to it. A window's keyboard layout
/// guide read from the step did not follow the keyboard: it never read it as up.
@MainActor
enum KeyboardWatch {
    private(set) static var frame: CGRect = .zero
    private static var observer: (any NSObjectProtocol)?

    static func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main
        ) { notification in
            let end = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            MainActor.assumeIsolated {
                frame = end ?? .zero
            }
        }
    }
}
