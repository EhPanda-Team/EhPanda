import AppFeature
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The capture core on small synthetic views in the app-hosted test's real key window (19-01 Task 1).
final class HostedWindowCaptureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testStaticViewSettlesAfterTheStableSpan() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(Self.sample(offset: 0), in: window, style: .light)
        defer { hosted.dispose() }
        let result = await HostedWindowCapture.settle(window)
        guard case .settled(let samples, let seconds) = result else {
            return XCTFail("A still view did not settle")
        }
        // Settling is timed, not counted: the identical reads must span the stable span. How many reads that takes
        // depends on the host, since each gap is the sample interval plus a capture: a loaded runner settled on read 4
        // (run 42490998810), a local one on read 5, a starved one on read 3. The floor is two: one read opens the run,
        // and one that matches it at least the stable span later closes it.
        XCTAssertGreaterThanOrEqual(samples, 2)
        XCTAssertGreaterThanOrEqual(seconds, HostedWindowCapture.stableSpan / .seconds(1))
    }

    /// A scenario that asks for more reads settles on no fewer, even on a host that would settle a still view on
    /// two (run 42533872440's first-launch candidates).
    @MainActor
    func testAStillViewSettlesOnNoFewerThanTheMinimumReads() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(Self.sample(offset: 0), in: window, style: .light)
        defer { hosted.dispose() }
        for reads in [2, 6, 9] {
            guard case .settled(let samples, _) = await HostedWindowCapture.settle(window, minimumReads: reads) else {
                return XCTFail("A still view did not settle on \(reads) reads")
            }
            XCTAssertGreaterThanOrEqual(samples, reads)
        }
    }

    @MainActor
    func testChangingViewTimesOutAfterTheSampleCap() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(ChangingView(), in: window, style: .light)
        defer { hosted.dispose() }
        let result = await HostedWindowCapture.settle(window)
        XCTAssertEqual(result.samples, HostedWindowCapture.maximumSamples)
        guard case .timeout = result else {
            return XCTFail("A view that keeps changing settled")
        }
    }

    @MainActor
    func testCaptureIsTheWindowPointSizeAtScaleOne() throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(Self.sample(offset: 0), in: window, style: .dark)
        defer { hosted.dispose() }
        let image = HostedWindowCapture.capture(window)
        XCTAssertEqual(image.scale, 1)
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(CGFloat(cgImage.width), window.bounds.width)
        XCTAssertEqual(CGFloat(cgImage.height), window.bounds.height)
    }

    @MainActor
    func testCompareReportsPassedChangedAndMissing() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let directory = try Self.temporaryDirectory()
        let reference = directory.appending(path: "reference.png")
        try await Self.picture(of: Self.sample(offset: 0), in: window).write(to: reference)
        let same = try await Self.image(of: Self.sample(offset: 0), in: window)
        XCTAssertEqual(HostedWindowCapture.compare(same, reference: reference), .passed)
        let shifted = try await Self.image(of: Self.sample(offset: 1), in: window)
        guard case .changed(let difference) = HostedWindowCapture.compare(shifted, reference: reference) else {
            return XCTFail("A 1-point shift passed")
        }
        XCTAssertNotNil(difference)
        XCTAssertEqual(
            HostedWindowCapture.compare(same, reference: directory.appending(path: "absent.png")), .missingBaseline
        )
    }

    /// The never-record proof (T-19-01): a compare pass leaves the reference directory byte-identical.
    @MainActor
    func testComparePassLeavesTheReferenceDirectoryUnchanged() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let directory = try Self.temporaryDirectory()
        let reference = directory.appending(path: "iphone/en/large/sample/portrait-light.png")
        try FileManager.default.createDirectory(
            at: reference.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try await Self.picture(of: Self.sample(offset: 0), in: window).write(to: reference)
        let before = try Self.fingerprint(directory)
        for offset in [0, 1] {
            let outcome = await HostedWindowCapture.captureAndCompare(
                make: { AnyView(Self.sample(offset: CGFloat(offset))) }, window: window, style: .light,
                reference: reference, mode: .compare
            )
            XCTAssertEqual(outcome.status, offset == 0 ? .passed : .changed)
        }
        let missing = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .light,
            reference: directory.appending(path: "iphone/en/large/other/portrait-light.png"), mode: .compare
        )
        XCTAssertEqual(missing.status, .missingBaseline)
        XCTAssertEqual(try Self.fingerprint(directory), before)
    }

    @MainActor
    func testRetryTurnsAVanishingDifferenceIntoAFlakyPass() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let directory = try Self.temporaryDirectory()
        let reference = directory.appending(path: "reference.png")
        try await Self.picture(of: Self.sample(offset: 0), in: window).write(to: reference)
        var calls = 0
        let outcome = await HostedWindowCapture.captureAndCompare(
            make: {
                calls += 1
                return AnyView(Self.sample(offset: calls == 1 ? 1 : 0))
            },
            window: window, style: .light, reference: reference, mode: .compare
        )
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(outcome.status, .passed)
        XCTAssertEqual(outcome.attempts, 2)
        XCTAssertTrue(outcome.flaky)
        let steady = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 1)) }, window: window, style: .light, reference: reference,
            mode: .compare
        )
        XCTAssertEqual(steady.status, .changed)
        XCTAssertEqual(steady.attempts, 2)
        XCTAssertFalse(steady.flaky)
    }

    /// Run 42577585956: a failed user step was final on its first attempt and its reason said only `interaction`.
    @MainActor
    func testAFailedUserStepIsRetriedOnceAndNamesItsFailure() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        var steps = 0
        let recovered = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .light, reference: nil,
            mode: .candidate,
            interact: { _ in
                steps += 1
                if steps == 1 { throw AccessibilityActionDriver.Failure.notFound("menu") }
            }
        )
        XCTAssertEqual(steps, 2)
        XCTAssertEqual(recovered.status, .recorded)
        XCTAssertEqual(recovered.attempts, 2)
        XCTAssertTrue(recovered.flaky)
        let failing = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .light, reference: nil,
            mode: .candidate, interact: { _ in throw StepError() }
        )
        XCTAssertEqual(failing.status, .error)
        XCTAssertEqual(failing.attempts, 2)
        XCTAssertEqual(failing.reason, "interaction:step-error")
    }

    /// Run 42577585956: a timeout with nothing moving said only `settle-timeout`.
    @MainActor
    func testATimeoutWithNothingMovingNamesWhereThePixelsChanged() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(ChangingView(), in: window, style: .light)
        defer { hosted.dispose() }
        guard case .timeout = await HostedWindowCapture.settle(window) else {
            return XCTFail("A view that keeps changing settled")
        }
        XCTAssertNil(HostedWindowCapture.lastMotion)
        let change = try XCTUnwrap(HostedWindowCapture.lastChange)
        XCTAssertTrue(change.hasPrefix("pixels:"), change)
        XCTAssertEqual(HostedWindowCapture.changedRegion([0, 0, 0, 255, 9, 9, 9, 255], [0, 0, 0, 255, 1, 9, 9, 255],
                                                         width: 2), "pixels:1,0,1x1")
        XCTAssertNil(HostedWindowCapture.changedRegion([1, 2, 3, 4], [1, 2, 3, 4], width: 1))
    }

    @MainActor
    func testCandidateModeRecordsWithoutAReference() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let outcome = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .dark, reference: nil,
            mode: .candidate
        )
        XCTAssertEqual(outcome.status, .recorded)
        XCTAssertEqual(outcome.attempts, 1)
        XCTAssertNotNil(outcome.png.flatMap(UIImage.init(data:)))
    }

    /// The same sample strings are asserted by `Scripts/visual/test_snapshot_matrix.py`.
    func testCoordinateKeyAndBaselinePathMatchTheContract() {
        struct Sample {
            let coordinate: SnapshotCoordinate
            let key: String
            let path: String

            init(_ coordinate: SnapshotCoordinate, _ key: String, _ path: String) {
                self.coordinate = coordinate
                self.key = key
                self.path = path
            }
        }
        let samples: [Sample] = [
            .init(.init(scenario: "home-populated", locale: "en", size: "large", orientation: "portrait",
                        family: "iphone", theme: "light"),
                  "home-populated__en__large__portrait__iphone__light",
                  "iphone/en/large/home-populated/portrait-light.png"),
            .init(.init(scenario: "report-form-sending", locale: "zh-Hant", size: "accessibility5",
                        orientation: "landscape", family: "ipad", theme: "dark"),
                  "report-form-sending__zh-Hant__accessibility5__landscape__ipad__dark",
                  "ipad/zh-Hant/accessibility5/report-form-sending/landscape-dark.png"),
            .init(.init(scenario: "agewall-unticked", locale: "de", size: "xSmall", orientation: "portrait",
                        family: "ipad", theme: "light"),
                  "agewall-unticked__de__xSmall__portrait__ipad__light",
                  "ipad/de/xSmall/agewall-unticked/portrait-light.png")
        ]
        for sample in samples {
            XCTAssertEqual(sample.coordinate.key, sample.key)
            XCTAssertEqual(sample.coordinate.baselinePath, sample.path)
        }
        XCTAssertEqual(samples.first?.coordinate.configuration, "en-large")
    }

    func testResultWriterAppendsOneLinePerCoordinate() throws {
        let writer = SnapshotResultWriter(output: try Self.temporaryDirectory())
        let line = SnapshotResultLine(
            key: "a__en__large__portrait__iphone__light", status: .passed, attempts: 1, flaky: false, seconds: 1.2,
            settleSamples: 7, bytes: 10, sha256: "00", reason: nil
        )
        try writer.append(line)
        try writer.append(SnapshotResultLine(
            key: "b__en__large__portrait__iphone__light", status: .notApplicable, attempts: 0, flaky: false,
            seconds: 0, settleSamples: 0, bytes: 0, sha256: nil, reason: "width-compact"
        ))
        let lines = try writer.lines()
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first, line)
        let text = try String(contentsOf: writer.resultsURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\"status\":\"notApplicable\""))
        XCTAssertTrue(text.contains("\"status\":\"passed\""))
    }

    func testRecordedKeysPassOverALineCutShort() throws {
        let writer = SnapshotResultWriter(output: try Self.temporaryDirectory())
        XCTAssertEqual(try writer.recordedKeys(), [])
        try writer.append(SnapshotResultLine(
            key: "a__en__large__portrait__iphone__light", status: .passed, attempts: 1, flaky: false, seconds: 1.2,
            settleSamples: 7, bytes: 10, sha256: "00", reason: nil
        ))
        let handle = try FileHandle(forWritingTo: writer.resultsURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"key\":\"b__en".utf8))
        try handle.close()
        XCTAssertEqual(try writer.recordedKeys(), ["a__en__large__portrait__iphone__light"])
    }

    // MARK: Helpers

    @MainActor
    private static func sample(offset: CGFloat) -> some View {
        VStack(spacing: 12) {
            Text(verbatim: "Hosted capture")
                .font(.title)
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange)
                .frame(width: 160, height: 80)
        }
        .padding(.top, offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    @MainActor
    private static func image(of view: some View, in window: UIWindow) async throws -> UIImage {
        let hosted = HostedWindowCapture.host(view, in: window, style: .light)
        defer { hosted.dispose() }
        guard case .settled = await HostedWindowCapture.settle(window) else { throw CaptureTestError.unsettled }
        return HostedWindowCapture.capture(window)
    }

    @MainActor
    private static func picture(of view: some View, in window: UIWindow) async throws -> Data {
        HostedWindowCapture.pngData(try await image(of: view, in: window))
    }

    private static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(component: "ehp19-capture-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Every file below `directory` with its SHA-256.
    private static func fingerprint(_ directory: URL) throws -> [String: String] {
        let root = directory.standardizedFileURL.path(percentEncoded: false)
        var result: [String: String] = [:]
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        while let url = enumerator?.nextObject() as? URL {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let path = String(url.standardizedFileURL.path(percentEncoded: false).dropFirst(root.count))
            result[path] = SHA256.hash(data: try Data(contentsOf: url)).map({ String(format: "%02x", $0) }).joined()
        }
        return result
    }
}

private enum CaptureTestError: Error {
    case unsettled
}

private struct StepError: CaptureStepFailure {
    var reason: String { "step-error" }
}

/// Paints how many times it has been drawn and asks to be drawn again after every draw, so consecutive reads never
/// match on any host. The redraw request from the draw a read shows is queued on the main queue before the settle
/// loop's sleep starts, so it runs ahead of the loop's next read, which resumes on the same serial queue; that read
/// then shows a later draw (from a commit in between, or from the capture's own `afterScreenUpdates` commit). A
/// timer-driven view does not hold on a starved host: one that redrew every 50 ms went 500 ms without a redraw
/// when the app ran at background priority, and settled.
private struct ChangingView: UIViewRepresentable {
    func makeUIView(context: Context) -> CountingView { CountingView() }
    func updateUIView(_ uiView: CountingView, context: Context) {}

    final class CountingView: UIView {
        private var draws = 0

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .white
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func draw(_ rect: CGRect) {
            draws += 1
            let text = "\(draws)" as NSString
            text.draw(at: CGPoint(x: 20, y: bounds.midY - 40), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 64, weight: .bold), .foregroundColor: UIColor.black
            ])
            DispatchQueue.main.async { [weak self] in self?.setNeedsDisplay() }
        }
    }
}
