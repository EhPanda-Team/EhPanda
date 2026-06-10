//
//  DownloadQueueStore.swift
//  EhPanda
//

import ComposableArchitecture
import Foundation

struct DownloadQueueStore: Sendable {
    private let identifiers: Shared<[String]>

    init(fileURL: URL) {
        identifiers = Shared(wrappedValue: [], .fileStorage(fileURL))
    }

    var gids: [String] {
        identifiers.wrappedValue
    }

    func contains(_ gid: String) -> Bool {
        identifiers.wrappedValue.contains(gid)
    }

    func enqueue(_ gid: String) async {
        identifiers.withLock { gids in
            guard !gids.contains(gid) else { return }
            gids.append(gid)
        }
        await save()
    }

    func remove(_ gid: String) async {
        identifiers.withLock { gids in
            gids.removeAll { $0 == gid }
        }
        await save()
    }

    func removeAll() async {
        identifiers.withLock { gids in
            gids.removeAll()
        }
        await save()
    }

    private func save() async {
        do {
            try await identifiers.save()
        } catch {
            Logger.error(error)
        }
    }
}
