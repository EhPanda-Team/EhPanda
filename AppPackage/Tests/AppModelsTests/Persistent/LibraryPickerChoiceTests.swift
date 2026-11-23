@testable import AppModels
import ComposableArchitecture
import Foundation
import Testing
import TestingSupport

/// The compact Library picker's remembered group (261117-tyj, owner decisions A-1 and A-2): the full group, a strict
/// versioned decode, and a key whose absence means nothing is remembered.
@Suite(.isolatedAppStorage)
struct LibraryPickerChoiceTests {
    @Test(arguments: [
        LibraryGroup.favorites(-1),
        .favorites(9),
        .downloads(.all),
        .downloads(.folder("Reading"))
    ])
    func roundTripsThroughJSON(group: LibraryGroup) throws {
        let choice = LibraryPickerChoice(group: group)
        let decoded = try JSONDecoder().decode(LibraryPickerChoice.self, from: JSONEncoder().encode(choice))
        #expect(decoded == choice)
    }

    @Test
    func aNewerSchemaVersionThrows() throws {
        let data = try Self.blob(schemaVersion: 2, group: LibraryGroup.downloads(.all))
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(LibraryPickerChoice.self, from: data)
        }
    }

    @Test(arguments: [10, -2])
    func aFavoritesCategoryOutsideTheSiteIndicesThrows(index: Int) throws {
        let data = try Self.blob(schemaVersion: 1, group: LibraryGroup.favorites(index))
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(LibraryPickerChoice.self, from: data)
        }
    }

    @Test
    func aBlobWithoutAGroupThrows() {
        let data = Data(#"{"schemaVersion": 1}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(LibraryPickerChoice.self, from: data)
        }
    }

    @Test
    func noStoredDataReadsNothingRemembered() {
        @Shared(.libraryPickerChoice) var choice
        #expect(choice == nil)
    }

    @Test
    func aCorruptBlobReadsNothingRemembered() {
        @Dependency(\.defaultAppStorage) var defaults
        defaults.set(Data("not json".utf8), forKey: "libraryPickerChoice")
        @Shared(.libraryPickerChoice) var choice
        #expect(choice == nil)
    }

    @Test
    func aNilWriteReadsBackAsNothingRemembered() {
        @Shared(.libraryPickerChoice) var choice
        $choice.withLock({ $0 = LibraryPickerChoice(group: .downloads(.folder("Reading"))) })
        #expect(choice != nil)

        $choice.withLock({ $0 = nil })
        #expect(choice == nil)
        @Shared(.libraryPickerChoice) var reopened
        #expect(reopened == nil)
    }
}

private extension LibraryPickerChoiceTests {
    /// A stored blob of the current shape with the given version and group.
    static func blob(schemaVersion: Int, group: LibraryGroup) throws -> Data {
        let groupObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(group))
        return try JSONSerialization.data(withJSONObject: ["schemaVersion": schemaVersion, "group": groupObject])
    }
}
