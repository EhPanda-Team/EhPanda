//
//  DetailView.swift
//  EhPanda
//

import SwiftUI
import Kingfisher
import ComposableArchitecture
import CommonMark

struct DetailView: View {
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

    @Bindable private var store: StoreOf<DetailReducer>
    @State private var downloadDialog: DownloadDialog?
    private let gid: String
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

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
                        isPreparingDownload: store.isPreparingDownload,
                        canDownload: !store.gallery.id.isEmpty
                            && (AppUtil.galleryHost == .ehentai || CookieUtil.didLogin),
                        displaysJapaneseTitle: setting.displaysJapaneseTitle,
                        showFullTitle: store.showsFullTitle,
                        showFullTitleAction: { store.send(.toggleShowFullTitle) },
                        downloadAction: { handleDownloadAction() },
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
                            translateAction: { tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags) }
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
            .sheet(item: $store.route.sending(\.setNavigation).share, id: \.absoluteString) { url in
                ActivityView(activityItems: [url])
                    .autoBlur(radius: blurRadius)
            }
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

    private func handleDownloadAction() {
        let options = setting.downloadOptionsSnapshot
        switch store.downloadBadge {
        case .none:
            store.send(.startDownload(options))
        case .queued:
            break
        case .downloading, .paused:
            store.send(.toggleDownloadPause)
        case .downloaded:
            downloadDialog = .delete(isActiveDownload: false)
        case .failed, .partial:
            downloadDialog = .retry(.redownload)
        case .updateAvailable:
            downloadDialog = .retry(.update)
        case .missingFiles:
            downloadDialog = .retry(.repair)
        }
    }

    private func runLaunchAutomationIfNeeded() {
        store.send(.runLaunchAutomationIfNeeded(setting.downloadOptionsSnapshot))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: NavigationLinks
private extension DetailView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: $store.route, case: \.previews) { _ in
            PreviewsView(
                store: store.scope(state: \.previewsState, action: \.previews),
                gid: gid, setting: $setting, blurRadius: blurRadius
            )
        }
        NavigationLink(unwrapping: $store.route, case: \.comments) { route in
            if let commentStore = store.scope(state: \.commentsState.wrappedValue, action: \.comments) {
                CommentsView(
                    store: commentStore, gid: gid, token: store.gallery.token, apiKey: store.apiKey,
                    galleryURL: route.wrappedValue, comments: store.galleryComments, user: user,
                    setting: $setting, blurRadius: blurRadius,
                    tagTranslator: tagTranslator
                )
            }
        }
        NavigationLink(unwrapping: $store.route, case: \.detailSearch) { route in
            if let detailSearchStore = store.scope(state: \.detailSearchState.wrappedValue, action: \.detailSearch) {
                DetailSearchView(
                    store: detailSearchStore, keyword: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
        NavigationLink(unwrapping: $store.route, case: \.galleryInfos) { route in
            let (gallery, galleryDetail) = route.wrappedValue
            GalleryInfosView(
                store: store.scope(state: \.galleryInfosState, action: \.galleryInfos),
                gallery: gallery, galleryDetail: galleryDetail
            )
        }
    }
}

// MARK: ToolBar
private extension DetailView {
    func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                Button {
                    if let galleryURL = store.gallery.galleryURL,
                       let archiveURL = store.galleryDetail?.archiveURL
                    {
                        store.send(.setNavigation(.archives(galleryURL, archiveURL)))
                    }
                } label: {
                    Label(L10n.Localizable.DetailView.ToolbarItem.Button.archives, systemSymbol: .docZipper)
                }
                .disabled(store.galleryDetail?.archiveURL == nil || !CookieUtil.didLogin)
                Button {
                    store.send(.setNavigation(.torrents()))
                } label: {
                    let base = L10n.Localizable.DetailView.ToolbarItem.Button.torrents
                    let torrentCount = store.galleryDetail?.torrentCount ?? 0
                    let baseWithCount = [base, "(\(torrentCount))"].joined(separator: " ")
                    Label(torrentCount > 0 ? baseWithCount : base, systemSymbol: .leaf)
                }
                .disabled((store.galleryDetail?.torrentCount ?? 0 > 0) != true)
                Button {
                    if let galleryURL = store.gallery.galleryURL {
                        store.send(.setNavigation(.share(galleryURL)))
                    }
                } label: {
                    Label(L10n.Localizable.DetailView.ToolbarItem.Button.share, systemSymbol: .squareAndArrowUp)
                }
            }
            .disabled(store.galleryDetail == nil || store.loadingState == .loading)
        }
    }
}

