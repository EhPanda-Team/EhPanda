//
//  DownloadRequestOptions.swift
//  EhPanda
//

struct DownloadRequestOptions: Equatable, Sendable {
    var threadLimit = 1
    var allowCellular = true
    var autoRetryFailedPages = true

    var workerCount: Int {
        threadLimit
    }
}
