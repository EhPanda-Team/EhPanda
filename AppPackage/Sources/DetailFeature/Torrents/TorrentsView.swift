import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import SystemNotification
import AppComponents
import SFSafeSymbolsExt

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
                        store.send(.fetchTorrent(torrent.hash, torrent.torrentURL))
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
                    store.send(.fetchGalleryTorrents(gid, token))
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
            .onAppear {
                store.send(.fetchGalleryTorrents(gid, token))
            }
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
                HStack(spacing: 12) {
                    Label {
                        Text(torrent.seedCount, format: .number)
                    } icon: {
                        Image(systemSymbol: .arrowUpCircle)
                    }

                    Label {
                        Text(torrent.peerCount, format: .number)
                    } icon: {
                        Image(systemSymbol: .arrowDownCircle)
                    }

                    Label {
                        Text(torrent.downloadCount, format: .number)
                    } icon: {
                        Image(systemSymbol: .checkmarkCircle)
                    }

                    Label(torrent.fileSize, systemSymbol: .documentCircle)
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
