import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import Kingfisher
import ComposableArchitecture
import CommonMark
import AppTools
import AppComponents
import ReadingFeature

public struct DetailView: View {
    @Bindable var store: StoreOf<DetailReducer>
    let gid: String
    let user: User
    @Binding var setting: Setting
    let blurRadius: Double
    let tagTranslator: TagTranslator

    public init(
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

    public var body: some View {
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
            .appAlert($store.scope(state: \.alert, action: \.alert))
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
                            manageFoldersAction: { store.send(.folderManagerButtonTapped) },
                            createDefaultFolderAction: { store.send(.createDefaultFolder) },
                            favorAction: { store.send(.favorGallery($0)) },
                            unfavorAction: { store.send(.unfavorGallery) },
                            navigateReadingAction: { store.send(.openReading) },
                            navigateUploaderAction: {
                                if let uploader = store.galleryDetail?.uploader {
                                    let keyword = "uploader:" + "\"\(uploader)\""
                                    store.send(.delegate(.pushDetailSearch(keyword)))
                                }
                            }
                        )
                        .padding(.horizontal)
                        DescriptionSection(
                            gallery: store.gallery,
                            galleryDetail: store.galleryDetail ?? .empty,
                            navigateGalleryInfosAction: {
                                if let galleryDetail = store.galleryDetail {
                                    store.send(.delegate(.pushGalleryInfos(store.gallery, galleryDetail)))
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
                                    store.send(.delegate(.pushDetailSearch(trimmedTitle)))
                                }
                            }
                        )
                        if !store.galleryTags.isEmpty {
                            TagsSection(
                                tags: store.galleryTags, showsImages: setting.showsImagesInTags,
                                voteTagAction: { store.send(.voteTag($0, $1)) },
                                navigateSearchAction: { store.send(.delegate(.pushDetailSearch($0))) },
                                navigateTagDetailAction: { store.send(.tagDetailButtonTapped($0)) },
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
                                navigatePreviewsAction: {
                                    store.send(.delegate(.pushPreviews(
                                        store.gallery, store.previewConfig, store.galleryDetail?.language
                                    )))
                                },
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
                                    store.send(.delegate(.pushComments(
                                        gid: gid, token: store.gallery.token, apiKey: store.apiKey,
                                        galleryURL: galleryURL, comments: store.galleryComments,
                                        scrollCommentID: nil
                                    )))
                                }
                            },
                            navigatePostCommentAction: { store.send(.postCommentButtonTapped) }
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
            .sheet(item: $store.destination.postComment, id: \.id) { _ in
                PostCommentView(
                    title: .postComment,
                    content: $store.commentContent,
                    isFocused: $store.postCommentFocused,
                    postAction: {
                        if let galleryURL = store.gallery.galleryURL {
                            store.send(.postComment(galleryURL))
                        }
                        store.send(.destination(.dismiss))
                    },
                    cancelAction: { store.send(.destination(.dismiss)) },
                    onAppearAction: { store.send(.onPostCommentAppear) }
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.destination.newDawn) { greeting in
                NewDawnView(greeting: greeting.wrappedValue)
                    .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.destination.tagDetail, id: \.title) { detail in
                TagDetailView(detail: detail.wrappedValue)
                    .autoBlur(radius: blurRadius)
            }
    }

    private func primaryModalModifiers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .fullScreenCover(
                item: $store.scope(state: \.destination?.reading, action: \.destination.reading)
            ) { store in
                ReadingView(
                    store: store,
                    gid: gid,
                    setting: $setting,
                    blurRadius: blurRadius
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(
                item: $store.scope(state: \.destination?.archives, action: \.destination.archives)
            ) { archivesStore in
                if let galleryURL = store.gallery.galleryURL, let archiveURL = store.galleryDetail?.archiveURL {
                    ArchivesView(
                        store: archivesStore,
                        gid: gid,
                        user: user,
                        galleryURL: galleryURL,
                        archiveURL: archiveURL
                    )
                    .accentColor(setting.accentColor)
                    .autoBlur(radius: blurRadius)
                }
            }
            .sheet(
                item: $store.scope(state: \.destination?.torrents, action: \.destination.torrents)
            ) { store in
                TorrentsView(
                    store: store,
                    gid: gid,
                    token: self.store.gallery.token,
                    blurRadius: blurRadius
                )
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(
                item: $store.scope(state: \.destination?.folderManager, action: \.destination.folderManager)
            ) { store in
                FolderManagerView(store: store)
                    .accentColor(setting.accentColor)
                    .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.destination.share, id: \.absoluteString) { url in
                ActivityView(activityItems: [url.wrappedValue])
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
            store.send(.deleteDownloadButtonTapped)
        case .error:
            store.send(.retryDownloadButtonTapped(store.downloadNeedsRepair ? .repair : .redownload))
        case .updateAvailable:
            store.send(.retryDownloadButtonTapped(.update))
        }
    }

    private func runLaunchAutomationIfNeeded() {
        store.send(.runLaunchAutomationIfNeeded)
    }

    @ViewBuilder private func offlineFallbackNotice(error: AppError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                .savedDetails,
                systemSymbol: .wifiExclamationmark
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            if error.isRetryable != false {
                Button(.RLocalizable.retry) {
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
        NavigationStack {
            DetailView(
                store: .init(initialState: .init(gallery: .preview), reducer: DetailReducer.init),
                gid: .init(),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
