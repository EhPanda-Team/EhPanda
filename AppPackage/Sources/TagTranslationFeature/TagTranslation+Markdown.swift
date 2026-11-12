public import AppModels
public import Foundation
import MarkdownExt

extension TagTranslation {
    public var displayValue: String {
        let text = valuePlainText ?? value
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? key : text
    }

    public var detail: TagDetail? {
        let description = descriptionPlainText ?? ""
        var images = descriptionImageURLs
        if let image = valueImageURL, !images.contains(image) {
            images.insert(image, at: 0)
        }
        let links = links
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !images.isEmpty || !links.isEmpty else { return nil }
        return .init(title: displayValue, description: description, imageURLs: images, links: links)
    }

    public var valuePlainText: String? {
        MarkdownUtil.parseTexts(markdown: value).first
    }
    public var valueImageURL: URL? {
        MarkdownUtil.parseImages(markdown: value).first
    }
    public var descriptionPlainText: String? {
        if let description = description {
            return MarkdownUtil.parseTexts(markdown: description.replacing("`", with: " ")).joined()
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
