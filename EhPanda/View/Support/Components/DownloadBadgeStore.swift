//
//  DownloadBadgeStore.swift
//  EhPanda
//

import Foundation

@MainActor
final class DownloadBadgeStore: ObservableObject {
    static let shared = DownloadBadgeStore(client: DownloadClientKey.liveValue)

    @Published private(set) var badges = [String: DownloadBadge]()
    @Published private(set) var downloads = [String: DownloadedGallery]()

    private let client: DownloadClient
    private var observeTask: Task<Void, Never>?

    init(client: DownloadClient) {
        self.client = client
        observeTask = Task { [weak self] in
            guard let self else { return }
            await self.apply(downloads: client.fetchDownloads())
            for await downloads in client.observeDownloads() {
                await self.apply(downloads: downloads)
            }
        }
    }

    func resolvedCoverURL(for gallery: Gallery) -> URL? {
        downloads[gallery.gid]?.coverURL ?? gallery.coverURL
    }

    private func apply(downloads: [DownloadedGallery]) {
        let resolvedDownloads = Dictionary(uniqueKeysWithValues: downloads.map { ($0.gid, $0) })
        let resolvedBadges = Dictionary(uniqueKeysWithValues: downloads.map { ($0.gid, $0.badge) })

        guard self.downloads != resolvedDownloads || badges != resolvedBadges else {
            return
        }

        self.downloads = resolvedDownloads
        badges = resolvedBadges
    }

    deinit {
        observeTask?.cancel()
    }
}
