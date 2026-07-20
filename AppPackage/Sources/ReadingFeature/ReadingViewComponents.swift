import SwiftUI
import AppModels
import Resources
import Kingfisher
import SDWebImage
import SDWebImageSwiftUI
import ComposableArchitecture
import AppTools
import ImageClient
import AppComponents
import SFSafeSymbols
import SFSafeSymbolsExt

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
    private let isDualPage: Bool
    private let isActive: Bool
    private let backgroundColor: Color
    private let config: ImageStackConfig
    private let imageURLs: [Int: URL]
    private let originalImageURLs: [Int: URL]
    private let loadingStates: [Int: LoadingState]
    private let enablesLiveText: Bool
    private let liveTextGroups: [Int: [LiveTextGroup]]
    private let focusedLiveTextGroup: LiveTextGroup?
    private let liveTextTapAction: (LiveTextGroup) -> Void
    private let fetchAction: (Int) -> Void
    private let refetchAction: (Int) -> Void
    private let prefetchAction: (Int) -> Void
    private let loadRetryAction: (Int) -> Void
    private let loadSucceededAction: (Int) -> Void
    private let loadFailedAction: (Int) -> Void
    private let copyImageAction: (URL) -> Void
    private let saveImageAction: (URL) -> Void
    private let shareImageAction: (URL) -> Void

    init(
        index: Int, isDualPage: Bool, isActive: Bool, backgroundColor: Color,
        config: ImageStackConfig, imageURLs: [Int: URL], originalImageURLs: [Int: URL],
        loadingStates: [Int: LoadingState], enablesLiveText: Bool,
        liveTextGroups: [Int: [LiveTextGroup]], focusedLiveTextGroup: LiveTextGroup?,
        liveTextTapAction: @escaping (LiveTextGroup) -> Void,
        fetchAction: @escaping (Int) -> Void,
        refetchAction: @escaping (Int) -> Void, prefetchAction: @escaping (Int) -> Void,
        loadRetryAction: @escaping (Int) -> Void, loadSucceededAction: @escaping (Int) -> Void,
        loadFailedAction: @escaping (Int) -> Void, copyImageAction: @escaping (URL) -> Void,
        saveImageAction: @escaping (URL) -> Void, shareImageAction: @escaping (URL) -> Void
    ) {
        self.index = index
        self.isDualPage = isDualPage
        self.isActive = isActive
        self.backgroundColor = backgroundColor
        self.config = config
        self.imageURLs = imageURLs
        self.originalImageURLs = originalImageURLs
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
            loadingState: loadingStates[page] ?? .idle,
            isDualPage: isDualPage,
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
        .contextMenu { contextMenuItems(page: page) }
    }
    @ViewBuilder private func contextMenuItems(page: Int) -> some View {
        Button {
            refetchAction(page)
        } label: {
            Label(.reload, systemSymbol: .arrowCounterclockwise)
        }
        if let imageURL = imageURLs[page] {
            Button {
                copyImageAction(imageURL)
            } label: {
                Label(.copy, systemSymbol: .plusSquareOnSquare)
            }
            Button {
                saveImageAction(imageURL)
            } label: {
                Label(.save, systemSymbol: .squareAndArrowDown)
            }
            if let originalImageURL = originalImageURLs[page] {
                Button {
                    saveImageAction(originalImageURL)
                } label: {
                    Label(
                        .saveOriginal,
                        systemSymbol: .squareAndArrowDownOnSquare
                    )
                }
            }
            Button {
                shareImageAction(imageURL)
            } label: {
                Label(.RLocalizable.share, systemSymbol: .squareAndArrowUp)
            }
        }
    }
}

// MARK: ImageContainer
struct ImageContainer: View {
    private let index: Int
    private let imageURL: URL?
    private let loadingState: LoadingState
    private let isDualPage: Bool
    private let isActive: Bool
    private let backgroundColor: Color
    private let enablesLiveText: Bool
    private let liveTextGroups: [LiveTextGroup]
    private let focusedLiveTextGroup: LiveTextGroup?
    private let liveTextTapAction: (LiveTextGroup) -> Void
    private let refetchAction: (Int) -> Void
    private let loadRetryAction: (Int) -> Void
    private let loadSucceededAction: (Int) -> Void
    private let loadFailedAction: (Int) -> Void

