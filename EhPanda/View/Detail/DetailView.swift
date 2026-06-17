//
//  DetailView.swift
//  EhPanda
//

import SwiftUI
import Kingfisher
import ComposableArchitecture
import CommonMark

private enum DownloadDialog: Equatable {
    case delete(isActiveDownload: Bool)
    case retry(DownloadStartMode)

    var title: String {
        switch self {
        case .delete:
            return L10n.Localizable.DetailView.Dialog.Title.deleteDownload
        case .retry(let mode):
            switch mode {
            case .repair:
                return L10n.Localizable.DetailView.Dialog.Title.repairDownload
            case .update:
                return L10n.Localizable.DetailView.Dialog.Title.updateDownload
            case .initial, .redownload:
                return L10n.Localizable.DetailView.Dialog.Title.redownloadGallery
            }
        }
    }

    var message: String {
        switch self {
        case .delete(let isActiveDownload):
            return isActiveDownload
                ? L10n.Localizable.DetailView.Dialog.Message.deleteActiveDownload
                : L10n.Localizable.DetailView.Dialog.Message.deleteDownloadedGallery
        case .retry(let mode):
            switch mode {
            case .repair:
                return L10n.Localizable.DetailView.Dialog.Message.repairDownload
            case .update:
                return L10n.Localizable.DetailView.Dialog.Message.updateDownload
            case .initial, .redownload:
                return L10n.Localizable.DetailView.Dialog.Message.redownloadGallery
            }
        }
    }

    var confirmTitle: String {
        switch self {
        case .delete:
            return L10n.Localizable.ConfirmationDialog.Button.delete
        case .retry(let mode):
            switch mode {
            case .repair:
                return L10n.Localizable.DetailView.Dialog.Button.repair
            case .update:
                return L10n.Localizable.DetailView.Dialog.Button.update
            case .initial, .redownload:
                return L10n.Localizable.DetailView.Dialog.Button.redownload
            }
        }
    }

    var confirmRole: ButtonRole? {
        switch self {
        case .delete:
            return .destructive
        case .retry:
            return nil
        }
    }
}

struct DetailView: View {
    @Bindable var store: StoreOf<DetailReducer>
    @State private var downloadDialog: DownloadDialog?
    let gid: String
    let user: User
    @Binding var setting: Setting
    let blurRadius: Double
    let tagTranslator: TagTranslator

    init(
        store: StoreOf<DetailReducer>, gid: String,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.gid = gid
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        modalModifiers(content: { content })
            .animation(.default, value: store.showsUserRating)
            .animation(.default, value: store.showsFullTitle)
            .animation(.default, value: store.galleryDetail)
            .onAppear {
                DispatchQueue.main.async {
                    store.send(.onAppear(gid, setting.showsNewDawnGreeting))
                }
            }
            .onChange(of: store.galleryDetail) { _, _ in
                runLaunchAutomationIfNeeded()
            }
            .onChange(of: store.hasLoadedDownloadBadge) { _, _ in
                runLaunchAutomationIfNeeded()
            }
            .alert(
                downloadDialog?.title ?? "",
                isPresented: Binding(
                    get: { downloadDialog != nil },
                    set: { if !$0 { downloadDialog = nil } }
                ),
                presenting: downloadDialog
            ) { dialog in
                Button(dialog.confirmTitle, role: dialog.confirmRole) {
                    switch dialog {
                    case .delete:
                        store.send(.deleteDownload)
                    case .retry(let mode):
                        store.send(.retryDownload(mode))
                    }
                    downloadDialog = nil
                }
                Button(L10n.Localizable.Common.Button.cancel, role: .cancel) {
                    downloadDialog = nil
                }
            } message: { dialog in
                Text(dialog.message)
            }
            .background(navigationLinks)
            .toolbar(content: toolbar)
    }

}

