@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CustomDump
import Foundation
import HomeFeature
import LibraryClient
import ReadingFeature
import Testing

// The reading-live-text screen replays what a recording of the flow's Live Text page saved, and a
// recording launch lets the reader recognize that page. These cases build both scenes from fixtures
// and refuse every record that belongs to another page, another image or other recognition
// languages, or that holds lines the reader cannot draw.
struct CaptureLiveTextRecordTests {
    @Test
    func theReadingLiveTextSceneReplaysTheRecordOfTheFlowPage() throws {
        let record = LiveTextRecordFile()
        let scene = try makeScene(
            try MarketingFixtureBuilder.standard().addingFlowPage().addingLiveTextRecord(record),
            scenarioID: CaptureScreen.readingLiveText.rawValue
        )

        let capture = try #require(scene.liveText)
        expectNoDifference(capture.gid, MarketingFixtureBuilder.flowGID)
        expectNoDifference(capture.page, MarketingFixtureBuilder.flowPage)
        expectNoDifference(capture.source, .replay(try record.liveTextGroups()))
    }

    @Test
    func aRecordingOpensTheReaderOnTheFlowPageToRecognizeIt() async throws {
        let scene = try makeScene(
            try MarketingFixtureBuilder.standard().addingFlowPage(),
            scenarioID: CaptureScenario.liveTextRecordingID
        )
        let popular = try await scene.homeClient.fetchPopularGalleries(.ehentai, Filter())
        let gallery = try #require(popular.first(where: { $0.gid == MarketingFixtureBuilder.flowGID }))

        expectNoDifference(scene.route, .readingLiveText(gallery, page: MarketingFixtureBuilder.flowPage))
        let capture = try #require(scene.liveText)
        expectNoDifference(capture.gid, MarketingFixtureBuilder.flowGID)
        expectNoDifference(capture.page, MarketingFixtureBuilder.flowPage)
        expectNoDifference(capture.source, .record)
    }

    @Test(arguments: CaptureScreen.allCases.filter({ $0 != .readingLiveText }))
    func noOtherScreenHasLiveText(_ screen: CaptureScreen) throws {
        let fixture = try MarketingFixtureBuilder.standard().addingFlowPage().addingLiveTextRecord(LiveTextRecordFile())

        #expect(try makeScene(fixture, scenarioID: screen.rawValue).liveText == nil)
    }

    @Test
    func theIsolatedReaderShowsTheScenesLiveText() throws {
        let scene = try makeScene(
            try MarketingFixtureBuilder.standard().addingFlowPage().addingLiveTextRecord(LiveTextRecordFile()),
            scenarioID: CaptureScreen.readingLiveText.rawValue
        )
        let storage = try CaptureStorage.reset(at: makeTemporaryDirectory().appending(path: "EhPandaCapture"))

        try withDependencies {
            CaptureScenePreparation.isolate(
                &$0,
                scene: scene,
                storage: storage,
                libraryClient: .noop,
                downloads: .empty
            )
        } operation: {
            @Dependency(\.liveTextCapture) var liveTextCapture
            let installed = try #require(liveTextCapture)
            #expect(installed === scene.liveText)
        }
    }

