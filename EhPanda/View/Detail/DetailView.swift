//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import Kingfisher

struct DetailView: View, PersistenceAccessor {
//    @EnvironmentObject var store: DeprecatedStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var keyword = ""
    @State private var commentContent = ""
    @State private var commentViewScrollID = ""
    @State private var isReadingLinkActive = false
    @State private var isCommentsLinkActive = false
    @State private var isTorrentsLinkActive = false
    @State private var isAssociatedLinkActive = false

    let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: DetailView
    var body: some View {
        ZStack {
            if let detail = galleryDetail {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
//                        HeaderView(
//                            gallery: gallery, detail: detail,
//                            favoriteNames: user.favoriteNames,
//                            addFavAction: { store.dispatch(.favorGallery(gid: gid, favIndex: $0)) },
//                            deleteFavAction: { store.dispatch(.unfavorGallery(gid: gid)) },
//                            onUploaderTapAction: tryNavigateToUploader
//                        )
//                        .padding(.horizontal)
                        DescScrollView(gallery: gallery, detail: detail)
                        ActionRow(
                            detail: detail,
                            ratingAction: rateGallery,
                            galleryAction: tryNavigateToSimilarGallery
                        )
//                        if !galleryState.tags.isEmpty {
//                            TagsView(
//                                tags: galleryState.tags,
//                                onTapAction: navigateToAssociatedView,
//                                translateAction: {
//                                    settings.tagTranslator.tryTranslate(
//                                        text: $0, returnOriginal: !setting.translatesTags
//                                    )
//                                }
//                            )
//                            .padding(.horizontal)
//                        }
//                        PreviewView(
//                            gid: gid, previews: detailInfo.previews[gid] ?? [:],
//                            pageCount: detail.pageCount, tapAction: navigateToReading,
//                            fetchAction: { store.dispatch(.fetchGalleryPreviews(gid: gid, index: $0)) }
//                        )
                        CommentScrollView(
                            gid: gid, comments: galleryState.comments,
                            toggleCommentAction: { presentSheet(state: .comment) }
                        )
                    }
                    .padding(.bottom, 20)
                    .padding(.top, -25)
                }
            }
//            else if detailInfo.detailLoading[gid] == true {
//                LoadingView()
//            } else if let error = detailInfo.detailLoadErrors[gid] {
//                switch error {
//                case .copyrightClaim, .expunged:
//                    ErrorView(error: error)
//                default:
//                    ErrorView(error: error, retryAction: fetchGalleryDetail)
//                }
//            }
        }
        .onAppear(perform: onStartTasks).onDisappear(perform: onEndTasks)
//        .navigationBarHidden(environment.navigationBarHidden)
//        .sheet(item: $store.appState.environment.detailViewSheetState, content: sheet)
        .background(content: navigationLinks).toolbar(content: toolbar)
    }
}

private extension DetailView {
    // MARK: NavigationLinks
    @ViewBuilder func navigationLinks() -> some View {
        NavigationLink("", destination: ReadingView(gid: gid), isActive: $isReadingLinkActive)
        NavigationLink(
            "", destination: CommentView(gid: gid, comments: galleryState.comments, scrollID: commentViewScrollID),
            isActive: $isCommentsLinkActive
        )
        NavigationLink("", destination: TorrentsView(gid: gid, token: gallery.token), isActive: $isTorrentsLinkActive)
        NavigationLink("", destination: AssociatedView(keyword: keyword), isActive: $isAssociatedLinkActive)
    }
    // MARK: Sheet
    func sheet(item: DetailViewSheetState) -> some View {
        Group {
            switch item {
            case .archive:
                ArchiveView(gid: gid)
            case .comment:
                DraftCommentView(
                    content: $commentContent,
                    title: "Post Comment",
                    postAction: postComment,
                    cancelAction: { presentSheet(state: nil) }
                )
            }
        }
//        .accentColor(accentColor)
//        .blur(radius: environment.blurRadius)
//        .allowsHitTesting(environment.isAppUnlocked)
    }
    // MARK: Toolbar
    func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    presentSheet(state: .archive)
                } label: {
                    Label("Archive", systemImage: "doc.zipper")
                }
                .disabled(galleryDetail?.archiveURL == nil || !CookiesUtil.didLogin)
                Button {
                    isTorrentsLinkActive.toggle()
                } label: {
                    Label(
                        "Torrents".localized + (
                            galleryDetail?.torrentCount ?? 0 > 0
                            ? " (\(galleryDetail?.torrentCount ?? 0))" : ""
                        ),
                        systemImage: "leaf"
                    )
                }
                .disabled((galleryDetail?.torrentCount ?? 0 > 0) != true)
                Button {
                    guard let data = URL(string: gallery.galleryURL) else { return }
                    AppUtil.presentActivity(items: [data])
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
//            .disabled(galleryDetail == nil || detailInfo.detailLoading[gid] == true)
        }
    }
}

