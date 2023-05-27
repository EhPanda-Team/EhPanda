//
//  TorrentsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/02.
//

import SwiftUI
import ComposableArchitecture

struct TorrentsView: View {
    private let store: StoreOf<TorrentsReducer>
    @ObservedObject private var viewStore: ViewStoreOf<TorrentsReducer>
    private let gid: String
    private let token: String
    private let blurRadius: Double

    init(store: StoreOf<TorrentsReducer>, gid: String, token: String, blurRadius: Double) {
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
                        viewStore.send(.copyText(magnetURL))
                    }
                    .swipeActions {
                        Button {
                            viewStore.send(.fetchTorrent(torrent.hash, torrent.torrentURL))
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
            .sheet(unwrapping: viewStore.binding(\.$route), case: /TorrentsReducer.Route.share) { route in
                ActivityView(activityItems: [route.wrappedValue])
                    .autoBlur(radius: blurRadius)
            }
            .progressHUD(
                config: viewStore.hudConfig,
                unwrapping: viewStore.binding(\.$route),
                case: /TorrentsReducer.Route.hud
            )
            .animation(.default, value: viewStore.torrents)
            .onAppear {
                viewStore.send(.fetchGalleryTorrents(gid, token))
            }
            .navigationTitle(L10n.Localizable.TorrentsView.Title.torrents)
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
                reducer: TorrentsReducer()
            ),
            gid: .init(),
            token: .init(),
            blurRadius: 0
        )
    }
}
