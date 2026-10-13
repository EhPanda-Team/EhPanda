import AppModels
import CoreGraphics
import Dependencies
import Foundation
@testable import LiveTextTranslation
@testable import ReadingFeature
import Testing

// The reader translates the pages Live Text recognized, except in a capture launch, whose screens must
// not depend on the system's translation models; turning Live Text off lets a page that failed be
// tried again.
@MainActor
struct LiveTextHandlerTranslationTests {
    private static let gid = "1979820"

    private struct TranslationFailed: Error {}

    private static func groups() throws -> [LiveTextGroup] {
        let bounds = LiveTextBounds(
            topLeft: .init(x: 0.1, y: 0.2),
            topRight: .init(x: 0.6, y: 0.2),
            bottomLeft: .init(x: 0.1, y: 0.25),
            bottomRight: .init(x: 0.6, y: 0.25)
        )
        return [try #require(LiveTextGroup(blocks: [LiveTextBlock(text: "You sent me away,", bounds: bounds)]))]
    }

    private static func image() throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: 1000,
            height: 1400,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1400))
        return try #require(context.makeImage())
    }

    /// A handler for a Japanese reader, counting the translation client's calls in `calls`.
    private static func handler(
        capture: LiveTextCapture? = nil,
        calls: LockIsolated<Int>,
        translate: @escaping @Sendable (String) throws -> String = { "訳: \($0)" }
    ) -> LiveTextHandler {
        withDependencies {
            $0.liveTextCapture = capture
            $0.liveTextTranslationClient = LiveTextTranslationClient(
                preferredLanguages: {
                    calls.withValue({ $0 += 1 })
                    return [.init(identifier: "ja")]
                },
                availability: { _, _ in
                    calls.withValue({ $0 += 1 })
                    return .installed
                },
                translate: { texts, _ in
                    calls.withValue({ $0 += 1 })
                    return try Dictionary(
                        texts.map({ ($0.groupID, try translate($0.text)) }),
                        uniquingKeysWith: { first, _ in first }
                    )
                }
            )
        } operation: {
            LiveTextHandler()
        }
    }

    @Test
    func aRecognizedPageIsTranslated() async throws {
        let calls = LockIsolated(0)
        let handler = Self.handler(calls: calls)
        let groups = try Self.groups()
        handler.liveTextGroups[4] = groups

        #expect(handler.needsAnalysis(page: 4))
        handler.analyzeImage(try Self.image(), size: .zero, page: 4, recognitionLanguages: ["en-US"])
        await handler.translator.waitForTranslations()

        #expect(handler.translator.translatedPage(of: groups)?.groups.map(\.text) == ["訳: You sent me away,"])
        #expect(!handler.needsAnalysis(page: 4))
    }

    @Test
    func aRecordingCaptureNeverTranslates() async throws {
        let calls = LockIsolated(0)
        let capture = LiveTextCapture(gid: Self.gid, page: 4, source: .record)
        let handler = Self.handler(capture: capture, calls: calls)
        let groups = try Self.groups()
        handler.liveTextGroups[4] = groups

        #expect(!handler.needsAnalysis(page: 4))
        handler.analyzeImage(try Self.image(), size: .zero, page: 4, recognitionLanguages: ["en-US"])
        await handler.translator.waitForTranslations()

        #expect(calls.value == 0)
        #expect(handler.translator.translatedPages.isEmpty)
        #expect(handler.liveTextGroups == [4: groups])
    }

    @Test
    func aReplayedCaptureShowsItsGroupsUntranslated() throws {
        let calls = LockIsolated(0)
        let groups = try Self.groups()
        let capture = LiveTextCapture(gid: Self.gid, page: 4, source: .replay(groups))
        let handler = Self.handler(capture: capture, calls: calls)

        #expect(handler.capturesLiveText(gid: Self.gid, page: 4))

        #expect(handler.liveTextGroups == [4: groups])
        #expect(!handler.needsAnalysis(page: 4))
        #expect(calls.value == 0)
    }

    @Test
    func turningLiveTextOffLetsAFailedPageBeTriedAgain() async throws {
        let calls = LockIsolated(0)
        let handler = Self.handler(calls: calls, translate: { _ in throw TranslationFailed() })
        handler.enablesLiveText = true
        handler.liveTextGroups[4] = try Self.groups()

        handler.analyzeImage(try Self.image(), size: .zero, page: 4, recognitionLanguages: ["en-US"])
        await handler.translator.waitForTranslations()

        #expect(handler.translator.takeFailure() == .translationFailed)
        #expect(!handler.needsAnalysis(page: 4))

        handler.enablesLiveText = false

        #expect(handler.needsAnalysis(page: 4))
    }
}
