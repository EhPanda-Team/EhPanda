import AppTools
@testable import CrashReporting
import Foundation
import Sentry
import Testing

/// One redaction case. A named struct rather than a positional tuple: the tables below are long, and
/// `.0`/`.1` reads would carry no meaning at the assertion site.
struct RedactionCase: Sendable, CustomTestStringConvertible {
    let input: String
    let expected: String

    var testDescription: String { "\(input) -> \(expected)" }
}

@Suite
struct CrashReportScrubberTests {
    // MARK: Whole-event behavior

    @Test
    func scrubReturnsTheSameEventAndKeepsItsCrashStructure() {
        let event = Event()
        let exception = Exception(value: "boom", type: "EXC_BAD_ACCESS")
        let frame = Frame()
        frame.function = "crashHere"
        exception.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        event.exceptions = [exception]
        let thread = SentryThread(threadId: 1)
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        event.threads = [thread]
        let image = DebugMeta()
        image.debugID = "ABCD"
        event.debugMeta = [image]

        let scrubbed = CrashReportScrubber.scrub(event)

        #expect(scrubbed === event)
        #expect(scrubbed.exceptions?.count == 1)
        #expect(scrubbed.exceptions?.first?.stacktrace?.frames.first?.function == "crashHere")
        #expect(scrubbed.threads?.count == 1)
        #expect(scrubbed.debugMeta?.first?.debugID == "ABCD")
    }

    @Test
    func scrubClearsUserBreadcrumbsRequestTagsAndExtra() {
        let event = Event()
        event.user = Sentry.User(userId: "someone")
        event.breadcrumbs = [Breadcrumb(level: .info, category: "ui.click")]
        let request = SentryRequest()
        request.url = "https://example.com/private"
        event.request = request
        event.tags = ["gallery": "2345678"]
        event.extra = ["token": "abcdef"]

        CrashReportScrubber.scrub(event)

        #expect(event.user == nil)
        #expect(event.breadcrumbs == nil)
        #expect(event.request == nil)
        #expect(event.tags == nil)
        #expect(event.extra == nil)
    }

    // MARK: Contexts

    @Test
    func scrubKeepsExactlyTheReviewedContexts() {
        let event = Event()
        event.context = [
            "app": ["app_name": "EhPanda"],
            "culture": ["locale": "ja_JP"],
            "device": ["model": "iPhone18,1"],
            "os": ["name": "iOS"],
            "trace": ["trace_id": "0123"],
            "custom": ["key": "value"],
            "NSException": ["userInfo": "free text from an uncaught exception"],
            "runtime": ["name": "Swift"]
        ]

        CrashReportScrubber.scrub(event)

        #expect(Set((event.context ?? [:]).keys) == ["app", "culture", "device", "os", "trace"])
        #expect(event.context?["device"]?["model"] as? String == "iPhone18,1")
    }

    @Test
    func scrubRemovesTheDeviceAppHashAndKeepsTheOtherAppKeys() {
        let event = Event()
        event.context = ["app": ["device_app_hash": "0123abcd", "app_name": "EhPanda", "app_version": "3.0.0"]]

        CrashReportScrubber.scrub(event)

        #expect(event.context?["app"]?["device_app_hash"] == nil)
        #expect(event.context?["app"]?["app_name"] as? String == "EhPanda")
        #expect(event.context?["app"]?["app_version"] as? String == "3.0.0")
    }

    @Test
    func scrubLeavesAnEventWithoutContextsWithoutContexts() {
        let event = Event()

        CrashReportScrubber.scrub(event)

        #expect(event.context == nil)
    }

    // MARK: Free text in the event

    @Test
    func scrubRedactsTheMessage() throws {
        let event = Event()
        let message = SentryMessage(formatted: "failed https://e-hentai.org/g/1/abcdef1234/ for alice@example.com")
        message.message = "failed %@ for %@"
        message.params = ["https://exhentai.org/s/0123456789/2345678-1", "alice@example.com"]
        event.message = message

        CrashReportScrubber.scrub(event)

        let scrubbed = try #require(event.message)
        #expect(scrubbed.formatted == "failed [redacted] for [redacted]")
        #expect(scrubbed.message == "failed %@ for %@")
        #expect(scrubbed.params == ["[redacted]", "[redacted]"])
    }

    @Test
    func scrubRedactsEveryExceptionValue() {
        let event = Event()
        event.exceptions = [
            Exception(value: "load https://e-hentai.org/g/1/abcdef1234/", type: "A"),
            Exception(value: "peer 192.168.1.10 refused", type: "B"),
            Exception(value: nil, type: "C")
        ]

        CrashReportScrubber.scrub(event)

        #expect(event.exceptions?.map(\.value) == ["load [redacted]", "peer [redacted] refused", nil])
    }

