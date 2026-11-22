/// A waiting download's place among the waiting downloads. A waiting item is a gallery whose display status
/// is `.queued`; position 1 is the next to start. The coordinator derives places from the persisted queue on
/// every read and nothing stores them; they drive the waiting group's order and the badge's VoiceOver reading
/// (A-1, B-6).
public struct DownloadQueuePlace: Equatable, Sendable {
    public let position: Int
    public let waitingCount: Int

    public init(position: Int, waitingCount: Int) {
        self.position = position
        self.waitingCount = waitingCount
    }

    public static func places(forWaitingGIDs gids: [String]) -> [String: DownloadQueuePlace] {
        Dictionary(
            gids.enumerated().map({ offset, gid in
                (gid, DownloadQueuePlace(position: offset + 1, waitingCount: gids.count))
            }),
            uniquingKeysWith: { first, _ in first }
        )
    }
}
