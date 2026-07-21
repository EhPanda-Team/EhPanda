import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbolsExt
import SwiftUI
import SystemNotification

struct TorrentsView: View {
    @Bindable private var store: StoreOf<TorrentsReducer>
    private let gid: String
    private let token: String

    init(store: StoreOf<TorrentsReducer>, gid: String, token: String) {
        self.store = store
        self.gid = gid
        self.token = token
    }

    var body: some View {
        NavigationStack {
            List(store.torrents) { torrent in
                TorrentRow(torrent: torrent) { magnetURL in
                    store.send(.copyText(magnetURL))
                }
                .swipeActions {
                    Button {
                        store.send(.fetchTorrent(hash: torrent.hash, url: torrent.torrentURL))
                    } label: {
                        Label(.accessibilityDownload, systemSymbol: .arrowDownDocumentFill)
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .overlay {
                LoadingView()
                    .animation(.default) {
                        $0.opacity(store.loadingState == .loading && store.torrents.isEmpty ? 1 : 0)
                    }
            }
            .overlay {
                let error = store.loadingState.failed
                ErrorView(error: error ?? .unknown) {
                    store.send(.fetchGalleryTorrents(gid: gid, token: token))
                }
                .animation(.default) {
                    $0.opacity(error != nil && store.torrents.isEmpty ? 1 : 0)
                }
            }
            .sheet(item: $store.destination.share, id: \.absoluteString) { url in
                ActivityView(activityItems: [url.wrappedValue])
                    .privacyMask()
            }
            .toast($store.scope(\.$toast, action: \.toast))
            .animation(.default, value: store.torrents)
            .navigationTitle(.torrents)
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
                // A list row inflates a `titleAndIcon` label's icon well past the bare `Image` these
                // replaced — measured at ~29% wider (G-11-8). Re-asserting the default scale on each
                // icon overrides that ambient inflation and restores the pre-sweep glyphs; it is
                // deliberately not a no-op, and all four must carry it or they drift apart.
                HStack(spacing: 12) {
                    Label {
                        Text(torrent.seedCount, format: .number)
                    } icon: {
                        Image(systemSymbol: .arrowUpCircle)
                            .imageScale(.medium)
                    }

                    Label {
                        Text(torrent.peerCount, format: .number)
                    } icon: {
                        Image(systemSymbol: .arrowDownCircle)
                            .imageScale(.medium)
                    }

                    Label {
                        Text(torrent.downloadCount, format: .number)
                    } icon: {
                        Image(systemSymbol: .checkmarkCircle)
                            .imageScale(.medium)
                    }

                    Label {
                        Text(torrent.fileSize)
                    } icon: {
                        Image(systemSymbol: .documentCircle)
                            .imageScale(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .labelIconToTitleSpacing(3)
                .foregroundStyle(.primary)
                .font(.footnote)
                .lineLimit(1)

                Button {
                    action(torrent.magnetURL)
                } label: {
                    Text(torrent.fileName)
                        .font(.headline)
                }

                HStack {
                    Text(torrent.uploader)
                    Text(torrent.formattedDateString)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
            }
            .padding()
        }
    }
}

#Preview("Initial") {
    TorrentsView(
        store: .init(
            initialState: .init(
                torrents: [
                    .init(
                        postedDate: .now, fileSize: "312 MB",
                        seedCount: 42, peerCount: 5, downloadCount: 1280,
                        uploader: "Nreo", fileName: "Sample Gallery [2400x].torrent",
                        hash: .init(), torrentURL: .mock
                    ),
                    .init(
                        postedDate: .now, fileSize: "184 MB",
                        seedCount: 17, peerCount: 2, downloadCount: 640,
                        uploader: "Chihchy", fileName: "Sample Gallery [1280x].torrent",
                        hash: .init(), torrentURL: .mock
                    )
                ]
            ),
            reducer: TorrentsReducer.init
        ),
        gid: .init(),
        token: .init()
    )
}
