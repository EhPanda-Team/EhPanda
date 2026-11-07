@testable import DetailFeature
import Foundation
import Testing

/// The posting filter's matching rules (DD-04, research §5.3) over a synthetic list, and the bundled list's shape.
///
/// The rules are proved on invented terms so no test spells out a real slur; the bundled list is checked only for
/// what it must be (six non-empty language groups, nothing else, every entry stable under normalisation).
struct CommentFilterTests {
    private static let synthetic = CommentFilterTerms(groups: [
        "en": ["Slur", "go away now"],
        "ja": ["禁止語"],
        "ko": ["금지어"]
    ])

    // MARK: Latin terms: word boundaries, case, width and diacritics

    @Test(arguments: [
        "a SLUR here",
        "slur",
        "Slur!",
        "(slur)",
        "ｓｌｕｒ",
        "a ｓｌｕｒ here",
        "slür",
        "SLÚR at the start",
        "ends with slur"
    ])
    func aLatinTermMatchesWhateverItsCaseWidthOrAccents(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.synthetic))
    }

    @Test(arguments: ["slurry", "a slurp", "unslur", "slurs", "s l u r", "sl-ur"])
    func aLatinTermDoesNotMatchInsideALongerWord(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.synthetic) == false)
    }

    @Test(arguments: ["go away now", "GO   away\n now", "please go away now!", "ｇｏ ａｗａｙ ｎｏｗ"])
    func aPhraseMatchesAcrossAnyRunOfWhitespace(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.synthetic))
    }

    @Test
    func aPhraseDoesNotMatchWhenAWordIsMissing() {
        #expect(CommentFilter.matches("go away", terms: Self.synthetic) == false)
    }

    @Test
    func aLatinTermNextToCJKTextStillMatches() {
        #expect(CommentFilter.matches("这是slur吧", terms: Self.synthetic))
    }

    // MARK: CJK and Hangul terms: substrings

    @Test(arguments: ["これは禁止語です", "禁止語", "「禁止語」だ"])
    func aCJKTermMatchesInsideASentenceWithoutSpaces(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.synthetic))
    }

    @Test(arguments: ["금지어가 있다", "금지어를", "이건금지어야"])
    func aHangulTermMatchesWithAParticleAttached(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.synthetic))
    }

    @Test
    func aCJKTermDoesNotMatchWhenACharacterIsMissing() {
        #expect(CommentFilter.matches("禁止です", terms: Self.synthetic) == false)
        #expect(CommentFilter.matches("금지가", terms: Self.synthetic) == false)
    }

    // MARK: Text that never matches

    @Test(arguments: ["", " ", "\n\t  \n", "\u{3000}"])
    func emptyOrWhitespaceTextNeverMatches(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.synthetic) == false)
    }

    @Test
    func anOrdinaryCommentDoesNotMatch() {
        #expect(CommentFilter.matches("Thanks for the upload, great translation.", terms: Self.synthetic) == false)
    }

    @Test
    func anEmptyListNeverMatches() {
        #expect(CommentFilter.matches("slur 禁止語 금지어", terms: CommentFilterTerms(groups: [:])) == false)
    }

    @Test
    func aBlankTermInTheListNeverMatchesEverything() {
        let terms = CommentFilterTerms(groups: ["en": ["", "   "]])
        #expect(CommentFilter.matches("anything at all", terms: terms) == false)
    }

    // MARK: Normalisation

    @Test(arguments: ["Slür", "ｓｌｕｒ", "  GO \n AWAY  ", "禁止語", "금지어", "ガイジ", "ﾃｽﾄ", "I’ll"])
    func normalisationIsIdempotent(text: String) {
        let once = CommentFilter.normalized(text)
        #expect(CommentFilter.normalized(once) == once)
    }

    @Test
    func aTypographicApostropheMatchesAPlainOne() {
        let terms = CommentFilterTerms(groups: ["en": ["you'll see"]])
        #expect(CommentFilter.matches("You’ll see", terms: terms))
    }

    // MARK: The bundled list

    @Test
    func theBundledListLoadsWithTheSixLanguageGroupsAndNoOther() throws {
        let terms = try CommentFilterTerms.load(from: CommentFilterTerms.bundle)

        #expect(Set(terms.groups.keys) == ["de", "en", "ja", "ko", "zh-Hans", "zh-Hant"])
        for (language, entries) in terms.groups {
            #expect(entries.isEmpty == false, "The \(language) group is empty.")
        }
        #expect(CommentFilterTerms.bundled == terms)
    }

    @Test
    func everyBundledEntryNormalisesIdempotentlyAndOnce() throws {
        let terms = try CommentFilterTerms.load(from: CommentFilterTerms.bundle)

        for (language, entries) in terms.groups {
            for entry in entries {
                let once = CommentFilter.normalized(entry)
                #expect(once.isEmpty == false, "\(language) has a blank entry.")
                #expect(CommentFilter.normalized(once) == once, "\(language) entry is not idempotent: \(entry)")
            }
            let normalized = entries.map(CommentFilter.normalized)
            #expect(Set(normalized).count == entries.count, "The \(language) group repeats an entry.")
        }
    }

    @Test
    func theBundledListMatchesEachOfItsOwnEntries() throws {
        let terms = try CommentFilterTerms.load(from: CommentFilterTerms.bundle)

        for entries in terms.groups.values {
            for entry in entries {
                #expect(CommentFilter.matches("» \(entry) «", terms: terms), "No match for its own entry: \(entry)")
            }
        }
    }

    @Test
    func theBundledListLeavesOrdinaryCommentsAlone() {
        let comments = [
            "Thanks for the upload!",
            "Great translation, looking forward to the next chapter.",
            "Danke für den Upload, tolle Übersetzung.",
            "アップロードありがとうございます。",
            "업로드 감사합니다. 번역 최고예요.",
            "感谢上传，翻译得很好。",
            "感謝上傳，翻譯得很好。",
            // Everyday words that contain a shorter insult; the list keeps only the longer, unambiguous forms.
            "ガイジンの主人公が好き。",
            "주인공이 죽어라 노력하는 장면이 좋아요.",
            "가방을 뒤져라, 열쇠가 있을 거야.",
            "주인공이 자살해서 너무 슬펐어요.",
            // Ordinary words around a two-character term (18-UAT test 11): "I never believed it before", in both
            // scripts, and the neutral Japanese words for a disabled child and for a child victim.
            "我过去死活不信。",
            "我過去死活不信。",
            "障害児の支援についての話です。",
            "被害児童を守る話。"
        ]
        for comment in comments {
            #expect(CommentFilter.matches(comment, terms: .bundled) == false, "False positive: \(comment)")
        }
    }
}
