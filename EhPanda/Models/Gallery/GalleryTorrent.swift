//
//  GalleryTorrent.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
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
    let torrentURL: String
}

extension GalleryTorrent: DateFormattable {
    var originalDate: Date {
        postedDate
    }
    var magnetURL: String {
        "magnet:?xt=urn:btih:\(hash)"
    }
}
