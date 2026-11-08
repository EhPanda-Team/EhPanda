import Foundation

/// `results.json`, schema 1 (19-CONTEXT D-22; 19-RESEARCH §7): the run's date and mode, and per page only its name,
/// HTTP status, classification and expectation ID. Every field but the date and the status is an enum, so no URL,
/// title, gallery ID, header or body can reach the file.
struct LiveCheckResults: Codable, Equatable, Sendable {
    let schema: Int
    let date: Date
    let mode: LiveCheckMode
    let pages: [LiveCheckPageResult]

    init(date: Date, mode: LiveCheckMode, pages: [LiveCheckPageResult]) {
        schema = 1
        self.date = date
        self.mode = mode
        self.pages = pages
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }
}

/// Where the check ran (`EHPANDA_LIVE_CHECK_MODE`).
enum LiveCheckMode: String, Codable, Sendable {
    case hosted, local
}

/// One page's verdict. `unreachable` (a block) and `parser` (a break) never mix (D-23).
enum LiveCheckClassification: String, Codable, Sendable {
    case okay = "ok"
    case unreachable, parser, skipped
}

struct LiveCheckPageResult: Codable, Equatable, Sendable {
    let page: LiveCheckPage
    let status: Int?
    let classification: LiveCheckClassification
    let expectation: LiveCheckExpectation?

    init(
        page: LiveCheckPage, status: Int?, classification: LiveCheckClassification,
        expectation: LiveCheckExpectation? = nil
    ) {
        self.page = page
        self.status = status
        self.classification = classification
        self.expectation = expectation
    }

    private enum CodingKeys: String, CodingKey {
        case page, status, classification, expectation
    }

    /// Writes all four fields, an absent status or expectation as `null`, so every page has the same keys.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(page, forKey: .page)
        try container.encode(status, forKey: .status)
        try container.encode(classification, forKey: .classification)
        try container.encode(expectation, forKey: .expectation)
    }
}
