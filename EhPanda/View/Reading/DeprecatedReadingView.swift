//
//  ReadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import Combine
import Kingfisher
import SwiftUIPager
import TTProgressHUD

struct DeprecatedReadingView: View, PersistenceAccessor {
//    @EnvironmentObject var store: DeprecatedStore

    @Environment(\.colorScheme) private var colorScheme
    private var backgroundColor: Color {
        colorScheme == .light
        ? Color(.systemGray4)
        : Color(.systemGray6)
    }

    @StateObject private var page: Page = .first()

    @State private var showsPanel = false
    @State private var sliderValue: Float = 1
    @State private var sheetState: ReadingViewSheetState?

    @State private var autoPlayTimer: Timer?
    @State private var autoPlayPolicy: AutoPlayPolicy = .never

    @State private var scaleAnchor: UnitPoint = .center
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    @State private var pageCount = 1

    @StateObject private var imageSaver = ImageSaver()
    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    let gid: String

    init(gid: String) {
        self.gid = gid
        initializeParams()
    }

    mutating func initializeParams() {
        AppUtil.dispatchMainSync {
            _pageCount = State(
                initialValue: galleryDetail?.pageCount ?? 1
            )
        }
    }

    // MARK: ReadingView
    var body: some View {
        Text("")
//        .statusBar(hidden: !showsPanel)
//        .onAppear(perform: onStartTasks)
//        .onDisappear(perform: onEndTasks)
//        .navigationBarBackButtonHidden(true)
//        .navigationBarHidden(environment.navigationBarHidden)
//        .sheet(item: $sheetState, content: sheet)
//        .onChange(of: page.index, perform: updateSliderValue)
//        .onChange(of: autoPlayPolicy, perform: reconfigureTimer)
//        .onChange(of: setting.exceptCover, perform: tryUpdatePagerIndex)
//        .onChange(of: setting.readingDirection, perform: tryUpdatePagerIndex)
//        .onChange(of: setting.enablesDualPageMode, perform: tryUpdatePagerIndex)
//        .onChange(of: imageSaver.saveSucceeded, perform: { newValue in
//            guard let isSuccess = newValue else { return }
//            presentHUD(isSuccess: isSuccess, caption: "Saved to photo library")
//        })
//        .onReceive(AppNotification.appWidthDidChange.publisher) { _ in
//            DispatchQueue.main.async {
//                trySetOffset(.zero)
//                trySetScale(1.1)
//                trySetScale(1)
//            }
//            tryUpdatePagerIndex()
//        }
//        .onReceive(UIApplication.didBecomeActiveNotification.publisher) { _ in
//            trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
//        }
//        .onReceive(UIApplication.willTerminateNotification.publisher) { _ in onEndTasks() }
//        .onReceive(UIApplication.willResignActiveNotification.publisher) { _ in onEndTasks() }
//        .onReceive(AppNotification.readingViewShouldHideStatusBar.publisher, perform: trySetNavigationBarHidden)
    }
}