// MARK: Private Methods
private extension DetailView {
    // MARK: Life Cycle
    func onStartTasks() {
//        if environment.navigationBarHidden {
//            store.dispatch(.setNavigationBarHidden(false))
//        }
//        store.dispatch(.fulfillGalleryPreviews(gid: gid))
//        store.dispatch(.fulfillGalleryContents(gid: gid))
        PersistenceController.updateLastOpenDate(gid: gid)

        fetchGalleryDetail()
        updateViewControllersCount()
        detectNavigations()
    }
    func onEndTasks() {
        updateViewControllersCount()
        NotificationUtil.post(.readingViewShouldHideStatusBar)
    }

    // MARK: Navigation
    func detectNavigations() {
//        if let pageIndex = detailInfo.pendingJumpPageIndices[gid] {
//            store.dispatch(.setPendingJumpInfos(gid: gid, pageIndex: nil, commentID: nil))
//            store.dispatch(.setReadingProgress(gid: gid, tag: pageIndex))
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
//                isReadingLinkActive.toggle()
//            }
//        }
//        if let commentID = detailInfo.pendingJumpCommentIDs[gid] {
//            store.dispatch(.setPendingJumpInfos(gid: gid, pageIndex: nil, commentID: nil))
//            commentViewScrollID = commentID
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
//                isCommentsLinkActive.toggle()
//            }
//        }
    }
    func navigateToAssociatedView(_ keyword: String) {
        self.keyword = keyword
        isAssociatedLinkActive.toggle()
    }
    func tryNavigateToUploader() {
        guard let uploader = galleryDetail?.uploader else { return }
        navigateToAssociatedView("uploader:" + "\"\(uploader)\"")
    }
    func tryNavigateToSimilarGallery() {
        guard let title = galleryDetail?.trimmedTitle else { return }
        navigateToAssociatedView(title)
    }
    func navigateToReading(index: Int, triggersLink: Bool) {
//        store.dispatch(.setReadingProgress(gid: gid, tag: index))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationUtil.post(.readingViewShouldHideStatusBar)
        }

        guard triggersLink else { return }
        isReadingLinkActive.toggle()
    }

    // MARK: Tools
    func rateGallery(value: Int) {
//        store.dispatch(.rateGallery(gid: gid, rating: value))
    }
    func postComment() {
//        store.dispatch(.commentGallery(gid: gid, content: commentContent))
        presentSheet(state: nil)
        commentContent = ""
    }
    func presentSheet(state: DetailViewSheetState?) {
//        store.dispatch(.setDetailViewSheetState(state))
    }
    func updateViewControllersCount() {
//        store.dispatch(.setViewControllersCount)
    }
    func fetchGalleryDetail() {
//        store.dispatch(.fetchGalleryDetail(gid: gid))
    }
}

// MARK: HeaderView
private struct HeaderView: View {
    private let gallery: Gallery
    private let detail: GalleryDetail
    private let favoriteNames: [Int: String]?
    private let addFavAction: (Int) -> Void
    private let deleteFavAction: () -> Void
    private let onUploaderTapAction: () -> Void

    init(
        gallery: Gallery,
        detail: GalleryDetail,
        favoriteNames: [Int: String]?,
        addFavAction: @escaping (Int) -> Void,
        deleteFavAction: @escaping () -> Void,
        onUploaderTapAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.detail = detail
        self.favoriteNames = favoriteNames
        self.addFavAction = addFavAction
        self.deleteFavAction = deleteFavAction
        self.onUploaderTapAction = onUploaderTapAction
    }

