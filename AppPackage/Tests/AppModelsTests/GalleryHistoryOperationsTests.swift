import AppModels
import ComposableArchitecture
import Foundation
import Testing
import TestingSupport

// REV-13: the shared history mutators are the single home for the persisted-list invariants, so they
// must reject unresolvable records at the source — a non-numeric gid, or a brand-new entry with no
// token — rather than relying on every call site to pre-validate.
@Suite(.isolatedAppStorage)
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

    // D-07: the webtoon verdict goes through the same upsert as the reading progress.
    @Test
    func recordWebtoonVerdictInsertsAResolvableFrontEntry() {
        var history = [GalleryHistoryEntry(gid: "1", token: "t1", lastOpenDate: date)]
        history.recordWebtoonVerdict(gid: "42", token: "tok", isWebtoon: true, date: date)
        #expect(history.map(\.gid) == ["42", "1"])
        #expect(history.first?.token == "tok")
        #expect(history.first?.isWebtoon == true)
        #expect(history.first?.readingProgress == 0)
    }

    @Test
    func recordWebtoonVerdictRejectsUnresolvableEntries() {
        var history = [GalleryHistoryEntry]()
        history.recordWebtoonVerdict(gid: "junk", token: "tok", isWebtoon: true, date: date)
        history.recordWebtoonVerdict(gid: "42", token: "", isWebtoon: true, date: date)
        #expect(history.isEmpty)
    }

    @Test
    func recordWebtoonVerdictInPlaceKeepsEverythingElse() {
        let later = date.addingTimeInterval(60)
        var history = [
            GalleryHistoryEntry(gid: "1", token: "t1", lastOpenDate: later),
            GalleryHistoryEntry(gid: "42", token: "stored", lastOpenDate: date, readingProgress: 7)
        ]
        history.recordWebtoonVerdict(gid: "42", token: "ignored", isWebtoon: false, date: later)
        #expect(history.map(\.gid) == ["1", "42"])
        #expect(history.last == GalleryHistoryEntry(
            gid: "42", token: "stored", lastOpenDate: date, readingProgress: 7, isWebtoon: false
        ))
    }

    @Test
    func reopeningAGalleryKeepsItsVerdict() {
        var history = [GalleryHistoryEntry(gid: "42", token: "tok", lastOpenDate: date, isWebtoon: true)]
        history.recordGalleryOpen(gid: "42", token: "tok", date: date.addingTimeInterval(60))
        #expect(history.isWebtoon(gid: "42") == true)
    }

    @Test
    func aGalleryNeverCheckedHasNoVerdict() {
        let history = [GalleryHistoryEntry(gid: "42", token: "tok", lastOpenDate: date)]
        #expect(history.isWebtoon(gid: "42") == nil)
        #expect(history.isWebtoon(gid: "7") == nil)
    }

    // W-4 of quick 261126-iq9: a history stored by an earlier build reads back through `SchemaMigrator`, element by
    // element, losing only the negative verdicts the old sampling rule recorded. The next write stores every element
    // at v2, and a negative verdict recorded under the new rule survives a relaunch.
    @Test
    func aStoredOldHistoryDropsItsNegativeVerdictsOnceAndKeepsNewOnes() throws {
        @Dependency(\.defaultAppStorage) var defaults
        let storedV1 = """
        [
            {"schemaVersion": 1, "gid": "1", "token": "a", "lastOpenDate": 0, "readingProgress": 3, "isWebtoon": false},
            {"schemaVersion": 1, "gid": "2", "token": "b", "lastOpenDate": 0, "readingProgress": 0, "isWebtoon": true},
            {"schemaVersion": 1, "gid": "3", "token": "c", "lastOpenDate": 0, "readingProgress": 0}
        ]
        """
        defaults.set(Data(storedV1.utf8), forKey: "galleryHistory")

        @Shared(.galleryHistory) var history
        #expect(history.map(\.gid) == ["1", "2", "3"])
        #expect(history.map(\.isWebtoon) == [nil, true, nil])
        #expect(history.first?.readingProgress == 3)

        $history.withLock({
            $0.recordWebtoonVerdict(gid: "1", token: "a", isWebtoon: false, date: date)
        })

        let stored = try #require(defaults.data(forKey: "galleryHistory"))
        let objects = try #require(JSONSerialization.jsonObject(with: stored) as? [[String: Any]])
        #expect(objects.count == 3)
        #expect(objects.allSatisfy({ $0["schemaVersion"] as? Int == 2 }))
        #expect(objects.map({ $0["gid"] as? String }) == ["1", "2", "3"])
        #expect(objects.map({ $0["isWebtoon"] as? Bool }) == [false, true, nil])
        let reopened = try JSONDecoder().decode([GalleryHistoryEntry].self, from: stored)
        #expect(reopened.map(\.isWebtoon) == [false, true, nil])
    }
}
