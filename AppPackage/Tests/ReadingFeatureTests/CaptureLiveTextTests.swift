import AppModels
import Dependencies
import Foundation
@testable import ReadingFeature
import Testing

// A capture of the reading-live-text screen shows the groups a recording saved through the reader's
// own Live Text handler and overlay. These cases drive the handler's capture seam directly: which
// pages it answers itself, which it leaves to recognition, and what it reports for the diagnostics.
@MainActor
@Suite
struct CaptureLiveTextTests {
    private static let gid = "1979820"

    private static func groups() throws -> [LiveTextGroup] {
        let bounds = LiveTextBounds(
            topLeft: .init(x: 0.1, y: 0.2),
            topRight: .init(x: 0.4, y: 0.2),
            bottomLeft: .init(x: 0.1, y: 0.25),
            bottomRight: .init(x: 0.4, y: 0.25)
        )
        var group = try #require(LiveTextGroup(blocks: [LiveTextBlock(text: "You sent me away,", bounds: bounds)]))
        group.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        return [group]
    }

    private func makeHandler(capture: LiveTextCapture?) -> LiveTextHandler {
        withDependencies {
            $0.liveTextCapture = capture
        } operation: {
            LiveTextHandler()
        }
    }

    @Test
    func aReplayShowsItsGroupsOnItsPageAndNothingElsewhere() throws {
        let groups = try Self.groups()
        let capture = LiveTextCapture(gid: Self.gid, page: 4, source: .replay(groups))
        let handler = makeHandler(capture: capture)

        #expect(handler.enablesLiveText)
        #expect(capture.outcome == nil)
        #expect(handler.capturesLiveText(gid: Self.gid, page: 4))
        #expect(handler.capturesLiveText(gid: Self.gid, page: 5))

        #expect(handler.liveTextGroups == [4: groups])
        #expect(capture.outcome == .replayed(groups))
    }

    @Test
    func aReplayKeepsItsGroupsWhateverRecognitionReports() throws {
        let groups = try Self.groups()
        let capture = LiveTextCapture(gid: Self.gid, page: 4, source: .replay(groups))
        let handler = makeHandler(capture: capture)
        #expect(handler.capturesLiveText(gid: Self.gid, page: 4))

        capture.recognized([], page: 4, recognitionLanguages: ["en-US"])

        #expect(capture.outcome == .replayed(groups))
    }

    @Test
    func aRequestFromAnotherGalleryShowsNothingAndFailsTheCapture() throws {
        let capture = LiveTextCapture(gid: Self.gid, page: 4, source: .replay(try Self.groups()))
        let handler = makeHandler(capture: capture)

        #expect(handler.capturesLiveText(gid: "351187", page: 4))

        #expect(handler.liveTextGroups.isEmpty)
        #expect(capture.outcome == .otherGallery("351187"))
    }

    @Test
    func aRecordingLetsTheReaderRecognizeItsPageOnly() throws {
        let groups = try Self.groups()
        let capture = LiveTextCapture(gid: Self.gid, page: 4, source: .record)
        let handler = makeHandler(capture: capture)

        #expect(handler.enablesLiveText)
        #expect(!handler.capturesLiveText(gid: Self.gid, page: 4))
        #expect(handler.capturesLiveText(gid: Self.gid, page: 5))
        #expect(capture.outcome == nil)

        capture.recognized(groups, page: 5, recognitionLanguages: ["en-US"])
        #expect(capture.outcome == nil)
        capture.recognized(groups, page: 4, recognitionLanguages: ["en-US"])
        #expect(capture.outcome == .recognized(groups, recognitionLanguages: ["en-US"]))
        #expect(handler.liveTextGroups.isEmpty)
    }

    @Test
    func theReaderOutsideACaptureIsUnchanged() {
        let handler = makeHandler(capture: nil)

        #expect(!handler.enablesLiveText)
        #expect(!handler.capturesLiveText(gid: Self.gid, page: 4))
        #expect(handler.liveTextGroups.isEmpty)
    }
}