    var body: some View {
        HStack {
            KFImage(URL(string: gallery.coverURL))
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                .defaultModifier().scaledToFit().frame(width: width, height: height)
            VStack(alignment: .leading) {
                Text(title).font(.title3.bold()).lineLimit(3)
                Button(gallery.uploader ?? "", action: onUploaderTapAction)
                    .lineLimit(1).font(.callout).foregroundStyle(.secondary)
                Spacer()
                HStack {
                    CategoryLabel(
                        text: gallery.category.rawValue.localized, color: gallery.color,
                        font: .headline, insets: .init(top: 2, leading: 4, bottom: 2, trailing: 4),
                        cornerRadius: 3
                    )
                    Spacer()
                    ZStack {
                        Button(action: deleteFavAction) {
                            Image(systemName: "heart.fill").foregroundStyle(.tint).imageScale(.large)
                        }
                        .opacity(detail.isFavored ? 1 : 0)
                        Menu {
//                            ForEach(0..<10) { index in
//                                Button(User.getFavNameFrom(index: index, names: favoriteNames)) {
//                                    addFavAction(index)
//                                }
//                            }
                        } label: {
                            Image(systemName: "heart").imageScale(.large).foregroundStyle(.tint)
                        }
                        .opacity(detail.isFavored ? 0 : 1)
                    }
                    .disabled(!CookiesUtil.didLogin)
                    Button(action: {}, label: {
                        NavigationLink(destination: { ReadingView(gid: gallery.gid) }, label: {
                            Text("Read".localized).bold().textCase(.uppercase)
                                .font(.headline).foregroundColor(.white)
                                .padding(.vertical, -2).padding(.horizontal, 2)
                                .lineLimit(1)
                        })
                    })
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                }
                .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 10)
            .frame(height: height)
        }
    }
}

private extension HeaderView {
    var width: CGFloat {
        Defaults.ImageSize.headerW
    }
    var height: CGFloat {
        Defaults.ImageSize.headerH
    }
    var title: String {
        if let jpnTitle = detail.jpnTitle {
            return jpnTitle
        } else {
            return detail.title
        }
    }
}

// MARK: DescScrollView
private struct DescScrollView: View {
    struct DescScrollInfo: Identifiable, Equatable {
        var id: Int { title.hashValue }

        let title: String
        var titleKey: LocalizedStringKey = ""
        let numeral: String
        let value: String
        var rating: Float = 0
        var isRating = false
    }

    @State private var itemWidth = max(DeviceUtil.absWindowW / 5, 80)

    private let gallery: Gallery
    private let detail: GalleryDetail
    private var infos: [DescScrollInfo] {
        [
            DescScrollInfo(
                title: "DESC_SCROLL_ITEM_FAVORITED", numeral: "Times",
                value: String(detail.favoredCount)
            ),
            DescScrollInfo(
                title: "Language",
                numeral: detail.language.name,
                value: detail.languageAbbr
            ),
            DescScrollInfo(
                title: "",
                titleKey: LocalizedStringKey(
                    "\(detail.ratingCount) Ratings"
                ),
                numeral: "", value: "",
                rating: detail.rating, isRating: true
            ),
            DescScrollInfo(
                title: "Page Count", numeral: "Pages",
                value: String(detail.pageCount)
            ),
            DescScrollInfo(
                title: "File Size", numeral: detail.sizeType,
                value: String(detail.sizeCount)
            )
        ]
    }

    init(gallery: Gallery, detail: GalleryDetail) {
        self.gallery = gallery
        self.detail = detail
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(infos) { info in
                    Group {
                        if info.isRating {
                            DescScrollRatingItem(
                                titleKey: info.titleKey,
                                rating: info.rating
                            )
                        } else {
                            DescScrollItem(
                                title: info.title,
                                value: info.value,
                                numeral: info.numeral
                            )
                        }
                    }
                    .frame(width: itemWidth).drawingGroup()
                    Divider()
                    if info == infos.last {
                        NavigationLink(
                            destination: GalleryInfosView(
                                gallery: gallery, detail: detail
                            )
                        ) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(width: itemWidth)
                    }
                }
                .withHorizontalSpacing()
            }
        }
        .frame(height: 60)
        .onReceive(AppNotification.appWidthDidChange.publisher, perform: tryResetItemWidth)
    }

    private func tryResetItemWidth(_: Any? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard itemWidth != max(DeviceUtil.absWindowW / 5, 80) else { return }
            withAnimation { itemWidth = max(DeviceUtil.absWindowW / 5, 80) }
        }
    }
}

private struct DescScrollItem: View {
    private let title: String
    private let value: String
    private let numeral: String

    init(title: String, value: String, numeral: String) {
        self.title = title
        self.value = value
        self.numeral = numeral
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(title.localized).textCase(.uppercase).font(.caption)
            Text(value).fontWeight(.medium).font(.title3).lineLimit(1)
            Text(numeral.localized).font(.caption)
        }
    }
}

