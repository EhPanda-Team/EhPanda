//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var manager = RequestManager.shared
    
    var body: some View {
        NavigationView {
            if manager.status == .loaded {
                ScrollView {
                    LazyVStack {
                        if let mangaItems = RequestManager.shared.popularMangas {
                            ForEach(mangaItems) { item in
                                MangaSummaryRow(container: ImageContainer(from: item.coverURL), manga: item)
                            }
                        }
                    }
                    .padding()
                    .navigationBarTitle("ホーム")
                }
            } else if manager.status == .loading {
                ProgressView("読み込み中...")
                    .navigationBarTitle("ホーム")
            } else if manager.status == .failed {
                VStack {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 50))
                        .padding(.bottom, 15)
                    Text("読み込み中に問題が発生しました\nしばらくしてからもう一度お試しください")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .font(.headline)
                }
                .navigationBarTitle("ホーム")
                .onTapGesture {
                    RequestManager.shared.getPopularManga()
                }
            }
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
