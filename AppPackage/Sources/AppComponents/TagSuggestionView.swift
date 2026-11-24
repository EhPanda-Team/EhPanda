public import AppModels
import AppTools
import Kingfisher
import Observation
import Resources
import SFSafeSymbols
public import SwiftUI
import TagTranslationFeature

/// Tag suggestions for a `searchSuggestions` closure.
///
/// The system shows suggestions either in a menu attached to the search field or inline with the
/// content, choosing by the room around the field, so each view reads that placement rather than
/// the device. A menu row is a plain completion the system applies; inline, a count heads the rows
/// and each row completes the keyword itself.
public struct TagSuggestionView: View {
    /// Where the keyword being completed is typed.
    public enum Source {
        /// A search field: the typed text is tidied (runs of spaces, full-width colons) as it changes.
        case searchField
        /// A multi-line text field in a form: the text is never rewritten while typing, which would cancel a
        /// marked (CJK composition) range and move the cursor, and the suggestion rows stay out of the way until
        /// there is something to suggest.
        case multilineField
        /// One tag in a form (My Tags' Add Tag): the text is never rewritten while typing, and a chosen suggestion
        /// replaces it with the tag as the site keeps it, `namespace:tag` (design approved 2026-11-22).
        case tagName
    }

    @Environment(\.searchSuggestionsPlacement) private var searchSuggestionsPlacement
    @Binding private var keyword: String
    private let translations: [String: TagTranslation]
    private let showsImages: Bool
    private let isEnabled: Bool
    private let source: Source

    @State private var translationHandler = TagTranslationHandler()

    public init(
        keyword: Binding<String>, translations: [String: TagTranslation], showsImages: Bool, isEnabled: Bool,
        source: Source = .searchField
    ) {
        _keyword = keyword
        self.translations = translations
        self.showsImages = showsImages
        self.isEnabled = isEnabled
        self.source = source
    }

    public var body: some View {
        if isEnabled {
            if searchSuggestionsPlacement != .menu, source == .searchField || !translationHandler.suggestions.isEmpty {
                Text(.matchesCount(count: translationHandler.suggestions.count))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            let suggestions = translationHandler.suggestions
            ForEach(suggestions.prefix(min(suggestions.count, 10))) { suggestion in
                SuggestionCell(
                    suggestion: suggestion,
                    showsImages: showsImages,
                    action: { complete(with: suggestion) }
                )
            }
            .onChange(of: keyword) {
                switch source {
                case .searchField:
                    translationHandler.analyze(text: &keyword, translations: translations)
                case .multilineField, .tagName:
                    translationHandler.analyze(readingText: keyword, translations: translations)
                }
            }
        }
    }

    private func complete(with suggestion: TagSuggestion) {
        switch source {
        case .searchField, .multilineField:
            translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword)
        case .tagName:
            keyword = "\(suggestion.tag.namespace.rawValue):\(suggestion.tag.key)"
        }
    }
}

// MARK: SuggestionCell
private struct SuggestionCell: View {
    @Environment(\.searchSuggestionsPlacement) private var searchSuggestionsPlacement
    private let suggestion: TagSuggestion
    private let showsImages: Bool
    private let action: () -> Void

    init(suggestion: TagSuggestion, showsImages: Bool, action: @escaping () -> Void) {
        self.suggestion = suggestion
        self.showsImages = showsImages
        self.action = action
    }

    private var displayValue: String {
        let value = suggestion.displayValue
        return showsImages ? value : value.emojisRipped
    }

    // Two-line label for the search-completion suggestion, built as an `AttributedString` rather
    // than an interpolated `Text("\(…)\n\(…)")` so Xcode does not extract a "%@\n%@" catalog key.
    // Markdown is parsed inline (matching `Text(_ key: LocalizedStringKey)` above) since the tag
    // strings are dynamic content, not localization keys.
    private var searchCompletionLabel: AttributedString {
        var label = Self.markdown(displayValue)
        label.append(AttributedString("\n"))
        label.append(Self.markdown(suggestion.displayKey))
        return label
    }
    private static func markdown(_ string: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: string,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            // Markdown styling is optional presentation enrichment; malformed input renders literally.
            return AttributedString(string)
        }
    }

    var body: some View {
        if searchSuggestionsPlacement != .menu {
            // A real `Button`, so the row is a named, activatable control for VoiceOver and Voice
            // Control; `.unhighlighted` keeps the designed row look. Its two texts name it, so the glyphs are
            // decoration: the search symbol restates the row's purpose and the photo symbol only
            // reserves the tag image's space.
            Button(action: action) {
                HStack(spacing: 20) {
                    Image(systemSymbol: .magnifyingglass)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            Text(displayValue.localizedKey)

                            if let imageURL = suggestion.tag.valueImageURL, showsImages {
                                Image(systemSymbol: .photo)
                                    .opacity(0)
                                    .overlay {
                                        KFImage(imageURL)
                                            .resizable()
                                            .scaledToFit()
                                    }
                                    .accessibilityHidden(true)
                            }
                        }
                        .font(.callout)
                        .lineLimit(1)

                        Text(suggestion.displayKey.localizedKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.unhighlighted)
            .interactiveHover(.highlight, in: .rect(cornerRadius: 10, style: .continuous))
        } else {
            Text(searchCompletionLabel)
                .searchCompletion(
                    TagTranslationHandler.searchPrefix(of: suggestion.originalKeyword) + suggestion.tag.searchKeyword
                )
        }
    }
}

