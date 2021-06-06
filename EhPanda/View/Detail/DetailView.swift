//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import Kingfisher

struct DetailView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme
    @State private var associatedKeyword = AssociatedKeyword()
    @State private var isAssociatedLinkActive = false

    private let gid: String
    private let depth: Int

    init(gid: String, depth: Int) {
        self.gid = gid
        self.depth = depth
    }

    // MARK: DetailView
    var body: some View {
        ZStack {
            NavigationLink(
                "",
                destination: AssociatedView(
                    depth: depth,
                    keyword: associatedKeyword
                ),
                isActive: $isAssociatedLinkActive
            )
            Group {
                if let detail = mangaDetail {
                    ScrollView(showsIndicators: false) {
                        VStack {
                            HeaderView(manga: manga, detail: detail)
                                .padding(.top, -40)
                                .padding(.bottom, 15)
                            Group {
                                DescScrollView(detail: detail)
                                if isTokenMatched {
                                    ActionRow(
                                        detail: detail,
                                        ratingAction: onUserRatingChanged
                                    ) {
                                        onSimilarGalleryTap(detail.title)
                                    }
                                }
                                if !detail.detailTags.isEmpty && isTokenMatched {
                                    TagsView(
                                        tags: detail.detailTags,
                                        onTapAction: onTagsViewTap
                                    )
                                }
                                PreviewView(
                                    previews: detail.previews,
                                    alterImages: detail.alterImages
                                )
                                if !(detail.comments.isEmpty && !isTokenMatched) {
                                    CommentScrollView(
                                        gid: gid,
                                        depth: depth,
                                        comments: detail.comments
                                    )
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .transition(AnyTransition.opacity.animation(.default))
                } else if detailInfo.mangaDetailLoading {
                    LoadingView()
                } else if detailInfo.mangaDetailLoadFailed {
                    NetworkErrorView(retryAction: fetchMangaDetail)
                }
            }
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .navigationBarItems(trailing: menu)
        .navigationBarHidden(environment.navBarHidden)
        .sheet(item: environmentBinding.detailViewSheetState) { item in
            switch item {
            case .archive:
                ArchiveView(gid: gid)
                    .environmentObject(store)
                    .accentColor(accentColor)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            case .torrents:
                TorrentsView(gid: gid)
                    .environmentObject(store)
                    .accentColor(accentColor)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            case .comment:
                DraftCommentView(
                    content: commentContentBinding,
                    title: "Post Comment",
                    postAction: draftCommentViewPost,
                    cancelAction: draftCommentViewCancel
                )
                .accentColor(accentColor)
                .preferredColorScheme(colorScheme)
                .blur(radius: environment.blurRadius)
                .allowsHitTesting(environment.isAppUnlocked)
            }
        }
    }
}

private extension DetailView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var commentContent: String {
        detailInfo.commentContent
    }
    var commentContentBinding: Binding<String> {
        detailInfoBinding.commentContent
    }
    var manga: Manga {
        cachedList.items?[gid] ?? Manga.empty
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[gid]?.detail
    }
    var torrentCount: Int? {
        mangaDetail?.torrentCount
    }
    var archiveURL: String? {
        mangaDetail?.archiveURL
    }
    var menu: some View {
        Group {
            if !detailInfo.mangaDetailLoading {
                Menu(content: {
                    if !detailInfo.mangaDetailUpdating {
                        if isTokenMatched {
                            if mangaDetail?.archiveURL != nil {
                                Button(action: onArchiveButtonTap) {
                                    Label("Archive", systemImage: "doc.zipper")
                                }
                            }
                            if let count = torrentCount, count > 0 {
                                Button(action: onTorrentsButtonTap) {
                                    Label(
                                        "Torrents".localized() + " (\(count))",
                                        systemImage: "leaf"
                                    )
                                }
                            }
                        }
                        Button(action: onShareButtonTap) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }, label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                })
                .disabled(
                    detailInfo.mangaDetailLoading
                        || detailInfo.mangaDetailUpdating
                )
            }
        }
    }

    func onAppear() {
        toggleNavBarHidden()

        if mangaDetail == nil {
            fetchMangaDetail()
        } else {
            updateMangaDetail()
        }
        updateHistoryItems()
        updateViewControllersCount()
    }
    func onDisappear() {
        updateViewControllersCount()
        postDetailViewOnDisappearNotification()
    }
    func onArchiveButtonTap() {
        toggleSheetState(.archive)
    }
    func onTorrentsButtonTap() {
        toggleSheetState(.torrents)
    }
    func onShareButtonTap() {
        guard let data = URL(string: manga.detailURL) else { return }
        let activityVC = UIActivityViewController(
            activityItems: [data],
            applicationActivities: nil
        )
        if isPad {
            activityVC.popoverPresentationController?.sourceView =
                UIApplication.shared.windows.first
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: screenW, y: 0,
                width: 200, height: 200
            )
        }
        UIApplication.shared.windows
            .first?.rootViewController?
            .present(
                activityVC,
                animated: true,
                completion: nil
            )
        impactFeedback(style: .light)
    }
    func onUserRatingChanged(_ value: Int) {
        sendRating(value)
    }
    func onSimilarGalleryTap(_ title: String) {
        associatedKeyword = AssociatedKeyword(
            title: title.trimmedTitle()
        )
        isAssociatedLinkActive.toggle()
    }
    func onTagsViewTap(_ keyword: AssociatedKeyword) {
        associatedKeyword = keyword
        isAssociatedLinkActive.toggle()
    }

    func draftCommentViewPost() {
        if !commentContent.isEmpty {
            postComment()
            toggleSheetNil()
        }
    }
    func draftCommentViewCancel() {
        toggleSheetNil()
    }

    func postComment() {
        store.dispatch(.comment(gid: gid, content: commentContent))
        store.dispatch(.cleanDetailViewCommentContent)
    }

    func fetchMangaDetail() {
        store.dispatch(.fetchMangaDetail(gid: gid))
    }
    func updateMangaDetail() {
        store.dispatch(.updateMangaDetail(gid: gid))
    }
    func fetchMangaTorrents() {
        store.dispatch(.fetchMangaTorrents(gid: gid))
    }
    func updateHistoryItems() {
        if environment.homeListType != .history {
            store.dispatch(.updateHistoryItems(gid: gid))
        }
    }
    func updateViewControllersCount() {
        store.dispatch(.updateViewControllersCount)
    }
    func sendRating(_ value: Int) {
        store.dispatch(.rate(gid: gid, rating: value))
    }

    func toggleNavBarHidden() {
        if environment.navBarHidden {
            store.dispatch(.toggleNavBarHidden(isHidden: false))
        }
    }
    func toggleSheetState(_ state: DetailViewSheetState) {
        store.dispatch(.toggleDetailViewSheetState(state: state))
    }
    func toggleSheetNil() {
        store.dispatch(.toggleDetailViewSheetNil)
    }
}

// MARK: HeaderView
private struct HeaderView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private let manga: Manga
    private let detail: MangaDetail

    init(manga: Manga, detail: MangaDetail) {
        self.manga = manga
        self.detail = detail
    }

    var body: some View {
        HStack {
            KFImage(URL(string: manga.coverURL))
                .placeholder(placeholder)
                .loadImmediately()
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .font(.title3)
                if let uploader = manga.uploader {
                    Text(uploader)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack {
                    if isTokenMatched {
                        Text(category)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .foregroundColor(manga.color)
                            )
                    }
                    Spacer()
                    if isTokenMatched {
                        if isFavored {
                            Button(action: onFavoriteDelete) {
                                Image(systemName: "heart.fill")
                                    .imageScale(.large)
                                    .foregroundColor(.accentColor)
                            }
                        } else {
                            if let user = user,
                               let names = user.favoriteNames
                            {
                                Menu {
                                    ForEach(0..<names.count - 1) { index in
                                        Button(user.getFavNameFrom(index)) {
                                            onFavoriteAdd(index)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "heart")
                                        .imageScale(.large)
                                        .foregroundColor(.accentColor)
                                }
                            }

                        }
                    }
                    Button(action: {}, label: {
                        NavigationLink(destination: ContentView(gid: manga.gid)) {
                            Text("Read".localized().uppercased())
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 14)
                                .background(Color.accentColor)
                                .cornerRadius(30)
                        }
                    })
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
        }
    }
}

private extension HeaderView {
    var isFavored: Bool {
        detail.isFavored
    }
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
    var category: String {
        if setting?.translateCategory == true {
            return manga.category.rawValue.localized()
        } else {
            return manga.category.rawValue
        }
    }
    func placeholder() -> some View {
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
    }

    func onFavoriteAdd(_ index: Int) {
        addFavorite(index)
    }
    func onFavoriteDelete() {
        deleteFavorite()
    }

    func addFavorite(_ index: Int) {
        store.dispatch(.addFavorite(gid: manga.gid, favIndex: index))
    }
    func deleteFavorite() {
        store.dispatch(.deleteFavorite(gid: manga.gid))
    }
    func updateMangaDetail() {
        store.dispatch(.updateMangaDetail(gid: manga.gid))
    }
}

// MARK: DescScrollView
private struct DescScrollView: View {
    @State private var itemWidth = max((absoluteWindowW ?? absoluteScreenW) / 5, 80)

    private let detail: MangaDetail

    init(detail: MangaDetail) {
        self.detail = detail
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center) {
                DescScrollItem(
                    title: "Favored",
                    value: detail.likeCount,
                    numeral: "Times"
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollItem(
                    title: "Language",
                    value: detail.languageAbbr,
                    numeral: detail.language.rawValue
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollRatingItem(
                    title: detail.ratingCount
                        + " Ratings".localized(),
                    rating: detail.rating
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollItem(
                    title: "Page Count",
                    value: detail.pageCount,
                    numeral: "Pages"
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollItem(
                    title: "Size",
                    value: detail.sizeCount,
                    numeral: detail.sizeType
                )
                .frame(width: itemWidth)
            }
        }
        .frame(height: 60)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("AppWidthDidChange")
            )
        ) { _ in
            onWidthChange()
        }
    }

    private func onWidthChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if itemWidth != max((absoluteWindowW ?? absoluteScreenW) / 5, 80) {
                withAnimation {
                    itemWidth = max((absoluteWindowW ?? absoluteScreenW) / 5, 80)
                }
            }
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
            Text(title.localized().uppercased())
                .font(.caption)
            Text(value)
                .fontWeight(.medium)
                .font(.title3)
                .lineLimit(1)
            Text(numeral.localized())
                .font(.caption)
        }
    }
}

