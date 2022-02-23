//
//  TagDetail.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/23.
//

import Foundation

struct TagDetail: Equatable {
    let title: String
    let description: String
    let imageURLs: [URL]
    let externalLinks: [ExternalLink]

    init(title: String, description: String, imageURLs: [URL], links: [URL]) {
        self.title = title
        self.description = description
        self.imageURLs = imageURLs
        externalLinks = links.compactMap(ExternalLink.init)
    }
}

enum ExternalLink: Equatable, Identifiable {
    case other(URL)
    case pixiv(URL)
    case patreon(URL)
    case twitter(URL)
    case wikipedia(URL)
    case niconicoSeiga(URL)

    init?(url: URL) {
        guard let host = url.host else { return nil }
        if host.contains("www.pixiv.net") {
            self = .pixiv(url)
        } else if host.contains("www.patreon.com") {
            self = .patreon(url)
        } else if host.contains("twitter.com") {
            self = .twitter(url)
        } else if host.contains("wikipedia.org") {
            self = .wikipedia(url)
        } else if host.contains("seiga.nicovideo.jp") {
            self = .niconicoSeiga(url)
        } else {
            self = .other(url)
        }
    }
}

extension ExternalLink {
    var id: String {
        url.absoluteString
    }

    var url: URL {
        switch self {
        case .pixiv(let url), .patreon(let url), .twitter(let url),
                .wikipedia(let url), .niconicoSeiga(let url), .other(let url):
            return url
        }
    }
}
