//
//  DownloadProgress.swift
//  EhPanda
//

struct DownloadProgress: Equatable, Sendable {
    let completedPageCount: Int
    let pageCount: Int

    var displayPageCount: Int {
        max(pageCount, 1)
    }
    var displayCompletedPageCount: Int {
        min(max(completedPageCount, 0), displayPageCount)
    }

    var fraction: Double {
        Double(displayCompletedPageCount) / Double(displayPageCount)
    }
}
