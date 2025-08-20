//
//  GalleryTorrent.swift
//  EhPanda
//

import Foundation

struct GalleryTorrent: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    let postedDate: Date
    let fileSize: String
    let seedCount: Int
    let peerCount: Int
    let downloadCount: Int
    let uploader: String
    let fileName: String
    let hash: String
    let torrentURL: URL
}

extension GalleryTorrent: DateFormattable {
    var originalDate: Date {
        postedDate
    }
    var magnetURL: String {
        "magnet:?xt=urn:btih:\(hash)"
    }
}
