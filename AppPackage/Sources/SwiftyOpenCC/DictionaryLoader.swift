import Foundation

extension ChineseConverter {
    /// Resolves bundled `.ocd2` dictionaries and assembles the segmentation dictionary and
    /// conversion chain for a set of options, reusing loaded dictionaries via ``DictionaryStore``.
    struct DictionaryLoader {
        private static let subdirectory = "Dictionary"

        private let bundle: Bundle
        private let store: DictionaryStore

        init(bundle: Bundle, store: DictionaryStore = .shared) {
            self.bundle = bundle
            self.store = store
        }

        private func dictionary(_ name: DictionaryName) throws -> ConversionDictionary {
            guard let path = bundle.path(
                forResource: name.rawValue, ofType: "ocd2", inDirectory: Self.subdirectory
            ) else {
                throw ConversionError.fileNotFound
            }
            return try store.dictionary(atPath: path)
        }

        func segmentation(options: Options) throws -> ConversionDictionary {
            try dictionary(options.segmentationDictName)
        }

        func conversionChain(options: Options) throws -> [ConversionDictionary] {
            try options.conversionChain.compactMap { names in
                switch names.count {
                case 0:
                    return nil
                case 1:
                    guard let first = names.first else { return nil }
                    return try dictionary(first)
                default:
                    let dicts = try names.map(dictionary)
                    return ConversionDictionary(group: dicts)
                }
            }
        }
    }
}
