//
//  MangaSummaryRow.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/31.
//

import SwiftUI

struct MangaSummaryRow: View {
    @ObservedObject var container: ImageContainer
    let manga: Manga
    var body: some View {
        HStack {
            container.image
                .resizable()
                .frame(width: 70, height: 110)
                .scaledToFit()
            VStack(alignment: .leading) {
                Text(manga.title)
                    .lineLimit(1)
                    .font(.headline)
                Text(manga.uploader)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    let rating = manga.rating
                    let fillCount = Int(rating)
                    let halfCount = /* Int(rating - 0.5) == fillCount ? 1 : */ 0
                    let emptyCount = 5 - fillCount - halfCount
                    
                    
                    ForEach(0..<fillCount) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.small)
                    }
//                    ForEach(0..<halfCount) { _ in
//                        Image(systemName: "star.lefthalf.fill")
//                            .foregroundColor(.yellow)
//                            .imageScale(.small)
//                    }
                    ForEach(0..<emptyCount) { _ in
                        Image(systemName: "star")
                            .foregroundColor(.yellow)
                            .imageScale(.small)
                    }
                }
                HStack(alignment: .bottom) {
                    Text(manga.category)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 1, leading: 3, bottom: 1, trailing: 3))
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .foregroundColor(.blue)
                        )
                    Spacer()
                    Text(manga.publishedTime)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.top, 1)
            }.padding(10)
        }
        .background(Color(.systemGray6))
        .cornerRadius(3)
    }
}

final class ImageContainer: ObservableObject {

    // @PublishedをつけるとSwiftUIのViewへデータが更新されたことを通知してくれる
    @Published var image = Image("test")

    init(from resource: String) {
        // ネットワークから画像データ取得
        guard let URL = URL(string: resource) else { return }
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: URL, completionHandler: { [weak self] data, _, _ in
            guard let imageData = data,
                let networkImage = UIImage(data: imageData) else {
                return
            }

            DispatchQueue.main.async {
                // 宣言時に@Publishedを付けているので、プロパティを更新すればView側に更新が通知される
                self?.image = Image(uiImage: networkImage)
            }
            session.invalidateAndCancel()
        })
        task.resume()
    }
}
