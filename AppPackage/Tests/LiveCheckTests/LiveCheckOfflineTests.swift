import Foundation
import XCTest

/// The check's vocabulary, results schema and GET-only allowlist, offline (19-14). No test reaches a host, and none
/// needs the opt-in.
final class LiveCheckOfflineTests: XCTestCase {
    // MARK: Vocabulary and schema

    func testEveryGuestPageHasOneReaderAndSignedInPagesAreSkipped() {
        let guests = LiveCheckPage.allCases.filter({ !$0.needsSignIn })
        XCTAssertEqual(LiveCheckPage.allCases.filter(\.needsSignIn), [.watched, .favorites, .exhentai])
        XCTAssertEqual(guests.count, 9)
        for page in guests {
            XCTAssertNotNil(page.reader, page.rawValue)
            XCTAssertNotNil(page.primaryExpectation, page.rawValue)
        }
    }

    func testAllowlistNamesOnlyGetRequestTypes() {
        let allowed: Set = [
            "GalleryDetailRequest", "ThumbnailURLsRequest", "GalleryNormalImageURLsRequest", "DataRequest",
            "TagTranslatorRequest", "ReportFormRequest"
        ]
        let named = Set(LiveCheckReader.allCases.flatMap(\.requestTypes))
        XCTAssertEqual(named, allowed)
    }

    func testExpectationsHaveFixedIDsAndSentences() {
        let cases = LiveCheckExpectation.allCases
        XCTAssertEqual(Set(cases.map(\.rawValue)).count, cases.count)
        XCTAssertEqual(Set(cases.map(\.sentence)).count, cases.count)
        XCTAssertEqual(LiveCheckExpectation.toplistsRows.rawValue, "toplists.rows")
        XCTAssertEqual(
            LiveCheckExpectation.toplistsRows.sentence, "expected a gallery table with at least one row, found none"
        )
        let pages = Set(LiveCheckPage.allCases.map(\.rawValue) + ["dependency"])
        for expectation in cases {
            let parts = expectation.rawValue.split(separator: ".")
            XCTAssertEqual(parts.count, 2, expectation.rawValue)
            XCTAssertTrue(pages.contains(String(parts.first ?? "")), expectation.rawValue)
            XCTAssertTrue(expectation.sentence.hasPrefix("expected "), expectation.rawValue)
        }
    }

    func testResultsCarryOnlyTheFourPageFields() throws {
        let results = LiveCheckResults(date: Date(timeIntervalSince1970: 1_735_689_600), mode: .local, pages: [
            LiveCheckPageResult(page: .toplists, status: 200, classification: .parser, expectation: .toplistsRows),
            LiveCheckPageResult(page: .gallery, status: nil, classification: .unreachable),
            LiveCheckPageResult(page: .watched, status: nil, classification: .skipped)
        ])
        let data = try results.encoded()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schema", "date", "mode", "pages"])
        XCTAssertEqual(object["schema"] as? Int, 1)
        let pages = try XCTUnwrap(object["pages"] as? [[String: Any]])
        let fields: Set = ["page", "status", "classification", "expectation"]
        XCTAssertEqual(pages.map({ Set($0.keys) }), [fields, fields, fields])
        XCTAssertTrue(pages.last?["expectation"] is NSNull)
        XCTAssertEqual(try LiveCheckResults.decoded(from: data), results)
    }
}
