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
                    StarView(rating: manga.rating)
                }
                HStack(alignment: .bottom) {
                    Text(manga.translatedCategory)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.init(top: 1, leading: 3, bottom: 1, trailing: 3))
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .foregroundColor(Color(manga.color))
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

struct StarView: View {
    let rating: Float
    
    var fillCount: Int {
        get { Int(rating) }
    }
    var halfCount: Int {
        get { Int(rating - 0.5) == fillCount ? 1 : 0 }
    }
    var emptyCount: Int {
        get { 5 - fillCount - halfCount }
    }
    
    var body: some View {
        ForEach(0..<fillCount) { _ in
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .imageScale(.small)
        }
        ForEach(0..<halfCount) { _ in
            Image(systemName: "star.lefthalf.fill")
                .foregroundColor(.yellow)
                .imageScale(.small)
        }
        ForEach(0..<emptyCount) { _ in
            Image(systemName: "star")
                .foregroundColor(.yellow)
                .imageScale(.small)
        }
    }
}

final class ImageContainer: ObservableObject {
    @Published var image = Image("test")

    init(from resource: String) {
        guard let URL = URL(string: resource) else { return }
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: URL, completionHandler: { [weak self] data, _, _ in
            guard let imageData = data,
                let networkImage = UIImage(data: imageData) else {
                return
            }

            DispatchQueue.main.async {
                self?.image = Image(uiImage: networkImage)
            }
            session.invalidateAndCancel()
        })
        task.resume()
    }
}
