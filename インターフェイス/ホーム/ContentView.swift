//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import SDWebImageSwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = ContentItemsStore(owner: "ContentView")
    
    var rectangle: some View {
        Rectangle()
            .fill(Color(.systemGray5))
    }
    
    let detailURL: String
    let pages: Int
    
    var body: some View {
        Group {
            if !store.contentItems.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.contentItems) { item in
                            WebImage(url: URL(string: item.url))
                                .resizable()
                                .placeholder{ rectangle }
                                .indicator(.progress)
                                .scaledToFit()
                        }
                    }
                }
                .ignoresSafeArea()
                .transition(AnyTransition.opacity.animation(.default))
            } else {
                LoadingView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(settings.navBarHidden)
        .onAppear {
            settings.navBarHidden = true
            
            store.fetchContentItems(url: detailURL, pages: pages)
        }
    }
}
