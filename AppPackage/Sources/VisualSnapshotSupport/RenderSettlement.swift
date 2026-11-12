import Foundation

/// The pixel-settlement rule shared by the native viewport reference and the grown full-content window.
///
/// Layout convergence is not render convergence. The glass toolbar material steps once, about 0.45 s after its
/// window appears (measured 2026-10-03: captures at t <= 0.38 s differ from the final one by +-1-2 inside the
/// glass disc, captures at t >= 0.52 s are identical on both devices), and glass first drawn after the window
/// grows changes once within about 0.1 to 0.45 s (measured 2026-10-05; 17-02-PLAN.md, owner approval of
/// owned-row verification). A sample is therefore accepted only once consecutive samples stay identical over a run
/// spanning at least ``stableSpan``, which is longer than either delay. This is the same stable-iterations idea the
/// layout loop uses, applied to pixels; no fixed sleep stands in for it.
@MainActor
enum RenderSettlement {
    /// The shortest span of consecutive identical samples that is accepted.
    static let stableSpan: Duration = .milliseconds(500)
    /// The pause after each sample's next display frame.
    static let sampleInterval: Duration = .milliseconds(100)
    static let maximumSamples = 40

    struct Settled<Value> {
        /// The sample that closed the accepted run.
        let value: Value
        /// Samples taken, including the accepted one.
        let samples: Int
        /// The span of the identical run the accepted sample closed.
        let settledDuration: Duration
    }

    /// Samples until consecutive samples are identical by `key` over a run spanning at least ``stableSpan``.
    ///
    /// `sample` returns `nil` for a sample rejected by a change inside it; that restarts the run exactly as a change
    /// between consecutive samples does. Other errors propagate. Throws `failure` when ``maximumSamples`` samples
    /// never settle.
    static func settle<C: Clock<Duration>, Value, Key: Equatable>(
        clock: C, failure: FullContentHostError, key: (Value) -> Key, nextFrame: () async -> Void,
        sample: (_ index: Int) async throws -> Value?
    ) async throws -> Settled<Value> {
        var runStart = clock.now
        var previous: Key?
        for index in 1...maximumSamples {
            try Task.checkCancellation()
            if let value = try await sample(index) {
                let now = clock.now
                let current = key(value)
                if previous == current {
                    let duration = runStart.duration(to: now)
                    if duration >= stableSpan {
                        return Settled(value: value, samples: index, settledDuration: duration)
                    }
                } else {
                    runStart = now
                }
                previous = current
            } else {
                runStart = clock.now
                previous = nil
            }
            await nextFrame()
            try await clock.sleep(for: sampleInterval)
        }
        throw failure
    }
}
