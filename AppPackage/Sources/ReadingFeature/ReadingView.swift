import AnimatedImageFeature
import AppComponents
import AppModels
import AppTools
public import ComposableArchitecture
import Dependencies
import LiveTextTranslation
import Observation
import OSLogExt
import ReadingSettingFeature
import SFSafeSymbols
import SFSafeSymbolsExt
import Sharing
public import SwiftUI
import SystemNotification
#if DEBUG
import Synchronization
#endif

private let logger = Logger(category: .init(describing: ReadingView.self))

public struct ReadingView: View {
    @Dependency(\.dataCache) private var dataCache
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #if DEBUG
    @Environment(\.captureSystemOverlayVisibility) private var captureSystemOverlayVisibility
    #endif

    @Bindable var store: StoreOf<ReadingReducer>
    // Write handle backing the reader's own controls (e.g. the ControlPanel slider). The reading-setting
    // sheet owns its own `@Shared(.setting)`; other reads go through `store.setting`. Same underlying
    // storage — the model clamps keep every write safe.
    @Shared(.setting) private var setting: Setting

    @State private var liveTextHandler = LiveTextHandler()
    @State private var autoPlayHandler = AutoPlayHandler()
    @State var gestureHandler = GestureHandler()
    @State private var deviceState: WindowDevice?
    @State private var pagerSeed = PagerSeed()
    @State private var lowerPanelHeight: CGFloat = 0
    private let pageHandler = PageHandler()

    // The reader opens on the resume page the reducer computed in `State.init`: the first pager is
    // built placed on `store.position`, once the reading area is measured (`PagerSeed`).
    public init(store: StoreOf<ReadingReducer>) {
        self.store = store
    }

    private var backgroundColor: Color {
        colorScheme == .light ? Color(uiColor: .systemGray4) : Color(uiColor: .systemGray6)
    }

    private var isLandscape: Bool {
        gestureHandler.containerSize.width > gestureHandler.containerSize.height
    }

    private var systemOverlayVisibility: Visibility {
        #if DEBUG
        if let captureSystemOverlayVisibility {
            return captureSystemOverlayVisibility
        }
        #endif
        return store.showsPanel ? .automatic : .hidden
    }

