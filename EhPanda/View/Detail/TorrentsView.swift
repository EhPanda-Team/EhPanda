//
//  TorrentsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/02.
//

import SwiftUI
import ComposableArchitecture

struct TorrentsView: View {
    private let store: Store<TorrentsState, TorrentsAction>
    @ObservedObject private var viewStore: ViewStore<TorrentsState, TorrentsAction>
    private let gid: String
    private let token: String
    private let blurRadius: Double

    init(store: Store<TorrentsState, TorrentsAction>, gid: String, token: String, blurRadius: Double) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        self.token = token
        self.blurRadius = blurRadius
    }

    var body: some View {
        NavigationView {
            ZStack {
                List(viewStore.torrents) { torrent in
                    TorrentRow(torrent: torrent) { magnetURL in
                        viewStore.send(.copyMagnetURL(magnetURL))
                    }
                    .swipeActions {
                        Button {
                            if let torrentURL = URL(string: torrent.torrentURL) {
                                viewStore.send(.fetchTorrent(torrent.hash, torrentURL))
                            }
                        } label: {
                            Image(systemSymbol: .arrowDownDocFill)
                        }
                    }
                }
                LoadingView().opacity(viewStore.loadingState == .loading && viewStore.torrents.isEmpty ? 1 : 0)
                let error = (/LoadingState.failed).extract(from: viewStore.loadingState)
                ErrorView(error: error ?? .unknown) {
                    viewStore.send(.fetchGalleryTorrents(gid, token))
                }
                .opacity(error != nil && viewStore.torrents.isEmpty ? 1 : 0)
            }
            .animation(.default, value: viewStore.torrents)
            .progressHUD(
                config: viewStore.hudConfig,
                unwrapping: viewStore.binding(\.$route),
                case: /TorrentsState.Route.hud
            )
            .sheet(unwrapping: viewStore.binding(\.$route), case: /TorrentsState.Route.share) { route in
                ActivityView(activityItems: [route.wrappedValue])
                    .autoBlur(radius: blurRadius)
            }
            .onAppear {
                viewStore.send(.fetchGalleryTorrents(gid, token))
            }
            .navigationTitle("Torrents")
        }
    }
}

private extension TorrentsView {
    struct TorrentRow: View {
        private let torrent: GalleryTorrent
        private let action: (String) -> Void

        init(torrent: GalleryTorrent, action: @escaping (String) -> Void) {
            self.torrent = torrent
            self.action = action
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemSymbol: .arrowUpCircle)
                        Text("\(torrent.seedCount)")
                    }
                    HStack(spacing: 3) {
                        Image(systemSymbol: .arrowDownCircle)
                        Text("\(torrent.peerCount)")
                    }
                    HStack(spacing: 3) {
                        Image(systemSymbol: .checkmarkCircle)
                        Text("\(torrent.downloadCount)")
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemSymbol: .docCircle)
                        Text(torrent.fileSize)
                    }
                }
                .minimumScaleFactor(0.1).lineLimit(1)
                Button {
                    action(torrent.magnetURL)
                } label: {
                    Text(torrent.fileName).font(.headline)
                }
                HStack {
                    Spacer()
                    Text(torrent.uploader)
                    Text(torrent.formattedDateString)
                }
                .lineLimit(1).font(.callout)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.5)
                .padding(.top, 10)
            }
            .padding()
        }
    }
}

struct TorrentsView_Previews: PreviewProvider {
    static var previews: some View {
        TorrentsView(
            store: .init(
                initialState: .init(),
                reducer: torrentsReducer,
                environment: TorrentsEnvironment(
                    fileClient: .live,
                    hapticClient: .live,
                    clipboardClient: .live
                )
            ),
            gid: .init(),
            token: .init(),
            blurRadius: 0
        )
    }
}
