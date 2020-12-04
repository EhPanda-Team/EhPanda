//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            LoadingView { ScrollView { LazyVStack {
                if let mangaItems = RequestManager.shared.popularMangas {
                    ForEach(mangaItems) { item in
                        MangaSummaryRow(container: ImageContainer(from: item.coverURL), manga: item)
                    }
                }}.padding()}
            } retryAction: {
                RequestManager.shared.getPopularManga()
            }
            .navigationBarTitle("ホーム")
        }
        .onAppear {
            RequestManager.shared.getPopularManga()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