    @Test
    func aRecordThatIsNotTheFlowPagesIsRefused() throws {
        let name = "the Live Text record of page 1 of gallery \(MarketingFixtureBuilder.flowGID)"
        let line = LiveTextRecordFile.line()
        var otherPage = LiveTextRecordFile()
        otherPage.page = 2
        var otherSchema = LiveTextRecordFile()
        otherSchema.schemaVersion = 2
        var otherBytes = LiveTextRecordFile()
        otherBytes.pageSHA256 = CaptureFixture.sha256(Data("other".utf8))
        var otherLanguages = LiveTextRecordFile()
        otherLanguages.recognitionLanguages = ["en-US"]
        var unnamedSimulator = LiveTextRecordFile()
        unnamedSimulator.model = ""
        var repeatedID = LiveTextRecordFile()
        repeatedID.groups = [.init(id: line.id, blocks: [line])]
        var noGroups = LiveTextRecordFile()
        noGroups.groups = []
        var noLines = LiveTextRecordFile()
        noLines.groups = [.init(id: UUID(0), blocks: [])]

        #expect(
            throws: CaptureFailure.malformedScene("the fixture holds no Live Text record of page 1 of gallery 101")
        ) {
            try Self.scene(record: nil)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) names another page or schema")) {
            try Self.scene(record: otherPage)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) names another page or schema")) {
            try Self.scene(record: otherSchema)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) was recognized on other bytes than the page image")) {
            try Self.scene(record: otherBytes)
        }
        #expect(
            throws: CaptureFailure.malformedScene("\(name) was recognized in other languages than the reader requests")
        ) {
            try Self.scene(record: otherLanguages)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) names no recording simulator")) {
            try Self.scene(record: unnamedSimulator)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) repeats an ID")) {
            try Self.scene(record: repeatedID)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) holds no groups")) {
            try Self.scene(record: noGroups)
        }
        #expect(throws: CaptureFailure.malformedScene("\(name) holds a group without lines")) {
            try Self.scene(record: noLines)
        }
    }

    @Test(arguments: [
        LiveTextRecordFile.line(text: ""),
        // Entirely right of the page.
        LiveTextRecordFile.line(left: 1, right: 1.2),
        // Entirely above the page.
        LiveTextRecordFile.line(top: -0.2, bottom: 0),
        // No height.
        LiveTextRecordFile.line(top: 0.2, bottom: 0.2),
        // No width.
        LiveTextRecordFile.line(left: 0.4, right: 0.4)
    ])
    func aLineTheReaderCannotDrawIsRefused(_ line: CaptureLiveTextBlock) {
        var record = LiveTextRecordFile()
        record.groups = [.init(id: UUID(0), blocks: [line])]

        #expect(
            throws: CaptureFailure.malformedScene(
                "the Live Text record of page 1 of gallery 101 holds a line without text or outside the page"
            )
        ) {
            try Self.scene(record: record)
        }
    }

    @Test
    func aLineReachingJustOutsideThePageIsKeptAsRecognized() throws {
        let line = LiveTextRecordFile.line(left: -0.01, right: 1.01, top: 0.9, bottom: 1.02)
        var record = LiveTextRecordFile()
        record.groups = [.init(id: UUID(0), blocks: [line])]

        let capture = try #require(try Self.scene(record: record).liveText)

        expectNoDifference(capture.source, .replay(try record.liveTextGroups()))
    }

    @Test
    func aRecordWithAKeyTheToolsDoNotWriteIsRefused() throws {
        let record = try JSONSerialization.jsonObject(with: try LiveTextRecordFile().data())
        var object = try #require(record as? [String: Any])
        object["confidence"] = 1
        var fixture = try MarketingFixtureBuilder.standard().addingFlowPage()
        fixture.files.append(.liveTextRecord(try JSONSerialization.data(withJSONObject: object)))

        let error = #expect(throws: CaptureFailure.self) {
            try makeScene(fixture, scenarioID: CaptureScreen.readingLiveText.rawValue)
        }

        guard case .malformedScene(let message) = error else {
            Issue.record("Expected a malformed scene, got \(String(describing: error))")
            return
        }
        #expect(message.hasPrefix("the Live Text record of page 1 of gallery 101 does not decode"))
        #expect(message.contains("confidence"))
    }

    @Test
    func diagnosticsCarryTheGroupsARecordKeeps() throws {
        let record = LiveTextRecordFile()
        let capture = LiveTextCapture(gid: record.gid, page: record.page, source: .record)
        let recognized = LiveTextCapture.Outcome.recognized(try record.liveTextGroups(), recognitionLanguages: nil)

        let diagnostics = try #require(CaptureLiveTextDiagnostics(capture: capture, outcome: recognized))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try #require(
            try JSONSerialization.jsonObject(with: try encoder.encode(diagnostics)) as? [String: Any]
        )
        let groups = try JSONSerialization.data(withJSONObject: try #require(json["groups"]))

        expectNoDifference(diagnostics.source, .recognition)
        #expect(json["recognitionLanguages"] is NSNull)
        expectNoDifference(try JSONDecoder().decode([CaptureLiveTextGroup].self, from: groups), record.groups)
        #expect(CaptureLiveTextDiagnostics(capture: capture, outcome: nil) == nil)
        #expect(CaptureLiveTextDiagnostics(capture: capture, outcome: .otherGallery("999")) == nil)
    }

    /// The reading-live-text scene of the standard fixture with the flow page and `record`.
    @discardableResult
    private static func scene(record: LiveTextRecordFile?) throws -> CaptureScene {
        var fixture = try MarketingFixtureBuilder.standard().addingFlowPage()
        if let record {
            fixture = try fixture.addingLiveTextRecord(record)
        }
        return try makeScene(fixture, scenarioID: CaptureScreen.readingLiveText.rawValue)
    }
}

/// A Live Text record file of the standard fixture's flow page as `record-live-text.py` writes it:
/// one group of one line, recognized on the flow page's image in the languages the reader requests for
/// the saved detail page's language, Japanese.
struct LiveTextRecordFile: Encodable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case gid
        case page
        case pageSHA256
        case recognitionLanguages
        case recordedOn
        case groups
    }

    var schemaVersion = 1
    var gid = MarketingFixtureBuilder.flowGID
    var page = MarketingFixtureBuilder.flowPage
    var pageSHA256 = CaptureFixture.sha256(MarketingFixtureBuilder.flowPageData)
    var recognitionLanguages = Language.japanese.codes
    var model = "iPhone Air"
    var runtimeBuild = "24A5000"
    var groups = [CaptureLiveTextGroup(id: UUID(0), blocks: [Self.line()])]

    /// A line with these edges, as an upright rectangle.
    static func line(
        text: String = "You sent me away,",
        left: Double = 0.1,
        right: Double = 0.4,
        top: Double = 0.2,
        bottom: Double = 0.25
    ) -> CaptureLiveTextBlock {
        CaptureLiveTextBlock(
            id: UUID(1),
            text: text,
            topLeft: .init(horizontal: left, vertical: top),
            topRight: .init(horizontal: right, vertical: top),
            bottomLeft: .init(horizontal: left, vertical: bottom),
            bottomRight: .init(horizontal: right, vertical: bottom)
        )
    }

    /// The groups the reader shows for this record.
    func liveTextGroups() throws -> [LiveTextGroup] {
        try groups.map { group in
            var liveTextGroup = try #require(LiveTextGroup(blocks: group.blocks.map(\.liveTextBlock)))
            liveTextGroup.id = group.id
            return liveTextGroup
        }
    }

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(gid, forKey: .gid)
        try container.encode(page, forKey: .page)
        try container.encode(pageSHA256, forKey: .pageSHA256)
        try container.encode(recognitionLanguages, forKey: .recognitionLanguages)
        try container.encode(["model": model, "runtimeBuild": runtimeBuild], forKey: .recordedOn)
        try container.encode(groups, forKey: .groups)
    }
}

extension MarketingFixtureBuilder {
    /// This fixture with `record` as the Live Text record of the flow page.
    func addingLiveTextRecord(_ record: LiveTextRecordFile) throws -> Self {
        var fixture = self
        fixture.files.append(.liveTextRecord(try record.data()))
        return fixture
    }
}