    public var body: some View {
        NavigationStack {
            content
                .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
                // The bottom edge softens only under the shown control panel; a hidden panel
                // leaves the page edge to edge.
                .scrollEdgeEffectHidden(!store.showsPanel, for: .bottom)
                .toolbar(content: readingToolbar)
                .toolbarTitleDisplayMode(.inline)
                .toolbarMinimizationBehavior(.never, for: .navigationBar)
                .toolbarVisibility(store.showsPanel ? .visible : .hidden, for: .navigationBar)
                .toolbarVisibility(store.showsPanel ? .visible : .hidden, for: .statusBar)
                .toolbarBackground(.hidden, for: .navigationBar)
                // Outside captures, the home indicator follows the controls like the status bar.
                // The system still answers a swipe from the edge when its indicator is hidden.
                .persistentSystemOverlays(systemOverlayVisibility)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reading_view")
        .background {
            WindowDeviceObservation { state in
                deviceState = state
                updateReadingLayout()
            }
        }
        .onChange(of: store.setting.readingOrientation) {
            store.send(.readingOrientationPreferencesChanged)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).readingSetting
        ) { readingSettingStore in
            NavigationStack {
                ReadingSettingView(store: readingSettingStore)
                .toolbar {
                    // In a window compact in height the sheet covers the whole screen, so it carries
                    // its own close button.
                    if verticalSizeClass == .compact {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                store.send(.destination(.dismiss))
                            } label: {
                                Label(.close, systemSymbol: .chevronDown)
                            }
                        }
                    }
                }
            }
            .privacyMask()
        }
        .sheet(item: $store.destination.share, id: \.id) { shareItemBox in
            ActivityView(activityItems: [shareItemBox.wrappedValue.associatedValue])
                .scrollEdgeEffectStyle(.soft, for: .top)
                .privacyMask()
        }
        .toast($store.scope(\.$toast, action: \.toast))
        .environment(liveTextHandler.translator)
        .liveTextTranslations(for: liveTextHandler.translator)

        // Pan and zoom: the page still follows the finger — these animate only the eased settle
        // after each gesture step, which is position / size motion, so Reduce Motion drops it. The
        // Live Text swaps are opacity-only and stay animated; `showsPanel` keeps its animation for
        // the panel's fade, whose slide `ControlPanel` removes on its own (D-29).
        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: gestureHandler.offset)
        .animation(.default, value: liveTextHandler.enablesLiveText)
        .animation(.default, value: liveTextHandler.liveTextGroups)
        .animation(.default, value: liveTextHandler.translator.translatedPages)
        .animation(reduceMotion ? nil : .default, value: gestureHandler.scale)
        .animation(.default, value: store.showsPanel)
        // D-02 exception candidate: teardown of two view-owned `@State` handlers that hold live
        // work of their own — `liveTextHandler`'s in-flight Vision requests and `autoPlayHandler`'s
        // ticking task. Neither is reducer state, so no reducer action can stand in for this,
        // and no value change marks the view's removal. Dropping it would leave the autoplay task
        // ticking until SwiftUI releases the view's state, which the removal does not pin down.
        // Progress is NOT flushed here: the reducer flushes on `.onPerformDismiss`, before the
        // presentation is torn down; a send from here would arrive after the destination is
        // nil'd and be dropped. So only non-persistence teardown happens here.
        // swiftlint:disable:next lifecycle_modifiers
        .onDisappear {
            liveTextHandler.cancelRequests()
            autoPlayHandler.policy = .off
        }
    }

    private func readingToolbar() -> some ToolbarContent {
        @Bindable var bindableLiveTextHandler = liveTextHandler
        return ReadingToolbar(
            setting: Binding($setting),
            enablesLiveText: $bindableLiveTextHandler.enablesLiveText,
            autoPlayHandler: autoPlayHandler,
            title: "\(max(Int(store.sliderValue), 1)) / \(store.gallery.pageCount)",
            isLandscape: isLandscape,
            dismissAction: { store.send(.onPerformDismiss) },
            navigateSettingAction: { store.send(.presentReadingSetting) },
            reloadAllImagesAction: { store.send(.reloadAllWebImages) },
            retryAllFailedImagesAction: { store.send(.retryAllFailedWebImages) }
        )
    }

    @ContentBuilder
    var content: some View {
        VStack {
            // The pager is built only once the reading area is measured, so its first layout already
            // sits on the position its placement maps to for the measured aspect ratio.
            if !pagerSeed.isMeasured {
                Color.clear
            } else {
                changeTriggers(content: { pages })
            }
        }
        .scaleEffect(gestureHandler.scale, anchor: gestureHandler.scaleAnchor)
        .offset(gestureHandler.offset)
        .highPriorityGesture(
            dragGesture.simultaneously(with: tapGesture),
            isEnabled: gestureHandler.scale > 1
        )
        .gesture(tapGesture, isEnabled: gestureHandler.scale == 1)
        .gesture(magnificationGesture)
        .modifier(
            ReaderPagesAccessibility(
                store: store,
                page: store.position.displayedPage,
                isLandscape: isLandscape,
                turnPage: turnPage(by:)
            )
        )
        // Assistive alternatives to the edge taps and the pinch (VoiceOver criterion 5, Voice
        // Control criterion 2). Both page actions reach `turnPage(by:)`, the one turn path the tap
        // zones' offset closure already lands on. "Next" is +1 in the data source, which stays
        // forward under every reading direction — RTL flips only the paging axis, never the index
        // order — so no direction is derived here and no second page-turn path exists.
        .accessibilityAction(named: .accessibilityNextPage) {
            turnPage(by: 1)
        }
        .accessibilityAction(named: .accessibilityPreviousPage) {
            turnPage(by: -1)
        }
        .accessibilityZoomAction(performAccessibilityZoom)
        .ignoresSafeArea()
        // A forced refresh builds the pages anew; the reducer starts a new pager generation with it.
        .id(store.forceRefreshID)
        .background {
            backgroundColor
                .ignoresSafeArea()
        }
        // The control panel is an overlay, so the scroll views can't see it as a bar. This
        // invisible bar spans the lower panel to give the bottom edge the soft effect the
        // navigation bar gives the top; `.scrollEdgeEffectHidden` drops it with the panel. The
        // pages above already ignore the safe area, so the bar's inset never reaches them: pager
        // frames, paging snaps and the vertical list's center anchor keep their geometry.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            // The bar waits for a reading area. While the reader is presented it is offered no size,
            // and the bar's padding and height alone made it measure 32 by 118 pt, which seeded the
            // vertical list at that width: the pages built above the resume page kept the heights
            // they had there, and a rotation then left the page off the top of the screen.
            if PagerSeed.isReadingArea(gestureHandler.containerSize) {
                // The effect only follows bar elements such as text, so the bar holds a blank line.
                // It stays inset like the panel: a full-width bar moved the vertical reader's
                // opening page on iOS 26.
                Text(verbatim: " ")
                    .frame(maxWidth: .infinity)
                    .frame(height: lowerPanelHeight)
                    .padding(.horizontal)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            let usesHalfWidth = deviceState?.supportsLandscapePanes(in: gestureHandler.containerSize) == true
            ControlPanel(
                showsPanel: $store.showsPanel,
                showsSliderPreview: $store.showsSliderPreview,
                sliderValue: $store.sliderValue,
                isReversed: setting.readingDirection == .rightToLeft,
                containerSize: gestureHandler.containerSize,
                usesHalfWidth: usesHalfWidth,
                showsCloseButton: !usesHalfWidth || deviceState == .pad,
                range: 1...Float(store.gallery.pageCount),
                previewURLs: store.displayPreviewURLs,
                dismissGesture: controlPanelDismissGesture,
                dismissAction: { store.send(.onPerformDismiss) },
                fetchPreviewURLsAction: { store.send(.fetchPreviewURLs($0)) },
                lowerPanelHeightChangeAction: { lowerPanelHeight = $0 }
            )
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            gestureHandler.containerSize = size
            updateReadingLayout()
        }
    }

    private func updateReadingLayout() {
        let size = gestureHandler.containerSize
        guard let deviceState, PagerSeed.isReadingArea(size) else { return }
        store.send(.layoutChanged(
            isLandscape: isLandscape, supportsAutomaticLayout: deviceState.supportsAutomaticLayout
        ))
        _ = pagerSeed.measures()
    }

    /// The pager of the current generation: built anew, on the page the reader names, whenever the generation
    /// changes (`ReaderPosition.pagerRebuilt()`).
    @ContentBuilder
    private var pages: some View {
        let placement = store.position.placement
        Group {
            switch store.setting.readingDirection {
            case .vertical:
                AdvancedList(
                    placement: placement,
                    command: store.position.issued,
                    data: store.state.containerDataSource(
                        setting: store.setting,
                        isLandscape: isLandscape
                    ),
                    id: \.self,
                    spacing: store.setting.contentDividerHeight,
                    gesture: SimultaneousGesture(magnificationGesture, tapGesture),
                    phaseChangeAction: reportPhaseChange,
                    settleAction: reportSettle,
                    content: imageStack
                )
                .scrollDisabled(gestureHandler.scale != 1)

            case .leftToRight, .rightToLeft:
                horizontalPagingList(placement: placement)
            }
        }
        .id(placement.generation)
    }

    // D-04/D-05: the non-vertical reader pages through a stock horizontal paging ScrollView.
    // The `.scrollPosition(id:)` ids are the 0-based POSITIONS in `containerDataSource`, the
    // index space of `PageHandler.mapToPager` (in dual-page mode the element values are
    // non-uniform reading pages, so positions, not elements, are the ids).
    private func horizontalPagingList(placement: PagerCommand) -> some View {
        let setting = store.setting
        let pageCount = store.gallery.pageCount
        let isLandscape = isLandscape
        let pageHandler = pageHandler
        return HorizontalPager(
            placement: placement,
            command: store.position.issued,
            positions: store.state.containerDataSource(setting: setting, isLandscape: isLandscape),
            positionOfPage: { pageHandler.mapToPager(index: $0, setting: setting, isLandscape: isLandscape) },
            pageAtPosition: {
                pageHandler.mapFromPager(index: $0, pageCount: pageCount, setting: setting, isLandscape: isLandscape)
            },
            isReversed: setting.readingDirection == .rightToLeft,
            phaseChangeAction: reportPhaseChange,
            settleAction: reportSettle,
            content: imageStack
        )
        .scrollDisabled(gestureHandler.scale != 1)
    }

    @ContentBuilder
    private func changeTriggers<Content: View>(@ContentBuilder content: () -> Content) -> some View {
        pageAndAutoPlayTriggers(content: content)
            // LiveText
            .onChange(of: liveTextHandler.enablesLiveText) { _, newValue in
                if newValue { store.webImageLoadSuccessIndices.forEach(analyzeImageForLiveText) }
            }
            .onChange(of: store.webImageLoadSuccessIndices) { _, newValue in
                if liveTextHandler.enablesLiveText {
                    newValue.forEach(analyzeImageForLiveText)
                }
            }
            // A one-way hint for the translator, which nothing in the reader reads back.
            .onChange(of: store.sliderValue, initial: true) { _, newValue in
                liveTextHandler.translator.readingPage = Int(newValue)
            }
            .onChange(of: liveTextHandler.translator.failure) {
                if let failure = liveTextHandler.translator.takeFailure() {
                    store.send(.liveTextTranslationFailed(failure))
                }
            }
    }

    @ContentBuilder
    private func pageAndAutoPlayTriggers<Content: View>(@ContentBuilder content: () -> Content) -> some View {
        content()
            // Page: a change of direction or of the positions laid out builds a new pager.
            .onChange(
                of: PagerLayout(
                    direction: store.setting.readingDirection,
                    positions: store.state.containerDataSource(setting: store.setting, isLandscape: isLandscape)
                )
            ) {
                store.send(.pagerRebuilt)
            }
            .onChange(of: store.showsSliderPreview) {
                autoPlayHandler.policy = .off
            }
            // AutoPlay
            .onChange(of: store.destination != nil) { _, isPresented in
                if isPresented {
                    autoPlayHandler.policy = .off
                }
            }
            .onChange(of: autoPlayHandler.tickCount) {
                let setting = store.setting
                let dataSource = store.state.containerDataSource(setting: setting, isLandscape: isLandscape)
                let position = pageHandler.mapToPager(
                    index: store.position.displayedPage, setting: setting, isLandscape: isLandscape
                )
                let tick = AutoPlayHandler.tick(from: position, count: dataSource.count)
                store.send(.turn(toPage: pageHandler.mapFromPager(
                    index: tick.target, pageCount: store.gallery.pageCount, setting: setting, isLandscape: isLandscape
                )))
                if tick.stops {
                    autoPlayHandler.policy = .off
                }
            }
    }

    @ContentBuilder private func imageStack(index: Int) -> some View {
        let setting = store.setting
        let imageStackConfig = store.state.imageContainerConfigs(
            index: index,
            setting: setting,
            isLandscape: isLandscape
        )
        let slot: PageSlot = setting.readingDirection == .vertical
            ? .strip
            : .pager(isDualPage: setting.enableDualPageMode && isLandscape)
        let dataSource = store.state.containerDataSource(setting: setting, isLandscape: isLandscape)
        let activePosition = pageHandler.mapToPager(
            index: store.position.displayedPage, setting: setting, isLandscape: isLandscape
        )
        let activeStackIndex = dataSource.indices.contains(activePosition) ? dataSource[activePosition] : nil
        HorizontalImageStack(
            index: index,
            slot: slot,
            isActive: index == activeStackIndex,
            backgroundColor: backgroundColor,
            config: imageStackConfig,
            imageURLs: store.displayImageURLs,
            originalImageURLs: store.displayOriginalImageURLs,
            pageSizes: store.pageSizes,
            loadingStates: store.imageURLLoadingStates,
            enablesLiveText: liveTextHandler.enablesLiveText,
            liveTextGroups: liveTextHandler.liveTextGroups,
            focusedLiveTextGroup: liveTextHandler.focusedLiveTextGroup,
            liveTextTapAction: liveTextHandler.setFocusedLiveTextGroup,
            fetchAction: { store.send(.fetchImageURLs($0)) },
            refetchAction: { store.send(.refetchImageURLs($0)) },
            prefetchAction: { store.send(.prefetchImages(fromIndex: $0, prefetchLimit: store.setting.prefetchLimit)) },
            loadRetryAction: { store.send(.onWebImageRetry($0)) },
            loadSucceededAction: { store.send(.onWebImageSucceeded($0, pixelSize: $1)) },
            loadFailedAction: { store.send(.onWebImageFailed($0)) },
            copyImageAction: { store.send(.copyImage($0)) },
            saveImageAction: { store.send(.saveImage($0)) },
            shareImageAction: { store.send(.shareImage($0)) }
        )
    }
}

