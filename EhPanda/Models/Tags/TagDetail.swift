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
    let links: [URL]

    init(title: String, description: String, imageURLs: [URL], links: [URL]) {
        self.title = title
        self.description = description
        self.imageURLs = imageURLs
        self.links = links
    }
}
