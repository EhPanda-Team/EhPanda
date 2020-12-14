//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var store = ContentItemsStore()
    @Binding var isContentViewPresented: Bool
    
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
        .navigationBarHidden(true)
        .onAppear {
            isContentViewPresented = true
            
            if store.contentItems.isEmpty {
                store.fetchContentItems(url: detailURL, pages: pages)
            }
        }
        .onDisappear {
            store.contentItems.removeAll()
        }
    }
}

private struct ImageView: View {
    @ObservedObject var container: ImageContainer
    
    var body: some View {
        container.image
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
