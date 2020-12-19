//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = ContentItemsStore(owner: "ContentView")
    
    let detailURL: String
    let pages: Int
    
    var body: some View { Group {
        if !store.contentItems.isEmpty {
            ScrollView { LazyVStack(spacing: 0) {
                ForEach(store.contentItems) { item in
                    ImageView(container: ImageContainer(from: item.url, type: .none, 0))
                }
            }}
            .ignoresSafeArea()
            .transition(AnyTransition.opacity.animation(.linear(duration: 0.5)))
        } else {
            LoadingView()
        }}
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(settings.navBarHidden)
        .onAppear {
            settings.navBarHidden = true
            
            store.fetchContentItems(url: detailURL, pages: pages)
        }
    }
}

private struct ImageView: View {
    @StateObject var container: ImageContainer
    
    var body: some View {
        container.image
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
