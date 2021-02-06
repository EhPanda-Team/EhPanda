//
//  TorrentsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/02.
//

import SwiftUI

struct TorrentsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    var id: String
    var color: Color {
        colorScheme == .light
            ? Color(.systemGray6)
            : Color(.systemGray5)
    }
    
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[id]?.detail
    }
    var torrents: [MangaTorrent] {
        mangaDetail?.torrents ?? []
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !torrents.isEmpty {
                    ScrollView {
                        LazyVStack {
                            ForEach(torrents) { torrent in
                                TorrentRow(torrent: torrent)
                                    .background(color)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .padding(.vertical, 5)
                            }
                        }
                        .padding(.top)
                    }
                } else if detailInfo.mangaTorrentsLoading {
                    LoadingView()
                } else {
                    NetworkErrorView(retryAction: fetchMangaTorrents)
                }
            }
            .navigationBarTitle("トレント")
        }
        .onAppear(perform: onAppear)
    }
    
    func onAppear() {
        fetchMangaTorrents()
    }
    func fetchMangaTorrents() {
        store.dispatch(.fetchMangaTorrents(id: id))
    }
}

private struct TorrentRow: View {
    let torrent: MangaTorrent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SeedLabel(
                    symbolName: "arrow.up.circle",
                    text: "\(torrent.seedCount)"
                )
                SeedLabel(
                    symbolName: "arrow.down.circle",
                    text: "\(torrent.peerCount)"
                )
                SeedLabel(
                    symbolName: "checkmark.circle",
                    text: "\(torrent.downloadCount)"
                )
                Spacer()
                SeedLabel(
                    symbolName: "doc.circle",
                    text: torrent.fileSize
                )
            }
            .lineLimit(1)
            Button(action: onFileNameTap) {
                Text(torrent.fileName)
                    .font(.headline)
            }
            HStack {
                Spacer()
                Text(torrent.uploader)
                Text(torrent.postedTime)
            }
            .lineLimit(1)
            .font(.callout)
            .foregroundColor(.gray)
            .padding(.top, 10)
        }
        .padding()
    }
    
    func onFileNameTap() {
        saveToPasteboard(torrent.magnet)
    }
}

private struct SeedLabel: View {
    let symbolName: String
    let text: String
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbolName)
            Text(text)
        }
    }
}
