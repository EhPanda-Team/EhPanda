//
//  TorrentsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/02.
//

import SwiftUI
import TTProgressHUD

struct TorrentsView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )

    private var gid: String

    init(gid: String) {
        self.gid = gid
    }

    var body: some View {
        NavigationView {
            Group {
                if !torrents.isEmpty {
                    ZStack {
                        ScrollView {
                            LazyVStack {
                                ForEach(torrents) { torrent in
                                    TorrentRow(
                                        torrent: torrent,
                                        action: onTorrentRowTap
                                    )
                                    .background(color)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .padding(.vertical, 5)
                                }
                            }
                            .padding(.top)
                        }
                        TTProgressHUD($hudVisible, config: hudConfig)
                    }
                } else if detailInfo.mangaTorrentsLoading {
                    LoadingView()
                } else {
                    NetworkErrorView(retryAction: fetchMangaTorrents)
                }
            }
            .navigationBarTitle("Torrents")
        }
        .onAppear(perform: onAppear)
    }
}

private extension TorrentsView {
    var color: Color {
        colorScheme == .light
            ? Color(.systemGray6)
            : Color(.systemGray5)
    }

    var mangaDetail: MangaDetail? {
        cachedList.items?[gid]?.detail
    }
    var torrents: [MangaTorrent] {
        mangaDetail?.torrents ?? []
    }

    func onAppear() {
        fetchMangaTorrents()
    }
    func onTorrentRowTap(_ magnet: String) {
        saveToPasteboard(magnet)
        showCopiedHUD()
    }

    func showCopiedHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .success,
            title: "Success".localized(),
            caption: "Copied to clipboard".localized(),
            shouldAutoHide: true,
            autoHideInterval: 2,
            hapticsEnabled: false
        )
        hudVisible.toggle()
    }

    func fetchMangaTorrents() {
        store.dispatch(.fetchMangaTorrents(gid: gid))
    }
}

private struct TorrentRow: View {
    private let torrent: MangaTorrent
    private let action: (String) -> Void

    init(
        torrent: MangaTorrent,
        action: @escaping (String) -> Void
    ) {
        self.torrent = torrent
        self.action = action
    }

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
                Text(torrent.formattedDateString)
            }
            .lineLimit(1)
            .font(.callout)
            .foregroundColor(.gray)
            .padding(.top, 10)
        }
        .padding()
    }

    private func onFileNameTap() {
        action(torrent.magnet)
    }
}

private struct SeedLabel: View {
    private let symbolName: String
    private let text: String

    init(symbolName: String, text: String) {
        self.symbolName = symbolName
        self.text = text
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbolName)
            Text(text)
        }
    }
}
