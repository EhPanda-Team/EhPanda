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
    @State var shouldBackButtonHidden = true
    @State var backgroundColor: Color = .clear
    
    let manga: Manga
    
    var body: some View { Group {
        if let detailItem = store.detailItem {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                VStack { Group {
                    HeaderView(container: ImageContainer(from: manga.coverURL, type: .cover, 150),
                               isContentViewPresented: $isContentViewPresented,
                               manga: manga,
                               mangaDetail: detailItem)
                        .frame(height: 150)
                    DescScrollView(manga: manga, detail: detailItem)
                        .frame(height: 60)
                        .padding(.vertical, 30)
                    let pageCount = Int(detailItem.pageCount) ?? 0
                    let previewCount = pageCount > 10 ? 10 : pageCount
                    PreviewView(previewItems: store.previewItems, previewCount: previewCount)
                        .frame(maxHeight: .infinity)
                }.shadow(radius: 10)}
                .padding(.top, -40)
                .padding(.bottom, 10)
                .padding(.horizontal)
            }
            .transition(AnyTransition.opacity.animation(.linear(duration: 0.5)))
            .onAppear {
                shouldBackButtonHidden = false
            }
        } else {
            LoadingView()
        }}
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Group {
            if !shouldBackButtonHidden {
                BackButton()
            }
        })
        .onAppear {
            fetchItems()
            fetchBackgroundColor()
            isContentViewPresented = false
        }
        .onDisappear {
            if isContentViewPresented { return }
            
            store.detailItem = nil
            store.previewItems.removeAll()
            store.removeTmpPreviewItems()
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
    
    func fetchBackgroundColor() {
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

// MARK: バックボタン
private struct BackButton: View {
    @Environment(\.presentationMode) var presentationMode
    @State var isPressed = false
    let color: Color = Color.white.opacity(0.8)
    
    var body: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.backward.circle")
                .foregroundColor(isPressed ? color.opacity(0.5) : color)
                .font(.system(.title))
        }
        .shadow(radius: 10)
        .onLongPressGesture(pressing: { (_) in
            isPressed.toggle()
        }, perform: {})
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    @ObservedObject var container: ImageContainer
    @Binding var isContentViewPresented: Bool
    
    let manga: Manga
    var mangaDetail: MangaDetail
    
    var title: String {
        if mangaDetail.jpnTitle.isEmpty {
            return manga.title
        } else {
            return mangaDetail.jpnTitle
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
                        .foregroundColor(.white)
                    Text(manga.uploader)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.6))
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
                        let contentView = ContentView(isContentViewPresented: $isContentViewPresented,
                                                      detailURL: manga.detailURL,
                                                      pages: Int(mangaDetail.pageCount) ?? 0)
                        Button(action: {}) { NavigationLink(destination: contentView) {
                            Text("読む")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }}
                        .buttonStyle(CapsuleButtonStyle())
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
        HStack {
            DescScrollItem(title: "気に入り", value: detail.likeCount, numeral: "人")
            Spacer()
            DescScrollItem(title: "言語", value: detail.languageAbbr, numeral: detail.translatedLanguage)
            Spacer()
            DescScrollRatingItem(title: detail.ratingCount + "件の評価", rating: manga.rating)
            Spacer()
            DescScrollItem(title: "ページ", value: detail.pageCount, numeral: "頁")
            Spacer()
            DescScrollItem(title: "サイズ", value: detail.sizeCount, numeral: detail.sizeType)
        }
        .foregroundColor(.white)
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
        .frame(minWidth: 50, maxWidth: 60)
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
            RatingView(rating: rating, .white)
        }
        .frame(minWidth: 60, maxWidth: 100)
    }
}

// MARK: プレビュー
private struct PreviewView: View {
    let previewItems: [MangaContent]
    let previewCount: Int
    
    var body: some View {
        VStack {
            HStack {
                Text("プレビュー")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .font(.title3)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) { HStack {
                if !previewItems.isEmpty {
                    ForEach(previewItems) { item in
                        ImageView(container: ImageContainer(from: item.url, type: .preview, 300))
                    }
                } else {
                    ForEach(0..<previewCount) { _ in
                        ImageView(container: ImageContainer(from: "", type: .preview, 300))
                    }
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