    init(
        index: Int, imageURL: URL?,
        loadingState: LoadingState,
        isDualPage: Bool,
        isActive: Bool,
        backgroundColor: Color,
        enablesLiveText: Bool,
        liveTextGroups: [LiveTextGroup],
        focusedLiveTextGroup: LiveTextGroup?,
        liveTextTapAction: @escaping (LiveTextGroup) -> Void,
        refetchAction: @escaping (Int) -> Void,
        loadRetryAction: @escaping (Int) -> Void,
        loadSucceededAction: @escaping (Int) -> Void,
        loadFailedAction: @escaping (Int) -> Void
    ) {
        self.index = index
        self.imageURL = imageURL
        self.loadingState = loadingState
        self.isDualPage = isDualPage
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
        Placeholder(
            style: .progress(
                pageNumber: index,
                progress: progress,
                isDualPage: isDualPage,
                backgroundColor: backgroundColor
            )
        )
        .containerRelativeFrame([.horizontal, .vertical]) { length, axis in
            axis == .horizontal ? length / (isDualPage ? 2 : 1) : length
        }
        .aspectRatio(Defaults.ImageSize.contentAspect, contentMode: .fit)
    }
    @ViewBuilder private func image(url: URL?) -> some View {
        ByteRoutedReaderImage(
            url: url,
            isActive: isActive,
            placeholder: { progress in placeholder(progress) },
            onSucceeded: { loadSucceededAction(index) },
            onFailed: { loadFailedAction(index) }
        )
    }

    // 30pt at default (.large); scales with Dynamic Type relative to the nearest text style (.title, 28pt).
    @ScaledMetric(relativeTo: .title) private var reloadSymbolSize: CGFloat = 30

    var body: some View {
        if loadingState == .idle {
            image(url: imageURL).scaledToFit().overlay(
                LiveTextView(
                    liveTextGroups: liveTextGroups,
                    focusedLiveTextGroup: focusedLiveTextGroup,
                    tapAction: liveTextTapAction
                )
                .opacity(enablesLiveText ? 1 : 0)
            )
        } else {
            backgroundColor
                .overlay {
                    VStack {
                        Text(index.description)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.gray)
                            .padding(.bottom, 30)

                        Button(action: reloadImage) {
                            Label(.reload, systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
                                .labelStyle(.iconOnly)
                        }
                        .font(.system(size: reloadSymbolSize, weight: .medium))
                        .foregroundStyle(.gray)
                        .animation(.default) {
                            $0.opacity(loadingState == .loading ? 0 : 1)
                        }
                        .overlay {
                            ProgressView()
                                .animation(.default) {
                                    $0.opacity(loadingState == .loading ? 1 : 0)
                                }
                        }
                    }
                }
                .containerRelativeFrame([.horizontal, .vertical]) { length, axis in
                    axis == .horizontal ? length / (isDualPage ? 2 : 1) : length
                }
                .aspectRatio(Defaults.ImageSize.contentAspect, contentMode: .fit)
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
    let isActive: Bool
    @ViewBuilder let placeholder: (Progress?) -> Placeholder
    let onSucceeded: () -> Void
    let onFailed: () -> Void

    @Dependency(\.imageClient) private var imageClient
    @State private var stillImage: UIImage?
    @State private var animatedData: Data?
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
        content.task(id: url) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let animatedData {
            AnimatedImage(data: animatedData, isAnimating: .constant(isActive))
                .resizable()
        } else if let stillImage {
            Image(uiImage: stillImage).resizable()
        } else {
            placeholder(progress)
        }
    }

    @MainActor private func load() async {
        stillImage = nil
        animatedData = nil
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
        guard let asset else {
            onFailed()
            return
        }
        if asset.isAnimated {
            animatedData = asset.data
        } else {
            stillImage = asset.image
        }
        onSucceeded()
    }
}
