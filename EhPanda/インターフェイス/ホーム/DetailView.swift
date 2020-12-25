//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import SDWebImageSwiftUI

struct DetailView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = DetailItemsStore()
    @StateObject var contentStore = ContentItemsStore(owner: "DetailView")
    
    @Environment(\.colorScheme) var colorScheme
    @State var backgroundColor: Color?
    @State var lighterColor: Color?
    @State var darkerColor: Color?
    
    let manga: Manga
    
    var body: some View {
        Group {
            if let detailItem = store.detailItem {
                ZStack {
                    backgroundColor
                        .ignoresSafeArea()
                    VStack {
                        Group {
                            HeaderView(manga: manga, mangaDetail: detailItem)
                                .frame(height: 150)
                            DescScrollView(manga: manga, detail: detailItem)
                                .frame(height: 60)
                                .padding(.vertical, 30)
                            PreviewView(previewItems: contentStore.contentItems)
                        }
                    }
                    .padding(.top, -40)
                    .padding(.bottom, 10)
                    .padding(.horizontal)
                }
                .transition(AnyTransition.opacity.animation(.default))
            } else {
                LoadingView()
            }
        }
        .navigationBarHidden(settings.navBarHidden)
        .onChange(of: colorScheme) { _ in
            changeBackgroundColor(reverse: true)
        }
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
        
        let manager = ImageManager(url: url)
        manager.setOnSuccess { (image) in
            guard let uiColor = image.imageWithoutBaseline().averageColor,
                  let lighterUIColor = uiColor.lighter(),
                  let darkerUIColor = uiColor.darker()
            else { return }
            
            lighterColor = Color(lighterUIColor)
            darkerColor = Color(darkerUIColor)
            changeBackgroundColor(reverse: false)
        }
        manager.load()
    }
    
    func changeBackgroundColor(reverse: Bool) {
        if colorScheme == .light {
            backgroundColor = reverse ? darkerColor : lighterColor
        } else {
            backgroundColor = reverse ? lighterColor : darkerColor
        }
    }
}

// MARK: ヘッダー
private struct HeaderView: View {
    var rectangle: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 8/11 * 150, height: 150)
    }
    
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
            WebImage(url: URL(string: manga.coverURL))
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
                Text(manga.uploader)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(Color.primary.opacity(0.6))
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
        .scaledToFill()
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
        .scaledToFill()
        .frame(idealWidth: 60)
    }
}

// MARK: プレビュー
private struct PreviewView: View {
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
    
    let previewItems: [MangaContent]
    
    var body: some View {
        VStack {
            HStack {
                Text("プレビュー")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
            }
            GeometryReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        if !previewItems.isEmpty {
                            ForEach(previewItems) { item in
                                WebImage(url: URL(string: item.url))
                                    .resizable()
                                    .placeholder {
                                        Placeholder(width: reader.size.height * 32/45,
                                                    height: reader.size.height)
                                    }
                                    .indicator(.progress)
                                    .scaledToFill()
                                    .frame(width: reader.size.height * 32/45,
                                           height: reader.size.height)
                                    .cornerRadius(15)
                            }
                        } else {
                            ForEach(0..<10) { _ in
                                Placeholder(width: reader.size.height * 32/45,
                                            height: reader.size.height)
                            }
                        }
                    }
                }
            }
        }
    }
}
