import ComposableArchitecture
import AppModels
import Foundation

public struct DownloadQueueStore: Sendable {
    private let identifiers: Shared<[String]>

    public init(fileURL: URL) {
        identifiers = Shared(wrappedValue: [], .fileStorage(fileURL))
    }

    public var gids: [String] {
        identifiers.wrappedValue
    }

    public func contains(_ gid: String) -> Bool {
        identifiers.wrappedValue.contains(gid)
    }

    public func enqueue(_ gid: String) async {
        identifiers.withLock { gids in
            guard !gids.contains(gid) else { return }
            gids.append(gid)
        }
        await save()
    }

    public func remove(_ gid: String) async {
        identifiers.withLock { gids in
            gids.removeAll { $0 == gid }
        }
        await save()
    }

    public func removeAll() async {
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
