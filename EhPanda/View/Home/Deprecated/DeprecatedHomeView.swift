// swiftlint:disable all
////
////  HomeView.swift
////  EhPanda
////
////  Created by 荒木辰造 on R 2/10/28.
////
//
//import SwiftUI
//import AlertKit
//import TTProgressHUD
//
//struct HomeView: View, StoreAccessor {
//    @EnvironmentObject var store: Store
//    @Environment(\.colorScheme) private var colorScheme
//
//    @AppStorage(wrappedValue: .ehentai, AppUserDefaults.galleryHost.rawValue)
//    var galleryHost: GalleryHost
//
//    @State private var isSearching = false
//    @State private var keyword = ""
//    @State private var lastKeyword = ""
//    @State private var pendingKeywords = [String]()
//
//    @State private var clipboardJumpID: String?
//    @State private var isNavLinkActive = false
//    @State private var greeting: Greeting?
//
//    @State private var hudVisible = false
//    @State private var hudConfig = TTProgressHUDConfig()
//
//    @State private var alertInput = ""
//    @FocusState private var isAlertFocused: Bool
//    @StateObject private var alertManager = CustomAlertManager()
//    @State private var clearHistoryDialogPresented = false
//
//    // MARK: HomeView
//    var body: some View {
//        NavigationView {
//            ZStack {
//                conditionalList
//                SearchHelper(isSearching: $isSearching)
//                TTProgressHUD($hudVisible, config: hudConfig)
//            }
//            .background {
//                NavigationLink(
//                    "",
//                    destination: DetailView(gid: clipboardJumpID ?? ""),
//                    isActive: $isNavLinkActive
//                )
//            }
//            .searchable(
//                text: $keyword, placement: .navigationBarDrawer(displayMode: .always)
//            ) { SuggestionProvider(keyword: $keyword) }
//            .navigationBarTitle(navigationBarTitle)
//            .onSubmit(of: .search, performSearch)
//            .toolbar(content: toolbar)
//        }
//        .navigationViewStyle(.stack)
//        .onOpenURL(perform: tryOpenURL).onAppear(perform: onStartTasks)
//        .onReceive(UIApplication.didBecomeActiveNotification.publisher, perform: onBecomeActive)
//        .onChange(of: environment.galleryItemReverseLoading, perform: tryDismissLoadingHUD)
//        .onChange(of: currentListTypePageNumber) { alertInput = String($0.current + 1) }
//        .onChange(of: environment.galleryItemReverseID, perform: tryActivateNavLink)
//        .onChange(of: isSearching, perform: tryUpdateHistoryKeywords)
//        .onChange(of: galleryHost) { _ in
//            CookiesUtil.removeYay()
//            store.dispatch(.verifyEhProfile)
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                store.dispatch(.resetHomeInfo)
//            }
//        }
//    }
//}
//
//private extension HomeView {
//    // MARK: Sheet
//    func sheet(item: HomeViewSheetState) -> some View {
//        Group {
//            switch item {
//            case .setting:
//                SettingView().tint(accentColor)
//            case .filter:
//                FilterView().tint(accentColor)
//            case .newDawn:
//                NewDawnView(greeting: greeting)
//            case .quickSearch:
//                QuickSearchView(searchAction: performQuickSearch)
//            }
//        }
//        .accentColor(accentColor)
//        .blur(radius: environment.blurRadius)
//        .allowsHitTesting(environment.isAppUnlocked)
//    }
//
//    func moreFeaturesMenu() -> some View {
//        Menu {
//            Button {
//                store.dispatch(.setHomeViewSheetState(.filter))
//            } label: {
//                Image(systemName: "line.3.horizontal.decrease")
//                Text("Filters")
//            }
//            Button {
//                store.dispatch(.setHomeViewSheetState(.quickSearch))
//            } label: {
//                Image(systemName: "magnifyingglass")
//                Text("Quick search")
//            }
//            Button(action: presentJumpPageAlert) {
//                Image(systemName: "arrowshape.bounce.forward")
//                Text("Jump page")
//            }
//            .disabled(currentListTypePageNumber.isSinglePage)
//            if environment.homeListType == .history {
//                Button {
//                    clearHistoryDialogPresented = true
//                } label: {
//                    Image(systemName: "trash")
//                    Text("Clear history")
//                }
//                .disabled(galleryHistory.isEmpty)
//            }
//        } label: {
//            Image(systemName: "ellipsis.circle")
//                .symbolRenderingMode(.hierarchical)
//                .foregroundColor(.primary)
//        }
//    }
//}
//
//// MARK: Private Properties
//private extension HomeView {
//    var galleryHistory: [Gallery] {
//        PersistenceController.fetchGalleryHistory()
//    }
//    var environmentBinding: Binding<AppState.Environment> {
//        $store.appState.environment
//    }
//    var homeInfoBinding: Binding<AppState.HomeInfo> {
//        $store.appState.homeInfo
//    }
//
//    var hasJumpPermission: Bool {
//        detectsLinksFromPasteboard && viewControllersCount == 1
//    }
//    var pasteboardURL: URL? {
//        let currentChangeCount = UIPasteboard.general.changeCount
//        if PasteboardUtil.changeCount != currentChangeCount {
//            PasteboardUtil.setChangeCount(value: currentChangeCount)
//            return PasteboardUtil.url
//        } else {
//            return nil
//        }
//    }
//}
//
//private extension HomeView {
//    // MARK: Life Cycle
//    func onStartTasks() {
//        tryOpenPasteboardURL()
//        tryFetchGreeting()
//        tryFetchFrontpageItems()
//    }
//    func onBecomeActive(_: Any? = nil) {
//        guard viewControllersCount == 1 else { return }
//        tryOpenPasteboardURL()
//        tryFetchGreeting()
//    }
//
//    // MARK: Navigation(handleURL)
//    func tryOpenURL(_ url: URL) {
//        guard let scheme = url.scheme else { return }
//        let replacedString = url.absoluteString
//            .replacingOccurrences(of: scheme, with: "https")
//        guard let replacedURL = URL(string: replacedString) else { return }
//
//        handleURL(replacedURL)
//    }
//    func tryOpenPasteboardURL() {
//        guard hasJumpPermission, let url = pasteboardURL else { return }
//        handleURL(url)
//    }
//    func handleURL(_ url: URL) {
//        let shouldDelayDisplay = homeInfo.frontpageItems.isEmpty
//        URLUtil.handleURL(url) { shouldParseGalleryURL, incomingURL, pageIndex, commentID in
//            guard let incomingURL = incomingURL else { return }
//
//            let gid = URLUtil.parseGID(url: incomingURL, isGalleryURL: shouldParseGalleryURL)
//            store.dispatch(.setPendingJumpInfos(
//                gid: gid, pageIndex: pageIndex, commentID: commentID
//            ))
//
//            if PersistenceController.galleryCached(gid: gid) {
//                replaceGalleryCommentJumpID(gid: gid)
//            } else {
//                if shouldDelayDisplay {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
//                        store.dispatch(.fetchGalleryItemReverse(
//                            url: incomingURL.absoluteString,
//                            shouldParseGalleryURL: shouldParseGalleryURL
//                        ))
//                        presentLoadingHUD()
//                    }
//                } else {
//                    store.dispatch(.fetchGalleryItemReverse(
//                        url: incomingURL.absoluteString,
//                        shouldParseGalleryURL: shouldParseGalleryURL
//                    ))
//                    presentLoadingHUD()
//                }
//            }
//            PasteboardUtil.clear()
//            clearObstruction()
//        }
//    }
//    // Removing this could cause unexpected blank leading space
//    func clearObstruction() {
//        if environment.homeViewSheetState != nil {
//            store.dispatch(.setHomeViewSheetState(nil))
//        }
//    }
//
//    // MARK: Navigation(other)
//    func presentLoadingHUD() {
//        hudConfig = TTProgressHUDConfig(type: .loading, title: "Loading...".localized)
//        hudVisible = true
//    }
//    func tryDismissLoadingHUD(newValue: Bool) {
//        guard !newValue, hasJumpPermission else { return }
//        hudVisible = false
//        hudConfig = TTProgressHUDConfig()
//    }
//    func replaceGalleryCommentJumpID(gid: String?) {
//        store.dispatch(.setGalleryCommentJumpID(gid: gid))
//    }
//    func presentJumpPageAlert() {
//        alertManager.show()
//        isAlertFocused = true
//        HapticUtil.generateFeedback(style: .light)
//    }
//    func tryPerformJumpPage() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            guard let index = Int(alertInput), index <= currentListTypePageNumber.maximum + 1 else { return }
//            store.dispatch(.handleJumpPage(index: index - 1, keyword: lastKeyword))
//        }
//    }
//    func tryActivateNavLink(newValue: String?) {
//        guard newValue != nil, hasJumpPermission else { return }
//        clipboardJumpID = newValue
//        isNavLinkActive = true
//        replaceGalleryCommentJumpID(gid: nil)
//    }
//
//    // MARK: Search
//    func tryUpdateHistoryKeywords(isSearching: Bool) {
//        guard !isSearching, !lastKeyword.isEmpty else { return }
//        store.dispatch(.appendHistoryKeywords(texts: pendingKeywords))
//        pendingKeywords = []
//    }
//    func tryRefetchSearchItems() {
//        guard !lastKeyword.isEmpty else { return }
//        store.dispatch(.fetchSearchItems(keyword: lastKeyword))
//    }
//    func performSearch() {
//        if environment.homeListType != .search {
//            store.dispatch(.setHomeListType(.search))
//        }
//        if !keyword.isEmpty {
//            pendingKeywords.append(keyword)
//            lastKeyword = keyword
//        }
//        store.dispatch(.fetchSearchItems(keyword: keyword))
//    }
//    func performQuickSearch(keyword: String) {
//        store.dispatch(.setHomeViewSheetState(.none))
//        self.keyword = keyword
//        performSearch()
//    }
//}
//
//// MARK: SearchHelper
//private struct SearchHelper: View {
//    @Environment(\.isSearching) var isSearchingEnvironment
//    @Binding var isSearching: Bool
//
//    init(isSearching: Binding<Bool>) {
//        _isSearching = isSearching
//    }
//
//    var body: some View {
//        Text("").onChange(of: isSearchingEnvironment) { newValue in
//            isSearching = newValue
//        }
//    }
//}
