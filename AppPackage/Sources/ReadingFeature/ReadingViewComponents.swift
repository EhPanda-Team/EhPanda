import AppComponents
import AppModels
import ComposableArchitecture
import ImageClient
import Kingfisher
import Resources
import SDWebImage
import SDWebImageSwiftUI
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

// MARK: ImageStackConfig
struct ImageStackConfig {
    let firstIndex: Int
    let secondIndex: Int
    let isFirstAvailable: Bool
    let isSecondAvailable: Bool
}

// MARK: AutoPlayPolicy
enum AutoPlayPolicy: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case off = -1
    case sec1 = 1
    case sec2 = 2
    case sec3 = 3
    case sec4 = 4
    case sec5 = 5
}

extension AutoPlayPolicy {
    var value: LocalizedStringResource {
        switch self {
        case .off:
            return .autoPlayPolicyOff
        default:
            return .RLocalizable.seconds(count: rawValue)
        }
    }
}

// MARK: HorizontalImageStack
struct HorizontalImageStack: View {
    private let index: Int
    private let slot: PageSlot
    private let isActive: Bool
    private let backgroundColor: Color
    private let config: ImageStackConfig
    private let imageURLs: [Int: URL]
    private let originalImageURLs: [Int: URL]
    private let pageSizes: [Int: KnownPageSize]
    private let loadingStates: [Int: LoadingState]
    private let enablesLiveText: Bool
    private let liveTextGroups: [Int: [LiveTextGroup]]
    private let focusedLiveTextGroup: LiveTextGroup?
    private let liveTextTapAction: (LiveTextGroup) -> Void
    private let fetchAction: (Int) -> Void
    private let refetchAction: (Int) -> Void
    private let prefetchAction: (Int) -> Void
    private let loadRetryAction: (Int) -> Void
    private let loadSucceededAction: (Int, PagePixelSize) -> Void
    private let loadFailedAction: (Int) -> Void
    private let copyImageAction: (URL) -> Void
    private let saveImageAction: (URL) -> Void
    private let shareImageAction: (URL) -> Void

    init(
        index: Int, slot: PageSlot, isActive: Bool, backgroundColor: Color,
        config: ImageStackConfig, imageURLs: [Int: URL], originalImageURLs: [Int: URL],
        pageSizes: [Int: KnownPageSize], loadingStates: [Int: LoadingState], enablesLiveText: Bool,
        liveTextGroups: [Int: [LiveTextGroup]], focusedLiveTextGroup: LiveTextGroup?,
        liveTextTapAction: @escaping (LiveTextGroup) -> Void,
        fetchAction: @escaping (Int) -> Void,
        refetchAction: @escaping (Int) -> Void, prefetchAction: @escaping (Int) -> Void,
        loadRetryAction: @escaping (Int) -> Void, loadSucceededAction: @escaping (Int, PagePixelSize) -> Void,
        loadFailedAction: @escaping (Int) -> Void, copyImageAction: @escaping (URL) -> Void,
        saveImageAction: @escaping (URL) -> Void, shareImageAction: @escaping (URL) -> Void
    ) {
        self.index = index
        self.slot = slot
        self.isActive = isActive
        self.backgroundColor = backgroundColor
        self.config = config
        self.imageURLs = imageURLs
        self.originalImageURLs = originalImageURLs
        self.pageSizes = pageSizes
        self.loadingStates = loadingStates
        self.enablesLiveText = enablesLiveText
        self.liveTextGroups = liveTextGroups
        self.focusedLiveTextGroup = focusedLiveTextGroup
        self.liveTextTapAction = liveTextTapAction
        self.fetchAction = fetchAction
        self.refetchAction = refetchAction
        self.prefetchAction = prefetchAction
        self.loadRetryAction = loadRetryAction
        self.loadSucceededAction = loadSucceededAction
        self.loadFailedAction = loadFailedAction
        self.copyImageAction = copyImageAction
        self.saveImageAction = saveImageAction
        self.shareImageAction = shareImageAction
    }

    var body: some View {
        HStack(spacing: 0) {
            if config.isFirstAvailable {
                imageContainer(page: config.firstIndex)
            }
            if config.isSecondAvailable {
                imageContainer(page: config.secondIndex)
            }
        }
    }