private struct DescScrollRatingItem: View {
    private let title: String
    private let rating: Float

    init(title: String, rating: Float) {
        self.title = title
        self.rating = rating
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(title.localized().uppercased())
                .font(.caption)
                .lineLimit(1)
            Text(String(format: "%.2f", rating))
                .fontWeight(.medium)
                .font(.title3)
            RatingView(rating: rating)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
}

// MARK: ActionRow
private struct ActionRow: View {
    @State private var showUserRating = false
    @State private var userRating: Int = 0

    private let detail: MangaDetail
    private let ratingAction: (Int) -> Void
    private let galleryAction: () -> Void

    init(
        detail: MangaDetail,
        ratingAction: @escaping (Int) -> Void,
        galleryAction: @escaping () -> Void
    ) {
        self.detail = detail
        self.ratingAction = ratingAction
        self.galleryAction = galleryAction
    }

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button(action: onRateButtonTap) {
                        Spacer()
                        Image(systemName: "square.and.pencil")
                        Text("Give a Rating")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    Button(action: galleryAction) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Similar Gallery")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            if showUserRating {
                HStack {
                    RatingView(rating: Float(userRating) / 2)
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged(onRatingChanged)
                                .onEnded(onRatingEnded)
                        )
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
        .onAppear(perform: onAppear)
    }
}

private extension ActionRow {
    func onAppear() {
        if let rating = detail.userRating {
            userRating = Int(rating.fixedRating() * 2)
        }
    }
    func onRateButtonTap() {
        withAnimation {
            showUserRating.toggle()
        }
    }
    func onRatingChanged(_ value: DragGesture.Value) {
        updateRating(value)
    }
    func onRatingEnded(_ value: DragGesture.Value) {
        updateRating(value)
        ratingAction(userRating)
        impactFeedback(style: .soft)
        withAnimation(Animation.default.delay(1)) {
            showUserRating.toggle()
        }
    }
    func updateRating(_ value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
}

// MARK: TagsView
private struct TagsView: View {
    private let tags: [MangaTag]
    private let onTapAction: (AssociatedKeyword) -> Void

