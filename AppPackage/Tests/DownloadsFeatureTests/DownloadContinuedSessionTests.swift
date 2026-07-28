import BackgroundProcessingClient
import Testing

@Suite
struct DownloadContinuedSessionTests: DownloadFeatureTestCase {
    /// Every endpoint of the unimplemented test value must report an issue when called. That is
    /// the whole point of the seam's `testValue`: a call the test did not arrange for fails the
    /// test loudly instead of silently succeeding against a do-nothing stub.
    @Test
    func testUnimplementedClientReportsAnIssueForEveryEndpoint() async {
        let client = BackgroundProcessingClient()

        await withKnownIssue("start is unimplemented") {
            _ = await client.start("Downloading galleries", "0 / 10 pages · 1 gallery")
        }
        await withKnownIssue("updateProgress is unimplemented") {
            await client.updateProgress(3, 10, "3 / 10 pages · 1 gallery")
        }
        await withKnownIssue("finish is unimplemented") {
            await client.finish(true)
        }
    }

    /// The no-op value is inert in both directions: it starts nothing, and the stream it hands
    /// back is already finished, so a consumer written against the live contract drops straight
    /// out of its loop rather than hanging on a session that will never report.
    @Test
    func testNoopClientStartsAnAlreadyFinishedStream() async {
        let client = BackgroundProcessingClient.noop

        var events = [BackgroundProcessingEvent]()
        for await event in await client.start("Downloading galleries", "0 / 10 pages · 1 gallery") {
            events.append(event)
        }
        #expect(events.isEmpty)

        await client.updateProgress(3, 10, "3 / 10 pages · 1 gallery")
        await client.finish(true)
    }

    /// The spy has to hold up the same contract the live client does, because every later
    /// behavior assertion reads its recordings and drives its events. Note the drain loop below
    /// exits without anything cancelling it: `expire()` finishes the stream itself, exactly as
    /// the live session does after the system reclaims or the user cancels the card.
    @Test
    func testSpyRecordsPushedValuesAndFinishesItsStreamOnExpiration() async {
        let spy = BackgroundProcessingClientSpy()
        let client = spy.client

        let stream = await client.start("Downloading galleries", "0 / 10 pages · 1 gallery")
        #expect(spy.startCount == 1)
        #expect(spy.startTitles == ["Downloading galleries"])
        #expect(spy.startSubtitles == ["0 / 10 pages · 1 gallery"])

        spy.emit(.granted)
        await client.updateProgress(3, 10, "3 / 10 pages · 1 gallery")
        #expect(spy.progressUpdates == [
            .init(
                completedUnitCount: 3,
                totalUnitCount: 10,
                subtitle: "3 / 10 pages · 1 gallery"
            )
        ])

        spy.expire()

        var events = [BackgroundProcessingEvent]()
        for await event in stream {
            events.append(event)
        }
        #expect(events == [.granted, .expired])

        await client.finish(true)
        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
    }
}
