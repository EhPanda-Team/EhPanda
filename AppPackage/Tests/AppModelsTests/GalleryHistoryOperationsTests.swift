import Foundation
import Testing
import AppModels

// REV-13: the shared history mutators are the single home for the persisted-list invariants, so they
// must reject unresolvable records at the source — a non-numeric gid, or a brand-new entry with no
// token — rather than relying on every call site to pre-validate.
@Suite
struct GalleryHistoryOperationsTests {
    private let date = Date(timeIntervalSince1970: 1_000)

    @Test
    func recordGalleryOpenRejectsNonNumericGID() {
        var history = [GalleryHistoryEntry]()
        history.recordGalleryOpen(gid: "not-a-number", token: "tok", date: date)
        #expect(history.isEmpty)
    }

    @Test
    func recordGalleryOpenRejectsNewTokenlessEntry() {
        var history = [GalleryHistoryEntry]()
        history.recordGalleryOpen(gid: "42", token: "", date: date)
        #expect(history.isEmpty)
    }

    @Test
    func recordGalleryOpenInsertsResolvableEntry() {
        var history = [GalleryHistoryEntry]()
        history.recordGalleryOpen(gid: "42", token: "tok", date: date)
        #expect(history.count == 1)
        #expect(history.first?.gid == "42")
        #expect(history.first?.token == "tok")
    }

    @Test
    func recordGalleryOpenBackfillsMissingTokenAndMovesToFront() {
        var history = [
            GalleryHistoryEntry(gid: "1", token: "t1", lastOpenDate: date),
            GalleryHistoryEntry(gid: "42", token: "", lastOpenDate: date, readingProgress: 5)
        ]
        let later = date.addingTimeInterval(60)
        history.recordGalleryOpen(gid: "42", token: "tok", date: later)
        #expect(history.count == 2)
        #expect(history.first?.gid == "42")
        #expect(history.first?.token == "tok")           // backfilled
        #expect(history.first?.readingProgress == 5)     // preserved
        #expect(history.first?.lastOpenDate == later)
    }

    @Test
    func updateReadingProgressRejectsNonNumericGID() {
        var history = [GalleryHistoryEntry]()
        history.updateReadingProgress(gid: "junk", token: "tok", progress: 3, date: date)
        #expect(history.isEmpty)
    }

    @Test
    func updateReadingProgressRejectsNewTokenlessEntry() {
        var history = [GalleryHistoryEntry]()
        history.updateReadingProgress(gid: "42", token: "", progress: 3, date: date)
        #expect(history.isEmpty)
    }

    @Test
    func updateReadingProgressInsertsResolvableEntryWithToken() {
        var history = [GalleryHistoryEntry]()
        history.updateReadingProgress(gid: "42", token: "tok", progress: 3, date: date)
        #expect(history.count == 1)
        #expect(history.first?.token == "tok")
        #expect(history.first?.readingProgress == 3)
    }

    @Test
    func updateReadingProgressInPlaceKeepsStoredToken() {
        var history = [GalleryHistoryEntry(gid: "42", token: "stored", lastOpenDate: date)]
        history.updateReadingProgress(gid: "42", token: "ignored", progress: 7, date: date)
        #expect(history.count == 1)
        #expect(history.first?.token == "stored")        // in-place update keeps stored token
        #expect(history.first?.readingProgress == 7)
    }
}
