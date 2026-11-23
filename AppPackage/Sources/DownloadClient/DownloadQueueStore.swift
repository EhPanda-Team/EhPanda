import AppModels
import ComposableArchitecture
public import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadQueueStore.self))

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

    /// Rewrites the order of the named gids within the slots they already occupy. The gids of `order` that the
    /// queue holds, each counted once at its first appearance, fill those same slots in `order`'s order; every
    /// other entry keeps its slot, and a gid the queue does not hold is ignored, never added. So this is a
    /// permutation that never adds or removes an entry: it is not a queue entrance, which is why
    /// `DownloadSourceInventoryTests`' entrance census does not count it, and it needs none of the failure-state
    /// clearing an entrance owes.
    public func reorder(_ order: [String]) async {
        identifiers.withLock { gids in
            let held = Set(gids)
            var seen = Set<String>()
            var moved = order.filter({ held.contains($0) && seen.insert($0).inserted })[...]
            gids = gids.map({ gid in
                seen.contains(gid) ? (moved.popFirst() ?? gid) : gid
            })
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
            logger.error("\(error, privacy: .private)")
        }
    }
}