    init(
        tags: [MangaTag],
        onTapAction: @escaping (AssociatedKeyword) -> Void
    ) {
        self.tags = tags
        self.onTapAction = onTapAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(tag: tag, onTapAction: onTapAction)
            }
        }
        .padding(.horizontal)
    }
}

private struct TagRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private let tag: MangaTag
    private let onTapAction: (AssociatedKeyword) -> Void
    private var reversePrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(
        tag: MangaTag,
        onTapAction: @escaping (AssociatedKeyword) -> Void
    ) {
        self.tag = tag
        self.onTapAction = onTapAction
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(tag.category.rawValue.localized())
                .fontWeight(.bold)
                .font(.subheadline)
                .foregroundColor(reversePrimary)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(
                    Rectangle()
                        .foregroundColor(Color(.systemGray))
                )
                .cornerRadius(5)
            TagCloudView(
                tag: tag,
                font: .subheadline,
                textColor: .primary,
                backgroundColor: Color(.systemGray5),
                paddingV: 5,
                paddingH: 14,
                onTapAction: onTapAction
            )
        }
    }
}

// MARK: PreviewView
private struct PreviewView: View {
    private let previews: [MangaPreview]
    private let alterImages: [MangaAlterData]

    private var width: CGFloat {
        Defaults.ImageSize.previewW
    }
    private var height: CGFloat {
        Defaults.ImageSize.previewH
    }
    private func placeholder() -> some View {
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
        .cornerRadius(15)
    }

