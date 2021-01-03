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
                        DescScrollView(manga: manga, detail: detail)
                            .padding(.vertical, 30)
                        PreviewView(previews: detail.previews)
                        Group {
                            if !detail.comments.isEmpty {
                                CommentScrollView(id: id, comments: detail.comments)
                            } else if detailInfo.mangaCommentsUpdating {
                                LoadingView()
                            }
                        }
                        .padding(.vertical, 30)
                    }
                    .padding(.top, -40)
                    .padding(.horizontal)
                    .transition(AnyTransition.opacity.animation(.default))
                }
            } else if detailInfo.mangaDetailLoading {
                LoadingView()
            } else if detailInfo.mangaDetailLoadFailed {
                NetworkErrorView {
                    store.dispatch(.fetchMangaDetail(id: id))
                }
            }
        }
        .navigationBarHidden(environment.navBarHidden)
        .onAppear {
            store.dispatch(.toggleNavBarHidden(isHidden: false))
            
            if mangaDetail == nil {
                store.dispatch(.fetchMangaDetail(id: id))
            }
            store.dispatch(.updateMangaComments(id: id))
        }
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    @EnvironmentObject var store: Store
    
    let manga: Manga
    let detail: MangaDetail
    
    var isFavored: Bool {
        store.appState.homeList.isFavored(id: manga.id)
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
                .placeholder{ rectangle }
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
                    Text(manga.translatedCategory.lString())
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.init(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(Color(manga.color))
                        )
                    Spacer()
                    Image(systemName: isFavored ? "heart.fill" : "heart")
                        .imageScale(.large)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            if isFavored {
                                store.dispatch(.deleteFavorite(id: manga.id))
                            } else {
                                store.dispatch(.addFavorite(id: manga.id))
                            }
                        }
                    Button(action: {}) {
                        NavigationLink(destination: ContentView(id: manga.id)) {
                             Text("読む")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(CapsuleButtonStyle())
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
        }
    }
}

// MARK: 基本情報
private struct DescScrollView: View {
    let manga: Manga
    let detail: MangaDetail
    
    var body: some View {
        HStack(alignment: .center) {
            DescScrollItem(title: "気に入り".lString(),
                           value: detail.likeCount,
                           numeral: "人".lString())
            Spacer()
            DescScrollItem(title: "言語".lString(),
                           value: detail.languageAbbr,
                           numeral: detail.translatedLanguage.lString())
            Spacer()
            DescScrollRatingItem(title: detail.ratingCount + "件の評価".lString(),
                                 rating: manga.rating)
            Spacer()
            DescScrollItem(title: "ページ".lString(),
                           value: detail.pageCount,
                           numeral: "頁".lString())
            Spacer()
            DescScrollItem(title: "サイズ".lString(),
                           value: detail.sizeCount,
                           numeral: detail.sizeType)
        }
        .padding(.horizontal)
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
        .frame(idealWidth: 50)
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
        .frame(idealWidth: 60)
    }
}

// MARK: プレビュー
private struct PreviewView: View {
    let previews: [MangaPreview]
    
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
                HStack {
                    if !previews.isEmpty {
                        ForEach(previews) { item in
                            WebImage(url: URL(string: item.url), options: .handleCookies)
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
    
    var body: some View {
        VStack {
            HStack {
                Text("コメント")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
                NavigationLink(destination: CommentView(id: id)) {
                    Text("すべて表示")
                        .font(.subheadline)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(6)) { comment in
                        CommentScrollCell(comment: comment)
                    }
                }
            }
        }
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
