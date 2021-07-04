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
    @State private var hudConfig = TTProgressHUDConfig()

    @State private var loadingFlag = false
    @State private var torrents = [MangaTorrent]()

    private let gid: String
    private let token: String

    init(gid: String, token: String) {
        self.gid = gid
        self.token = token
    }

    var body: some View {
        NavigationView {
            Group {
                if !torrents.isEmpty {
                    ZStack {
                        List(torrents) { torrent in
                            TorrentRow(
                                torrent: torrent,
                                action: onTorrentRowTap
                            )
                        }
                        TTProgressHUD($hudVisible, config: hudConfig)
                    }
                } else if loadingFlag {
                    LoadingView()
                } else {
                    NetworkErrorView(retryAction: fetchMangaTorrents)
                }
            }
            .navigationBarTitle("Torrents")
        }
        .task(fetchMangaTorrents)
    }
}

private extension TorrentsView {
    func onTorrentRowTap(magnet: String) {
        saveToPasteboard(value: magnet)
        showCopiedHUD()
    }

    func showCopiedHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .success,
            title: "Success".localized(),
            caption: "Copied to clipboard".localized(),
            shouldAutoHide: true,
            autoHideInterval: 2
        )
        hudVisible.toggle()
    }

    func fetchMangaTorrents() {
        if loadingFlag { return }
        loadingFlag = true

        let sToken = SubscriptionToken()
        MangaTorrentsRequest(gid: gid, token: token)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                loadingFlag = false
                sToken.unseal()
            } receiveValue: {
                torrents = $0
                loadingFlag = false
            }
            .seal(in: sToken)
    }
}

// MARK: TorrentRow
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
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle")
                    Text("\(torrent.seedCount)")
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle")
                    Text("\(torrent.peerCount)")
                }
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle")
                    Text("\(torrent.downloadCount)")
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "doc.circle")
                    Text(torrent.fileSize)
                }
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
            .padding(.top, 10)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func onFileNameTap() {
        action(torrent.magnet)
    }
}