// MARK: Content
private extension DetailView {
    var content: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                let content =
                    VStack(spacing: 30) {
                        if let error = store.loadingState.failed,
                           store.galleryDetail != nil {
                            offlineFallbackNotice(error: error)
                                .padding(.horizontal)
                        }
                        HeaderSection(
                            gallery: store.gallery,
                            galleryDetail: store.galleryDetail ?? .empty,
                            user: user,
                            downloadBadge: store.downloadBadge,
                            downloadNeedsRepair: store.downloadNeedsRepair,
                            downloadFolders: store.downloadFolders,
                            isPreparingDownload: store.isPreparingDownload,
                            canDownload: !store.gallery.id.isEmpty
                                && (AppUtil.galleryHost == .ehentai || CookieUtil.didLogin),
                            displaysJapaneseTitle: setting.displaysJapaneseTitle,
                            showFullTitle: store.showsFullTitle,
                            showFullTitleAction: { store.send(.toggleShowFullTitle) },
                            downloadAction: { handleDownloadAction() },
                            downloadToFolderAction: {
                                store.send(.startDownload($0))
                            },
                            manageFoldersAction: { store.send(.setNavigation(.folderManager())) },
                            favorAction: { store.send(.favorGallery($0)) },
                            unfavorAction: { store.send(.unfavorGallery) },
                            navigateReadingAction: { store.send(.openReading) },
                            navigateUploaderAction: {
                                if let uploader = store.galleryDetail?.uploader {
                                    let keyword = "uploader:" + "\"\(uploader)\""
                                    store.send(.setNavigation(.detailSearch(keyword)))
                                }
                            }
                        )
                        .padding(.horizontal)
                        DescriptionSection(
                            gallery: store.gallery,
                            galleryDetail: store.galleryDetail ?? .empty,
                            navigateGalleryInfosAction: {
                                if let galleryDetail = store.galleryDetail {
                                    store.send(.setNavigation(.galleryInfos(store.gallery, galleryDetail)))
                                }
                            }
                        )
                        ActionSection(
                            galleryDetail: store.galleryDetail ?? .empty,
                            userRating: store.userRating,
                            showUserRating: store.showsUserRating,
                            showUserRatingAction: { store.send(.toggleShowUserRating) },
                            updateRatingAction: { store.send(.updateRating($0)) },
                            confirmRatingAction: { store.send(.confirmRating($0)) },
                            navigateSimilarGalleryAction: {
                                if let trimmedTitle = store.galleryDetail?.trimmedTitle {
                                    store.send(.setNavigation(.detailSearch(trimmedTitle)))
                                }
                            }
                        )
                        if !store.galleryTags.isEmpty {
                            TagsSection(
                                tags: store.galleryTags, showsImages: setting.showsImagesInTags,
                                voteTagAction: { store.send(.voteTag($0, $1)) },
                                navigateSearchAction: { store.send(.setNavigation(.detailSearch($0))) },
                                navigateTagDetailAction: { store.send(.setNavigation(.tagDetail($0))) },
                                translateAction: {
                                    tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
                                }
                            )
                            .padding(.horizontal)
                        }
                        let displayPreviewURLs = store.localPreviewURLs.merging(
                            store.galleryPreviewURLs,
                            uniquingKeysWith: { local, _ in local }
                        )
                        if !displayPreviewURLs.isEmpty {
                            PreviewsSection(
                                pageCount: store.galleryDetail?.pageCount ?? 0,
                                previewURLs: displayPreviewURLs,
                                navigatePreviewsAction: { store.send(.setNavigation(.previews)) },
                                navigateReadingAction: {
                                    store.send(.updateReadingProgress($0))
                                    store.send(.openReading)
                                }
                            )
                        }
                        CommentsSection(
                            comments: store.galleryComments,
                            navigateCommentAction: {
                                if let galleryURL = store.gallery.galleryURL {
                                    store.send(.setNavigation(.comments(galleryURL)))
                                }
                            },
                            navigatePostCommentAction: { store.send(.setNavigation(.postComment())) }
                        )
                    }
                    .padding(.bottom, 20)

