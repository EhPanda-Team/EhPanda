//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import SDWebImageSwiftUI

struct DetailView: View {
    @EnvironmentObject var store: Store
    
    let id: String
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
    
    var body: some View {
        Group {
            if let detail = mangaDetail {
                ScrollView(showsIndicators: false) {
                    VStack {
                        HeaderView(manga: manga, detail: detail)
                            .padding(.top, -40)
                            .padding(.bottom, 15)
                        Group {
                            DescScrollView(manga: manga, detail: detail)
                                .frame(height: 60)
                            PreviewView(previews: detail.previews, alterImages: detail.alterImages)
                                .frame(height: 240)
                            if !(detail.comments.isEmpty && !exx) {
                                CommentScrollView(id: id, comments: detail.comments)
                            }
                        }
                        .padding(.vertical, 15)
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
        .navigationBarHidden(environment.navBarHidden)
        .onAppear(perform: onAppear)
    }
    
    func onAppear() {
        toggleNavBarHidden()
        
        if mangaDetail == nil {
            fetchMangaDetail()
        } else {
            updateMangaComments()
        }
    }
    
    func fetchMangaDetail() {
        store.dispatch(.fetchMangaDetail(id: id))
    }
    func updateMangaComments() {
        store.dispatch(.updateMangaComments(id: id))
    }
    
    func toggleNavBarHidden() {
        store.dispatch(.toggleNavBarHidden(isHidden: false))
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    @EnvironmentObject var store: Store
    
    let manga: Manga
    let detail: MangaDetail
    
    var isFavored: Bool {
        store.appState.homeInfo.isFavored(id: manga.id)
    }
    
    var rectangle: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 8/11 * 150, height: 150)
    }
    
    var title: String {
        if detail.jpnTitle.isEmpty {
            return manga.title
        } else {
            return detail.jpnTitle
        }
    }
    
    var body: some View {
        HStack {
            WebImage(url: URL(string: manga.coverURL), options: .handleCookies)
                .resizable()
                .placeholder { rectangle }
                .indicator(.activity)
                .scaledToFit()
                .frame(width: 8/11 * 150, height: 150)
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
                        Text(manga.jpnCategories.lString())
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
    }
    
    func addFavorite() {
        store.dispatch(.addFavorite(id: manga.id))
    }
    func deleteFavorite() {
        store.dispatch(.deleteFavorite(id: manga.id))
    }
}

// MARK: 基本情報
private struct DescScrollView: View {
    let manga: Manga
    let detail: MangaDetail
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center) {
                DescScrollItem(title: "気に入り".lString(),
                               value: detail.likeCount,
                               numeral: "人".lString())
                Divider()
                DescScrollItem(title: "言語".lString(),
                               value: detail.languageAbbr,
                               numeral: detail.translatedLanguage.lString())
                Divider()
                DescScrollRatingItem(title: detail.ratingCount + "件の評価".lString(),
                                     rating: manga.rating)
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
            Text(String(format: "%.1f", rating))
                .fontWeight(.medium)
                .font(.title3)
            RatingView(rating: rating, .primary)
        }
        .frame(minWidth: 80)
    }
}

// MARK: プレビュー
private struct PreviewView: View {
    let previews: [MangaPreview]
    let alterImages: [Data]
    
    struct Placeholder: View {
        let width: CGFloat
        let height: CGFloat
        
        var body: some View {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: width, height: height)
                .cornerRadius(15)
        }
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
                            WebImage(url: URL(string: item.url),
                                     options: [.retryFailed, .handleCookies]
                            )
                            .resizable()
                            .placeholder {
                                Placeholder(width: 200 * 32/45,
                                            height: 200)
                            }
                            .indicator(.activity)
                            .scaledToFill()
                            .frame(width: 200 * 32/45,
                                   height: 200)
                            .cornerRadius(15)
                        }
                    } else if !alterImages.isEmpty {
                        ForEach(alterImages, id: \.self) { item in
                            AnimatedImage(data: item)
                                .resizable()
                                .placeholder {
                                    Placeholder(width: 200 * 32/45,
                                                height: 200)
                                }
                                .indicator(.activity)
                                .scaledToFill()
                                .frame(width: 200 * 32/45,
                                       height: 200)
                                .cornerRadius(15)
                        }
                    } else {
                        ForEach(0..<10) { _ in
                            Placeholder(width: 200 * 32/45,
                                        height: 200)
                        }
                    }
                }
            }
            
        }
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
        .sheet(item: environmentBinding.detailViewSheetState, content: { item in
            switch item {
            case .comment:
                DraftCommentView(
                    content: commentContentBinding,
                    title: "コメントを書く",
                    postAction: draftCommentViewPost,
                    cancelAction: draftCommentViewCancel
                )
            }
        })
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
