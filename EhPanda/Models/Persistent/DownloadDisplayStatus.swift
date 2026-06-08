//
//  DownloadDisplayStatus.swift
//  EhPanda
//

enum DownloadDisplayStatus: Int, Equatable, CaseIterable, Sendable {
    case active
    case queued
    case updateAvailable
    case error
    case inactive
    case completed
}