// MARK: Handler methods
extension ReadingView {
    /// Turns the page by `offset` positions, forward when positive: tap-to-turn and the accessibility page actions.
    /// Every turn reaches the reducer as `.turn(toPage:)`, which clamps it to the gallery and sends the pager there.
    func turnPage(by offset: Int) {
        store.send(.turn(toPage: pageHandler.page(
            turningFrom: store.position.displayedPage, by: offset, pageCount: store.gallery.pageCount,
            setting: store.setting, isLandscape: isLandscape
        )))
    }
    private func reportPhaseChange(_ motion: PagerMotion, generation: Int) {
        store.send(.pagerPhaseChanged(motion, generation: generation))
    }
    private func reportSettle(_ shown: Int?, generation: Int) {
        store.send(.pagerSettled(shown: shown, generation: generation))
    }
    func analyzeImageForLiveText(page: Int) {
        guard liveTextHandler.needsAnalysis(page: page) else {
            return
        }
        #if DEBUG
        guard !liveTextHandler.capturesLiveText(gid: store.gallery.gid, page: page) else {
            return
        }
        #endif
        guard let imageURL = store.displayImageURLs[page] else {
            logger.debug("analyzeImageForLiveText URL not found, page: \(page, privacy: .public)")
            return
        }
        if imageURL.isFileURL {
            analyzeLocalImage(at: imageURL, page: page)
            return
        }
        Task {
            await analyzeCachedImageData(
                cacheKeys: imageURL.imageCacheKeys,
                page: page
            )
        }
    }

