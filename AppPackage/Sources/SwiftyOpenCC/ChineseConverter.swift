import Foundation
import copencc

/// Converts Simplified Chinese to Traditional Chinese, optionally toward the Hong Kong or
/// Taiwan regional standard, backed by the internal `copencc` OpenCC engine.
///
/// An instance compiles an immutable conversion pipeline from bundled `.ocd2` dictionaries
/// and can be reused for repeated conversions. EhPanda constructs a converter per
/// translation-table build, so the type deliberately exposes only the traditionalization
/// options the app needs rather than OpenCC's full option matrix (see D-02).
public final class ChineseConverter {
    /// Conversion options. EhPanda only traditionalizes, optionally toward a regional standard.
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Convert Simplified Chinese to Traditional Chinese (the default behavior).
        public static let traditionalize = Options(rawValue: 1 << 0)
        /// Apply the Hong Kong regional standard.
        public static let hkStandard = Options(rawValue: 1 << 1)
        /// Apply the Taiwan regional standard.
        public static let twStandard = Options(rawValue: 1 << 2)
        /// Apply Taiwanese idiom conversion.
        public static let twIdiom = Options(rawValue: 1 << 3)
    }

    // Retained for the converter's lifetime. The engine keeps its own references to these
    // dictionaries, so retaining them here simply keeps the Swift-side handles valid and
    // matches the converter's ownership.
    private let segmentation: ConversionDictionary
    private let chain: [ConversionDictionary]

    private let converter: CCConverterRef

    /// Creates a converter for `options`, loading dictionaries from the module bundle.
    /// - Throws: ``ConversionError`` if a required dictionary is missing or invalid.
    public convenience init(options: Options) throws {
        try self.init(loader: DictionaryLoader(bundle: .module), options: options)
    }

    init(loader: DictionaryLoader, options: Options) throws {
        let segmentation = try loader.segmentation(options: options)
        let chain = try loader.conversionChain(options: options)
        var rawChain = chain.map(\.dict)
        self.segmentation = segmentation
        self.chain = chain
        self.converter = CCConverterCreate("EhPanda", segmentation.dict, &rawChain, rawChain.count)
    }

    deinit {
        CCConverterDestroy(converter)
    }

    /// Returns `text` converted using the receiver's options. If the bridge fails to produce
    /// a converted string, the original `text` is returned unchanged so conversion never
    /// crashes or silently drops content.
    public func convert(_ text: String) -> String {
        guard let converted = CCConverterCreateConvertedStringFromString(converter, text) else {
            return text
        }
        defer { STLStringDestroy(converted) }
        guard let result = String(validatingCString: STLStringGetUTF8String(converted)) else {
            return text
        }
        return result
    }
}
