//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import AlamofireImage

struct DetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var backgroundColor: Color = .clear
    let manga: Manga
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.linear(duration: 1.5))
            VStack { LoadingView(type: .detail) { Group {
                if let mangaDetail = RequestManager.shared.mangaDetail {
                    HeaderView(container: ImageContainer(from: manga.coverURL, type: .cover, 150),
                               manga: manga,
                               mangaDetail: mangaDetail)
                        .frame(height: 150)
                    Divider()
                    DescScrollView(manga: manga, detail: mangaDetail)
                        .frame(height: 60)
                    Divider()
                    PreviewView(manga: manga)
                        .frame(maxHeight: .infinity)
                }}
                } retryAction: {
                    RequestManager.shared.getMangaDetail(url: manga.detailURL)
                }
                .padding(.top, 10)
            }
            .padding(.top, -40)
            .padding(.bottom, 10)
            .padding(.horizontal)
        }
        .onAppear {
            setBackgroundColor()
            RequestManager.shared.stopPreviewLoadFlag = false
            RequestManager.shared.getMangaDetail(url: manga.detailURL)
            RequestManager.shared.getMangaPreview(url: manga.detailURL)
        }
        .onDisappear {
            RequestManager.shared.mangaDetail = nil
            RequestManager.shared.mangaPreviewItems = nil
            RequestManager.shared.stopPreviewLoadFlag = true
        }
    }
    
    func setBackgroundColor() {
        guard let url = URL(string: manga.coverURL) else { return }
        
        let downloader = ImageDownloader()
        downloader.download(URLRequest(url: url), completion: { (resp) in
            if case .success(let image) = resp.result {
                guard let uiColor = image.averageColor else { return }
                
                if let darkerColor = uiColor.darker(), colorScheme == .dark {
                    backgroundColor = Color(darkerColor)
                } else {
                    backgroundColor = Color(uiColor)
                }
            }
        })
    }
}

// MARK: ヘッダー
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
        }
        
    }
}

// MARK: 基本情報
private struct DescScrollView: View {
    let manga: Manga
    let detail: MangaDetail
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 0) {
            DescScrollItem(title: "気に入り", value: detail.likeCount, numeral: "人")
            Divider()
            DescScrollRatingItem(title: detail.ratingCount + "件の評価", rating: manga.rating)
            Divider()
            DescScrollItem(title: "言語", value: detail.languageAbbr, numeral: detail.translatedLanguage)
            Divider()
            DescScrollItem(title: "ページ", value: detail.pageCount, numeral: "頁")
            Divider()
            DescScrollItem(title: "サイズ", value: detail.sizeCount, numeral: "MB")
        }.foregroundColor(.primary)}
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
    let manga: Manga
    
    var body: some View {
        VStack {
            HStack {
                Text("プレビュー")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .font(.title3)
                Spacer()
            }
            
            LoadingView(type: .preview) { ScrollView(.horizontal, showsIndicators: false) { HStack {
                if let previewItems = RequestManager.shared.mangaPreviewItems {
                    ForEach(previewItems) { item in
                        PreviewImageView(container: ImageContainer(from: item.url, type: .preview, 300))
                    }
                }
            }}
            } retryAction: {
                RequestManager.shared.getMangaPreview(url: manga.detailURL)
            }
        }
    }
}

private struct PreviewImageView: View {
    @ObservedObject var container: ImageContainer
    
    var body: some View {
        container.image
            .resizable()
            .aspectRatio(32/45, contentMode: .fit)
            .cornerRadius(15)
    }
}
