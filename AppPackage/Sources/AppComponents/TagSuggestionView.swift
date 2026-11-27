public import AppModels
import AppTools
import Kingfisher
import Observation
import Resources
import SFSafeSymbols
public import SwiftUI
import TagTranslationFeature

/// Tag suggestions for a `searchSuggestions` closure, or for one tag typed in a form.
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
    }

    /// What the rows complete.
    private enum Completion {
        /// A keyword, completed in place; nothing shows while `isEnabled` is off.
        case keyword(Binding<String>, source: Source, isEnabled: Bool)
        /// One tag in a form, which the host fills with the `namespace:tag` of the chosen row.
        case tag(String, siteSuggestions: [SiteTagSuggestion], choose: (String) -> Void)
    }

    @Environment(\.searchSuggestionsPlacement) private var searchSuggestionsPlacement
    private let completion: Completion
    private let translations: [String: TagTranslation]
    private let showsImages: Bool

    @State private var translationHandler = TagTranslationHandler()

    public init(
        keyword: Binding<String>, translations: [String: TagTranslation], showsImages: Bool, isEnabled: Bool,
        source: Source = .searchField
    ) {
        completion = .keyword(keyword, source: source, isEnabled: isEnabled)
        self.translations = translations
        self.showsImages = showsImages
    }

    /// One tag typed in a form, My Tags' Add Tag (design approved 2026-11-22; G-1 of quick 261126-wzg): the site's
    /// suggestions for `tag` first, as the host has them, then the matches in `translations` the site did not
    /// suggest, every row by its translated name when `translations` has one. Without translations the site's rows
    /// show alone, by their own names. `tag` is never rewritten while typing, and a chosen row hands `choose` the
    /// `namespace:tag` it puts in the field: for an alias, its canonical tag.
    public init(
        tag: String,
        siteSuggestions: [SiteTagSuggestion],
        translations: [String: TagTranslation],
        showsImages: Bool,
        choose: @escaping (String) -> Void
    ) {
        completion = .tag(tag, siteSuggestions: siteSuggestions, choose: choose)
        self.translations = translations
        self.showsImages = showsImages
    }

    public var body: some View {
        switch completion {
        case .keyword(let keyword, let source, let isEnabled):
            if isEnabled {
                keywordRows(keyword: keyword, source: source)
            }
        case .tag(let tag, let siteSuggestions, let choose):
            tagRows(tag: tag, siteSuggestions: siteSuggestions, choose: choose)
        }
    }

    @ViewBuilder
    private func keywordRows(keyword: Binding<String>, source: Source) -> some View {
        if searchSuggestionsPlacement != .menu, source == .searchField || !translationHandler.suggestions.isEmpty {
            Text(.matchesCount(count: translationHandler.suggestions.count))
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }

        let suggestions = translationHandler.suggestions
        ForEach(suggestions.prefix(min(suggestions.count, 10))) { suggestion in
            SuggestionCell(
                suggestion: suggestion,
                alias: nil,
                showsImages: showsImages,
                action: { translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword.wrappedValue) }
            )
        }
        .onChange(of: keyword.wrappedValue) {
            switch source {
            case .searchField:
                translationHandler.analyze(text: &keyword.wrappedValue, translations: translations)
            case .multilineField:
                translationHandler.analyze(readingText: keyword.wrappedValue, translations: translations)
            }
        }
    }

    @ViewBuilder
    private func tagRows(
        tag: String,
        siteSuggestions: [SiteTagSuggestion],
        choose: @escaping (String) -> Void
    ) -> some View {
        let rows = TagNameSuggestion.rows(
            site: siteSuggestions,
            translationMatches: translationHandler.suggestions,
            tag: tag,
            translations: translations
        )
        if searchSuggestionsPlacement != .menu, !rows.isEmpty {
            Text(.matchesCount(count: rows.count))
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }

        ForEach(rows.prefix(10)) { row in
            SuggestionCell(
                suggestion: row.suggestion,
                alias: row.alias,
                showsImages: showsImages,
                action: { choose(row.insertedName) }
            )
        }
        .onChange(of: tag) { _, newTag in
            translationHandler.analyze(readingText: newTag, translations: translations)
        }
    }
}

// MARK: SuggestionCell
private struct SuggestionCell: View {
    @Environment(\.searchSuggestionsPlacement) private var searchSuggestionsPlacement
    private let suggestion: TagSuggestion
    /// The alias the site found the tag through, as `namespace:tag`, named on a third line (G-1 of quick 261126-wzg).
    /// Only a form's tag rows have one, and they never show in a search field's menu.
    private let alias: String?
    private let showsImages: Bool
    private let action: () -> Void

    init(suggestion: TagSuggestion, alias: String?, showsImages: Bool, action: @escaping () -> Void) {
        self.suggestion = suggestion
        self.alias = alias
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

                        if let alias {
                            Text(.myTagsAlias(alias))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
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

// MARK: TagNameSuggestion
/// A row of the suggestions for one tag typed in a form (G-1 of quick 261126-wzg): one of the site's, or a match of
/// the local translations the site did not list.
struct TagNameSuggestion: Identifiable {
    enum RowID: Hashable {
        /// One of the site's, by the site's id of the suggested tag.
        case site(Int)
        /// A translation's match, by its `namespace:tag`.
        case translation(String)
    }

    let id: RowID
    /// What the row shows: the tag it puts in the field, by its translated name when the translations have one, with
    /// what the field's text matches in it highlighted.
    let suggestion: TagSuggestion
    /// The alias the site found the tag through, as `namespace:tag`; nil for a row that is no alias.
    let alias: String?
    /// The `namespace:tag` choosing the row puts in the field.
    let insertedName: String

    /// The site's suggestions in the site's order, then the translation matches in theirs, leaving out a match whose
    /// tag a site row already puts in the field. The site's rows stay as the site lists them, so an alias row and the
    /// row of its canonical tag both show, as on the site.
    static func rows(
        site: [SiteTagSuggestion],
        translationMatches: [TagSuggestion],
        tag: String,
        translations: [String: TagTranslation]
    ) -> [TagNameSuggestion] {
        let query = TagSuggestQuery(tag)
        let siteRows = site.map { suggestion in
            let inserted = suggestion.insertedTag
            let translation = translations[inserted.namespace.rawValue + inserted.name]
                ?? TagTranslation(namespace: inserted.namespace, key: inserted.name, value: "")
            return TagNameSuggestion(
                id: .site(suggestion.id),
                suggestion: translation.getSuggestion(
                    keyword: query?.term ?? "",
                    originalKeyword: tag,
                    matchesNamespace: query?.text.hasPrefix(inserted.namespace.rawValue + ":") == true
                ),
                alias: suggestion.canonical == nil ? nil : suggestion.tag.fullName,
                insertedName: inserted.fullName
            )
        }
        let siteNames = Set(siteRows.map(\.insertedName))
        let translationRows = translationMatches.compactMap { match -> TagNameSuggestion? in
            let name = match.tag.namespace.rawValue + ":" + match.tag.key
            guard !siteNames.contains(name) else { return nil }
            return TagNameSuggestion(id: .translation(name), suggestion: match, alias: nil, insertedName: name)
        }
        return siteRows + translationRows
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
