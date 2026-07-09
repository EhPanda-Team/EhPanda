import AppTools
import SwiftUI
import AppModels
import Sharing
import ComposableArchitecture
import URLClient
import HapticsClient
import ImageClient
import NetworkingFeature
import DownloadClient
import ClipboardClient
import CookieClient
import DeviceClient
import AppDelegateClient
import AppComponents

@Reducer
public struct ReadingReducer: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case share(IdentifiableBox<ShareItem>)
        @ReducerCaseIgnored
        case readingSetting(EquatableVoid)
    }

    public enum ShareItem: Equatable, Sendable {
        var associatedValue: Any {
            switch self {
            case .data(let data):
                return data
            case .image(let image):
                return image
            }
        }
        case data(Data)
        case image(UIImage)
    }

    public enum ImageAction: Sendable {
        case copy, save, share
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var toast: AppAlertState<Never>?
        @Presents public var destination: Destination.State?
        public var contentSource: ReadingContentSource = .remote
        public var gallery: Gallery
        public var language: Language?

        // Read-only here: the reducer only reads `setting` (page math, orientation). The reading-setting
        // editor writes it through a view-owned `@Shared(.setting)` binding instead, and the mutual
        // scale-factor clamp lives on the `Setting` model, so those writes stay consistent without a
        // reducer round-trip.
        @SharedReader(.setting) public var setting: Setting

        public var readingProgress: Int = .zero
        // The latest page awaiting a debounced persist to `@Shared(.galleryHistory)`; kept separate
        // from `readingProgress` (which seeds the slider) so tracking it never feeds back into the pager.
        public var pendingReadingProgress: Int = .zero
        public var forceRefreshID: UUID = .init()

        public var webImageLoadSuccessIndices = Set<Int>()
        public var imageURLLoadingStates = [Int: LoadingState]()
        public var previewLoadingStates = [Int: LoadingState]()
        public var previewConfig: PreviewConfig = .normal(rows: 4)

        public var previewURLs = [Int: URL]()
        /// The single source of truth for downloaded page files. It is not copied into the
        /// other URL maps; both offline reads and the opportunistic "use the downloaded file
        /// if present" check in remote mode resolve a page through this map alone.
        public var localPageURLs = [Int: URL]()
        public var localPageRequestID = UUID()

        public var thumbnailURLs = [Int: URL]()
        public var imageURLs = [Int: URL]()
        public var originalImageURLs = [Int: URL]()

        public var mpvKey: String?
        public var mpvImageKeys = [Int: String]()
        public var mpvSkipServerIdentifiers = [Int: String]()

        public var showsPanel = false
        public var showsSliderPreview = false

        // `gallery` is required (no `.empty` default) so every pushing context is forced to seed it:
        // a blank gallery has a `nil` galleryURL and a random-UUID gid, which bricks remote reading
        // and writes junk history entries. `previewConfig`/`language` are threaded from the detail
        // context so page math and Live Text language stay correct for remote sessions; offline
        // sources overwrite both from the manifest on appear (see `applyLocalSource`).
        public init(
            gallery: Gallery,
            contentSource: ReadingContentSource = .remote,
            previewConfig: PreviewConfig = .normal(rows: 4),
            language: Language? = nil
        ) {
            self.gallery = gallery
            self.contentSource = contentSource
            self.previewConfig = previewConfig
            self.language = language
            // Offline sources overwrite the gallery/language/page source from the manifest, so resolve
            // them before keying the resume lookup on the final gallery id.
            if case .local(let download, let manifest) = contentSource {
                ReadingReducer().applyLocalSource(state: &self, download: download, manifest: manifest)
            }
            // Seed the resume page synchronously from the persisted browsing history so the pager is
            // built at the right page from the start (no post-render jump). `pendingReadingProgress`
            // mirrors it so a flush before the first page turn rewrites that position, not a stale zero.
            @Shared(.galleryHistory) var galleryHistory
            readingProgress = galleryHistory.readingProgress(gid: self.gallery.id)
            pendingReadingProgress = readingProgress
        }

        var isOffline: Bool { contentSource != .remote }

        // Update
        func update<T>(stored: inout [Int: T], new: [Int: T], replaceExisting: Bool = true) {
            guard !new.isEmpty else { return }
            stored = stored.merging(new, uniquingKeysWith: { stored, new in replaceExisting ? new : stored })
        }
        mutating func updatePreviewURLs(_ previewURLs: [Int: URL]) {
            update(stored: &self.previewURLs, new: previewURLs)
        }
        mutating func updateThumbnailURLs(_ thumbnailURLs: [Int: URL]) {
            update(stored: &self.thumbnailURLs, new: thumbnailURLs)
        }
        mutating func updateImageURLs(_ imageURLs: [Int: URL], _ originalImageURLs: [Int: URL]) {
            update(stored: &self.imageURLs, new: imageURLs)
            update(stored: &self.originalImageURLs, new: originalImageURLs)
        }

        // Image
        func containerDataSource(setting: Setting, isLandscape: Bool) -> [Int] {
            guard gallery.pageCount > 0 else { return [] }

            let defaultData = Array(1...gallery.pageCount)
            guard isLandscape && setting.enablesDualPageMode
                    && setting.readingDirection != .vertical
            else { return defaultData }

            let data = setting.exceptCover
                ? [1] + Array(stride(from: 2, through: gallery.pageCount, by: 2))
                : Array(stride(from: 1, through: gallery.pageCount, by: 2))

            return data
        }
        func imageContainerConfigs(
            index: Int, setting: Setting, isLandscape: Bool
        ) -> ImageStackConfig {
            let direction = setting.readingDirection
            let isReversed = direction == .rightToLeft
            let isFirstSingle = setting.exceptCover
            let isFirstPageAndSingle = index == 1 && isFirstSingle
            let isDualPage = isLandscape && setting.enablesDualPageMode && direction != .vertical
            let firstIndex = isDualPage && isReversed && !isFirstPageAndSingle ? index + 1 : index
            let secondIndex = firstIndex + (isReversed ? -1 : 1)
            let isValidFirstRange = firstIndex >= 1 && firstIndex <= gallery.pageCount
            let isValidSecondRange = isFirstSingle
                ? secondIndex >= 2 && secondIndex <= gallery.pageCount
                : secondIndex >= 1 && secondIndex <= gallery.pageCount
            return .init(
                firstIndex: firstIndex, secondIndex: secondIndex, isFirstAvailable: isValidFirstRange,
                isSecondAvailable: !isFirstPageAndSingle && isValidSecondRange && isDualPage
            )
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
        case destination(PresentationAction<Destination.Action>)
        case presentShare(IdentifiableBox<ShareItem>)
        case presentReadingSetting

        case toggleShowsPanel
        case setOrientationPortrait(Bool)
        case onPerformDismiss
        case onAppear(String)

        case onWebImageRetry(Int)
        case onWebImageSucceeded(Int)
        case onWebImageFailed(Int)
        case reloadAllWebImages
        case retryAllFailedWebImages

        case copyImage(URL)
        case saveImage(URL)
        case saveImageDone(Bool)
        case shareImage(URL)
        case fetchImage(ImageAction, URL)
        case fetchImageDone(ImageAction, Result<ImageClient.ImageAsset, Error>)

        case syncReadingProgress(Int)
        case flushReadingProgress

        case observeDownloads(String)
        case observeDownloadsDone([DownloadedGallery])
        case loadLocalPageURLs(String)
        case loadLocalPageURLsDone(UUID, [Int: URL])

        case fetchPreviewURLs(Int)
        case fetchPreviewURLsDone(Int, Result<[Int: URL], AppError>)

        case fetchImageURLs(Int)
        case refetchImageURLs(Int)
        case prefetchImages(Int, Int)

        case fetchThumbnailURLs(Int)
        case fetchThumbnailURLsDone(Int, Result<[Int: URL], AppError>)
        case fetchNormalImageURLs(Int, [Int: URL])
        case fetchNormalImageURLsDone(Int, Result<([Int: URL], [Int: URL]), AppError>)
        case refetchNormalImageURLs(Int)
        case refetchNormalImageURLsDone(Int, Result<([Int: URL], HTTPURLResponse?), AppError>)

        case fetchMPVKeys(Int, URL)
        case fetchMPVKeysDone(Int, Result<(String, [Int: String]), AppError>)
        case fetchMPVImageURL(Int, Bool)
        case fetchMPVImageURLDone(Int, Result<GalleryMPVImageURLResponse, AppError>)
        case captureCachedPage(Int)
    }

    @Dependency(\.appDelegateClient) var appDelegateClient
    @Dependency(\.clipboardClient) var clipboardClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.hapticsClient) var hapticsClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.deviceClient) var deviceClient
    @Dependency(\.imageClient) var imageClient
    @Dependency(\.urlClient) var urlClient
    @Dependency(\.date) var date
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> { makeBody() }
}

extension ReadingReducer.Destination.State: Equatable, Sendable {}
extension ReadingReducer.Destination.Action: Equatable, Sendable {}
