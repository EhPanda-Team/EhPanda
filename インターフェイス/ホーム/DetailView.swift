//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import AlamofireImage

struct DetailView: View {
    @ObservedObject var store = DetailItemsStore()
    @Environment(\.colorScheme) var colorScheme
    @State var isContentViewPresented = false
    
    let manga: Manga
    
    var body: some View {
        VStack { Group {
            if let detailItem = store.detailItem, !store.previewItems.isEmpty {
                HeaderView(container: ImageContainer(from: manga.coverURL, type: .cover, 150),
                           isContentViewPresented: $isContentViewPresented,
                           manga: manga,
                           mangaDetail: detailItem)
                    .frame(height: 150)
                DescScrollView(manga: manga, detail: detailItem)
                    .frame(height: 60)
                    .padding(.vertical, 30)
                PreviewView(previewItems: store.previewItems)
                    .frame(maxHeight: .infinity)
            } else {
                LoadingView()
            }
        }}
        .padding(.top, -40)
        .padding(.bottom, 10)
        .padding(.horizontal)
        .onAppear {
            fetchItems()
            isContentViewPresented = false
        }
        .onDisappear {
            if isContentViewPresented { return }
            
            store.detailItem = nil
            store.previewItems.removeAll()
        }
    }
    
    func fetchItems() {
        if store.detailItem == nil {
            store.fetchDetailItem(url: manga.detailURL)
        }
        if store.previewItems.isEmpty {
            store.fetchPreviewItems(url: manga.detailURL)
        }
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    @ObservedObject var container: ImageContainer
    @Binding var isContentViewPresented: Bool
    
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
                    Spacer()
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
                        let contentView = ContentView(isContentViewPresented: $isContentViewPresented, detailURL: manga.detailURL)
                        Button(action: {}) { NavigationLink(destination: contentView) {
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
        }
        
    }
}

// MARK: 基本情報
private struct DescScrollView: View {
    let manga: Manga
    let detail: MangaDetail
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Divider()
            HStack(spacing: 0) {
                DescScrollItem(title: "気に入り", value: detail.likeCount, numeral: "人")
                Divider()
                DescScrollRatingItem(title: detail.ratingCount + "件の評価", rating: manga.rating)
                Divider()
                DescScrollItem(title: "言語", value: detail.languageAbbr, numeral: detail.translatedLanguage)
                Divider()
                DescScrollItem(title: "ページ", value: detail.pageCount, numeral: "頁")
                Divider()
                DescScrollItem(title: "サイズ", value: detail.sizeCount, numeral: "MB")
            }
            .foregroundColor(.primary)
            Divider()
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

// MARK: プレビュー
private struct PreviewView: View {
    let previewItems: [MangaContent]
    
    var body: some View {
        VStack {
            HStack {
                Text("プレビュー")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .font(.title3)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) { HStack {
                if !previewItems.isEmpty {
                    ForEach(previewItems) { item in
                        ImageView(container: ImageContainer(from: item.url, type: .preview, 300))
                    }
                } else {
                    LoadingView()
                }
            }}
        }
    }
}

private struct ImageView: View {
    @ObservedObject var container: ImageContainer
    
    var body: some View {
        container.image
            .resizable()
            .aspectRatio(32/45, contentMode: .fit)
            .cornerRadius(15)
    }
}