    func imageContainer(page: Int) -> some View {
        ImageContainer(
            index: page,
            imageURL: imageURLs[page],
            pageSize: pageSizes[page]?.pixelSize,
            loadingState: loadingStates[page] ?? .idle,
            slot: slot,
            isActive: isActive,
            backgroundColor: backgroundColor,
            enablesLiveText: enablesLiveText,
            liveTextGroups: liveTextGroups[page] ?? [],
            focusedLiveTextGroup: focusedLiveTextGroup,
            liveTextTapAction: liveTextTapAction,
            refetchAction: refetchAction,
            loadRetryAction: loadRetryAction,
            loadSucceededAction: loadSucceededAction,
            loadFailedAction: loadFailedAction
        )
        // D-02 exception candidate: the trigger here IS materialization by the lazy container, and
        // that is the behaviour we want. Both readers (`LazyHStack` when paging, `AdvancedList` when
        // vertical) build a page's container shortly before it is needed, which is exactly when its
        // URL should be resolved and the prefetch window advanced. No reducer signal reproduces it:
        // `pageModel.index` moves only on *settled* page changes, dual-page mode maps one position
        // to two indices, and the vertical list renders many containers at once. Driving this from
        // scroll visibility would also fetch later than the container does — and prefetch exists
        // precisely to run ahead of visibility. This is the reader's hottest request path, so
        // rebuilding the laziness in the reducer would risk load-order and cancellation drift for
        // no behavioural gain.
        // swiftlint:disable:next lifecycle_modifiers
        .onAppear {
            if imageURLs[page] == nil {
                fetchAction(page)
            }
            prefetchAction(page)
        }
        // VoiceOver reaches these actions on the reader's pages element (`ReaderPagesAccessibility`), named with their
        // page: a page has no element of its own.
        .contextMenu {
            PageActions(
                page: page,
                naming: .plain,
                imageURL: imageURLs[page],
                originalImageURL: originalImageURLs[page],
                refetchAction: refetchAction,
                copyImageAction: copyImageAction,
                saveImageAction: saveImageAction,
                shareImageAction: shareImageAction
            )
        }
    }
}

// MARK: PageActions
/// What can be done to one page: its context menu, and the actions the reader's page element offers VoiceOver for
/// each page it shows.
struct PageActions: View {
    enum Naming {
        /// The context menu's names, which need no page: the menu opens on the page it acts on.
        case plain
        /// Names that say which page they act on, as one element offers them for both pages of a spread.
        case numbered
    }

    let page: Int
    let naming: Naming
    let imageURL: URL?
    let originalImageURL: URL?
    let refetchAction: (Int) -> Void
    let copyImageAction: (URL) -> Void
    let saveImageAction: (URL) -> Void
    let shareImageAction: (URL) -> Void

    var body: some View {
        Button {
            refetchAction(page)
        } label: {
            Label(name(.reload, numbered: .accessibilityReloadPage(page: page)), systemSymbol: .arrowCounterclockwise)
        }
        if let imageURL {
            Button {
                copyImageAction(imageURL)
            } label: {
                Label(name(.copy, numbered: .accessibilityCopyPage(page: page)), systemSymbol: .plusSquareOnSquare)
            }
            Button {
                saveImageAction(imageURL)
            } label: {
                Label(name(.save, numbered: .accessibilitySavePage(page: page)), systemSymbol: .squareAndArrowDown)
            }
            if let originalImageURL {
                Button {
                    saveImageAction(originalImageURL)
                } label: {
                    Label(
                        name(.saveOriginal, numbered: .accessibilitySaveOriginalPage(page: page)),
                        systemSymbol: .squareAndArrowDownOnSquare
                    )
                }
            }
            Button {
                shareImageAction(imageURL)
            } label: {
                Label(
                    name(.RLocalizable.share, numbered: .accessibilitySharePage(page: page)),
                    systemSymbol: .squareAndArrowUp
                )
            }
        }
    }

    private func name(
        _ plain: LocalizedStringResource, numbered: LocalizedStringResource
    ) -> LocalizedStringResource {
        switch naming {
        case .plain: plain
        case .numbered: numbered
        }
    }
}