                if #available(iOS 18.0, *) {
                    content
                        .padding(.top, 25)
                } else {
                    content
                        .padding(.top, -25)
                }
            }
            .opacity(store.galleryDetail == nil ? 0 : 1)

            LoadingView()
                .opacity(
                    store.galleryDetail == nil
                        && store.loadingState == .loading ? 1 : 0
                )

            let error = store.loadingState.failed
            let retryAction: () -> Void = { store.send(.fetchGalleryDetail) }
            ErrorView(error: error ?? .unknown, action: error?.isRetryable != false ? retryAction : nil)
                .opacity(store.galleryDetail == nil && error != nil ? 1 : 0)
        }
    }

    func modalModifiers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        primaryModalModifiers(content: content)
            .sheet(item: $store.route.sending(\.setNavigation).postComment) { _ in
                PostCommentView(
                    title: L10n.Localizable.PostCommentView.Title.postComment,
                    content: $store.commentContent,
                    isFocused: $store.postCommentFocused,
                    postAction: {
                        if let galleryURL = store.gallery.galleryURL {
                            store.send(.postComment(galleryURL))
                        }
                        store.send(.setNavigation(nil))
                    },
                    cancelAction: { store.send(.setNavigation(nil)) },
                    onAppearAction: { store.send(.onPostCommentAppear) }
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).newDawn) { greeting in
                NewDawnView(greeting: greeting)
                    .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).tagDetail, id: \.title) { detail in
                TagDetailView(detail: detail)
                    .autoBlur(radius: blurRadius)
            }
    }

    private func primaryModalModifiers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .fullScreenCover(item: $store.route.sending(\.setNavigation).reading) { _ in
                ReadingView(
                    store: store.scope(state: \.readingState, action: \.reading),
                    gid: gid,
                    setting: $setting,
                    blurRadius: blurRadius
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).archives, id: \.0.absoluteString) { urls in
                let (galleryURL, archiveURL) = urls
                ArchivesView(
                    store: store.scope(state: \.archivesState, action: \.archives),
                    gid: gid,
                    user: user,
                    galleryURL: galleryURL,
                    archiveURL: archiveURL
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).torrents) { _ in
                TorrentsView(
                    store: store.scope(state: \.torrentsState, action: \.torrents),
                    gid: gid,
                    token: store.gallery.token,
                    blurRadius: blurRadius
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).folderManager) { _ in
                FolderManagerView(
                    store: store.scope(state: \.folderManagerState, action: \.folderManager)
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).share, id: \.absoluteString) { url in
                ActivityView(activityItems: [url])
                    .autoBlur(radius: blurRadius)
            }
    }

}

// MARK: Actions
private extension DetailView {
    private func handleDownloadAction() {
        switch store.downloadBadge?.status {
        case nil:
            // Starting a new download requires picking a folder; the download
            // button presents a folder menu for this case instead.
            break
        case .queued, .active, .inactive:
            store.send(.toggleDownloadPause)
        case .completed:
            downloadDialog = .delete(isActiveDownload: false)
        case .error:
            downloadDialog = store.downloadNeedsRepair
                ? .retry(.repair)
                : .retry(.redownload)
        case .updateAvailable:
            downloadDialog = .retry(.update)
        }
    }

    private func runLaunchAutomationIfNeeded() {
        store.send(.runLaunchAutomationIfNeeded)
    }

    @ViewBuilder private func offlineFallbackNotice(error: AppError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                L10n.Localizable.DetailView.OfflineNotice.savedDetails,
                systemImage: "wifi.exclamationmark"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            if error.isRetryable != false {
                Button(L10n.Localizable.ErrorView.Button.retry) {
                    store.send(.fetchGalleryDetail)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
    }
}

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(
                store: .init(initialState: .init(), reducer: DetailReducer.init),
                gid: .init(),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