private extension DeprecatedReadingView {
    // MARK: Life Cycle
    func onStartTasks() {
        trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
        restoreReadingProgress()
//        trySetNavigationBarHidden()
//        fetchGalleryContentsIfNeeded()
    }
    func onEndTasks() {
        trySaveReadingProgress()
        autoPlayPolicy = .never
        trySetOrientation(allowsLandscape: false)
    }
    func trySetOrientation(allowsLandscape: Bool, shouldChangeOrientation: Bool = false) {
//        guard !DeviceUtil.isPad, setting.prefersLandscape else { return }
        if allowsLandscape {
            AppDelegate.orientationMask = .all
            if shouldChangeOrientation {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
        } else {
            AppDelegate.orientationMask = [.portrait, .portraitUpsideDown]
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    func restoreReadingProgress() {
        AppUtil.dispatchMainSync {
            let index = mapToPager(index: galleryState.readingProgress)
            page.update(.new(index: index))
        }
    }

    // MARK: Progress
    func tryUpdatePagerIndex(_: Any? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newIndex = mapToPager(index: Int(sliderValue))
            guard page.index != newIndex else { return }
            page.update(.new(index: newIndex))
        }
    }
    func updateSliderValue(newIndex: Int) {
        tryPrefetchImages(index: newIndex)
        let newValue = Float(mapFromPager(index: newIndex))
        withAnimation {
            if sliderValue != newValue {
                sliderValue = newValue
            }
        }
    }
    func reconfigureTimer(newPolicy: AutoPlayPolicy) {
        autoPlayTimer?.invalidate()
        guard newPolicy != .never else { return }
        autoPlayTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(newPolicy.rawValue),
            repeats: true, block: tryUpdatePagerIndexByTimer
        )
    }
    func tryUpdatePagerIndexByTimer(_: Timer) {
        guard Int(sliderValue) < pageCount else {
            autoPlayPolicy = .never
            return
        }
        page.update(.next)
    }
    func trySaveReadingProgress() {
//        let progress = mapFromPager(index: page.index)
//        guard progress > 0 else { return }
//        store.dispatch(.setReadingProgress(gid: gid, tag: progress))
    }
    func mapToPager(index: Int) -> Int {
//        guard DeviceUtil.isLandscape && setting.enablesDualPageMode
//                && setting.readingDirection != .vertical
//        else { return index - 1 }
//        guard index > 1 else { return 0 }
//
//        return setting.exceptCover ? index / 2 : (index - 1) / 2
        return 0
    }
    func mapFromPager(index: Int) -> Int {
//        guard DeviceUtil.isLandscape && setting.enablesDualPageMode
//                && setting.readingDirection != .vertical
//        else { return index + 1 }
//        guard index > 0 else { return 1 }
//
//        let result = setting.exceptCover ? index * 2 : index * 2 + 1
//
//        if result + 1 == pageCount {
//            return pageCount
//        } else {
//            return result
//        }
        return 0
    }

    // MARK: Prefetch
    func tryPrefetchImages(index: Int) {
//        var prefetchIndices = [URL]()
//        let prefetchLimit = setting.prefetchLimit / 2
//
//        let previousUpperBound = max(index - 2, 1)
//        let previousLowerBound = max(previousUpperBound - prefetchLimit, 1)
//        if previousUpperBound - previousLowerBound > 0 {
//            appendPrefetchIndices(
//                array: &prefetchIndices,
//                range: previousLowerBound...previousUpperBound
//            )
//        }
//
//        let nextLowerBound = min(index + 2, pageCount)
//        let nextUpperBound = min(nextLowerBound + prefetchLimit, pageCount)
//        if nextUpperBound - nextLowerBound > 0 {
//            appendPrefetchIndices(
//                array: &prefetchIndices,
//                range: nextLowerBound...nextUpperBound
//            )
//        }
//
//        guard !prefetchIndices.isEmpty else { return }
//        ImagePrefetcher(urls: prefetchIndices).start()
    }

    func appendPrefetchIndices(array: inout [URL], range: ClosedRange<Int>) {
//        let indices = Array(range.lowerBound...range.upperBound)
//        array.append(contentsOf: indices.compactMap { index in
//            tryFetchGalleryContents(index: index)
//            return URL(string: galleryContents[index] ?? "")
//        })
    }

    // MARK: ContextMenu
    func copyImage(url: String) async {
//        guard let image = try? await imageSaver.retrieveImage(url: url.safeURL()) else {
//            presentHUD(isSuccess: false)
//            return
//        }
//        UIPasteboard.general.image = image
//        presentHUD(isSuccess: true, caption: "Copied to clipboard")
    }
    func saveImage(url: String) async {
//        guard let image = try? await imageSaver.retrieveImage(url: url.safeURL()) else {
//            presentHUD(isSuccess: false)
//            return
//        }
//        imageSaver.saveImage(image)
    }
    func shareImage(url: String) async {
//        guard let image = try? await imageSaver.retrieveImage(url: url.safeURL()) else {
//            presentHUD(isSuccess: false)
//            return
//        }
//        AppUtil.presentActivity(items: [image])
    }
}

// MARK: Definition
enum ReadingViewSheetState: Identifiable {
    var id: Int { hashValue }
    case setting
}

enum AutoPlayPolicy: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case never = -1
    case sec1 = 1
    case sec2 = 2
    case sec3 = 3
    case sec4 = 4
    case sec5 = 5
}

extension AutoPlayPolicy {
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .never:
            return "Never"
        default:
            return "\(rawValue) seconds"
        }
    }
}
