extension Array where Element == Gallery {
    /// Appends a fetched page's galleries that are not listed yet, in the page's order, and returns how many that was.
    ///
    /// The site's lists shift while they are read, so a page can repeat galleries an earlier page already gave. Those
    /// are skipped. The count is what tells a list whether the page added anything at all: a page that added nothing
    /// leaves the list's last gallery where it was, so no scroll can ask for the next page, and the list has to fetch
    /// it at once instead (`PageNumber.advances(from:)`).
    public mutating func appendNew(_ galleries: [Gallery]) -> Int {
        var listed = Set(map(\.gid))
        let new = galleries.filter({ listed.insert($0.gid).inserted })
        append(contentsOf: new)
        return new.count
    }
}
