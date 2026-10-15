/// Reconciles a visible gallery when refresh or filtering changes the collection.
public enum GalleryScrollAnchor {
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
}
