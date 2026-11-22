import AppFeature
import CryptoKit
import Foundation
import SwiftUI
import Synchronization
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
        // Settling requires both the stable span and the six-read floor, so a single slow capture on a starved runner
        // cannot short-circuit on two or three reads before Liquid Glass and bar subviews converge.
        XCTAssertGreaterThanOrEqual(samples, HostedWindowCapture.minimumReads)
        XCTAssertGreaterThanOrEqual(seconds, HostedWindowCapture.stableSpan / .seconds(1))
    }

    @MainActor
    func testASettledAttemptRecordsTheSettledReadWithoutAnExtraCapture() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let before = HostedWindowCapture.captureCalls
        let outcome = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .light, reference: nil, mode: .candidate
        )
        XCTAssertEqual(outcome.status, .recorded)
        XCTAssertGreaterThanOrEqual(outcome.settleSamples, HostedWindowCapture.minimumReads)
        XCTAssertEqual(HostedWindowCapture.captureCalls - before, outcome.settleSamples)
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

    /// Run 42577585956: on the iPad turned to landscape, every read that rendered the window again drew the
    /// first-launch page's dimmed Liquid Glass Continue a step different from the read before (1/255 in a few to a few
    /// hundred pixels, cycling through two or three states), so a still page read as changing until the sample cap.
    /// Reading a window that has settled must not change it: a second settle matches from its first read.
    @MainActor
    func testReadingASettledGlassPageDoesNotChangeIt() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let reads = BrowsingScenarios.firstLaunchMinimumReads
        for style in [UIUserInterfaceStyle.light, .dark] {
            let hosted = HostedWindowCapture.host(BrowsingScenarios.analyticsChoice(nil), in: window, style: style)
            defer { hosted.dispose() }
            guard case .settled = await HostedWindowCapture.settle(window, minimumReads: reads) else {
                return XCTFail("The still first-launch page did not settle (style \(style.rawValue))")
            }
            let again = await HostedWindowCapture.settle(window, minimumReads: reads)
            XCTAssertEqual(again.samples, reads, "Reading the settled page changed it (style \(style.rawValue))")
        }
    }

    /// Two reads match when no byte moved more than one step and the bytes that moved stay within half the
    /// comparison's byte budget, so a picture taken within that of the settled read stays within the budget of a
    /// reference recorded the same way.
    func testReadsMatchWithinOneStepAndHalfTheComparisonBudget() {
        let count = 400_000
        let half = Int((1 - HostedWindowCapture.precision) * Float(count)) / 2
        XCTAssertEqual(half, 20)
        let still = [UInt8](repeating: 128, count: count)
        XCTAssertTrue(HostedWindowCapture.readsMatch(still, still))
        let stepped = Self.read(still, setting: [4: 129, 9: 127, count - 1: 129])
        XCTAssertTrue(HostedWindowCapture.readsMatch(still, stepped))
        let jumped = Self.read(still, setting: [4: 130])
        XCTAssertFalse(HostedWindowCapture.readsMatch(still, jumped), "Two steps in one byte is a change")
        let spread = Self.read(still, setting: Dictionary(uniqueKeysWithValues: (0..<half).map({ ($0 * 7, 129) })))
        XCTAssertTrue(HostedWindowCapture.readsMatch(still, spread))
        let wider = Self.read(spread, setting: [count - 2: 127])
        XCTAssertFalse(HostedWindowCapture.readsMatch(still, wider), "More bytes than half the budget is a change")
        XCTAssertFalse(HostedWindowCapture.readsMatch(still, Array(still.dropLast(4))))
    }

    /// `bytes` with the bytes at the given offsets replaced.
    private static func read(_ bytes: [UInt8], setting changes: [Int: UInt8]) -> [UInt8] {
        bytes.enumerated().map({ changes[$0.offset] ?? $0.element })
    }

    /// A view that moves one step a read never settles: every read is compared with the first read of its run, not
    /// with the read before, so steps of one cannot add up to a match.
    @MainActor
    func testAViewThatDriftsOneStepEachReadDoesNotSettle() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(DriftingView(), in: window, style: .light)
        defer { hosted.dispose() }
        guard case .timeout = await HostedWindowCapture.settle(window) else {
            return XCTFail("A view that drifts one step a read settled")
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
        // Run 43575259346: the result line kept only the second attempt's reason, and none for a picture that passed
        // on the retry, so the failures that the retry hid left no trace.
        XCTAssertEqual(recovered.firstReason, "interaction:not-found")
        XCTAssertEqual(failing.firstReason, "interaction:step-error")
        XCTAssertEqual(
            SnapshotMatrixCase.lineReason(recovered, picture: 1, of: 2),
            "attempt 1: interaction:not-found; picture 1 of 2"
        )
        XCTAssertEqual(
            SnapshotMatrixCase.lineReason(failing, picture: 2, of: 2),
            "interaction:step-error; attempt 1: interaction:step-error; picture 2 of 2"
        )
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
        XCTAssertNil(outcome.firstReason)
        XCTAssertNil(SnapshotMatrixCase.lineReason(outcome, picture: 1, of: 2))
    }

    // MARK: Tall window (19-19)

    /// A page committed shorter than its content fails with the height it needs, keeps its picture at the committed
    /// height, is not retried and leaves the window as it found it; committed at that need, it is recorded.
    @MainActor
    func testAPageTallerThanItsCommittedHeightFailsWithTheHeightItNeeds() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.frame
        // 1000 pt committed over 1500 pt of content on the 912 pt phone.
        let committed = native.height + 88
        let content = committed + 500
        var insets: CGFloat = 0
        var grownInsets = UIEdgeInsets.zero
        let failed = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.scrolling(content)) }, window: window, style: .light, reference: nil,
            mode: .candidate,
            interact: { window in
                let scrollView = Self.scrollViews(in: window).first
                insets = (scrollView?.adjustedContentInset.top ?? 0) + (scrollView?.adjustedContentInset.bottom ?? 0)
                grownInsets = window.safeAreaInsets
            },
            height: Self.height(committed)
        )
        let need = Int((content + insets).rounded(.up))
        // Recorded, not checked: the safe area the tall window ends up with (its top, left and right are pinned).
        let observed = XCTAttachment(string: """
            window \(native.width) x \(committed) pt, native height \(native.height) pt; \
            safeAreaInsets top \(grownInsets.top) left \(grownInsets.left) bottom \(grownInsets.bottom) \
            right \(grownInsets.right)
            """)
        observed.name = "tall-window-safe-area"
        observed.lifetime = .keepAlways
        add(observed)
        XCTAssertEqual(failed.status, .error)
        XCTAssertEqual(failed.attempts, 1)
        XCTAssertEqual(failed.reason, "page-height: needs \(need) pt, committed \(Int(committed)) pt")
        XCTAssertEqual(try Self.pixelHeight(failed.png), Int(committed))
        XCTAssertEqual(window.frame, native)
        // The size class pins are removed again.
        XCTAssertFalse(window.traitOverrides.contains(UITraitHorizontalSizeClass.self))
        XCTAssertFalse(window.traitOverrides.contains(UITraitVerticalSizeClass.self))

        let recorded = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.scrolling(content)) }, window: window, style: .light, reference: nil,
            mode: .candidate, height: Self.height(CGFloat(need))
        )
        XCTAssertEqual(recorded.status, .recorded, recorded.reason ?? "")
        XCTAssertEqual(try Self.pixelHeight(recorded.png), need)
        XCTAssertEqual(window.frame, native)
    }

    /// A height equal to the window's own is today's path: the same bytes as a call without a height.
    @MainActor
    func testACommittedHeightEqualToTheWindowTakesTheSameBytesAsNoHeight() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let plain = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .light, reference: nil,
            mode: .candidate
        )
        let sized = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.sample(offset: 0)) }, window: window, style: .light, reference: nil,
            mode: .candidate, height: Self.height(window.bounds.height)
        )
        XCTAssertEqual(plain.status, .recorded)
        XCTAssertEqual(sized.status, .recorded)
        XCTAssertNotNil(plain.png)
        XCTAssertEqual(sized.png, plain.png)
    }

    /// A scroll view the user cannot see never counts toward the need: hidden, or (nearly) transparent in itself or
    /// in an ancestor. The visible one is the control that fails.
    @MainActor
    func testAHiddenOrTransparentScrollViewNeverCountsTowardsThePageHeight() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        for concealment in OversizedScrollView.Concealment.allCases {
            let outcome = await HostedWindowCapture.captureAndCompare(
                make: { AnyView(OversizedScrollView(concealment: concealment)) }, window: window, style: .light,
                reference: nil, mode: .candidate, height: Self.height(window.bounds.height)
            )
            if concealment == .visible {
                XCTAssertEqual(outcome.status, .error)
                XCTAssertTrue(outcome.reason?.hasPrefix("page-height: needs") == true, outcome.reason ?? "")
            } else {
                XCTAssertEqual(outcome.status, .recorded, "\(concealment): \(outcome.reason ?? "")")
            }
        }
    }

    /// A committed height whose device pixels are above the render server's limit is taken in reads of the native
    /// size, settled on owned-row digests: the picture is exactly the committed height at 1x, and two captures in a row
    /// give the same bytes. The direct `drawHierarchy` path is not used after the user step.
    @MainActor
    func testAPageAboveTheRenderServerLimitIsTakenInSlicesAndRepeats() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.frame
        let committed = (RenderServerCapture.maximumSnapshotDimension / window.screen.scale).rounded(.up) + 200
        XCTAssertGreaterThan(committed * window.screen.scale, RenderServerCapture.maximumSnapshotDimension)
        var pictures: [Data] = []
        for _ in 1...2 {
            var drawsBeforeCapture = 0
            let outcome = await HostedWindowCapture.captureAndCompare(
                make: { AnyView(Self.bands(height: committed)) }, window: window, style: .light, reference: nil,
                mode: .candidate, interact: { _ in drawsBeforeCapture = HostedWindowCapture.captureCalls },
                height: Self.height(committed)
            )
            XCTAssertEqual(outcome.status, .recorded, outcome.reason ?? "")
            XCTAssertGreaterThanOrEqual(outcome.settleSamples, HostedWindowCapture.minimumReads)
            XCTAssertEqual(HostedWindowCapture.captureCalls, drawsBeforeCapture, "the direct path was used")
            XCTAssertEqual(try Self.pixelHeight(outcome.png), Int(committed))
            XCTAssertEqual(window.frame, native)
            pictures.append(try XCTUnwrap(outcome.png))
        }
        XCTAssertEqual(pictures.first, pictures.last)
    }

    /// A page at or under the limit keeps the direct `drawHierarchy` path, also in a tall window.
    @MainActor
    func testAPageUnderTheRenderServerLimitKeepsTheDirectPath() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let committed = window.bounds.height + 88
        XCTAssertLessThanOrEqual(committed * window.screen.scale, RenderServerCapture.maximumSnapshotDimension)
        var drawsBeforeCapture = 0
        let outcome = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.bands(height: committed)) }, window: window, style: .light, reference: nil,
            mode: .candidate, interact: { _ in drawsBeforeCapture = HostedWindowCapture.captureCalls },
            height: Self.height(committed)
        )
        XCTAssertEqual(outcome.status, .recorded, outcome.reason ?? "")
        XCTAssertEqual(HostedWindowCapture.captureCalls - drawsBeforeCapture, outcome.settleSamples)
        XCTAssertGreaterThan(outcome.settleSamples, 0)
        XCTAssertEqual(try Self.pixelHeight(outcome.png), Int(committed))
    }

    // MARK: Measuring mode (19-20)

    /// A scroll view with content taller than the window is measured at the need the check reports for it, in one
    /// growth step, and the window is left as it was found.
    @MainActor
    func testMeasuringAScrollViewGivesTheNeedTheCheckReports() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.frame
        let content = native.height + 588
        var insets: CGFloat = 0
        let measured = await Self.measure(Self.scrolling(content), in: window) { window in
            let scrollView = Self.scrollViews(in: window).first
            insets = (scrollView?.adjustedContentInset.top ?? 0) + (scrollView?.adjustedContentInset.bottom ?? 0)
        }
        let need = Int((content + insets).rounded(.up))
        XCTAssertEqual(measured, PageMeasurement(
            status: .measured, neededPoints: need, screenPoints: Int(native.height), steps: 1, reason: nil
        ))
        XCTAssertEqual(window.frame, native)
        XCTAssertFalse(window.traitOverrides.contains(UITraitHorizontalSizeClass.self))
        XCTAssertFalse(window.traitOverrides.contains(UITraitVerticalSizeClass.self))
        let checked = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.scrolling(content)) }, window: window, style: .light, reference: nil,
            mode: .candidate, height: Self.height(native.height)
        )
        XCTAssertEqual(checked.reason, "page-height: needs \(need) pt, committed \(Int(native.height)) pt")
    }

    /// A page that fits the screen is measured at the screen height, without growing the window.
    @MainActor
    func testAPageThatFitsTheScreenIsMeasuredAtTheScreenHeightInNoSteps() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let measured = await Self.measure(Self.sample(offset: 0), in: window)
        let screen = Int(window.bounds.height)
        XCTAssertEqual(measured, PageMeasurement(
            status: .measured, neededPoints: screen, screenPoints: screen, steps: 0, reason: nil
        ))
    }

    /// A scroll view that keeps its own height while the window grows cannot be covered by any window height.
    @MainActor
    func testAScrollViewThatDoesNotGrowWithTheWindowCannotBeCovered() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let view = VStack(spacing: 0) {
            ScrollView { Color.orange.frame(height: 900) }
                .frame(height: 300)
            Color.clear
        }
        var scrollViewClass = ""
        let measured = await Self.measure(view, in: window) { window in
            scrollViewClass = Self.scrollViews(in: window).first.map({ String(describing: type(of: $0)) }) ?? ""
        }
        XCTAssertFalse(scrollViewClass.isEmpty)
        XCTAssertEqual(measured.status, .cannotCover)
        XCTAssertEqual(measured.reason, "cannot-cover:\(scrollViewClass)")
        XCTAssertEqual(measured.steps, 1)
        XCTAssertEqual(window.frame.height, CGFloat(measured.screenPoints))
    }

    /// Content that grows with every window step never holds still: the measurement gives up after 12 steps.
    @MainActor
    func testContentThatGrowsWithTheWindowDoesNotConverge() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let view = ScrollView {
            Color.orange.containerRelativeFrame(.vertical) { length, _ in length + 100 }
        }
        let measured = await Self.measure(view, in: window)
        XCTAssertEqual(measured.status, .didNotConverge, measured.reason ?? "")
        XCTAssertEqual(measured.steps, HostedWindowCapture.maximumGrowthSteps)
        XCTAssertNotNil(measured.neededPoints)
        XCTAssertEqual(window.frame.height, CGFloat(measured.screenPoints))
    }

    /// Height lines go to `heights.jsonl` and never to `results.jsonl`; a coordinate keeps its first final line, and
    /// an `error` line gives way to a later measurement.
    func testHeightLinesHaveTheirOwnFileAndKeepTheFirstFinalLine() throws {
        let writer = SnapshotResultWriter(output: try Self.temporaryDirectory())
        let key = "a__en__large__portrait__iphone__light"
        func line(_ status: SnapshotHeightStatus, needed: Int?) -> SnapshotHeightLine {
            SnapshotHeightLine(key: key, status: status, neededPoints: needed, screenPoints: 912, steps: 1, reason: nil)
        }
        XCTAssertTrue(try writer.appendHeight(line(.error, needed: nil)))
        XCTAssertFalse(try writer.appendHeight(line(.error, needed: nil)))
        XCTAssertTrue(try writer.appendHeight(line(.measured, needed: 1200)))
        XCTAssertFalse(try writer.appendHeight(line(.measured, needed: 1300)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: writer.resultsURL.path(percentEncoded: false)))
        let decoded = try String(contentsOf: writer.heightsURL, encoding: .utf8)
            .split(separator: "\n")
            .map({ try JSONDecoder().decode(SnapshotHeightLine.self, from: Data($0.utf8)) })
        XCTAssertEqual(decoded, [line(.error, needed: nil), line(.measured, needed: 1200)])
        let text = try String(contentsOf: writer.heightsURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\"status\":\"error\""))
        XCTAssertTrue(text.contains("\"reason\":null"))
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

    func testResultWriterKeepsTheFirstLineOfACoordinateAndItsPictures() throws {
        // Run 43298876957, s15: runners XCTest had given up woke and wrote coordinates their replacements had written.
        let writer = SnapshotResultWriter(output: try Self.temporaryDirectory())
        let key = "a__en__large__portrait__iphone__light", path = "iphone/en/large/a/portrait-light.png"
        func line(_ sha: String) -> SnapshotResultLine {
            SnapshotResultLine(
                key: key, status: .recorded, attempts: 1, flaky: false, seconds: 1, settleSamples: 2, bytes: 1,
                sha256: sha, reason: nil
            )
        }
        let first = SnapshotPicture(Data([1]), kind: nil, relativePath: path)
        XCTAssertTrue(try writer.append(line("01"), pictures: [first]))
        XCTAssertFalse(try writer.append(line("02"), pictures: [
            SnapshotPicture(Data([2]), kind: nil, relativePath: path),
            SnapshotPicture(Data([2]), kind: "first-actual", relativePath: path)
        ]))
        XCTAssertEqual(try writer.lines(), [line("01")])
        XCTAssertEqual(try Data(contentsOf: writer.output.appending(path: path)), Data([1]))
        let firstActual = writer.output.appending(path: "first-actual").appending(path: path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstActual.path(percentEncoded: false)))
    }

    func testTwoWritersOfOneCoordinateKeepOneLineAndItsPicture() throws {
        // Two processes (a stalled runner and its replacement) write the same coordinate at once: one line is kept,
        // and the picture on disk is the one that line names.
        let output = try Self.temporaryDirectory()
        for round in 0..<20 {
            let key = "a\(round)__en__large__portrait__iphone__light"
            let path = "iphone/en/large/a\(round)/portrait-light.png"
            let accepted = Mutex<[Int]>([])
            DispatchQueue.concurrentPerform(iterations: 2) { writerIndex in
                // Each writer opens the results file itself, as each process does.
                let writer = SnapshotResultWriter(output: output)
                let byte = UInt8(writerIndex + 1)
                do {
                    let wrote = try writer.append(
                        Self.recordedLine(key, sha: String(format: "%02x", byte)),
                        pictures: [SnapshotPicture(Data(repeating: byte, count: 4096), kind: nil, relativePath: path)]
                    )
                    if wrote {
                        accepted.withLock({ $0.append(writerIndex) })
                    }
                } catch {
                    XCTFail("round \(round), writer \(writerIndex): \(error)")
                }
            }
            let writer = SnapshotResultWriter(output: output)
            let lines = try writer.lines().filter({ $0.key == key })
            XCTAssertEqual(accepted.withLock({ $0.count }), 1, "round \(round)")
            XCTAssertEqual(lines.count, 1, "round \(round)")
            let picture = try Data(contentsOf: output.appending(path: path))
            XCTAssertEqual(lines.first?.sha256, picture.first.map({ String(format: "%02x", $0) }), "round \(round)")
        }
        XCTAssertEqual(try Self.stagedFiles(in: output), [])
    }

    func testACaptureAfterAFailedOneIsWrittenAndThenKept() throws {
        let writer = SnapshotResultWriter(output: try Self.temporaryDirectory())
        let key = "a__en__large__portrait__iphone__light", path = "iphone/en/large/a/portrait-light.png"
        let failure = SnapshotResultLine(
            key: key, status: .error, attempts: 2, flaky: false, seconds: 1, settleSamples: 0, bytes: 1,
            sha256: nil, reason: "interaction"
        )
        let timeout = SnapshotResultLine(
            key: key, status: .timeout, attempts: 2, flaky: false, seconds: 1, settleSamples: 0, bytes: 0,
            sha256: nil, reason: "settle"
        )
        let failurePicture = SnapshotPicture(Data([9]), kind: "actual", relativePath: path)
        XCTAssertTrue(try writer.append(failure, pictures: [failurePicture]))
        // A second failure adds nothing: the coordinate still waits for a capture.
        XCTAssertFalse(try writer.append(timeout))
        XCTAssertTrue(try writer.append(
            Self.recordedLine(key, sha: "01"), pictures: [SnapshotPicture(Data([1]), kind: nil, relativePath: path)]
        ))
        XCTAssertFalse(try writer.append(
            Self.recordedLine(key, sha: "02"), pictures: [SnapshotPicture(Data([2]), kind: nil, relativePath: path)]
        ))
        XCTAssertFalse(try writer.append(timeout))
        XCTAssertEqual(try writer.lines(), [failure, Self.recordedLine(key, sha: "01")])
        XCTAssertEqual(try Data(contentsOf: writer.output.appending(path: path)), Data([1]))
        XCTAssertEqual(try Data(contentsOf: writer.output.appending(path: "actual").appending(path: path)), Data([9]))
    }

    func testAPictureThatCannotBeStagedLeavesNoLineAndNoPicture() throws {
        let output = try Self.temporaryDirectory()
        let writer = SnapshotResultWriter(output: output)
        let key = "a__en__large__portrait__iphone__light", path = "iphone/en/large/a/portrait-light.png"
        // A file where the second picture's folder must go: staging it fails after the first picture was staged.
        try Data().write(to: output.appending(path: "difference"))
        XCTAssertThrowsError(try writer.append(Self.recordedLine(key, sha: "01"), pictures: [
            SnapshotPicture(Data([1]), kind: nil, relativePath: path),
            SnapshotPicture(Data([1]), kind: "difference", relativePath: path)
        ]))
        XCTAssertEqual(try writer.lines(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.appending(path: path).path(percentEncoded: false)))
        XCTAssertEqual(try Self.stagedFiles(in: output), [])
        // The coordinate is still open: its re-run writes it.
        XCTAssertTrue(try writer.append(
            Self.recordedLine(key, sha: "02"), pictures: [SnapshotPicture(Data([2]), kind: nil, relativePath: path)]
        ))
        XCTAssertEqual(try Data(contentsOf: output.appending(path: path)), Data([2]))
    }

    func testAPictureThatCannotBeMovedIntoPlaceLeavesNoLine() throws {
        let output = try Self.temporaryDirectory()
        let writer = SnapshotResultWriter(output: output)
        let key = "a__en__large__portrait__iphone__light", path = "iphone/en/large/a/portrait-light.png"
        // A folder that is not empty where the second picture must go: moving it into place fails under the lock.
        let blocked = output.appending(path: "actual").appending(path: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        try Data([0]).write(to: blocked.appending(path: "keep"))
        XCTAssertThrowsError(try writer.append(Self.recordedLine(key, sha: "01"), pictures: [
            SnapshotPicture(Data([1]), kind: nil, relativePath: path),
            SnapshotPicture(Data([1]), kind: "actual", relativePath: path)
        ]))
        XCTAssertEqual(try writer.lines(), [])
        XCTAssertEqual(try Self.stagedFiles(in: output), [])
        // The picture moved before the failure is replaced by the coordinate's re-run.
        XCTAssertTrue(try writer.append(
            Self.recordedLine(key, sha: "02"), pictures: [SnapshotPicture(Data([2]), kind: nil, relativePath: path)]
        ))
        XCTAssertEqual(try writer.lines(), [Self.recordedLine(key, sha: "02")])
        XCTAssertEqual(try Data(contentsOf: output.appending(path: path)), Data([2]))
    }

    func testAWriterGivesUpOnALockHeldTooLong() throws {
        // A frozen holder must not hang the runner that replaced it.
        let output = try Self.temporaryDirectory()
        let writer = SnapshotResultWriter(output: output, lockTimeout: .milliseconds(200))
        try writer.append(Self.recordedLine("b__en__large__portrait__iphone__light", sha: "00"))
        let holder = open(writer.resultsURL.path(percentEncoded: false), O_RDONLY)
        XCTAssertGreaterThanOrEqual(holder, 0)
        defer { close(holder) }
        XCTAssertEqual(flock(holder, LOCK_EX), 0)
        let key = "a__en__large__portrait__iphone__light", path = "iphone/en/large/a/portrait-light.png"
        XCTAssertThrowsError(try writer.append(
            Self.recordedLine(key, sha: "01"), pictures: [SnapshotPicture(Data([1]), kind: nil, relativePath: path)]
        )) { error in
            XCTAssertEqual(error as? SnapshotResultWriterError, .lockTimedOut)
        }
        flock(holder, LOCK_UN)
        XCTAssertEqual(try writer.recordedKeys(), ["b__en__large__portrait__iphone__light"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.appending(path: path).path(percentEncoded: false)))
        XCTAssertEqual(try Self.stagedFiles(in: output), [])
    }

    // MARK: Helpers

    @MainActor
    private static func measure(
        _ view: some View, in window: UIWindow, interact: (@MainActor (UIWindow) async throws -> Void)? = nil
    ) async -> PageMeasurement {
        await HostedWindowCapture.measure(
            make: { AnyView(view) }, window: window, style: .light, interact: interact, freezeViewport: { _ in }
        )
    }

    private static func height(_ points: CGFloat) -> CaptureHeight {
        CaptureHeight(points: points, freezeViewport: { _ in })
    }

    @MainActor
    private static func scrolling(_ height: CGFloat) -> some View {
        ScrollView {
            Color.orange.frame(height: height)
        }
    }

    /// A page that never scrolls: rows of changing colour and text, exactly `height` points tall.
    @MainActor
    private static func bands(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<Int(height / 60), id: \.self) { row in
                Text(verbatim: "Row \(row)")
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color(hue: Double(row % 12) / 12, saturation: 0.4, brightness: 0.95))
            }
            Color.white
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @MainActor
    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                found.append(scrollView)
            }
            found += scrollViews(in: subview)
        }
        return found
    }

    private static func pixelHeight(_ png: Data?) throws -> Int {
        try XCTUnwrap(png.flatMap(UIImage.init(data:))?.cgImage).height
    }

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

    private static func recordedLine(_ key: String, sha: String) -> SnapshotResultLine {
        SnapshotResultLine(
            key: key, status: .recorded, attempts: 1, flaky: false, seconds: 1, settleSamples: 2, bytes: 1,
            sha256: sha, reason: nil
        )
    }

    /// The files left in the writer's staging folder (empty once every append has finished).
    private static func stagedFiles(in output: URL) throws -> [String] {
        let staging = output.appending(path: ".staging", directoryHint: .isDirectory)
        guard let walker = FileManager.default.enumerator(at: staging, includingPropertiesForKeys: nil) else {
            return []
        }
        return walker.compactMap({ $0 as? URL }).filter({ !$0.hasDirectoryPath }).map(\.lastPathComponent)
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

/// A scroll view with 5000 pt of content, in the hosted page, shown or concealed in one of the ways the check
/// ignores.
private struct OversizedScrollView: UIViewRepresentable {
    enum Concealment: CaseIterable {
        case visible, hidden, transparent, transparentAncestor
    }

    let concealment: Concealment

    func makeUIView(context: Context) -> UIView {
        let ancestor = UIView()
        let scrollView = UIScrollView()
        scrollView.contentSize = CGSize(width: 10, height: 5000)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ancestor.addSubview(scrollView)
        switch concealment {
        case .visible: break
        case .hidden: scrollView.isHidden = true
        case .transparent: scrollView.alpha = 0.005
        case .transparentAncestor: ancestor.alpha = 0
        }
        return ancestor
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The scroll view fills its container, which SwiftUI sizes after making it.
        for subview in uiView.subviews {
            subview.frame = uiView.bounds
        }
    }
}

private struct StepError: CaptureStepFailure {
    var reason: String { "step-error" }
}

/// A 4-point grey square on white that grows one step (1/255) darker every 200 ms: few enough bytes for any read to
/// match the one before, but two steps from a read 500 ms earlier.
///
/// The level is the time that has passed when the view is drawn, and the view asks to be drawn again after every
/// draw (as ``ChangingView`` does), so each read shows the level of its own moment. A level that a timer stepped
/// did not: a timer the main queue could not serve for a while fires once when it comes back, and a read taken
/// ahead of that fire shows the level of the read before, so two reads seconds apart on a starved host matched
/// (this case failed that way in hosted runs 43002788032 and 43023945072).
private struct DriftingView: UIViewRepresentable {
    func makeUIView(context: Context) -> DriftView { DriftView() }
    func updateUIView(_ uiView: DriftView, context: Context) {}

    final class DriftView: UIView {
        private static let stepSpan: CFTimeInterval = 0.2
        private static let levels = 141

        private let origin = CACurrentMediaTime()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .white
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func draw(_ rect: CGRect) {
            let steps = Int((CACurrentMediaTime() - origin) / Self.stepSpan)
            let level = 200 - steps % Self.levels
            UIColor(white: CGFloat(level) / 255, alpha: 1).setFill()
            UIRectFill(CGRect(x: 40, y: 200, width: 4, height: 4))
            DispatchQueue.main.async { [weak self] in self?.setNeedsDisplay() }
        }
    }
}

/// Paints how many times it has been drawn and asks to be drawn again after every draw, so consecutive reads never
/// match on any host. The redraw request from the draw a read shows is queued on the main queue before the settle
/// loop's sleep starts, so it runs ahead of the loop's next read, which resumes on the same serial queue; that read
/// then shows a later draw (from a commit in between, or from the capture's own `afterScreenUpdates` commit). A
/// timer-driven view does not hold on a starved host: one that redrew every 50 ms went 500 ms without a redraw
/// when the app ran at background priority, and settled.
struct ChangingView: UIViewRepresentable {
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
