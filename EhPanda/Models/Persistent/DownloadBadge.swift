//
//  DownloadBadge.swift
//  EhPanda
//

enum DownloadBadge: Equatable {
    case none
    case queued
    case downloading(Int, Int)
    case paused(Int, Int)
    case partial(Int, Int)
    case downloaded
    case failed
    case updateAvailable
    case missingFiles
}
