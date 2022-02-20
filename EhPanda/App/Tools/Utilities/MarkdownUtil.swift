//
//  MarkdownUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/20.
//

import Markdown

struct MarkdownUtil {
    static func ripImage(string: String) -> String? {
        var imageDeleter = ImageDeleter()
        if let document = imageDeleter.visit(Document(parsing: string)) as? Document {
            return document.format()
        }
        return nil
    }
    static func parseImage(string: String) -> String? {
        var imageParser = ImageParser()
        imageParser.visit(Document(parsing: string))
        return imageParser.images.first?.source
    }
}

private struct ImageDeleter: MarkupRewriter {
    mutating func visitImage(_ image: Image) -> Markup? { nil }
}
private struct ImageParser: MarkupWalker {
    var images = [Image]()

    mutating func visitImage(_ image: Image) {
        images.append(image)
        descendInto(image)
    }
}