    @Test
    func scrubRedactsEveryStringAtAnyDepthOfMechanismData() throws {
        let mechanism = Mechanism(type: "signal")
        mechanism.data = [
            "crash_info_messages": ["opened https://e-hentai.org/g/1/abcdef1234/", "from /Users/alice/x"],
            "nested": ["list": [["deep": "mail alice@example.com"]]],
            "signal": ["number": 11, "handled": false, "name": "SIGSEGV"]
        ]
        let exception = Exception(value: "boom", type: "EXC_BAD_ACCESS")
        exception.mechanism = mechanism
        let event = Event()
        event.exceptions = [exception]

        CrashReportScrubber.scrub(event)

        let data = try #require(event.exceptions?.first?.mechanism?.data)
        #expect(data["crash_info_messages"] as? [String] == ["opened [redacted]", "from /Users/_/x"])
        let nested = try #require(data["nested"] as? [String: Any])
        let list = try #require(nested["list"] as? [[String: Any]])
        #expect(list.first?["deep"] as? String == "mail [redacted]")
        let signal = try #require(data["signal"] as? [String: Any])
        #expect(signal["number"] as? Int == 11)
        #expect(signal["handled"] as? Bool == false)
        #expect(signal["name"] as? String == "SIGSEGV")
    }

    // MARK: Free text rules

    @Test(arguments: [
        RedactionCase(input: "see https://e-hentai.org/g/2345678/abcdef1234/ now", expected: "see [redacted] now"),
        RedactionCase(input: "https://exhentai.org/s/0123456789/2345678-1", expected: "[redacted]"),
        RedactionCase(input: "https://api.e-hentai.org/api.php", expected: "[redacted]"),
        RedactionCase(
            input: "https://abcd.efgh.hath.network:443/h/0123/keystamp=1/x.webp",
            expected: "[redacted]"
        ),
        RedactionCase(input: "ehpanda://gallery/2345678", expected: "[redacted]"),
        RedactionCase(input: "file:///Users/alice/Library/x", expected: "[redacted]")
    ])
    func redactsUrls(_ fixture: RedactionCase) {
        #expect(CrashReportScrubber.redact(fixture.input) == fixture.expected)
    }

    @Test(arguments: [
        RedactionCase(input: "load e-hentai.org/g/2345678/abcdef1234/", expected: "load [redacted]"),
        RedactionCase(input: "EXHENTAI.ORG/s/0123456789/2345678-1", expected: "[redacted]"),
        RedactionCase(input: "forums.e-hentai.org", expected: "[redacted]"),
        RedactionCase(input: "api.exhentai.org:443/api.php?x=1", expected: "[redacted]"),
        RedactionCase(input: "the e-hentai parser", expected: "the e-hentai parser")
    ])
    func redactsSchemeLessSiteHosts(_ fixture: RedactionCase) {
        #expect(CrashReportScrubber.redact(fixture.input) == fixture.expected)
    }

    @Test
    func redactsTheCredentialCookies() {
        let member = Defaults.Cookie.ipbMemberId
        let hash = Defaults.Cookie.ipbPassHash
        let igneous = Defaults.Cookie.igneous
        let input = "Cookie: \(member)=1234567; \(hash)=0123456789abcdef0123456789abcdef; "
            + "\(igneous)=abcdef012; \(Defaults.Cookie.ignoreOffensive)=1"

        let output = CrashReportScrubber.redact(input)

        #expect(output == "Cookie: [redacted]; [redacted]; [redacted]; nw=1")
    }

    @Test
    func redactsAJsonShapedCredentialCookie() {
        let output = CrashReportScrubber.redact("{\"\(Defaults.Cookie.ipbPassHash)\": \"0123abcd\"}")

        #expect(!output.contains("0123abcd"))
        #expect(!output.contains(Defaults.Cookie.ipbPassHash))
    }

    @Test(arguments: [
        RedactionCase(input: "alice@example.com", expected: "[redacted]"),
        RedactionCase(input: "user@localhost", expected: "[redacted]"),
        RedactionCase(input: "mail alice.b+tag@mail.example.co.jp now", expected: "mail [redacted] now"),
        RedactionCase(input: "@objc", expected: "@objc"),
        RedactionCase(
            input: "-[NSObject doesNotRecognizeSelector:]",
            expected: "-[NSObject doesNotRecognizeSelector:]"
        )
    ])
    func redactsEmailAddresses(_ fixture: RedactionCase) {
        #expect(CrashReportScrubber.redact(fixture.input) == fixture.expected)
    }

    @Test(arguments: [
        RedactionCase(input: "192.168.1.10", expected: "[redacted]"),
        RedactionCase(input: "at 10.0.0.1.", expected: "at [redacted]."),
        RedactionCase(input: "1.1.1.1,2.2.2.2", expected: "[redacted],[redacted]"),
        RedactionCase(input: "1.2.3.4.5", expected: "1.2.3.4.5"),
        RedactionCase(input: "27.2.1", expected: "27.2.1"),
        RedactionCase(input: "v1.2.3.4", expected: "v1.2.3.4")
    ])
    func redactsIPv4Addresses(_ fixture: RedactionCase) {
        #expect(CrashReportScrubber.redact(fixture.input) == fixture.expected)
    }