// MARK: TagTranslationHandler
@Observable
@MainActor
final class TagTranslationHandler {
    var suggestions = [TagSuggestion]()

    /// The text as the suggestions read it: runs of spaces collapsed and the full-width colon typed as a colon.
    static func normalized(_ text: String) -> String {
        text.replacing(/[ ]{2,}/, with: " ")
            .replacing("：", with: ":")
    }

    /// Suggests from `text` and writes the normalised text back, for a plain search field.
    func analyze(text: inout String, translations: [String: TagTranslation]) {
        text = Self.normalized(text)
        analyze(readingText: text, translations: translations)
    }

    /// Suggests from `text` without touching it. A multi-line text field must not have its text rewritten
    /// while the user types: replacing the bound text under a marked (CJK composition) range cancels or
    /// corrupts the composition and moves the cursor. Nothing is lost by leaving the text alone, because
    /// `autoComplete` normalises it when a suggestion is chosen.
    func analyze(readingText text: String, translations: [String: TagTranslation]) {
        let keyword = Self.normalized(text)
        let keywords = keyword.matches(of: /\S+:".+?"|".+?"|\S+:\S+|\S+/)
            .map({ String($0.output) })
        var result = [TagSuggestion]()
        var existingWords = Set<String>()
        let lastCompletedTagIndex = keywords.lastIndex(where: { ["\"", "$"].contains($0.last) })
        for index in (lastCompletedTagIndex ?? 0)..<keywords.count {
            let keywordList = keywords[index...]
            if !keywordList.isEmpty {
                let originalKeyword = keywordList.joined(separator: " ")
                // E-Hentai's `~tag` (or) and `-tag` (exclude) prefixes are not part of the tag, so they
                // are left out of the matching and put back by `autoComplete`.
                let matchingKeyword = String(originalKeyword.dropFirst(Self.searchPrefix(of: originalKeyword).count))
                getSuggestions(
                    translations: translations, keyword: matchingKeyword, originalKeyword: originalKeyword
                ).forEach {
                    if !existingWords.contains($0.tag.searchKeyword) {
                        existingWords.insert($0.tag.searchKeyword)
                        result.append($0)
                    }
                }
            }
        }
        suggestions = result
    }
    func autoComplete(suggestion: TagSuggestion, keyword: inout String) {
        // The suggestion was matched on normalised text, so its length is only a valid cut on that text.
        keyword = Self.normalized(keyword)
        let endIndex = keyword.index(keyword.endIndex, offsetBy: 0 - suggestion.originalKeyword.count)
        keyword = .init(keyword[keyword.startIndex..<endIndex])
            + Self.searchPrefix(of: suggestion.originalKeyword) + suggestion.tag.searchKeyword + " "
    }
    /// The `~` / `-` operators a search term starts with (none for a plain term).
    static func searchPrefix(of term: String) -> Substring {
        term.prefix(while: { $0 == "~" || $0 == "-" })
    }
    private func getSuggestions(
        translations: [String: TagTranslation],
        keyword: String,
        originalKeyword: String
    ) -> [TagSuggestion] {
        var keyword = keyword
        var namespace: String?

        if let colon = keyword.firstIndex(of: ":") {
            let key = String(keyword[keyword.startIndex..<colon])
            if let match = TagNamespace.allCases.first(where: {
                $0.rawValue.caseInsensitiveEqualsTo(key) || $0.abbreviation?.caseInsensitiveEqualsTo(key) == true
            }) {
                namespace = match.rawValue
                keyword = .init(keyword[keyword.index(colon, offsetBy: 1)..<keyword.endIndex])
            }
        }

        var translations = translations
        if let namespace = namespace {
            translations = translations.filter({ $0.value.namespace.rawValue == namespace })
        }
        if namespace != nil && keyword.isEmpty {
            // Returns suggestion based on namespace only
            return translations
                .map {
                    .init(
                        tag: $0.value, weight: 0, keyRange: nil, valueRange: nil,
                        originalKeyword: originalKeyword, matchesNamespace: true
                    )
                }
        } else {
            // Returns suggestion based on namespace and keyword
            return translations
                .map {
                    $0.value.getSuggestion(
                        keyword: keyword,
                        originalKeyword: originalKeyword,
                        matchesNamespace: namespace != nil
                    )
                }
                .filter({ $0.weight > 0 })
                .sorted(by: { $0.weight > $1.weight })
        }
    }
}
