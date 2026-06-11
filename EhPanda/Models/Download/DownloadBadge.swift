//
//  DownloadBadge.swift
//  EhPanda
//

struct DownloadBadge: Equatable, Sendable {
    let status: DownloadDisplayStatus
    let progress: DownloadProgress

    init(
        status: DownloadDisplayStatus,
        progress: DownloadProgress
    ) {
        self.status = status
        self.progress = progress
    }
}
