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
    @State var associatedKeyword = AssociatedKeyword()
    @State var isAssociatedLinkActive = false
    
    let id: String
    let depth: Int
    
    var environment: AppState.Environment {
        store.appState.environment
    }
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var manga: Manga {
        (cachedList.items?[id])!
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[id]?.detail
    }
    var menu: some View {
        Group {
            if exx {
                Menu(content: {
                    Button(action: {}, label: {
                        Text("Button")
                    })
                    Button(action: {}, label: {
                        Text("Button")
                    })
                    Button(action: {}, label: {
                        Text("Button")
                    })
                    Button(action: {}, label: {
                        Text("Button")
                    })
                    Button(action: {}, label: {
                        Text("Button")
                    })
                    Button(action: {}, label: {
                        Text("Button")
                    })
                }, label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                })
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: DetailView本体
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
                                        ratingAction: onUserRatingChanged,
                                        galleryAction: onSimilarGalleryTap
                                    )
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
                                        id: id,
                                        comments: detail.comments
                                    )
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal)
                        .transition(AnyTransition.opacity.animation(.default))
                    }
                } else if detailInfo.mangaDetailLoading {
                    LoadingView()
                } else if detailInfo.mangaDetailLoadFailed {
                    NetworkErrorView(retryAction: fetchMangaDetail)
                }
            }
        }
        .navigationBarHidden(environment.navBarHidden)
        .navigationBarItems(trailing: menu)
        .onAppear(perform: onAppear)
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
    func onUserRatingChanged(_ value: Int) {
        sendRating(value)
    }
    func onSimilarGalleryTap() {
        associatedKeyword = AssociatedKeyword(
            title: manga.title.trimmedTitle()
        )
        isAssociatedLinkActive.toggle()
    }
    func onTagsViewTap(_ keyword: AssociatedKeyword) {
        associatedKeyword = keyword
        isAssociatedLinkActive.toggle()
    }
    
    func fetchMangaDetail() {
        store.dispatch(.fetchMangaDetail(id: id))
    }
    func updateMangaDetail() {
        store.dispatch(.updateMangaDetail(id: id))
    }
    func updateHistoryItems() {
        store.dispatch(.updateHistoryItems(id: id))
    }
    func sendRating(_ value: Int) {
        store.dispatch(.rate(id: id, rating: value))
    }
    
    func toggleNavBarHidden() {
        if environment.navBarHidden {
            store.dispatch(.toggleNavBarHidden(isHidden: false))
        }
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    @EnvironmentObject var store: Store
    
    let manga: Manga
    let detail: MangaDetail
    
    var setting: Setting? {
        store.appState.settings.setting
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
        if detail.jpnTitle.isEmpty {
            return manga.title
        } else {
            return detail.jpnTitle
        }
    }
    var category: String {
        if setting?.translateCategory == true {
            return manga.jpnCategory.lString()
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
            KFImage(URL(string: manga.coverURL), options: [])
                .placeholder(placeholder)
                .imageModifier(modifier)
                .cancelOnDisappear(true)
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
                            .padding(.init(top: 2, leading: 4, bottom: 2, trailing: 4))
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .foregroundColor(manga.color)
                            )
                    }
                    Spacer()
                    if exx {
                        Image(systemName: isFavored ? "heart.fill" : "heart")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                            .onTapGesture(perform: onFavoriteTap)
                    }
                    Button(action: {}) {
                        NavigationLink(destination: ContentView(id: manga.id)) {
                            Text("読む")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .capsulePadding()
                        }
                    }
                    .buttonStyle(CapsuleButtonStyle())
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
        }
    }
    
    func onFavoriteTap() {
        if isFavored {
            deleteFavorite()
        } else {
            addFavorite()
        }
        updateMangaDetail()
    }
    
    func addFavorite() {
        store.dispatch(.addFavorite(id: manga.id))
    }
    func deleteFavorite() {
        store.dispatch(.deleteFavorite(id: manga.id))
    }
    func updateMangaDetail() {
        store.dispatch(.updateMangaDetail(id: manga.id))
    }
}