    /// The downloaded page file's bytes, or nil when it cannot be read.
    ///
    /// Nil is the ordinary "nothing to scan" answer rather than a swallowed error: the caller's
    /// guard already reports an unusable local page through its own debug log, so surfacing the
    /// read error separately would duplicate that one message.
    private func localImageData(at imageURL: URL) -> Data? {
        do {
            return try Data(contentsOf: imageURL)
        } catch {
            return nil
        }
    }

    /// Runs Live Text over a downloaded page file. Animated images are skipped by design
    /// (Live Text scans still images only), so a single non-animating frame is never lifted
    /// out of an animation.
    private func analyzeLocalImage(at imageURL: URL, page: Int) {
        // Local-file loading is an optional Live Text probe; failure skips analysis without affecting reading.
        guard let data = localImageData(at: imageURL),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            logger.debug("analyzeImageForLiveText local image not found, page: \(page, privacy: .public)")
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, page: page, recognitionLanguages:
                store.language?.codes
        )
    }

    /// Runs Live Text over a remote page's cached bytes, read from the owned `DataCache`
    /// (the reader's cache, not Kingfisher's). Animated images are skipped by design
    /// (Live Text scans still images only).
    private func analyzeCachedImageData(cacheKeys: [String], page: Int) async {
        guard let data = await dataCache.data(forKeys: cacheKeys),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            logger.debug("analyzeImageForLiveText image not found, page: \(page, privacy: .public)")
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, page: page, recognitionLanguages:
                store.language?.codes
        )
    }
}

