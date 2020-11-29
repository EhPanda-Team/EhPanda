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
