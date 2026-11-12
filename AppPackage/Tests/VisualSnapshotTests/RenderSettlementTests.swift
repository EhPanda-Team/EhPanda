import CustomDump
import Synchronization
@testable import VisualSnapshotSupport
import XCTest

/// The settle rule shared by the native viewport reference and the grown full-content window, driven by a clock
/// that only moves between samples, so every accepted span is exact rather than timing dependent.
final class RenderSettlementTests: XCTestCase {
    @MainActor
    func testAcceptsTheFirstIdenticalRunSpanningTheStableInterval() async throws {
        let run = try await Self.settle(Array(repeating: "a", count: 7))
        expectNoDifference(run.requested, Array(1...6))
        expectNoDifference(run.settled.value, "a")
        expectNoDifference(run.settled.samples, 6)
        expectNoDifference(run.settled.settledDuration, .milliseconds(500))
    }

    @MainActor
    func testAChangeBetweenSamplesRestartsTheRun() async throws {
        let run = try await Self.settle(["a"] + Array(repeating: "b", count: 7))
        expectNoDifference(run.settled.value, "b")
        expectNoDifference(run.settled.samples, 7)
        expectNoDifference(run.settled.settledDuration, .milliseconds(500))
    }

    /// A sample rejected by a change inside it cannot bridge the identical samples around it.
    @MainActor
    func testARejectedSampleRestartsTheRun() async throws {
        let run = try await Self.settle(["a", "a", "a", nil] + Array(repeating: "a", count: 7))
        expectNoDifference(run.settled.samples, 10)
        expectNoDifference(run.settled.settledDuration, .milliseconds(500))
    }

    /// Samples are compared by key, and the accepted sample is the one that closed the run.
    @MainActor
    func testComparesKeysAndReturnsTheClosingSample() async throws {
        let clock = ManualClock()
        let settled = try await RenderSettlement.settle(
            clock: clock, failure: .renderDidNotSettle, key: \Probe.key, nextFrame: {}
        ) { index in
            Probe(key: 1, index: index)
        }
        expectNoDifference(settled.value, Probe(key: 1, index: 6))
    }

    @MainActor
    func testFailsWithTheGivenErrorAfterTheSampleBound() async throws {
        var requested: [Int] = []
        do {
            _ = try await RenderSettlement.settle(
                clock: ManualClock(), failure: .fullContentRenderDidNotSettle, key: { $0 }, nextFrame: {}
            ) { index -> String? in
                requested.append(index)
                return index.isMultiple(of: 2) ? "a" : "b"
            }
            XCTFail("An alternating render must not settle")
        } catch FullContentHostError.fullContentRenderDidNotSettle {
            expectNoDifference(requested, Array(1...RenderSettlement.maximumSamples))
        }
    }

    @MainActor
    func testSampleErrorsPropagateImmediately() async throws {
        var requested: [Int] = []
        do {
            _ = try await RenderSettlement.settle(
                clock: ManualClock(), failure: .renderDidNotSettle, key: { $0 }, nextFrame: {}
            ) { index -> String? in
                requested.append(index)
                if index == 2 { throw RenderServerCaptureError.emptyImage }
                return "a"
            }
            XCTFail("A sample error must propagate")
        } catch RenderServerCaptureError.emptyImage {
            expectNoDifference(requested, [1, 2])
        }
    }

    /// Feeds `samples` in order (`nil` marks a rejected sample) and records which sample indices were requested.
    @MainActor
    private static func settle(
        _ samples: [String?]
    ) async throws -> (requested: [Int], settled: RenderSettlement.Settled<String>) {
        var requested: [Int] = []
        let settled = try await RenderSettlement.settle(
            clock: ManualClock(), failure: .renderDidNotSettle, key: { $0 }, nextFrame: {}
        ) { index -> String? in
            requested.append(index)
            return samples.indices.contains(index - 1) ? samples[index - 1] : nil
        }
        return (requested, settled)
    }
}

private struct Probe: Equatable {
    let key: Int
    let index: Int
}

/// A clock that advances only when the settle loop sleeps between samples.
private final class ManualClock: Clock {
    struct Instant: InstantProtocol {
        let offset: Swift.Duration

        func advanced(by duration: Swift.Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Swift.Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private let current = Mutex(Instant(offset: .zero))

    var now: Instant {
        current.withLock({ $0 })
    }

    var minimumResolution: Swift.Duration {
        .zero
    }

    func sleep(until deadline: Instant, tolerance: Swift.Duration?) async throws {
        current.withLock({ $0 = max($0, deadline) })
    }
}
