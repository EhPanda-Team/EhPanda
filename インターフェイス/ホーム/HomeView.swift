//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    let items = RequestManager.shared.getPopularManga()
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    if let mangaItems = items {
                        ForEach(mangaItems) { item in
                            MangaSummaryRow(container: ImageContainer(from: item.coverURL), manga: item)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle(Text("ホーム"))
        }
        
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