// MARK: HeaderSection
private struct HeaderSection: View {
    @ObservedObject private var downloadStore = DownloadBadgeStore.shared

    private let gallery: Gallery
    private let galleryDetail: GalleryDetail
    private let user: User
    private let downloadBadge: DownloadBadge
    private let isPreparingDownload: Bool
    private let canDownload: Bool
    private let displaysJapaneseTitle: Bool
    private let showFullTitle: Bool
    private let showFullTitleAction: () -> Void
    private let downloadAction: () -> Void
    private let favorAction: (Int) -> Void
    private let unfavorAction: () -> Void
    private let navigateReadingAction: () -> Void
    private let navigateUploaderAction: () -> Void

    private let actionIconButtonSize: CGFloat = 32
    private let actionIconFont: Font = .system(size: 16, weight: .semibold)

    init(
        gallery: Gallery, galleryDetail: GalleryDetail,
        user: User, downloadBadge: DownloadBadge, isPreparingDownload: Bool, canDownload: Bool,
        displaysJapaneseTitle: Bool, showFullTitle: Bool,
        showFullTitleAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void,
        favorAction: @escaping (Int) -> Void,
        unfavorAction: @escaping () -> Void,
        navigateReadingAction: @escaping () -> Void,
        navigateUploaderAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.user = user
        self.downloadBadge = downloadBadge
        self.isPreparingDownload = isPreparingDownload
        self.canDownload = canDownload
        self.displaysJapaneseTitle = displaysJapaneseTitle
        self.showFullTitle = showFullTitle
        self.showFullTitleAction = showFullTitleAction
        self.downloadAction = downloadAction
        self.favorAction = favorAction
        self.unfavorAction = unfavorAction
        self.navigateReadingAction = navigateReadingAction
        self.navigateUploaderAction = navigateUploaderAction
    }

