import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbols
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
                        $0.visible(store.loadingState == .loading && store.torrents.isEmpty)
                    }
            }
            .overlay {
                let error = store.loadingState.failed
                ErrorView(error: error ?? .unknown) {
                    store.send(.fetchGalleryTorrents(gid: gid, token: token))
                }
                .animation(.default) {
                    $0.visible(error != nil && store.torrents.isEmpty)
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
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        private let torrent: GalleryTorrent
        private let action: (String) -> Void

        init(torrent: GalleryTorrent, action: @escaping (String) -> Void) {
            self.torrent = torrent
            self.action = action
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                counters
                    .labelIconToTitleSpacing(3)
                    .foregroundStyle(.primary)
                    .font(.footnote)

                Button {
                    action(torrent.magnetURL)
                } label: {
                    Text(torrent.fileName)
                        .font(.headline)
                }

                uploaderAndDate
            }
            .padding()
        }

        /// The four counters are four glyph-and-number pairs sharing one line. Their glyphs are
        /// intrinsically sized and never give way, so once the numbers outgrow the line it is the
        /// numbers that are cut — the row used to end up showing four glyphs and no values at all,
        /// which is the whole of what it exists to say about a torrent's health and size.
        ///
        /// Below the gate the designed row renders verbatim. Above it the same four pairs flow:
        /// each line takes as many pairs as it holds whole and the rest wrap onto the next one, so
        /// the row grows downwards instead of cutting a number off. `FlowLayout` measures the real
        /// subviews against the width actually offered, so there is no ideal-versus-rendered
        /// mismatch to clip on, and a pair that fits no line at all is re-measured against that
        /// line, so its number wraps rather than losing digits. Nothing in this arrangement carries
        /// a `lineLimit`, for the same reason.
        ///
        /// The flowed pairs are plain stacks, not `Label`s. Inside a `List` row a `Label` is laid
        /// out by the list, which places the title against a shared icon column instead of inside
        /// the label's own bounds, so a custom `Layout` measuring the label is answered with the
        /// icon alone (44 x 44 points per pair, measured) and the value is drawn nowhere. A glyph
        /// and a text in an `HStack` own their whole size and measure honestly.
        ///
        /// What is given up above the gate is the file size's trailing anchor: in a flow the pairs
        /// simply follow one another, so the size sits wherever its line leaves it. That is
        /// decoration, and the values are content.
        @ViewBuilder private var counters: some View {
            if dynamicTypeSize <= .large {
                compactCounters
            } else {
                FlowLayout(spacing: 12, lineSpacing: 10) {
                    ForEach(TorrentCounter.allCases, id: \.self, content: flowedCounter)
                }
            }
        }

        /// The designed row, kept verbatim at and below the default size: three health counters
        /// leading, the file size trailing. The `Spacer(minLength: 0)` is what anchors that pair at
        /// the trailing edge, and its zero minimum lets it collapse completely before any of the
        /// four pairs has to give up width — the row spends its slack on the gap first.
        private var compactCounters: some View {
            HStack(spacing: 12) {
                labelledCounter(.seeds)
                labelledCounter(.peers)
                labelledCounter(.downloads)

                Spacer(minLength: 0)

                labelledCounter(.fileSize)
            }
            .lineLimit(1)
        }

        private func value(of counter: TorrentCounter) -> Text {
            switch counter {
            case .seeds: Text(torrent.seedCount, format: .number)
            case .peers: Text(torrent.peerCount, format: .number)
            case .downloads: Text(torrent.downloadCount, format: .number)
            case .fileSize: Text(torrent.fileSize)
            }
        }

        // A list row inflates a `titleAndIcon` label's icon well past the bare `Image` these
        // replaced — measured at ~29% wider (G-11-8). Re-asserting the default scale on each
        // icon overrides that ambient inflation and restores the pre-sweep glyphs; it is
        // deliberately not a no-op, and all four must carry it or they drift apart.
        private func labelledCounter(_ counter: TorrentCounter) -> some View {
            Label {
                value(of: counter)
            } icon: {
                Image(systemSymbol: counter.symbol)
                    .imageScale(.medium)
            }
        }

        /// The same glyph and value as `labelledCounter`, at the 3-point gap the labels get from
        /// `labelIconToTitleSpacing`, in a stack that measures as a whole (see `counters`).
        ///
        /// The glyph is hidden from assistive technology so both arrangements announce alike: a
        /// `Label` exposes only its title, whereas a bare `Image` in a stack is its own element
        /// read by its symbol description — "Arrow Up Circle", and "Selected" for the downloads
        /// glyph, which is wrong information beside a count (observed at AX3, plan 16-16).
        private func flowedCounter(_ counter: TorrentCounter) -> some View {
            HStack(spacing: 3) {
                Image(systemSymbol: counter.symbol)
                    .imageScale(.medium)
                    .accessibilityHidden(true)
                value(of: counter)
            }
        }

        /// Uploader and timestamp are a trailing-anchored pair: they sit together at the row's
        /// trailing edge for as long as both fit one line, and take a line each — still
        /// trailing-anchored — once they do not, instead of shortening a name to `Disko…` and a
        /// date to its year. The flexible frame that anchors them stays outside the pair, because
        /// inside a candidate it would absorb the overflow and every candidate would measure as
        /// fitting.
        private var uploaderAndDate: some View {
            AdaptiveStack(vAlignment: .trailing) {
                Text(torrent.uploader)
                Text(torrent.formattedDateString)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .lineLimit(statLineLimit)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        }

        /// Both values read in full on one line at every non-accessibility size, so they keep their
        /// single line there. At accessibility sizes the cap is lifted, so a name or a timestamp
        /// that outgrows even a full-width line of its own wraps rather than losing its tail.
        private var statLineLimit: Int? {
            dynamicTypeSize.isAccessibilitySize ? nil : 1
        }
    }
}

/// The four values a torrent row reports, in their designed order.
private enum TorrentCounter: CaseIterable {
    case seeds, peers, downloads, fileSize

    var symbol: SFSymbol {
        switch self {
        case .seeds: .arrowUpCircle
        case .peers: .arrowDownCircle
        case .downloads: .checkmarkCircle
        case .fileSize: .documentCircle
        }
    }
}

@MainActor private func previewTorrentsView() -> some View {
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

#Preview("Initial") {
    previewTorrentsView()
}

#Preview("Accessibility 3") {
    previewTorrentsView()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5") {
    previewTorrentsView()
        .environment(\.dynamicTypeSize, .accessibility5)
}
