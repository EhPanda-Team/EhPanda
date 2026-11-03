public import SwiftUI

/// A native List of galleries whose scroll anchor is the row a person sees at its top.
///
/// Rows report their frames, so the anchor follows what is on screen rather than a row that is merely
/// visible under a bar. A rebuilt list, for example after switching layouts, scrolls its anchor to
/// the top. If that alignment still leaves the row under a bar, as the iPad split detail once did,
/// the native minimal scroll then reveals it just below the bar.
public struct GalleryAnchoredList<Content: View>: View {
    @Binding private var anchorID: String?
    @State private var tracker: GalleryRowAnchorTracker
    private let ids: [String]
    private let content: Content

    public init(anchorID: Binding<String?>, ids: [String], @ViewBuilder content: () -> Content) {
        _anchorID = anchorID
        _tracker = State(initialValue: GalleryRowAnchorTracker(restoring: anchorID.wrappedValue))
        self.ids = ids
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            List {
                content
            }
            .environment(\.galleryRowAnchorTracker, tracker)
            .onGeometryChange(for: CGRect.self) { geometry in
                // The list lays out inside the bars and only scrolls its content beneath them,
                // so its own frame is the clear area.
                geometry.frame(in: .global)
            } action: { clearArea in
                tracker.updateClearArea(clearArea)
            }
            .onChange(of: ids.isEmpty, initial: true) { _, isEmpty in
                guard !isEmpty, let id = tracker.beginRestoration(availableIDs: ids) else { return }
                proxy.scrollTo(id, anchor: .top)
                Task {
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        // Nothing cancels this task, and an early end would only resume tracking sooner.
                    }
                    tracker.endRestoration()
                }
            }
            .onChange(of: tracker.revealID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
            .onChange(of: tracker.visibleID) { _, id in
                guard let id, id != anchorID else { return }
                anchorID = id
            }
        }
    }
}

public extension View {
    /// Reports this row's frame to the enclosing ``GalleryAnchoredList``.
    func galleryRowAnchor(_ id: String) -> some View {
        modifier(GalleryRowAnchor(id: id))
    }
}

private struct GalleryRowAnchor: ViewModifier {
    @Environment(\.galleryRowAnchorTracker) private var tracker
    let id: String

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .global)
            } action: { frame in
                tracker?.updateRow(id, frame: frame)
            }
            // A row scrolled out of the list stops reporting frames, so its last one must not count.
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                tracker?.updateRow(id, isVisible: isVisible)
            }
    }
}

private extension EnvironmentValues {
    @Entry var galleryRowAnchorTracker: GalleryRowAnchorTracker?
}

/// Row frames stay unobserved, so scrolling only invalidates views when the visible gallery changes.
@MainActor @Observable
final class GalleryRowAnchorTracker {
    private enum Phase {
        /// The list is rebuilding around this anchor and has not shown rows yet.
        case awaiting(String)
        /// The anchor is scrolling to the top; once it arrives, its frame decides whether a bar covers it.
        case restoring(String)
        case tracking
    }

    /// The gallery a person currently sees first.
    private(set) var visibleID: String?
    /// A restored gallery a bar still covers.
    private(set) var revealID: String?
    @ObservationIgnored private var phase: Phase
    @ObservationIgnored private var rowFrames = [String: CGRect]()
    @ObservationIgnored private var visibleRows = Set<String>()
    @ObservationIgnored private var clearArea = CGRect.null

    init(restoring id: String?) {
        phase = id.map(Phase.awaiting) ?? .tracking
    }

    /// Returns the anchor to scroll to the top once the rebuilt list has rows, at most once.
    func beginRestoration(availableIDs: [String]) -> String? {
        guard case .awaiting(let id) = phase else { return nil }
        guard availableIDs.contains(id) else {
            phase = .tracking
            reconcile()
            return nil
        }
        phase = .restoring(id)
        return id
    }

    func updateClearArea(_ area: CGRect) {
        clearArea = area
        reconcile()
    }

    func updateRow(_ id: String, frame: CGRect) {
        rowFrames[id] = frame
        reconcile()
    }

    func updateRow(_ id: String, isVisible: Bool) {
        if isVisible {
            visibleRows.insert(id)
        } else {
            visibleRows.remove(id)
            rowFrames[id] = nil
        }
        reconcile()
    }

    /// Resumes tracking when the anchor cannot reach the top, for example near the end of the list.
    func endRestoration() {
        guard case .restoring = phase else { return }
        phase = .tracking
        reconcile()
    }

    private func reconcile() {
        guard !clearArea.isNull, !clearArea.isEmpty else { return }
        let frames = rowFrames.filter({ visibleRows.contains($0.key) })
        switch phase {
        case .awaiting:
            return
        case .restoring(let id):
            // A row still lower than its own half height predates the scroll, so wait for it to arrive.
            guard let frame = frames[id], frame.minY < clearArea.minY + frame.height / 2 else { return }
            phase = .tracking
            if !GalleryScrollAnchor.isUncovered(rowFrame: frame, clearArea: clearArea) {
                revealID = id
                return
            }
        case .tracking:
            break
        }
        let id = GalleryScrollAnchor.topVisibleID(rowFrames: frames, clearArea: clearArea)
        if let id, id != visibleID {
            visibleID = id
        }
    }
}