    private var title: String {
        let normalTitle = galleryDetail.title
        return displaysJapaneseTitle ? galleryDetail.jpnTitle ?? normalTitle : normalTitle
    }
    private var downloadButtonTint: Color {
        switch downloadBadge {
        case .updateAvailable:
            return .orange
        case .downloaded:
            return .red
        case .partial:
            return .orange
        case .failed, .missingFiles:
            return .red
        default:
            return .accentColor
        }
    }
    private var downloadButtonAccessibilityLabel: String {
        guard canDownload else { return L10n.Localizable.DetailView.Accessibility.downloadButtonLogin }
        guard !showsMetadataPreparation else {
            return L10n.Localizable.DetailView.Accessibility.downloadButtonPreparing
        }
        switch downloadBadge {
        case .none:
            return L10n.Localizable.DetailView.Accessibility.downloadButtonDownload
        case .queued:
            return L10n.Localizable.DetailView.Accessibility.downloadButtonQueued
        case .downloading(let completed, let total):
            let progress = L10n.Localizable.DetailView.Accessibility.downloadButtonDownloading(
                completed,
                max(total, 1)
            )
            return [progress, L10n.Localizable.DetailView.Accessibility.downloadButtonPauseAction]
                .joined(separator: ". ")
        case .paused(let completed, let total):
            return L10n.Localizable.DetailView.Accessibility.downloadButtonPaused(
                completed,
                max(total, 1)
            )
        case .downloaded:
            return L10n.Localizable.DetailView.Accessibility.downloadButtonDownloaded
        case .updateAvailable:
            return L10n.Localizable.DetailView.Accessibility.downloadButtonUpdate
        case .partial(let completed, let total):
            return L10n.Localizable.DetailView.Accessibility.downloadButtonPartial(
                completed,
                max(total, 1)
            )
        case .failed:
            return L10n.Localizable.DetailView.Accessibility.downloadButtonRetry
        case .missingFiles:
            return L10n.Localizable.DetailView.Accessibility.downloadButtonRepair
        }
    }
    private var showsMetadataPreparation: Bool {
        isPreparingDownload && downloadBadge == .none
    }
    private var queuedDownloadProgress: Double? {
        if case .queued = downloadBadge {
            return 0
        }
        return nil
    }
    private var activeDownloadProgress: Double? {
        if case .downloading(let completed, let total) = downloadBadge {
            return Double(completed) / Double(max(total, 1))
        }
        if case .paused(let completed, let total) = downloadBadge {
            return Double(completed) / Double(max(total, 1))
        }
        return nil
    }
    private var activeDownloadIconSystemName: String {
        switch downloadBadge {
        case .paused:
            return "play.fill"
        case .downloading:
            return "pause.fill"
        default:
            return downloadIconSystemName
        }
    }
    private var downloadIconSystemName: String {
        switch downloadBadge {
        case .downloaded:
            return "trash"
        case .updateAvailable:
            return "arrow.triangle.2.circlepath"
        case .partial:
            return "exclamationmark.circle"
        case .failed:
            return "exclamationmark.circle"
        case .missingFiles:
            return "wrench.and.screwdriver"
        case .paused:
            return "play.fill"
        default:
            return "icloud.and.arrow.down"
        }
    }
    private var isDownloadActionDisabled: Bool {
        guard canDownload else { return true }
        return isPreparingDownload
    }
    private var categoryLabel: some View {
        CategoryLabel(
            text: gallery.category.value,
            color: gallery.color,
            font: .headline,
            insets: .init(top: 2, leading: 4, bottom: 2, trailing: 4),
            cornerRadius: 3
        )
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    private var downloadButton: some View {
        Group {
            if let progress = activeDownloadProgress {
                Button(action: downloadAction) {
                    progressIndicator(
                        progress: progress,
                        isDeterminate: true,
                        centerSystemName: activeDownloadIconSystemName
                    )
                }
                .buttonStyle(.plain)
            } else if let progress = queuedDownloadProgress {
                Button(action: downloadAction) {
                    progressIndicator(
                        progress: progress,
                        isDeterminate: false,
                        centerSystemName: activeDownloadIconSystemName
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: downloadAction) {
                    Image(systemName: downloadIconSystemName)
                        .font(actionIconFont)
                        .foregroundStyle(canDownload ? downloadButtonTint : .secondary)
                        .rotationEffect(.degrees(showsMetadataPreparation ? 360 : 0))
                        .frame(width: actionIconButtonSize, height: actionIconButtonSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
                .animation(
                    showsMetadataPreparation
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                        : .default,
                    value: showsMetadataPreparation
                )
            }
        }
        .disabled(isDownloadActionDisabled)
        .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        .accessibilityLabel(downloadButtonAccessibilityLabel)
    }
    private var favoriteButton: some View {
        ZStack {
            Button(action: unfavorAction) {
                Image(systemSymbol: .heartFill)
                    .font(actionIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            .opacity(galleryDetail.isFavorited ? 1 : 0)

            Menu {
                ForEach(0..<10) { index in
                    Button(user.getFavoriteCategory(index: index)) {
                        favorAction(index)
                    }
                }
            } label: {
                Image(systemSymbol: .heart)
                    .font(actionIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            .opacity(galleryDetail.isFavorited ? 0 : 1)
        }
        .foregroundStyle(.tint)
        .buttonStyle(.glass(.regular.interactive()))
        .buttonBorderShape(.circle)
        .disabled(!CookieUtil.didLogin)
    }
    private var readButton: some View {
        Button(action: navigateReadingAction) {
            Image(systemSymbol: .bookFill)
                .font(actionIconFont)
                .foregroundStyle(.white)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel(L10n.Localizable.DetailView.Button.read)
    }
    private func progressIndicator(
        progress: Double,
        isDeterminate: Bool,
        centerSystemName: String
    ) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
                )

            if isDeterminate {
                Circle()
                    .stroke(downloadButtonTint.opacity(0.18), lineWidth: 2.5)
                    .padding(3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        downloadButtonTint,
                        style: .init(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(3)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(downloadButtonTint)
                    .controlSize(.small)
            }

            Image(systemName: centerSystemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(downloadButtonTint)
        }
        .frame(width: actionIconButtonSize, height: actionIconButtonSize)
    }
    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                downloadButton
                favoriteButton
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    downloadButton
                    favoriteButton
                }
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .trailing, spacing: 6) {
                downloadButton
                favoriteButton
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
    }
    private var bottomActionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                categoryLabel
                Spacer(minLength: 8)
                actionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                categoryLabel
                actionButtons
            }
        }
    }

    private var resolvedCoverURL: URL? {
        downloadStore.resolvedCoverURL(for: gallery)
    }

    var body: some View {
        HStack {
            KFImage(resolvedCoverURL)
                .placeholder({ Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) })
                .defaultModifier()
                .scaledToFit()
                .frame(
                    width: Defaults.ImageSize.headerW,
                    height: Defaults.ImageSize.headerH
                )

            VStack(alignment: .leading) {
                Button(action: showFullTitleAction) {
                    Text(title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.leading)
                        .tint(.primary)
                        .lineLimit(showFullTitle ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(gallery.uploader ?? "", action: navigateUploaderAction)
                    .lineLimit(1)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                bottomActionRow
            }
            .padding(.horizontal, 10)
            .frame(minHeight: Defaults.ImageSize.headerH)
        }
    }
}

// MARK: DescriptionSection
private struct DescriptionSection: View {
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail
    private let navigateGalleryInfosAction: () -> Void

    init(
        gallery: Gallery, galleryDetail: GalleryDetail,
        navigateGalleryInfosAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.navigateGalleryInfosAction = navigateGalleryInfosAction
    }

    private var infos: [DescScrollInfo] {[
        DescScrollInfo(
            title: L10n.Localizable.DetailView.DescriptionSection.Title.favorited,
            description: L10n.Localizable.DetailView.DescriptionSection.Description.favorited,
            value: .init(galleryDetail.favoritedCount)
        ),
        DescScrollInfo(
            title: L10n.Localizable.DetailView.DescriptionSection.Title.language,
            description: galleryDetail.language.value,
            value: galleryDetail.language.abbreviation
        ),
        DescScrollInfo(
            title: L10n.Localizable.DetailView.DescriptionSection.Title.ratings("\(galleryDetail.ratingCount)"),
            description: .init(), value: .init(), rating: galleryDetail.rating, isRating: true
        ),
        DescScrollInfo(
            title: L10n.Localizable.DetailView.DescriptionSection.Title.pageCount,
            description: L10n.Localizable.DetailView.DescriptionSection.Description.pageCount,
            value: .init(galleryDetail.pageCount)
        ),
        DescScrollInfo(
            title: L10n.Localizable.DetailView.DescriptionSection.Title.fileSize,
            description: galleryDetail.sizeType, value: .init(galleryDetail.sizeCount)
        )
    ]}
    private var itemWidth: Double {
        max(DeviceUtil.absWindowW / 5, 80)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(infos) { info in
                    Group {
                        if info.isRating {
                            DescScrollRatingItem(title: info.title, rating: info.rating)
                        } else {
                            DescScrollItem(title: info.title, value: info.value, description: info.description)
                        }
                    }
                    .frame(width: itemWidth).drawingGroup()
                    Divider()
                    if info == infos.last {
                        Button(action: navigateGalleryInfosAction) {
                            Image(systemSymbol: .ellipsis)
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(width: itemWidth)
                    }
                }
                .withHorizontalSpacing()
            }
        }
        .frame(height: 60)
    }
}

private extension DescriptionSection {
    struct DescScrollInfo: Identifiable, Equatable {
        var id: String { title }

        let title: String
        let description: String
        let value: String
        var rating: Float = 0
        var isRating = false
    }
    struct DescScrollItem: View {
        private let title: String
        private let value: String
        private let description: String

        init(title: String, value: String, description: String) {
            self.title = title
            self.value = value
            self.description = description
        }

        var body: some View {
            VStack(spacing: 3) {
                Text(title).textCase(.uppercase).font(.caption)
                Text(value).fontWeight(.medium).font(.title3).lineLimit(1)
                Text(description).font(.caption)
            }
        }
    }
    struct DescScrollRatingItem: View {
        private let title: String
        private let rating: Float

        init(title: String, rating: Float) {
            self.title = title
            self.rating = rating
        }

        var body: some View {
            VStack(spacing: 3) {
                Text(title).textCase(.uppercase).font(.caption).lineLimit(1)
                Text(String(format: "%.2f", rating)).fontWeight(.medium).font(.title3)
                RatingView(rating: rating).font(.system(size: 12)).foregroundStyle(.primary)
            }
        }
    }
}

// MARK: ActionSection
private struct ActionSection: View {
    private let galleryDetail: GalleryDetail
    private let userRating: Int
    private let showUserRating: Bool
    private let showUserRatingAction: () -> Void
    private let updateRatingAction: (DragGesture.Value) -> Void
    private let confirmRatingAction: (DragGesture.Value) -> Void
    private let navigateSimilarGalleryAction: () -> Void

    init(
        galleryDetail: GalleryDetail,
        userRating: Int, showUserRating: Bool,
        showUserRatingAction: @escaping () -> Void,
        updateRatingAction: @escaping (DragGesture.Value) -> Void,
        confirmRatingAction: @escaping (DragGesture.Value) -> Void,
        navigateSimilarGalleryAction: @escaping () -> Void
    ) {
        self.galleryDetail = galleryDetail
        self.userRating = userRating
        self.showUserRating = showUserRating
        self.showUserRatingAction = showUserRatingAction
        self.updateRatingAction = updateRatingAction
        self.confirmRatingAction = confirmRatingAction
        self.navigateSimilarGalleryAction = navigateSimilarGalleryAction
    }

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button(action: showUserRatingAction) {
                        Spacer()
                        Image(systemSymbol: .squareAndPencil)
                        Text(L10n.Localizable.DetailView.ActionSection.Button.giveARating).bold()
                        Spacer()
                    }
                    .disabled(!CookieUtil.didLogin)
                    Button(action: navigateSimilarGalleryAction) {
                        Spacer()
                        Image(systemSymbol: .photoOnRectangleAngled)
                        Text(L10n.Localizable.DetailView.ActionSection.Button.similarGallery).bold()
                        Spacer()
                    }
                }
                .font(.callout).foregroundStyle(.primary)
            }
            if showUserRating {
                HStack {
                    RatingView(rating: Float(userRating) / 2)
                        .font(.system(size: 24))
                        .foregroundStyle(.yellow)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged(updateRatingAction)
                                .onEnded(confirmRatingAction)
                        )
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: TagsSection
private struct TagsSection: View {
    private let tags: [GalleryTag]
    private let showsImages: Bool
    private let voteTagAction: (String, Int) -> Void
    private let navigateSearchAction: (String) -> Void
    private let navigateTagDetailAction: (TagDetail) -> Void
    private let translateAction: (String) -> (String, TagTranslation?)

    init(
        tags: [GalleryTag], showsImages: Bool,
        voteTagAction: @escaping (String, Int) -> Void,
        navigateSearchAction: @escaping (String) -> Void,
        navigateTagDetailAction: @escaping (TagDetail) -> Void,
        translateAction: @escaping (String) -> (String, TagTranslation?)
    ) {
        self.tags = tags
        self.showsImages = showsImages
        self.voteTagAction = voteTagAction
        self.navigateSearchAction = navigateSearchAction
        self.navigateTagDetailAction = navigateTagDetailAction
        self.translateAction = translateAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(
                    tag: tag, showsImages: showsImages,
                    voteTagAction: voteTagAction,
                    navigateSearchAction: navigateSearchAction,
                    navigateTagDetailAction: navigateTagDetailAction,
                    translateAction: translateAction
                )
            }
        }
        .padding(.horizontal)
    }
}

private extension TagsSection {
    struct TagRow: View {
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.inSheet) private var inSheet

        private let tag: GalleryTag
        private let showsImages: Bool
        private let voteTagAction: (String, Int) -> Void
        private let navigateSearchAction: (String) -> Void
        private let navigateTagDetailAction: (TagDetail) -> Void
        private let translateAction: (String) -> (String, TagTranslation?)

        init(
            tag: GalleryTag, showsImages: Bool,
            voteTagAction: @escaping (String, Int) -> Void,
            navigateSearchAction: @escaping (String) -> Void,
            navigateTagDetailAction: @escaping (TagDetail) -> Void,
            translateAction: @escaping (String) -> (String, TagTranslation?)
        ) {
            self.tag = tag
            self.showsImages = showsImages
            self.voteTagAction = voteTagAction
            self.navigateSearchAction = navigateSearchAction
            self.navigateTagDetailAction = navigateTagDetailAction
            self.translateAction = translateAction
        }

        private var reversedPrimary: Color {
            colorScheme == .light ? .white : .black
        }
        private var backgroundColor: Color {
            inSheet && colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5)
        }
        private var padding: EdgeInsets {
            .init(top: 5, leading: 14, bottom: 5, trailing: 14)
        }

        var body: some View {
            HStack(alignment: .top) {
                Text(tag.namespace?.value ?? tag.rawNamespace).font(.subheadline.bold())
                    .foregroundColor(reversedPrimary).padding(padding)
                    .background(Color(.systemGray)).cornerRadius(5)
                TagCloudView(data: tag.contents) { content in
                    let (_, translation) = translateAction(content.rawNamespace + content.text)
                    Button {
                        navigateSearchAction(content.serachKeyword(tag: tag))
                    } label: {
                        TagCloudCell(
                            text: translation?.displayValue ?? content.text,
                            imageURL: translation?.valueImageURL,
                            showsImages: showsImages,
                            font: .subheadline, padding: padding, textColor: .primary,
                            backgroundColor: backgroundColor
                        )
                    }
                    .contextMenu {
                        if let translation = translation,
                            let description = translation.descriptionPlainText,
                            !description.isEmpty
                        {
                            Button {
                                navigateTagDetailAction(.init(
                                    title: translation.displayValue, description: description,
                                    imageURLs: translation.descriptionImageURLs,
                                    links: translation.links
                                ))
                            } label: {
                                Image(systemSymbol: .docRichtext)
                                Text(L10n.Localizable.DetailView.ContextMenu.Button.detail)
                            }
                        }
                        if CookieUtil.didLogin {
                            if content.isVotedUp || content.isVotedDown {
                                Button {
                                    voteTagAction(content.voteKeyword(tag: tag), content.isVotedUp ? -1 : 1)
                                } label: {
                                    Image(systemSymbol: content.isVotedUp ? .handThumbsup : .handThumbsdown)
                                        .symbolVariant(.fill)
                                    Text(L10n.Localizable.DetailView.ContextMenu.Button.withdrawVote)
                                }
                            } else {
                                Button {
                                    voteTagAction(content.voteKeyword(tag: tag), 1)
                                } label: {
                                    Image(systemSymbol: .handThumbsup)
                                    Text(L10n.Localizable.DetailView.ContextMenu.Button.voteUp)
                                }
                                Button {
                                    voteTagAction(content.voteKeyword(tag: tag), -1)
                                } label: {
                                    Image(systemSymbol: .handThumbsdown)
                                    Text(L10n.Localizable.DetailView.ContextMenu.Button.voteDown)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: PreviewSection
private struct PreviewsSection: View {
    private let pageCount: Int
    private let previewURLs: [Int: URL]
    private let navigatePreviewsAction: () -> Void
    private let navigateReadingAction: (Int) -> Void

    init(
        pageCount: Int, previewURLs: [Int: URL],
        navigatePreviewsAction: @escaping () -> Void,
        navigateReadingAction: @escaping (Int) -> Void
    ) {
        self.pageCount = pageCount
        self.previewURLs = previewURLs
        self.navigatePreviewsAction = navigatePreviewsAction
        self.navigateReadingAction = navigateReadingAction
    }

    private var width: CGFloat {
        Defaults.ImageSize.previewAvgW
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.previewAspect
    }

    var body: some View {
        SubSection(
            title: L10n.Localizable.DetailView.Section.Title.previews,
            showAll: pageCount > 20, showAllAction: navigatePreviewsAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(previewURLs.tuples.sorted(by: { $0.0 < $1.0 }), id: \.0) { index, previewURL in
                        Button {
                            navigateReadingAction(index)
                        } label: {
                            PreviewImageView(originalURL: previewURL)
                                .frame(width: width, height: height)
                        }
                    }
                    .withHorizontalSpacing(height: height)
                }
            }
        }
    }
}

// MARK: CommentsSection
private struct CommentsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.inSheet) private var inSheet

    private let comments: [GalleryComment]
    private let navigateCommentAction: () -> Void
    private let navigatePostCommentAction: () -> Void

    init(
        comments: [GalleryComment],
        navigateCommentAction: @escaping () -> Void,
        navigatePostCommentAction: @escaping () -> Void
    ) {
        self.comments = comments
        self.navigateCommentAction = navigateCommentAction
        self.navigatePostCommentAction = navigatePostCommentAction
    }

    private var backgroundColor: Color {
        inSheet && colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }

    var body: some View {
        SubSection(
            title: L10n.Localizable.DetailView.Section.Title.comments,
            showAll: !comments.isEmpty, showAllAction: navigateCommentAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(min(comments.count, 6))) { comment in
                        CommentCell(comment: comment, backgroundColor: backgroundColor)
                    }
                    .withHorizontalSpacing()
                }
                .drawingGroup()
            }
            CommentButton(backgroundColor: backgroundColor, action: navigatePostCommentAction)
                .padding(.horizontal).disabled(!CookieUtil.didLogin)
        }
    }
}

private struct CommentCell: View {
    private let comment: GalleryComment
    private let backgroundColor: Color

    init(comment: GalleryComment, backgroundColor: Color) {
        self.comment = comment
        self.backgroundColor = backgroundColor
    }

    private var content: String {
        comment.contents
            .filter({ [.plainText, .linkedText].contains($0.type) })
            .compactMap(\.text).joined()
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author).font(.subheadline.bold())
                Spacer()
                Group {
                    ZStack {
                        Image(systemSymbol: .handThumbsupFill)
                            .opacity(comment.votedUp ? 1 : 0)
                        Image(systemSymbol: .handThumbsdownFill)
                            .opacity(comment.votedDown ? 1 : 0)
                    }
                    Text(comment.score ?? "")
                    Text(comment.formattedDateString).lineLimit(1)
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            .minimumScaleFactor(0.75).lineLimit(1)
            Text(content).padding(.top, 1)
            Spacer()
        }
        .padding().background(backgroundColor)
        .frame(width: 300, height: 120)
        .cornerRadius(15)
    }
}

private struct CommentButton: View {
    private let backgroundColor: Color
    private let action: () -> Void

    init(backgroundColor: Color, action: @escaping () -> Void) {
        self.backgroundColor = backgroundColor
        self.action = action
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15)

        Button(action: action) {
            HStack {
                Image(systemSymbol: .squareAndPencil)

                Text(L10n.Localizable.DetailView.Button.postComment)
                    .bold()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .clipShape(shape)
        }
        .glassEffect(.clear.interactive(), in: shape)
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
