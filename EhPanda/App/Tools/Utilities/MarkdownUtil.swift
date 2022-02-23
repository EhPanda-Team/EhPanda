//
//  MarkdownUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/20.
//

import CasePaths
import CommonMark
import Foundation

struct MarkdownUtil {
    static func parseTexts(markdown: String) -> [String] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap((/Block.paragraph).extract)
            .flatMap(\.text)
            .compactMap((/Inline.text))
        ?? []
    }
    static func parseLinks(markdown: String) -> [URL] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap((/Block.paragraph).extract)
            .flatMap(\.text)
            .compactMap((/Inline.link))
            .compactMap(\.url)
        ?? []
    }
    static func parseImages(markdown: String) -> [URL] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap((/Block.paragraph).extract)
            .flatMap(\.text)
            .compactMap((/Inline.image))
            .compactMap { image in
                if image.url?.absoluteString.isValidURL == true {
                    return image.url
                } else if let title = image.title, title.isValidURL {
                    return .init(string: title)
                }
                return nil
            }
        ?? []
    }
}
