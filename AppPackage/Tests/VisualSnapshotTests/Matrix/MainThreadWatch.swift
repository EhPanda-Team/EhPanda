import Darwin
import Foundation
import Synchronization
import UIKit

/// Watches a matrix process's main thread: how long its run loop has turned, which a user step's wait counts
/// (``StepBudget``), and every stretch in which it did not turn, with what the main thread was doing meanwhile.
///
/// Run 43621303643's step failures looked once or twice in waits of 15 to 172 s (`polls=1`, `polls=2`): the main
/// thread did not come back for tens of seconds, and the step's wall-clock deadline ran out meanwhile. Whether the
/// main thread was held inside the process (UIKit waiting on a service) or the whole process was not run (the
/// simulator or the runner starved) could not be read from the run. Here a heartbeat on the main run loop records
/// each stretch of more than ``stallThreshold`` without a turn, and a watchdog thread of its own samples the main
/// thread's stack during it and records every wake of its own that came more than a second late. A stretch the
/// watchdog was itself late through is `frozen` (the process was not run); one it was on time through is `blocked`
/// (the main thread was held while the process ran). Each stretch is written to `logs/main-thread-<pid>.log` in the
/// run's output, with the coordinate being captured, the watchdog's lateness and the sampled stacks; other notes
/// for that log come through ``note(_:)``.
enum MainThreadWatch {
    /// How often the main run loop's heartbeat fires.
    static let beat: Duration = .milliseconds(50)
    /// The most one stretch without a turn adds to ``turned``.
    static let turnCap: Duration = .seconds(1)
    /// A stretch without a turn longer than this is a stall: recorded, and the main thread's stack sampled in it.
    static let stallThreshold: Duration = .seconds(2)
    /// How far into one stall the watchdog samples the main thread's stack.
    static let sampleMarks: [Duration] = [.seconds(2), .seconds(10), .seconds(30), .seconds(60), .seconds(120)]

    /// A stretch in which the main run loop did not turn, from its last turn before to its first turn after.
    struct Stall: Equatable {
        let start: UInt64
        let end: UInt64
        /// How much of the stretch the watchdog thread was itself late through.
        let watchdogLate: UInt64

        var seconds: Double { Double(end - start) / 1e9 }

        /// `frozen` when the watchdog was late through at least half of the stretch, else `blocked`.
        var kind: String { watchdogLate * 2 >= end - start ? "frozen" : "blocked" }
    }

    /// One look at the main thread's stack during a stall.
    struct Sample {
        let time: UInt64
        /// How long the main run loop had not turned.
        let stale: UInt64
        /// How late the watchdog's own wake was that took the sample.
        let late: UInt64
        let frames: [String]
    }

    /// A stretch in which the watchdog thread itself woke late: the process was not run.
    struct Late {
        let start: UInt64
        let end: UInt64
    }

    // Shared with the watchdog thread.
    private static let lastBeat = Atomic<UInt64>(0)
    private static let mainPort = Atomic<UInt32>(0)
    private static let stackTop = Atomic<UInt>(0)
    private static let stackBottom = Atomic<UInt>(0)
    private static let samples = Mutex<[Sample]>([])
    private static let lateWakes = Mutex<[Late]>([])

    @MainActor private static var timer: Timer?
    /// How long the main run loop has turned since the watch started: each stretch between two heartbeats counts,
    /// up to ``turnCap``.
    @MainActor private(set) static var turned: Duration = .zero
    @MainActor private(set) static var stalls: [Stall] = []
    /// The samples the watchdog took in the latest stall.
    @MainActor private(set) static var lastSamples: [Sample] = []
    /// What the process is capturing, for the log (a coordinate key).
    @MainActor static var context = ""
    @MainActor private static var log: URL?

