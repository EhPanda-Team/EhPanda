#if DEBUG
import Foundation

/// The capture scene one launch prepares, decoded from `EHPANDA_CAPTURE_CONFIGURATION`.
///
/// `purpose` decides which fixture schema the launch accepts, so a scene can only read the kind
/// of fixture it was configured for: the public regression export (17-01) or the real marketing
/// selection (17-03).
struct CaptureSceneConfiguration: Equatable, Sendable {
    enum Purpose: String, Decodable, Sendable {
        case regressionPublic
        case marketingReal
    }

    let purpose: Purpose
    /// The screen the launch shows, such as `home`.
    let scenarioID: String
    /// The fixture the scene reads: a public fixture ID such as `home-finite`, or a marketing
    /// selection set such as `nonexplicit`.
    let fixtureID: String
}

extension CaptureSceneConfiguration: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case purpose
        case scenarioID
        case fixtureID
    }

    /// Decodes a configuration, rejecting malformed JSON, missing or unknown keys, an unknown
    /// purpose and identifiers outside `[a-z][a-z0-9-]*`.
    init(json: Data) throws(CaptureFailure) {
        do {
            self = try JSONDecoder().decode(Self.self, from: json)
        } catch {
            throw .malformedConfiguration(CaptureFailure.describe(error))
        }
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        purpose = try container.decode(Purpose.self, forKey: .purpose)
        scenarioID = try container.decodeIdentifier(forKey: .scenarioID)
        fixtureID = try container.decodeIdentifier(forKey: .fixtureID)
    }
}

/// Why a capture launch was refused.
///
/// A capture never falls back to live data or a partial scene, so every failure ends the launch.
/// Each description names the check and the fixture-relative path or identifier involved, and
/// never a credential or a file's contents.
enum CaptureFailure: Error, Equatable, CustomStringConvertible {
    /// Other `EHPANDA_` launch keys were set beside the capture keys.
    case conflictingLaunchKeys([String])
    case missingConfiguration
    case missingFixtureDirectory
    case malformedConfiguration(String)
    case unreadableFile(String)
    case malformedManifest(String)
    /// The fixture's schema belongs to the other purpose.
    case purposeMismatch(configured: CaptureSceneConfiguration.Purpose)
    case unsafePath(String)
    case symbolicLink(String)
    case missingFile(String)
    case unexpectedFile(String)
    case sizeMismatch(String)
    case checksumMismatch(String)
    /// The aggregate digest or fixture version disagrees with the listed assets.
    case identityMismatch
    /// `selection.json` disagrees with the selection the manifest names.
    case selectionMismatch
    case unknownFixtureID(String)
    case unsupportedScenario(String)
    /// The selected scene cannot be shown as configured.
    case malformedScene(String)
    /// The capture-owned storage directory could not be emptied or created.
    case storageUnavailable

    var description: String {
        switch self {
        case .conflictingLaunchKeys(let keys):
            "A capture launch takes no other EHPANDA_ launch keys, found: \(keys.joined(separator: ", "))"
        case .missingConfiguration:
            "EHPANDA_CAPTURE_FIXTURES is set without EHPANDA_CAPTURE_CONFIGURATION"
        case .missingFixtureDirectory:
            "EHPANDA_CAPTURE_FIXTURES must name an absolute fixture version directory"
        case .malformedConfiguration(let reason):
            "Malformed capture configuration: \(reason)"
        case .unreadableFile(let path):
            "Cannot read fixture file \(path)"
        case .malformedManifest(let reason):
            "Malformed fixture manifest: \(reason)"
        case .purposeMismatch(let configured):
            "The fixture is not a \(configured.rawValue) fixture"
        case .unsafePath(let path):
            "Fixture path escapes its directory or is not canonical: \(path)"
        case .symbolicLink(let path):
            "Fixture contains a symbolic link: \(path)"
        case .missingFile(let path):
            "Fixture is missing the listed file \(path)"
        case .unexpectedFile(let path):
            "Fixture contains a file its manifest does not list: \(path)"
        case .sizeMismatch(let path):
            "Fixture file length differs from its manifest: \(path)"
        case .checksumMismatch(let path):
            "Fixture file SHA-256 differs from its manifest: \(path)"
        case .identityMismatch:
            "Fixture aggregate digest or version differs from its listed assets"
        case .selectionMismatch:
            "selection.json differs from the selection the manifest names"
        case .unknownFixtureID(let fixtureID):
            "The fixture has no \(fixtureID) fixture"
        case .unsupportedScenario(let scenarioID):
            "No capture scene \(scenarioID) exists for this purpose"
        case .malformedScene(let reason):
            "The selected scene cannot be shown as configured: \(reason)"
        case .storageUnavailable:
            "The capture-owned storage directory cannot be emptied or created"
        }
    }

    /// A decoding failure's coding path and reason, which name keys and types but no values.
    static func describe(_ error: any Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return "not valid JSON"
        }
        let context: DecodingError.Context
        switch decodingError {
        case .typeMismatch(_, let mismatchContext), .valueNotFound(_, let mismatchContext):
            context = mismatchContext
        case .keyNotFound(let key, let missingContext):
            return "missing key \((missingContext.codingPath + [key]).map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let corruptedContext):
            context = corruptedContext
        @unknown default:
            return "undecodable value"
        }
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
    }
}

// MARK: Strict decoding

/// A key for reading every key an object holds, declared or not.
private struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

extension Decoder {
    /// Rejects an object whose keys differ from `Keys`, so a misspelled or extra key fails instead
    /// of being ignored, matching the fixture tools' exact key sets.
    func requireExactKeys<Keys: CodingKey & CaseIterable>(_: Keys.Type) throws {
        let found = Set(try container(keyedBy: AnyCodingKey.self).allKeys.map(\.stringValue))
        let expected = Set(Keys.allCases.map(\.stringValue))
        guard found == expected else {
            let unknown = found.subtracting(expected).sorted()
            let missing = expected.subtracting(found).sorted()
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "unknown keys \(unknown), missing keys \(missing)"
                )
            )
        }
    }
}

extension KeyedDecodingContainer {
    /// A scenario or fixture identifier: a lowercase letter, then lowercase letters, digits or hyphens.
    func decodeIdentifier(forKey key: Key) throws -> String {
        let value = try decode(String.self, forKey: key)
        guard value.wholeMatch(of: /[a-z][a-z0-9-]*/) != nil else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "not an identifier of the form [a-z][a-z0-9-]*"
            )
        }
        return value
    }
}
#endif