private struct DescScrollRatingItem: View {
    private let titleKey: LocalizedStringKey
    private let rating: Float

    init(titleKey: LocalizedStringKey, rating: Float) {
        self.titleKey = titleKey
        self.rating = rating
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(titleKey).textCase(.uppercase).font(.caption).lineLimit(1)
            Text(String(format: "%.2f", rating)).fontWeight(.medium).font(.title3)
            RatingView(rating: rating).font(.system(size: 12)).foregroundStyle(.primary)
        }
    }
}

// MARK: ActionRow
private struct ActionRow: View {
    @State private var showUserRating = false
    @State private var userRating: Int

    private let detail: GalleryDetail
    private let ratingAction: (Int) -> Void
    private let galleryAction: () -> Void

    init(
        detail: GalleryDetail,
        ratingAction: @escaping (Int) -> Void,
        galleryAction: @escaping () -> Void
    ) {
        self.detail = detail
        self.ratingAction = ratingAction
        self.galleryAction = galleryAction
        let userRating = Int(detail.userRating.halfRounded * 2)
        _userRating = State(initialValue: userRating)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged(updateRating)
            .onEnded(confirmRating)
    }

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button {
                        withAnimation { showUserRating.toggle() }
                    } label: {
                        Spacer()
                        Image(systemName: "square.and.pencil")
                        Text("Give a Rating").bold()
                        Spacer()
                    }
                    .disabled(!CookiesUtil.didLogin)
                    Button(action: galleryAction) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Similar Gallery").bold()
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
                        .gesture(dragGesture)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }
}

private extension ActionRow {
    func updateRating(value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
    func confirmRating(value: DragGesture.Value) {
        updateRating(value: value)
        ratingAction(userRating)
        HapticUtil.generateFeedback(style: .soft)
        withAnimation(Animation.default.delay(1)) {
            showUserRating.toggle()
        }
    }
}

// MARK: TagsView
private struct TagsView: View {
    private let tags: [GalleryTag]
    private let onTapAction: (String) -> Void
    private let translateAction: (String) -> String

    init(
        tags: [GalleryTag],
        onTapAction: @escaping (String) -> Void,
        translateAction: @escaping (String) -> String
    ) {
        self.tags = tags
        self.onTapAction = onTapAction
        self.translateAction = translateAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(
                    tag: tag, onTapAction: onTapAction,
                    translateAction: translateAction
                )
            }
        }
        .padding(.horizontal)
    }
}

private struct TagRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private let tag: GalleryTag
    private let onTapAction: (String) -> Void
    private let translateAction: (String) -> String
    private var reversePrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(
        tag: GalleryTag,
        onTapAction: @escaping (String) -> Void,
        translateAction: @escaping (String) -> String
    ) {
        self.tag = tag
        self.onTapAction = onTapAction
        self.translateAction = translateAction
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(tag.namespace.firstLetterCapitalized.localized).font(.subheadline.bold())
                .foregroundColor(reversePrimary).padding(.vertical, 5).padding(.horizontal, 14)
                .background(Rectangle().foregroundColor(Color(.systemGray))).cornerRadius(5)
            TagCloudView(
                tag: tag, font: .subheadline, textColor: .primary, backgroundColor: Color(.systemGray5),
                paddingV: 5, paddingH: 14, onTapAction: onTapAction, translateAction: translateAction
            )
        }
    }
}

// MARK: PreviewView
private struct PreviewView: View {
    private let gid: String
    private let previews: [Int: String]
    private let pageCount: Int
    private let tapAction: (Int, Bool) -> Void
    private let fetchAction: (Int) -> Void

    init(
        gid: String,
        previews: [Int: String],
        pageCount: Int,
        tapAction: @escaping (Int, Bool) -> Void,
        fetchAction: @escaping (Int) -> Void
    ) {
        self.gid = gid
        self.previews = previews
        self.pageCount = pageCount
        self.tapAction = tapAction
        self.fetchAction = fetchAction
    }

    private var width: CGFloat {
        Defaults.ImageSize.previewAvgW
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.previewAspect
    }

