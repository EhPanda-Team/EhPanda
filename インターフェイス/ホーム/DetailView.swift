//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI

struct DetailView: View {
    let manga: Manga
    var body: some View {
        
        ScrollView { VStack { LoadingView(type: .detail) { Group {
            if let mangaDetail = RequestManager.shared.mangaDetail {
                HeaderView(container: ImageContainer(from: manga.coverURL, 150), manga: manga, mangaDetail: mangaDetail)
                DescScrollView(manga: manga, detail: mangaDetail)
            }}
            } retryAction: {
                RequestManager.shared.getMangaDetail(url: manga.detailURL)
            }
            .padding(.top, 10)
        }}
        .padding(.horizontal)
        .onAppear {
            RequestManager.shared.getMangaDetail(url: manga.detailURL)
        }
        .onDisappear {
            RequestManager.shared.mangaDetail = nil
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var container: ImageContainer
    let manga: Manga
    var mangaDetail: MangaDetail?
    
    var title: String {
        guard let jpnTitle = mangaDetail?.jpnTitle else {
            return manga.title
        }
        if jpnTitle.isEmpty {
            return manga.title
        } else {
            return jpnTitle
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                container.image
                    .resizable()
                    .frame(width: 70/110 * 150, height: 150)
                VStack(alignment: .leading) {
                    Text(title)
                        .fontWeight(.bold)
                        .lineLimit(3)
                        .font(.title3)
                        .foregroundColor(.primary)
                    Text(manga.uploader)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(manga.translatedCategory)
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
                        Button(action: {}) { NavigationLink(destination: EmptyView()) {
                            Text("読む")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }}
                        .capsulePadding()
                        .withTapEffect(backgroundColor: .blue)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
            }
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
        }
        
    }
}

private struct DescScrollView: View {
    let manga: Manga
    let detail: MangaDetail
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 0) {
            DescScrollItem(title: "いいね", value: detail.likeCount, numeral: "回")
            Divider()
            DescScrollRatingItem(title: detail.ratingCount + "件の評価", rating: manga.rating)
            Divider()
            DescScrollItem(title: "言語", value: detail.languageAbbr, numeral: detail.translatedLanguage)
            Divider()
            DescScrollItem(title: "ページ", value: detail.pageCount, numeral: "頁")
            Divider()
            DescScrollItem(title: "サイズ", value: detail.sizeCount, numeral: "MB")
        }.foregroundColor(.secondary)}
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
        }.frame(width: 100)
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
            RatingView(rating: rating, .secondary)
        }.frame(width: 100)
    }
}