/// What the pager lays out: a change builds a new pager (`ReadingReducer.Action.pagerRebuilt`), placed on the page the
/// reader names for the new layout, rather than moving the old one to it.
private struct PagerLayout: Equatable {
    let direction: ReadingDirection
    let positions: [Int]
}

/// The horizontal pager of one generation, which carries out the reducer's commands and reports what it shows.
///
/// It writes its scroll position only for a command of its own generation, and it reports its scroll phase and, at
/// rest, the page alone on screen, stamped with that generation. A pager built anew starts at its placement, the page
/// the reader names, and its state with it, so nothing of a pager torn down mid-turn is left to reconcile.
private struct HorizontalPager<PageView: View>: View {
    /// How long after a turn is sent the page on screen is checked. A turn that lands as the pager comes to rest can
    /// be lost without a scroll starting, so nothing reports a rest; by this delay a scroll that did start is under
    /// way, and its own rest is reported instead (timing verified by device UAT in Phase 17).
    static var landingCheckDelay: Double { 0.2 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    @Environment(\.dropsReaderInitialIdleReport) private var dropsInitialIdleReport
    @State private var hasDroppedInitialIdleReport = false
    #endif

    private let generation: Int
    private let command: IssuedPagerCommand?
    private let positions: [Int]
    private let positionOfPage: (Int) -> Int
    private let pageAtPosition: (Int) -> Int
    private let isReversed: Bool
    private let phaseChangeAction: (PagerMotion, Int) -> Void
    private let settleAction: (Int?, Int) -> Void
    private let content: (Int) -> PageView
    @State private var scrollPositionID: Int?
    /// The position that alone fills the pager, read from the screen rather than from the position binding: the
    /// binding can name a page the pager stopped short of.
    @State private var shownPosition: Int?

    init(
        placement: PagerCommand, command: IssuedPagerCommand?, positions: [Int],
        positionOfPage: @escaping (Int) -> Int, pageAtPosition: @escaping (Int) -> Int, isReversed: Bool,
        phaseChangeAction: @escaping (PagerMotion, Int) -> Void, settleAction: @escaping (Int?, Int) -> Void,
        @ContentBuilder content: @escaping (Int) -> PageView
    ) {
        generation = placement.generation
        self.command = command
        self.positions = positions
        self.positionOfPage = positionOfPage
        self.pageAtPosition = pageAtPosition
        self.isReversed = isReversed
        self.phaseChangeAction = phaseChangeAction
        self.settleAction = settleAction
        self.content = content
        _scrollPositionID = State(initialValue: positionOfPage(placement.page))
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                // `enumerated()` rather than indexing by position: `\.offset` is the identical
                // 0-based position id the `indices` form produced, so the scroll ids are unchanged,
                // and the page is read as an element instead of through an unguarded subscript.
                ForEach(positions.enumerated(), id: \.offset) { _, page in
                    content(page)
                        .containerRelativeFrame(.horizontal)
                        // Pages re-normalize to LTR: `imageContainerConfigs` already swaps the
                        // spread order for RTL, so the environment flip on the ScrollView may
                        // only reverse the paging axis, never the in-page order (no double-flip).
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .scrollPosition(id: $scrollPositionID)
        .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.5) { positions in
            shownPosition = positions.count == 1 ? positions.first : nil
        }
        // RTL flips only the paging axis; the data source stays forward so every index keeps
        // its logical meaning (PageHandler stays direction-agnostic).
        .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
        .onScrollPhaseChange { _, newValue in
            #if DEBUG
            if dropsInitialIdleReport, newValue == .idle, !hasDroppedInitialIdleReport {
                hasDroppedInitialIdleReport = true
                return
            }
            #endif
            phaseChangeAction(PagerMotion(newValue), generation)
            if newValue == .idle {
                // The screen's report can trail the rest; read it once it has caught up.
                DispatchQueue.main.async { reportShown() }
            }
        }
        .onChange(of: command) { _, command in
            carryOut(command?.command)
        }
    }

    private func reportShown() {
        settleAction(shownPosition.map(pageAtPosition), generation)
    }

    private func carryOut(_ command: PagerCommand?) {
        guard let command, command.generation == generation else { return }
        let target = positionOfPage(command.page)
        switch command {
        case .place:
            scrollPositionID = target

        case .drive:
            guard scrollPositionID == target, let shownPosition, shownPosition != target else {
                scroll(to: target)
                return
            }
            // The binding still names a page the pager stopped short of. Pointing it at the page on screen moves
            // nothing, and lets the turn register as a change again.
            scrollPositionID = shownPosition
            DispatchQueue.main.async { scroll(to: target) }
        }
    }

    /// Slides the pager across every page in between; under Reduce Motion it lands instantly (D-29).
    private func scroll(to target: Int) {
        withAnimation(reduceMotion ? nil : .default) {
            scrollPositionID = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.landingCheckDelay) {
            reportShown()
        }
    }
}

#if DEBUG
/// The reader's UI-test options. The app's UI-test automation sets them once at launch, before any reader is built,
/// from its own launch keys (`EHPANDA_UITEST_DROP_INITIAL_IDLE`); no launch key is read in this module.
public enum ReaderUITestOptions {
    private static let dropsInitialIdleReportValue = Mutex(false)

    /// The default of `EnvironmentValues.dropsReaderInitialIdleReport`; false unless a UI-test launch asks for it.
    public static var dropsInitialIdleReport: Bool {
        get { dropsInitialIdleReportValue.withLock({ $0 }) }
        set { dropsInitialIdleReportValue.withLock({ $0 = newValue }) }
    }
}

public extension EnvironmentValues {
    /// Drops the first `.idle` report of each horizontal pager the reader builds, so a UI test can show that a new
    /// pager's turns and its page do not depend on that report (17-VERIFICATION.md R5-1). Ordinary launches leave it
    /// false; a UI-test launch sets the default through `ReaderUITestOptions`.
    @Entry var dropsReaderInitialIdleReport = ReaderUITestOptions.dropsInitialIdleReport
}
#endif

#Preview("Loaded") {
    NavigationStack {
        Color.clear
            .fullScreenCover(isPresented: .constant(true)) {
                ReadingView(
                    store: .init(initialState: .init(gallery: .preview), reducer: ReadingReducer.init)
                )
            }
    }
}