// MARK: 基本情報
private struct DescScrollView: View {
    let detail: MangaDetail
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center) {
                DescScrollItem(title: "気に入り".lString(),
                               value: detail.likeCount,
                               numeral: "人".lString())
                Divider()
                DescScrollItem(title: "言語".lString().uppercased(),
                               value: detail.languageAbbr,
                               numeral: detail.translatedLanguage.lString())
                Divider()
                DescScrollRatingItem(title: detail.ratingCount + "件の評価".lString(),
                                     rating: detail.rating)
                Divider()
                DescScrollItem(title: "ページ".lString(),
                               value: detail.pageCount,
                               numeral: "頁".lString())
                Divider()
                DescScrollItem(title: "サイズ".lString(),
                               value: detail.sizeCount,
                               numeral: detail.sizeType)
            }
        }
        .frame(height: 60)
    }
}

private struct DescScrollItem: View {
    let title: String
    let value: String
    let numeral: String
    
    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption)
            Text(value)
                .fontWeight(.medium)
                .font(.title3)
                .lineLimit(1)
            Text(numeral)
                .font(.caption)
        }
        .frame(minWidth: 80)
    }
}

private struct DescScrollRatingItem: View {
    let title: String
    let rating: Float
    
    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
            Text(String(format: "%.2f", rating))
                .fontWeight(.medium)
                .font(.title3)
            RatingView(rating: rating)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 80)
    }
}

// MARK: サブアクション
private struct ActionRow: View {
    @State var showUserRating = false
    @State var userRating: Int = 0
    
    let detail: MangaDetail
    let ratingAction: (Int) -> ()
    let galleryAction: () -> ()
    
    var body: some View {
        VStack {
            HStack {
                Group {
                    Button(action: onRateButtonTap) {
                        Spacer()
                        Image(systemName: "square.and.pencil")
                        Text("評価する")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    Button(action: galleryAction) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("類似ギャラリー")
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

// MARK: タグ
private struct TagsView: View {
    let tags: [Tag]
    let onTapAction: ((AssociatedKeyword)->())
    
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
    
    let tag: Tag
    let onTapAction: ((AssociatedKeyword)->())
    var reversePrimary: Color {
        colorScheme == .light ? .white : .black
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(tag.jpnCategory.lString())
                .fontWeight(.bold)
                .font(.subheadline)
                .foregroundColor(reversePrimary)
                .capsulePadding()
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

// MARK: プレビュー
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
                Text("プレビュー")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    if !previews.isEmpty {
                        ForEach(previews) { item in
                            KFImage(URL(string: item.url), options: [])
                                .placeholder(placeholder)
                                .imageModifier(modifier)
                                .cancelOnDisappear(true)
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

// MARK: コメント
private struct CommentScrollView: View {
    @EnvironmentObject var store: Store
    
    let id: String
    let comments: [MangaComment]
    
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
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
    
    var body: some View {
        VStack {
            HStack {
                Text("コメント")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
                if !comments.isEmpty && exx {
                    NavigationLink(destination: CommentView(id: id)) {
                        Text("すべて表示")
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
        .sheet(item: environmentBinding.detailViewSheetState) { item in
            switch item {
            case .comment:
                DraftCommentView(
                    content: commentContentBinding,
                    title: "コメントを書く",
                    postAction: draftCommentViewPost,
                    cancelAction: draftCommentViewCancel
                )
            }
        }
    }
    
    func draftCommentViewPost() {
        if !commentContent.isEmpty {
            postComment()
            toggleNil()
        }
    }
    func draftCommentViewCancel() {
        toggleNil()
    }
    
    func postComment() {
        store.dispatch(.comment(id: id, content: commentContent))
        store.dispatch(.cleanDetailViewCommentContent)
    }
    
    func toggleDraft() {
        store.dispatch(.toggleDetailViewSheetState(state: .comment))
    }
    func toggleNil() {
        store.dispatch(.toggleDetailViewSheetNil)
    }
}

private struct CommentScrollCell: View {
    let comment: MangaComment
    
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
            Text(comment.content)
                .padding(.top, 1)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .frame(width: 300, height: 120)
        .cornerRadius(15)
    }
}

// MARK: 定義
enum DetailViewSheetState: Identifiable {
    var id: Int { hashValue }
    
    case comment
}
