import SwiftUI

// Built in a closure because a stored property has no statement position for a `do`/`catch`.
// The nil contract is deliberate: link detection is optional presentation enrichment, so an
// unavailable detector leaves the text unlinked rather than failing the view.
private let linkDetector: NSDataDetector? = {
    do {
        return try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    } catch {
        return nil
    }
}()

/// A comment's text with its links tappable. `Text` lays out the author's styles and the links
/// together, so a link lands where it is drawn at any size, weight or slant.
struct LinkedText: View {
    private let text: AttributedString
    private let action: (URL) -> Void

    /// Links whatever the detector finds in `text`.
    init(text: AttributedString, action: @escaping (URL) -> Void) {
        self.text = Self.detectingLinks(in: text)
        self.action = action
    }

    /// Links the whole of `text` to `link`.
    init(text: AttributedString, link: URL, action: @escaping (URL) -> Void) {
        var text = text
        text.link = link
        self.text = text
        self.action = action
    }

    /// The URL ranges of `text`, from the same detector the view links by — so a caller listing a
    /// comment's links names exactly the runs this view makes tappable.
    nonisolated static func linkMatches(in text: String) -> [NSTextCheckingResult] {
        let wholeString = NSRange(location: 0, length: (text as NSString).length)
        return linkDetector?.matches(in: text, options: [], range: wholeString) ?? []
    }

    nonisolated static func detectingLinks(in text: AttributedString) -> AttributedString {
        let string = String(text.characters)
        var result = text
        for match in linkMatches(in: string) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: string),
                  let range = Range(stringRange, in: result)
            else { continue }
            result[range].link = url
        }
        return result
    }

    var body: some View {
        Text(text)
            .environment(\.openURL, OpenURLAction { url in
                action(url)
                return .handled
            })
    }
}
