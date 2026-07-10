import copencc

/// Errors surfaced by the internal `copencc` bridge while loading a dictionary or
/// converting text. Each case maps one-to-one to a `CCErrorCode` reported by the engine.
public enum ConversionError: Error, Equatable {
    /// A required `.ocd2` dictionary could not be located.
    case fileNotFound
    /// A dictionary file was present but is not a valid serialized dictionary.
    case invalidFormat
    /// A text dictionary source was malformed.
    case invalidTextDictionary
    /// Input or dictionary data was not valid UTF-8.
    case invalidUTF8
    /// An unclassified engine failure.
    case unknown

    init(_ code: CCErrorCode) {
        switch code {
        case .fileNotFound: self = .fileNotFound
        case .invalidFormat: self = .invalidFormat
        case .invalidTextDictionary: self = .invalidTextDictionary
        case .invalidUTF8: self = .invalidUTF8
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}
