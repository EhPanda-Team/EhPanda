public import CoreGraphics

/// Reconciles a visible gallery when refresh or filtering changes the collection.
public enum GalleryScrollAnchor {
    /// How far a row may sit past an edge of the clear area before it counts as covered.
    static let edgeTolerance: CGFloat = 1

    public static func retaining(_ id: String?, previousIDs: [String], currentIDs: [String]) -> String? {
        guard let id else { return nil }
        guard !currentIDs.contains(id) else { return id }
        guard let previousIndex = previousIDs.firstIndex(of: id) else { return currentIDs.first }
        let remaining = Set(currentIDs)
        return previousIDs.enumerated()
            .filter({ remaining.contains($0.element) })
            .min(by: { abs($0.offset - previousIndex) < abs($1.offset - previousIndex) })?
            .element ?? currentIDs.first
    }

    /// The gallery a person sees first: the highest row whose center lies inside the clear area,
    /// the list's frame minus the navigation and tab bars. A row mostly covered by a bar never qualifies.
    public static func topVisibleID(rowFrames: [String: CGRect], clearArea: CGRect) -> String? {
        rowFrames
            .filter({ $0.value.midY >= clearArea.minY && $0.value.midY < clearArea.maxY })
            .min(by: { lhs, rhs in
                lhs.value.minY == rhs.value.minY ? lhs.key < rhs.key : lhs.value.minY < rhs.value.minY
            })?
            .key
    }

    /// Whether a restored row is complete inside the clear area, or still needs the list to reveal it.
    public static func isUncovered(rowFrame: CGRect, clearArea: CGRect) -> Bool {
        rowFrame.minY >= clearArea.minY - edgeTolerance && rowFrame.maxY <= clearArea.maxY + edgeTolerance
    }
}