// MARK: ImageContainer
struct ImageContainer: View {
    private let index: Int
    private let imageURL: URL?
    private let pageSize: PagePixelSize?
    private let loadingState: LoadingState
    private let slot: PageSlot
    private let isActive: Bool
    private let backgroundColor: Color
    private let enablesLiveText: Bool
    private let liveTextGroups: [LiveTextGroup]
    private let focusedLiveTextGroup: LiveTextGroup?
    private let liveTextTapAction: (LiveTextGroup) -> Void
    private let refetchAction: (Int) -> Void
    private let loadRetryAction: (Int) -> Void
    private let loadSucceededAction: (Int, PagePixelSize) -> Void
    private let loadFailedAction: (Int) -> Void

    /// - Parameter pageSize: The page's size in pixels as far as the reader knows it, `nil` when it knows none.
    init(
        index: Int, imageURL: URL?,
        pageSize: PagePixelSize?,
        loadingState: LoadingState,
        slot: PageSlot,
        isActive: Bool,
        backgroundColor: Color,
        enablesLiveText: Bool,
        liveTextGroups: [LiveTextGroup],
        focusedLiveTextGroup: LiveTextGroup?,
        liveTextTapAction: @escaping (LiveTextGroup) -> Void,
        refetchAction: @escaping (Int) -> Void,
        loadRetryAction: @escaping (Int) -> Void,
        loadSucceededAction: @escaping (Int, PagePixelSize) -> Void,
        loadFailedAction: @escaping (Int) -> Void
    ) {
        self.index = index
        self.imageURL = imageURL
        self.pageSize = pageSize
        self.loadingState = loadingState
        self.slot = slot
        self.isActive = isActive
        self.backgroundColor = backgroundColor
        self.enablesLiveText = enablesLiveText
        self.liveTextGroups = liveTextGroups
        self.focusedLiveTextGroup = focusedLiveTextGroup
        self.liveTextTapAction = liveTextTapAction
        self.refetchAction = refetchAction
        self.loadRetryAction = loadRetryAction
        self.loadSucceededAction = loadSucceededAction
        self.loadFailedAction = loadFailedAction
    }

    private func placeholder(_ progress: Progress?) -> some View {
        UnloadedPage(slot: slot, pageSize: pageSize, backgroundColor: backgroundColor) {
            VStack {
                pageNumber

                if let progress {
                    ProgressView(progress)
                        .progressViewStyle(.plainLinear)
                        .containerRelativeFrame(.horizontal) { width, _ in
                            width * (slot == .pager(isDualPage: true) ? 0.25 : 0.5)
                        }
                } else {
                    ProgressView()
                }
            }
        }
    }
    /// The number an unloaded page shows above its load's progress or its reload button.
    private var pageNumber: some View {
        Text(index.description)
            .font(.largeTitle.bold())
            .foregroundStyle(.gray)
            .padding(.bottom, 30)
    }
    @ContentBuilder private func image(url: URL?) -> some View {
        ByteRoutedReaderImage(
            url: url,
            slot: slot,
            isActive: isActive,
            placeholder: { progress in placeholder(progress) },
            onSucceeded: { loadSucceededAction(index, $0) },
            onFailed: { loadFailedAction(index) }
        )
    }

    // 30pt at default (.large); scales with Dynamic Type relative to the nearest text style (.title, 28pt).
    @ScaledMetric(relativeTo: .title) private var reloadSymbolSize: CGFloat = 30

    var body: some View {
        if loadingState == .idle {
            image(url: imageURL).overlay {
                LiveTextView(
                    liveTextGroups: liveTextGroups,
                    focusedLiveTextGroup: focusedLiveTextGroup,
                    tapAction: liveTextTapAction
                )
                .visible(enablesLiveText)
            }
        } else {
            UnloadedPage(slot: slot, pageSize: pageSize, backgroundColor: backgroundColor) {
                VStack {
                    pageNumber

                    Button(action: reloadImage) {
                        Label(.reload, systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
                            .labelStyle(.iconOnly)
                    }
                    .font(.system(size: reloadSymbolSize, weight: .medium))
                    .foregroundStyle(.gray)
                    .animation(.default) {
                        $0.visible(loadingState != .loading)
                    }
                    .overlay {
                        ProgressView()
                            .animation(.default) {
                                $0.visible(loadingState == .loading)
                            }
                    }
                }
            }
        }
    }
    private func reloadImage() {
        if let error = loadingState.failed {
            if case .webImageFailed = error {
                loadRetryAction(index)
            } else {
                refetchAction(index)
            }
        }
    }
}

// Renders a reader page from bytes loaded through the owned ImageClient fetch
// (DataCache → cookied URLSession), routing animated bytes to SDWebImage and
// still bytes to UIImage so the engine decides by content, not URL extension.
private struct ByteRoutedReaderImage<Placeholder: View>: View {
    private static var progressUnitCount: Int64 { 10_000 }

