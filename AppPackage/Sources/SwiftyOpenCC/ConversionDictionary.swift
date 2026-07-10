import copencc

/// A loaded OpenCC dictionary — either a single marisa-backed `.ocd2` file or a group
/// that applies several dictionaries as one step — owning its underlying `copencc` handle.
///
/// The handle is released exactly once on `deinit`. A grouped dictionary retains its
/// members so they outlive the group, and the engine keeps its own reference to any
/// dictionary handed to a converter, so releasing a member here never invalidates a
/// converter that is still using it.
final class ConversionDictionary {
    /// Retained sub-dictionaries for a grouped dictionary; empty for a leaf dictionary.
    private let members: [ConversionDictionary]

    /// The opaque `copencc` dictionary handle.
    let dict: CCDictRef

    /// Loads a single marisa-backed `.ocd2` dictionary from `path`.
    /// - Throws: ``ConversionError`` describing the engine failure if the file cannot be opened.
    init(path: String) throws {
        guard let dict = CCDictCreateMarisaWithPath(path) else {
            throw ConversionError(CCLastErrorCode())
        }
        self.members = []
        self.dict = dict
    }

    /// Builds a composite dictionary from an ordered `group`, retaining its members.
    init(group: [ConversionDictionary]) {
        var rawGroup = group.map(\.dict)
        self.members = group
        self.dict = CCDictCreateWithGroup(&rawGroup, rawGroup.count)
    }

    deinit {
        CCDictDestroy(dict)
    }
}