    /// The monotonic clock the watch counts on, in nanoseconds.
    nonisolated static func now() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    }

    /// Starts the heartbeat and the watchdog once per process; with `output`, stalls are written to its `logs`.
    @MainActor
    static func start(output: URL? = nil) {
        if let output, log == nil {
            let directory = output.appending(path: "logs", directoryHint: .isDirectory)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                log = directory.appending(path: "main-thread-\(getpid()).log")
            } catch {
                // No log: the stalls still reach the steps' reasons.
                log = nil
            }
        }
        guard timer == nil else { return }
        let thread = pthread_self()
        mainPort.store(pthread_mach_thread_np(thread), ordering: .relaxed)
        let top = UInt(bitPattern: pthread_get_stackaddr_np(thread))
        stackTop.store(top, ordering: .relaxed)
        stackBottom.store(top - UInt(pthread_get_stacksize_np(thread)), ordering: .relaxed)
        lastBeat.store(now(), ordering: .releasing)
        let timer = Timer(timeInterval: seconds(beat), repeats: true) { _ in
            MainActor.assumeIsolated { heartbeat() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let watchdog = Thread(block: watch)
        watchdog.name = "MainThreadWatch"
        watchdog.qualityOfService = .userInteractive
        watchdog.start()
    }

    /// How long the main run loop has not turned, now.
    @MainActor
    static var currentStretch: UInt64 {
        now() - lastBeat.load(ordering: .acquiring)
    }

    /// The longest stall that ended at or after `mark` (``now()``), counting a stretch still under way.
    @MainActor
    static func longestStall(since mark: UInt64) -> Stall? {
        let current = now()
        let last = lastBeat.load(ordering: .acquiring)
        var candidates = stalls.filter({ $0.end >= mark })
        if current - last > nanoseconds(stallThreshold) {
            candidates.append(Stall(start: max(last, mark), end: current, watchdogLate: late(from: last, to: current)))
        }
        return candidates.max(by: { $0.end - $0.start < $1.end - $1.start })
    }

    @MainActor
    private static func heartbeat() {
        let current = now()
        let previous = lastBeat.exchange(current, ordering: .acquiringAndReleasing)
        let gap = current - previous
        turned += .nanoseconds(Int64(min(gap, nanoseconds(turnCap))))
        guard gap > nanoseconds(stallThreshold) else { return }
        let stall = Stall(start: previous, end: current, watchdogLate: late(from: previous, to: current))
        stalls.append(stall)
        if stalls.count > 256 { stalls.removeFirst(stalls.count - 256) }
        write(stall)
    }

    /// How much of `start..<end` the watchdog thread was late through.
    private static func late(from start: UInt64, to end: UInt64) -> UInt64 {
        lateWakes.withLock { wakes in
            wakes.reduce(0) { total, wake in
                let (lower, upper) = (max(start, wake.start), min(end, wake.end))
                return total + (upper > lower ? upper - lower : 0)
            }
        }
    }

    /// Writes `text` to the log with the time and what the process is capturing.
    @MainActor
    static func note(_ text: String) {
        let time = Date().ISO8601Format(.iso8601.time(includingFractionalSeconds: true))
        append("\(time) context=\(context) \(text)\n")
    }

    @MainActor
    private static func append(_ text: String) {
        guard let log else { return }
        do {
            if !FileManager.default.fileExists(atPath: log.path) {
                FileManager.default.createFile(atPath: log.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: log)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
        } catch {
            // The log is diagnostics only; a stall still reaches the steps' reasons.
            return
        }
    }

    @MainActor
    private static func write(_ stall: Stall) {
        let taken = samples.withLock { samples in
            let mine = samples.filter({ $0.time >= stall.start && $0.time <= stall.end })
            samples.removeAll(where: { $0.time <= stall.end })
            return mine
        }
        lastSamples = taken
        let offset = Date().timeIntervalSince1970 - Double(now()) / 1e9
        let began = Date(timeIntervalSince1970: offset + Double(stall.start) / 1e9)
        var text = String(
            format: "%@ stall %.2fs %@ watchdog-late=%.2fs context=%@ process=%.0fs\n",
            began.ISO8601Format(.iso8601.time(includingFractionalSeconds: true)), stall.seconds, stall.kind,
            Double(stall.watchdogLate) / 1e9, context, BrowsingScenarios.processSeconds ?? -1
        )
        for sample in taken {
            text += String(
                format: "  sample at %.2fs (watchdog %.2fs late):\n", Double(sample.stale) / 1e9,
                Double(sample.late) / 1e9
            )
            text += sample.frames.enumerated().map({ "    #\($0.offset) \($0.element)\n" }).joined()
        }
        append(text)
    }

    // MARK: Watchdog thread

    private static let tick: UInt64 = 100_000_000
    private static let lateThreshold: UInt64 = 1_000_000_000

    private static func watch() {
        let capacity = 128
        let buffer = UnsafeMutablePointer<UInt>.allocate(capacity: capacity)
        var previous = now()
        var stallBeat: UInt64 = 0
        var taken = 0
        while true {
            usleep(UInt32(tick / 1000))
            let current = now()
            let late = current - previous > tick ? current - previous - tick : 0
            if late > lateThreshold {
                lateWakes.withLock { wakes in
                    wakes.append(Late(start: previous + tick, end: current))
                    if wakes.count > 256 { wakes.removeFirst(wakes.count - 256) }
                }
            }
            previous = current
            let beat = lastBeat.load(ordering: .acquiring)
            let stale = current > beat ? current - beat : 0
            if beat != stallBeat {
                stallBeat = beat
                taken = 0
            }
            guard taken < sampleMarks.count, stale >= nanoseconds(sampleMarks[taken]) else { continue }
            taken += 1
            let count = sampleMainThread(into: buffer, capacity: capacity)
            let frames = (0..<count).map({ symbol((buffer + $0).pointee, isReturnAddress: $0 > 0) })
            samples.withLock { samples in
                samples.append(Sample(time: current, stale: stale, late: late, frames: frames))
                if samples.count > 64 { samples.removeFirst(samples.count - 64) }
            }
        }
    }

    /// The main thread's program counter and return addresses, read by its frame pointers while it is suspended.
    /// Nothing is allocated while it is suspended: it may hold the allocator's lock.
    private static func sampleMainThread(into buffer: UnsafeMutablePointer<UInt>, capacity: Int) -> Int {
        let port = thread_act_t(mainPort.load(ordering: .relaxed))
        let top = stackTop.load(ordering: .relaxed)
        let bottom = stackBottom.load(ordering: .relaxed)
        guard port != 0, thread_suspend(port) == KERN_SUCCESS else { return 0 }
        defer { thread_resume(port) }
        var count = 0
        var frame: UInt = 0
        #if arch(arm64)
        var state = arm_thread_state64_t()
        var stateCount = mach_msg_type_number_t(
            MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &state) { pointer in
            pointer.withMemoryRebound(to: natural_t.self, capacity: Int(stateCount)) { words in
                thread_get_state(port, ARM_THREAD_STATE64, words, &stateCount)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        buffer.pointee = UInt(state.__pc)
        (buffer + 1).pointee = UInt(state.__lr)
        count = 2
        frame = UInt(state.__fp)
        #elseif arch(x86_64)
        var state = x86_thread_state64_t()
        var stateCount = mach_msg_type_number_t(
            MemoryLayout<x86_thread_state64_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &state) { pointer in
            pointer.withMemoryRebound(to: natural_t.self, capacity: Int(stateCount)) { words in
                thread_get_state(port, x86_THREAD_STATE64, words, &stateCount)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        buffer.pointee = UInt(state.__rip)
        count = 1
        frame = UInt(state.__rbp)
        #endif
        while count < capacity, frame >= bottom, frame + 16 <= top, frame % 8 == 0,
              let words = UnsafePointer<UInt>(bitPattern: frame) {
            let next = words.pointee
            let returnAddress = (words + 1).pointee
            guard returnAddress != 0 else { break }
            (buffer + count).pointee = returnAddress
            count += 1
            guard next > frame else { break }
            frame = next
        }
        return count
    }

    /// `image symbol + offset` for an address, as `dladdr` names it (exported names only).
    private static func symbol(_ address: UInt, isReturnAddress: Bool) -> String {
        let lookup = isReturnAddress && address > 0 ? address - 1 : address
        var info = Dl_info()
        guard let pointer = UnsafeRawPointer(bitPattern: lookup), dladdr(pointer, &info) != 0 else {
            return String(format: "0x%lx", address)
        }
        let image = info.dli_fname.map({ URL(filePath: String(cString: $0)).lastPathComponent }) ?? "?"
        guard let name = info.dli_sname.map({ String(cString: $0) }) else {
            return String(format: "%@ 0x%lx", image, address)
        }
        return "\(image) \(name) + \(lookup - UInt(bitPattern: info.dli_saddr))"
    }

    static func nanoseconds(_ duration: Duration) -> UInt64 {
        UInt64(duration.components.seconds) * 1_000_000_000 + UInt64(duration.components.attoseconds / 1_000_000_000)
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
