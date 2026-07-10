import AppModels
import Foundation
import MarkdownExt

extension TagTranslation {
    public var displayValue: String {
        valuePlainText ?? value
    }

    public var valuePlainText: String? {
        MarkdownUtil.parseTexts(markdown: value).first
    }
    public var valueImageURL: URL? {
        MarkdownUtil.parseImages(markdown: value).first
    }
    public var descriptionPlainText: String? {
        if let description = description {
            return MarkdownUtil.parseTexts(markdown: description.replacingOccurrences(of: "`", with: " ")).joined()
        }
        return nil
    }
    public var descriptionImageURLs: [URL] {
        if let description = description {
            return MarkdownUtil.parseImages(markdown: description)
        }
        return .init()
    }
    public var links: [URL] {
        if let linksString = linksString {
            return MarkdownUtil.parseLinks(markdown: linksString)
        }
        return .init()
    }
}
