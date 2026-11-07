@testable import DetailFeature
import Foundation
import Testing

/// The posting filter's matching rules (DD-04, research §5.3) over a synthetic list, and the bundled list's shape.
///
/// The rules are proved on invented terms; the bundled list is checked for what it must be (six non-empty language
/// groups, nothing else, every entry stable under normalisation) and, for the short CJK terms with exception words,
/// against the ordinary and the insulting sentences the language review named.
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

    // MARK: Kana: dakuten kept, width folded

    private static let kana = CommentFilterTerms(groups: ["ja": ["ゲゴ語", "パピ語"]])

    /// A dakuten or handakuten tells two words apart (a slur and a manga title differ by one), so neither is folded.
    @Test(arguments: ["ケコ語", "ゲコ語", "ケゴ語", "げご語", "ハヒ語", "バビ語"])
    func aKanaTermDoesNotMatchWithoutItsDakuten(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.kana) == false)
    }

    /// Half-width kana write a dakuten as a separate mark after the base; it folds onto the base like a combining one.
    @Test(arguments: ["ゲゴ語", "ｹﾞｺﾞ語", "ケ\u{3099}コ\u{3099}語", "パピ語", "ﾊﾟﾋﾟ語", "これはｹﾞｺﾞ語だ"])
    func aKanaTermMatchesInFullOrHalfWidthWithItsDakuten(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.kana))
    }

    // MARK: Exception words

    /// An ordinary word that holds a term is listed as the term's exception: inside it the term does not count, but the
    /// term anywhere else in the same text still does.
    private static let withExceptions = CommentFilterTerms(
        groups: ["ja": ["禁止語"], "en": ["slur"]],
        exceptions: ["禁止語": ["非禁止語"], "slur": ["slur-free"]]
    )

    @Test(arguments: ["非禁止語です", "これは非禁止語", "非禁止語、非禁止語", "a slur-free comment"])
    func aTermInsideOneOfItsExceptionWordsDoesNotMatch(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.withExceptions) == false)
    }

    @Test(arguments: ["禁止語です", "非禁止語と禁止語", "禁止語の非禁止語", "slur-free, but a slur"])
    func aTermOutsideItsExceptionWordsStillMatches(text: String) {
        #expect(CommentFilter.matches(text, terms: Self.withExceptions))
    }

    @Test
    func anExceptionWordOfAnotherTermExcusesNothing() {
        let terms = CommentFilterTerms(groups: ["ja": ["禁止語", "別語"]], exceptions: ["別語": ["非禁止語"]])
        #expect(CommentFilter.matches("非禁止語です", terms: terms))
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

    @Test(arguments: ["Slür", "ｓｌｕｒ", "  GO \n AWAY  ", "禁止語", "금지어", "ガイジ", "ﾃｽﾄ", "ｶﾞｲｼﾞ", "I’ll"])
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

    /// The bundled exceptions only narrow listed terms: each word holds its term, which is in the list, and the term on
    /// its own, or beside the word, still matches.
    @Test
    func everyBundledExceptionHoldsAListedTermThatStillMatchesOutsideIt() throws {
        let terms = try CommentFilterTerms.load(from: CommentFilterTerms.bundle)
        let entries = Set(terms.groups.values.joined().map(CommentFilter.normalized))

        #expect(terms.exceptions.isEmpty == false)
        for (term, words) in terms.exceptions {
            #expect(entries.contains(CommentFilter.normalized(term)), "The exception's term is not listed: \(term)")
            for word in words {
                #expect(word.contains(term) && word != term, "\(word) does not hold \(term).")
                #expect(CommentFilter.matches(word, terms: terms) == false, "\(word) still matches.")
                #expect(CommentFilter.matches("\(word)，\(term)", terms: terms), "\(term) beside \(word) is missed.")
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
            // Everyday words that contain a shorter insult; the list keeps only the longer, unambiguous forms, or names
            // the everyday word as the term's exception ("foreigner" holds the katakana slur).
            "ガイジンの主人公が好き。",
            // A title one dakuten away from the slur, in katakana and in hiragana: kana keep their dakuten.
            "カイジ",
            "カイジの映画が好き。",
            "かいじ",
            // The slur is listed in katakana only (language review): its hiragana spelling also runs across the
            // subject particle が, as in "the hero gets bullied" and "it's not wrong".
            "がいじんの友達ができた。",
            "がいじ",
            "お前がいじかよ",
            "主人公がいじめられる。",
            "まちがいじゃない。",
            "주인공이 죽어라 노력하는 장면이 좋아요.",
            "가방을 뒤져라, 열쇠가 있을 거야.",
            "주인공이 자살해서 너무 슬펐어요.",
            // Ordinary words around a two-character term (18-UAT test 11, per the language review): "I never believed
            // it before" and "the past death toll" in both scripts, "died in the past" in Japanese, and the neutral
            // Japanese words for a disabled child, a child victim and a child offender.
            "我过去死活不信。",
            "我過去死活不信。",
            "过去死亡人数在下降。",
            "過去死亡人數在下降。",
            "過去死んだキャラが復活した。",
            "障害児の支援についての話です。",
            "被害児童を守る話。",
            "加害児童の心理描写が深い。"
        ]
        for comment in comments {
            #expect(CommentFilter.matches(comment, terms: .bundled) == false, "False positive: \(comment)")
        }
    }

    /// The language review's cases that must still raise the warning (18-UAT test 11): 去死 after 过 when no ordinary
    /// word follows it, as in "go over there and die", in both scripts; 害児 on its own; and ガイジ in full-width and
    /// half-width katakana.
    @Test(arguments: ["你过去死吧", "滚过去死", "你過去死吧", "滾過去死", "害児", "ガイジ", "お前ガイジかよ", "ｶﾞｲｼﾞ"])
    func theBundledListMatchesATermThatNoOrdinaryWordHolds(text: String) {
        #expect(CommentFilter.matches(text, terms: .bundled), "Missed: \(text)")
    }
}