    init(
        previews: [MangaPreview],
        alterImages: [MangaAlterData]
    ) {
        self.previews = previews
        self.alterImages = alterImages
    }

    var body: some View {
        VStack {
            HStack {
                Text("Preview")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    if !previews.isEmpty {
                        ForEach(previews) { item in
                            KFImage(URL(string: item.url))
                                .placeholder(placeholder)
                                .loadImmediately()
                                .resizable()
                                .scaledToFit()
                                .frame(width: width, height: height)
                                .cornerRadius(15)
                        }
                    } else if !alterImages.isEmpty {
                        ForEach(alterImages) { item in
                            if let uiImage = UIImage(data: item.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: width, height: height)
                                    .cornerRadius(15)
                            } else {
                                placeholder()
                            }
                        }
                    } else {
                        ForEach(0..<10) { _ in placeholder() }
                    }
                }
            }
        }
        .frame(height: 240)
    }
}

// MARK: CommentScrollView
private struct CommentScrollView: View {
    @EnvironmentObject private var store: Store

    private let gid: String
    private let depth: Int
    private let comments: [MangaComment]

    init(
        gid: String,
        depth: Int,
        comments: [MangaComment]
    ) {
        self.gid = gid
        self.depth = depth
        self.comments = comments
    }

    var body: some View {
        VStack {
            HStack {
                Text("Comment")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
                if !comments.isEmpty && isTokenMatched {
                    NavigationLink(destination: CommentView(gid: gid, depth: depth)) {
                        Text("Show All")
                            .font(.subheadline)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(6)) { comment in
                        CommentScrollCell(comment: comment)
                    }
                }
            }
            if isTokenMatched {
                CommentButton(action: toggleDraft)
            }
        }
    }

    private func toggleDraft() {
        store.dispatch(.toggleDetailViewSheetState(state: .comment))
    }
}

private struct CommentScrollCell: View {
    private let comment: MangaComment
    private var content: String {
        comment.contents
            .filter {
                [.plainText, .linkedText]
                    .contains($0.type)
            }
            .compactMap {
                $0.text
            }
            .joined()
    }

    init(comment: MangaComment) {
        self.comment = comment
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author)
                    .fontWeight(.bold)
                    .font(.subheadline)
                Spacer()
                Group {
                    if comment.votedUp {
                        Image(systemName: "hand.thumbsup.fill")
                    } else if comment.votedDown {
                        Image(systemName: "hand.thumbsdown.fill")
                    }
                    if let score = comment.score {
                        Text(score)
                    }
                    Text(comment.commentTime)
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            Text(content)
                .padding(.top, 1)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .frame(width: 300, height: 120)
        .cornerRadius(15)
    }
}

// MARK: Definition
enum DetailViewSheetState: Identifiable {
    var id: Int { hashValue }

    case archive
    case torrents
    case comment
}
