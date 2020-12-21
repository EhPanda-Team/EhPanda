//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import AlamofireImage

struct DetailView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = DetailItemsStore()
    @StateObject var contentStore = ContentItemsStore(owner: "DetailView")
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State var backgroundColor: Color = .clear
    @State var shouldBackButtonHidden = true
    
    let manga: Manga
    
    var body: some View {
        Group {
            if let detailItem = store.detailItem {
                ZStack {
                    backgroundColor
                        .ignoresSafeArea()
                    VStack {
                        Group {
                            HeaderView(container: ImageContainer(from: manga.coverURL, type: .cover, 150),
                                       manga: manga,
                                       mangaDetail: detailItem)
                                .fixedSize(horizontal: false, vertical: true)
                            DescScrollView(manga: manga, detail: detailItem)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 30)
                            PreviewView(previewItems: contentStore.contentItems)
                        }
                        .shadow(color: colorScheme == .light ? .gray : .black, radius: 10)
                    }
                    .padding(.top, -40)
                    .padding(.bottom, 10)
                    .padding(.horizontal)
                }
                .transition(AnyTransition.opacity.animation(.default))
                .onAppear {
                    shouldBackButtonHidden = false
                }
            } else {
                LoadingView()
            }
        }
        .navigationBarHidden(settings.navBarHidden)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading:
                Group {
                    if !shouldBackButtonHidden {
                        BackButton {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        )
        .onAppear {
            settings.navBarHidden = false
            
            fetchItems()
            fetchBackgroundColor()
        }
    }
    
    func fetchItems() {
        if store.detailItem == nil {
            store.fetchDetailItem(url: manga.detailURL)
        }
        if contentStore.contentItems.isEmpty {
            contentStore.fetchPreviewItems(url: manga.detailURL)
        }
    }
    
    func fetchBackgroundColor() {
        guard let url = URL(string: manga.coverURL) else { return }
                
        let downloader = ImageDownloader()
        downloader.download(URLRequest(url: url), completion: { (resp) in
            if case .success(let image) = resp.result {
                guard let uiColor = image.averageColor else { return }
                
                if let lighterColor = uiColor.lighter(), colorScheme == .light {
                    backgroundColor = Color(lighterColor)
                } else if let darkerColor = uiColor.darker(), colorScheme == .dark {
                    backgroundColor = Color(darkerColor)
                }
            }
        })
    }
}

// MARK: バックボタン
private struct BackButton: View {
    @Environment(\.colorScheme) var colorScheme
    @State var isPressed = false
    
    let color: Color = Color.primary.opacity(0.8)
    var backAction: () -> ()
    
    var body: some View {
        Button(action: {
            backAction()
        }) {
            Image(systemName: "chevron.backward.circle")
                .foregroundColor(isPressed ? color.opacity(0.5) : color)
                .font(.system(.title))
        }
        .onLongPressGesture(pressing: { (_) in
            isPressed.toggle()
        }, perform: {})
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var container: ImageContainer
    
    let manga: Manga
    var mangaDetail: MangaDetail
    
    var contentView: ContentView {
        ePrint("ContentView inited!")
        let pageCount = mangaDetail.pageCount
        let pages = Int(pageCount) ?? 0
        return ContentView(detailURL: manga.detailURL, pages: pages)
    }
    
    var title: String {
        if mangaDetail.jpnTitle.isEmpty {
            return manga.title
        } else {
            return mangaDetail.jpnTitle
        }
    }
    
    var body: some View {
        HStack {
            container.image
                .resizable()
                .frame(width: 70/110 * 150, height: 150)
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .font(.title3)
                Text(manga.uploader)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(Color.primary.opacity(0.6))
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
                    Button(action: {}) {
                        NavigationLink(destination: contentView) {
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
    @Environment(\.colorScheme) var colorScheme
    
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
    @Environment(\.colorScheme) var colorScheme
    
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
        .frame(minWidth: 60, maxWidth: 100)
    }
}

// MARK: プレビュー
private struct PreviewView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let previewItems: [MangaContent]
    
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
                    if !previewItems.isEmpty {
                        ForEach(previewItems) { item in
                            ImageView(container: ImageContainer(from: item.url, type: .preview, 300))
                        }
                    } else {
                        ForEach(0..<10) { _ in
                            ImageView(container: ImageContainer(from: "", type: .preview, 300))
                        }
                    }
                }
            }
        }
    }
}

private struct ImageView: View {
    @StateObject var container: ImageContainer
    
    var body: some View {
        container.image
            .resizable()
            .aspectRatio(32/45, contentMode: .fit)
            .cornerRadius(15)
    }
}