    @Test(arguments: [
        RedactionCase(input: "2001:db8:85a3:0:0:8a2e:370:7334", expected: "[redacted]"),
        RedactionCase(input: "2001:db8::1", expected: "[redacted]"),
        RedactionCase(input: "::1", expected: "[redacted]"),
        RedactionCase(input: "fe80::1%en0", expected: "[redacted]"),
        RedactionCase(input: "::ffff:192.0.2.1", expected: "[redacted]"),
        RedactionCase(input: "bind to [2001:db8::1] failed", expected: "bind to [[redacted]] failed"),
        RedactionCase(input: "12:34:56", expected: "12:34:56"),
        RedactionCase(
            input: "Swift/Array.swift:418: Fatal error: Index out of range",
            expected: "Swift/Array.swift:418: Fatal error: Index out of range"
        )
    ])
    func redactsIPv6Addresses(_ fixture: RedactionCase) {
        #expect(CrashReportScrubber.redact(fixture.input) == fixture.expected)
    }

    @Test(arguments: [
        RedactionCase(input: "/Users/alice/Library/Developer/X", expected: "/Users/_/Library/Developer/X"),
        RedactionCase(
            input: "/private/var/containers/Bundle/Application/X/EhPanda.app/EhPanda",
            expected: "/private/var/containers/Bundle/Application/X/EhPanda.app/EhPanda"
        )
    ])
    func redactsTheHomeFolderName(_ fixture: RedactionCase) {
        #expect(CrashReportScrubber.redact(fixture.input) == fixture.expected)
    }

    @Test
    func addressRulesRunBeforeTheHomeFolderRule() {
        let output = CrashReportScrubber.redact("/Users/alicehttps://example.com/private")

        #expect(output == "/Users/_")
        #expect(!output.contains("alice"))
        #expect(!output.contains("example.com"))
    }

    @Test
    func redactCutsFreeTextAtThreeHundredCharacters() {
        #expect(CrashReportScrubber.redact(String(repeating: "x", count: 400)) == String(repeating: "x", count: 300))
        #expect(CrashReportScrubber.redact(String(repeating: "x", count: 300)).count == 300)
        #expect(CrashReportScrubber.redact(String(repeating: "x", count: 299)).count == 299)
    }

    @Test
    func redactionRunsBeforeTheCut() {
        let padding = String(repeating: "a", count: 290)

        let output = CrashReportScrubber.redact(padding + " https://e-hentai.org/g/1/abcdef1234/")

        #expect(output == String((padding + " [redacted]").prefix(300)))
        #expect(!output.contains("e-hen"))
    }

    // MARK: Paths

    @Test
    func scrubRedactsTheHomeFolderInEveryStackFramePackage() throws {
        func frame(package: String) -> Frame {
            let frame = Frame()
            frame.package = package
            return frame
        }
        let event = Event()
        let exception = Exception(value: "boom", type: "A")
        exception.stacktrace = SentryStacktrace(
            frames: [frame(package: "/Users/alice/exception.dylib")],
            registers: [:]
        )
        event.exceptions = [exception]
        let thread = SentryThread(threadId: 2)
        thread.stacktrace = SentryStacktrace(frames: [frame(package: "/Users/alice/thread.dylib")], registers: [:])
        event.threads = [thread]
        event.stacktrace = SentryStacktrace(frames: [frame(package: "/Users/alice/event.dylib")], registers: [:])

        CrashReportScrubber.scrub(event)

        #expect(event.exceptions?.first?.stacktrace?.frames.first?.package == "/Users/_/exception.dylib")
        #expect(event.threads?.first?.stacktrace?.frames.first?.package == "/Users/_/thread.dylib")
        #expect(event.stacktrace?.frames.first?.package == "/Users/_/event.dylib")
    }

    @Test
    func scrubRedactsOnlyTheHomeFolderInDebugImagePaths() {
        let longPath = "/Users/alice/" + String(repeating: "d", count: 350) + "/lib.dylib"
        let first = DebugMeta()
        first.codeFile = "/Users/alice/Library/Developer/CoreSimulator/lib.dylib"
        let second = DebugMeta()
        second.codeFile = longPath
        let event = Event()
        event.debugMeta = [first, second]

        CrashReportScrubber.scrub(event)

        #expect(first.codeFile == "/Users/_/Library/Developer/CoreSimulator/lib.dylib")
        #expect(second.codeFile == "/Users/_/" + String(repeating: "d", count: 350) + "/lib.dylib")
        #expect(second.codeFile?.count == longPath.count - "alice".count + "_".count)
    }
}
