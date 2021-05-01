//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import Kingfisher

struct DetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    @State var associatedKeyword = AssociatedKeyword()
    @State var isAssociatedLinkActive = false

    let gid: String
    let depth: Int

    var environment: AppState.Environment {
        store.appState.environment
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
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
    var accentColor: Color? {
        store.appState.settings.setting?.accentColor
    }
    var menu: some View {
        Group {
            if !detailInfo.mangaDetailLoading {
                Menu(content: {
                    if !detailInfo.mangaDetailUpdating {
                        if exx {
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
                                if exx {
                                    ActionRow(
                                        detail: detail,
                                        ratingAction: onUserRatingChanged
                                    ) {
                                        onSimilarGalleryTap(detail.title)
                                    }
                                }
                                if !detail.detailTags.isEmpty && exx {
                                    TagsView(
                                        tags: detail.detailTags,
                                        onTapAction: onTagsViewTap
                                    )
                                }
                                PreviewView(
                                    previews: detail.previews,
                                    alterImages: detail.alterImages
                                )
                                if !(detail.comments.isEmpty && !exx) {
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

    func onAppear() {
        toggleNavBarHidden()

        if mangaDetail == nil {
            fetchMangaDetail()
        } else {
            updateMangaDetail()
        }
        updateHistoryItems()
    }
    func onDisappear() {
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
private struct HeaderView: View {
    @EnvironmentObject var store: Store

    let manga: Manga
    let detail: MangaDetail

    var settings: AppState.Settings {
        store.appState.settings
    }
    var setting: Setting? {
        settings.setting
    }
    var user: User? {
        settings.user
    }

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
            return manga.category.rawValue.uppercased()
        }
    }
    var modifier: KFImageModifier {
        KFImageModifier(
            targetScale:
                Defaults
                .ImageSize
                .rowScale
        )
    }
    func placeholder() -> some View {
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
    }

    var body: some View {
        HStack {
            KFImage(URL(string: manga.coverURL))
                .placeholder(placeholder)
                .imageModifier(modifier)
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
                    if exx {
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
                    if exx {
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
    @State var itemWidth = max((absoluteWindowW ?? absoluteScreenW) / 5, 80)

    let detail: MangaDetail

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

    func onWidthChange() {
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
    let title: String
    let value: String
    let numeral: String

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
    let title: String
    let rating: Float

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
    @State var showUserRating = false
    @State var userRating: Int = 0

    let detail: MangaDetail
    let ratingAction: (Int) -> Void
    let galleryAction: () -> Void

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
    let tags: [MangaTag]
    let onTapAction: (AssociatedKeyword) -> Void

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
    @Environment(\.colorScheme) var colorScheme

    let tag: MangaTag
    let onTapAction: (AssociatedKeyword) -> Void
    var reversePrimary: Color {
        colorScheme == .light ? .white : .black
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
    let previews: [MangaPreview]
    let alterImages: [MangaAlterData]

    var width: CGFloat {
        Defaults.ImageSize.previewW
    }
    var height: CGFloat {
        Defaults.ImageSize.previewH
    }
    var modifier: KFImageModifier {
        KFImageModifier(
            targetScale:
                Defaults
                .ImageSize
                .rowScale
        )
    }
    func placeholder() -> some View {
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
        .cornerRadius(15)
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
                                .imageModifier(modifier)
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
    @EnvironmentObject var store: Store

    let gid: String
    let depth: Int
    let comments: [MangaComment]

    var body: some View {
        VStack {
            HStack {
                Text("Comment")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
                if !comments.isEmpty && exx {
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
            if exx {
                CommentButton(action: toggleDraft)
            }
        }
    }

    func toggleDraft() {
        store.dispatch(.toggleDetailViewSheetState(state: .comment))
    }
}

private struct CommentScrollCell: View {
    let comment: MangaComment
    var content: String {
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
