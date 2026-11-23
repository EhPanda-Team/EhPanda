import AppModels
import Testing

struct DownloadQueuePlaceTests {
    @Test
    func eachWaitingGIDTakesItsOneBasedPlace() {
        let places = DownloadQueuePlace.places(forWaitingGIDs: ["a", "b", "c"])

        #expect(places == [
            "a": DownloadQueuePlace(position: 1, waitingCount: 3),
            "b": DownloadQueuePlace(position: 2, waitingCount: 3),
            "c": DownloadQueuePlace(position: 3, waitingCount: 3)
        ])
    }

    @Test
    func noWaitingGIDsHaveNoPlaces() {
        #expect(DownloadQueuePlace.places(forWaitingGIDs: []) == [:])
    }
}
