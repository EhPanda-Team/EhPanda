public import Foundation
import SwiftUI
import Synchronization

#if DEBUG
/// The Recently Viewed row's UI-test options. The app's UI-test automation sets them once at launch, from its own
/// launch keys (`EHPANDA_UITEST_RECENT_FRAME_LOG`); no launch key is read in this module.
public enum RecentlyViewedUITestOptions {
    private static let frameLogValue = Mutex<URL?>(nil)

    /// The file each card appends a line to whenever its leading edge lands somewhere new, as
    /// `<seconds> <run loop turn> <gallery id> <edge>`; `nil` unless a UI-test launch asks for it.
    public static var frameLogURL: URL? {
        get { frameLogValue.withLock({ $0 }) }
        set { frameLogValue.withLock({ $0 = newValue }) }
    }

    /// How many times the main run loop has gone idle. The screen takes what a run loop turn leaves behind, so layouts
    /// that share a turn share a frame at most.
    private static let turnValue = Mutex(0)
    private static let observing = Mutex(false)

    private static func countTurns() {
        guard observing.withLock({ let first = !$0; $0 = true; return first }) else { return }
        let activity = CFRunLoopActivity.beforeWaiting.rawValue
        let observer = CFRunLoopObserverCreateWithHandler(nil, activity, true, 0) { _, _ in
            turnValue.withLock({ $0 += 1 })
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    static func record(id: String, edge: Double) {
        guard let path = frameLogURL?.path(percentEncoded: false) else { return }
        countTurns()
        let line = "\(Date().timeIntervalSinceReferenceDate) \(turnValue.withLock({ $0 })) \(id) \(edge)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}
#endif

extension View {
    /// Logs where this card's leading edge sits on screen, each time layout puts it somewhere new, for the UI test
    /// that watches the row for movement. Does nothing in a release build or when no log is asked for.
    func recordsLeadingEdge(of id: String) -> some View {
        #if DEBUG
        onGeometryChange(for: Double.self, of: { $0.frame(in: .global).minX }) {
            RecentlyViewedUITestOptions.record(id: id, edge: $0)
        }
        #else
        self
        #endif
    }
}
