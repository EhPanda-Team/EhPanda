//
//  DownloadBadgeStore.swift
//  EhPanda
//

import Foundation
import Observation

@Observable
@MainActor
final class DownloadBadgeStore {
    static let shared = DownloadBadgeStore(client: DownloadClientKey.liveValue)

    private(set) var badges = [String: DownloadBadge]()
    private(set) var downloads = [String: DownloadedGallery]()

    @ObservationIgnored
    private let client: DownloadClient
    @ObservationIgnored
    private var observeTask: Task<Void, Never>?

    init(client: DownloadClient) {
        self.client = client
        observeTask = Task { [weak self] in
            guard let self else { return }
            await self.apply(downloads: client.fetchDownloads())
            for await downloads in client.observeDownloads() {
                self.apply(downloads: downloads)
            }
        }
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