    let url: URL?
    let slot: PageSlot
    let isActive: Bool
    @ContentBuilder let placeholder: (Progress?) -> Placeholder
    /// Called with the loaded image's size in pixels.
    let onSucceeded: (PagePixelSize) -> Void
    let onFailed: () -> Void

    @Dependency(\.imageClient) private var imageClient
    @State private var loaded: LoadedReaderImage?
    @State private var progress: Progress?

    var body: some View {
        // D-02 exception candidate: `.task(id:)` is used here for its *cancellation*, not merely to
        // start work. It ties the download to both the view's lifetime and the URL's identity, so a
        // page scrolled off screen (or re-pointed at a new URL) cancels its in-flight image fetch —
        // `load()` reads exactly that signal below via `Task.isCancelled` to tell a cancellation
        // apart from a real failure. Every non-banned alternative (`.onChange(of: url, initial:)`
        // firing an unstructured `Task`) would drop that cancellation and leak concurrent image
        // downloads on the reader's hottest path.
        // swiftlint:disable:next lifecycle_modifiers
        content.task(id: url) {
            await load()
        }
    }

    // The loaded image takes its frame rather than this view framing its content: the placeholder takes the page's
    // frame from `UnloadedPage`, and an aspect-fitting modifier around it would size it from its ideal size instead.
    @ContentBuilder private var content: some View {
        if let loaded {
            switch slot {
            case .strip:
                // The frame the page took before its image loaded when the reader knew the image's size then.
                loadedImage(loaded.representation).modifier(StripPageFrame(pageSize: loaded.pixelSize))
            case .pager:
                loadedImage(loaded.representation).scaledToFit()
            }
        } else {
            placeholder(progress)
        }
    }

    /// The loaded image, animated or still, which SwiftUI's `scaledToFit()` and `StripPageFrame` frame as one view, so
    /// that no modifier an image view declares under the same name takes the call.
    @ContentBuilder private func loadedImage(_ representation: LoadedReaderImage.Representation) -> some View {
        switch representation {
        case .animated(let data):
            AnimatedImage(data: data, isAnimating: .constant(isActive)).resizable()
        case .still(let image):
            Image(uiImage: image).resizable()
        }
    }

    @MainActor private func load() async {
        loaded = nil
        progress = nil
        guard let url else { return }
        let downloadProgress = Progress(totalUnitCount: Self.progressUnitCount)
        progress = downloadProgress
        let asset = await imageClient.fetchReaderImageAsset(url: url) { fraction in
            downloadProgress.completedUnitCount = Int64(fraction * Double(Self.progressUnitCount))
        }
        progress = nil
        // A cancelled `.task(id:)` (scrolled off screen, URL changed) surfaces as a
        // nil asset; it is not a load failure, so report neither success nor failure.
        guard !Task.isCancelled else { return }
        // An image without a pixel to draw is no page either.
        guard let asset, let pixelSize = asset.image.pixelSize else {
            onFailed()
            return
        }
        loaded = LoadedReaderImage(
            representation: asset.isAnimated ? .animated(asset.data) : .still(asset.image), pixelSize: pixelSize
        )
        onSucceeded(pixelSize)
    }
}

/// A reader page's loaded image: its bytes, routed to the view that draws them, and its size in pixels.
private struct LoadedReaderImage {
    enum Representation {
        case animated(Data)
        case still(UIImage)
    }

    let representation: Representation
    let pixelSize: PagePixelSize
}

private extension UIImage {
    /// The image's size in pixels as it is drawn, its orientation applied, or `nil` when it has no pixel.
    var pixelSize: PagePixelSize? {
        PagePixelSize(width: Int((size.width * scale).rounded()), height: Int((size.height * scale).rounded()))
    }
}
