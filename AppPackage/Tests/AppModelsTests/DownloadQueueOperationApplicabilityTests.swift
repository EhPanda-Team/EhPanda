import AppModels
import Testing

/// B-5: one predicate decides what the menu offers, what VoiceOver lists and what the coordinator accepts.
struct DownloadQueueOperationApplicabilityTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let status: DownloadDisplayStatus
        let place: DownloadQueuePlace?
        let applicable: Set<DownloadQueueOperation>

        var testDescription: String { name }
    }

    @Test(arguments: [
        Row(
            name: "first of three",
            status: .queued,
            place: DownloadQueuePlace(position: 1, waitingCount: 3),
            applicable: [.downloadNow, .moveDown, .downloadLast]
        ),
        Row(
            name: "middle of three",
            status: .queued,
            place: DownloadQueuePlace(position: 2, waitingCount: 3),
            applicable: [.downloadNow, .downloadNext, .moveUp, .moveDown, .downloadLast]
        ),
        Row(
            name: "last of three",
            status: .queued,
            place: DownloadQueuePlace(position: 3, waitingCount: 3),
            applicable: [.downloadNow, .downloadNext, .moveUp]
        ),
        Row(
            name: "only waiting item",
            status: .queued,
            place: DownloadQueuePlace(position: 1, waitingCount: 1),
            applicable: [.downloadNow]
        ),
        Row(name: "waiting without a place", status: .queued, place: nil, applicable: [.downloadNow]),
        Row(name: "paused", status: .inactive, place: nil, applicable: [.downloadNow, .downloadNext]),
        Row(name: "active", status: .active, place: nil, applicable: []),
        Row(name: "update available", status: .updateAvailable, place: nil, applicable: []),
        Row(name: "error", status: .error, place: nil, applicable: []),
        Row(name: "completed", status: .completed, place: nil, applicable: [])
    ])
    func eachStatusAndPlaceOffersItsOperations(_ row: Row) {
        let applicable = DownloadQueueOperation.allCases.filter({ operation in
            operation.isApplicable(status: row.status, place: row.place)
        })

        #expect(Set(applicable) == row.applicable)
    }
}
