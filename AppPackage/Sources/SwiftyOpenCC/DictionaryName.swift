extension ChineseConverter {
    /// The bundled OpenCC dictionaries consumed by EhPanda's traditionalization paths.
    /// The raw value is the `.ocd2` resource's base file name.
    enum DictionaryName: String {
        case stCharacters = "STCharacters"
        case stPhrases = "STPhrases"
        case twPhrases = "TWPhrases"
        case twVariants = "TWVariants"
        case hkVariants = "HKVariants"
    }
}

extension ChineseConverter.Options {
    /// Segmentation dictionary for the current options. EhPanda only traditionalizes, so
    /// segmentation is always phrase-level Simplified→Traditional (`STPhrases`).
    var segmentationDictName: ChineseConverter.DictionaryName { .stPhrases }

    /// The ordered conversion chain for the current options. Each inner array is applied as
    /// one conversion step (grouped when it has more than one dictionary), reproducing
    /// OpenCC's `s2t` (default), `s2hk` (Hong Kong), and `s2twp` (Taiwan idiom) pipelines.
    var conversionChain: [[ChineseConverter.DictionaryName]] {
        var result: [[ChineseConverter.DictionaryName]] = [[.stPhrases, .stCharacters]]
        if contains(.twIdiom) {
            result.append([.twPhrases])
        }
        if contains(.hkStandard) {
            result.append([.hkVariants])
        } else if contains(.twStandard) {
            result.append([.twVariants])
        }
        return result
    }
}