    var body: some View {
        EmptyView()
//        SubSection(
//            title: "Preview", showAll: pageCount > 20,
//            destination: MorePreviewView(
//                gid: gid, previews: previews, pageCount: pageCount,
//                tapAction: tapAction, fetchAction: fetchAction
//            )
//        ) {
//            ScrollView(.horizontal, showsIndicators: false) {
//                LazyHStack {
//                    ForEach(1..<min(pageCount + 1, 21)) { index in
//                        let (url, modifier) =
//                        PreviewResolver.getPreviewConfigs(
//                            originalURL: previews[index] ?? ""
//                        )
//                        KFImage.url(URL(string: url), cacheKey: previews[index])
//                            .placeholder {
//                                Placeholder(style: .activity(
//                                    ratio: Defaults.ImageSize
//                                        .previewAspect
//                                ))
//                            }
//                            .imageModifier(modifier)
//                            .fade(duration: 0.25)
//                            .resizable().scaledToFit()
//                            .frame(width: width, height: height)
//                            .onTapGesture { tapAction(index, true) }
//                    }
//                    .withHorizontalSpacing(height: height)
//                }
//            }
//        }
    }
}

// MARK: MorePreviewView
private struct MorePreviewView: View {
    @Environment(\.dismiss) var dismissAction

    @State private var isActive = false

    private let gid: String
    private let previews: [Int: String]
    private let pageCount: Int
    private let tapAction: (Int, Bool) -> Void
    private let fetchAction: (Int) -> Void

    init(
        gid: String,
        previews: [Int: String],
        pageCount: Int,
        tapAction: @escaping (Int, Bool) -> Void,
        fetchAction: @escaping (Int) -> Void
    ) {
        self.gid = gid
        self.previews = previews
        self.pageCount = pageCount
        self.tapAction = tapAction
        self.fetchAction = fetchAction
    }

    private var gridItems: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: Defaults.ImageSize.previewMinW,
                maximum: Defaults.ImageSize.previewMaxW
            ),
            spacing: 10
        )]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItems) {
                ForEach(1..<pageCount + 1) { index in
                    VStack {
                        let (url, modifier) =
                        PreviewResolver.getPreviewConfigs(
                            originalURL: previews[index] ?? ""
                        )
                        KFImage.url(URL(string: url), cacheKey: previews[index])
                            .placeholder {
                                Placeholder(style: .activity(
                                    ratio: Defaults.ImageSize
                                        .previewAspect
                                ))
                            }
                            .imageModifier(modifier)
                            .fade(duration: 0.25)
                            .resizable().scaledToFit()
                            .onTapGesture {
                                tapAction(index, false)
                                isActive = true
                            }
                        Text("\(index)")
                            .font(DeviceUtil.isPadWidth ? .callout : .caption)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        guard previews[index] == nil && (index - 1) % 20 == 0 else { return }
                        fetchAction(index)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background {
            NavigationLink(
                "",
                destination: ReadingView(gid: gid),
                isActive: $isActive
            )
        }
    }
}

// MARK: CommentScrollView
private struct CommentScrollView: View {
    private let gid: String
    private let comments: [GalleryComment]
    private let toggleCommentAction: () -> Void

    init(
        gid: String,
        comments: [GalleryComment],
        toggleCommentAction: @escaping () -> Void
    ) {
        self.gid = gid
        self.comments = comments
        self.toggleCommentAction = toggleCommentAction
    }

    var body: some View {
        EmptyView()
//        SubSection(
//            title: "Comment", showAll: !comments.isEmpty,
//            destination: CommentView(gid: gid, comments: comments)
//        ) {
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack {
//                    ForEach(comments.prefix(6)) { comment in
//                        CommentScrollCell(comment: comment)
//                    }
//                    .withHorizontalSpacing()
//                }
//                .drawingGroup()
//            }
//            CommentButton(action: toggleCommentAction).padding(.horizontal)
//                .disabled(!CookiesUtil.didLogin)
//        }
    }
}

private struct CommentScrollCell: View {
    private let comment: GalleryComment
    private var content: String {
        comment.contents
            .filter { [.plainText, .linkedText].contains($0.type) }
            .compactMap { $0.text }.joined()
    }

    init(comment: GalleryComment) {
        self.comment = comment
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author).font(.subheadline.bold())
                Spacer()
                Group {
                    ZStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .opacity(comment.votedUp ? 1 : 0)
                        Image(systemName: "hand.thumbsdown.fill")
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
        .padding().background(Color(.systemGray6))
        .frame(width: 300, height: 120)
        .cornerRadius(15)
    }
}

// MARK: Definition
enum DetailViewSheetState: Identifiable {
    var id: Int { hashValue }

    case archive
    case comment
}
