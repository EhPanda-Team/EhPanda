import ComposableArchitecture
import Foundation
import Testing
import TestingSupport

/// What `.isolatedAppStorage` promises a case: a suite of its own, empty at the start and cleared at the end.
@Suite(.isolatedAppStorage)
struct IsolatedAppStorageTraitTests {
    private static let key = "isolatedAppStorageProbe"

    @Test(arguments: [1, 2, 3])
    func everyCaseStartsEmptyAndReadsItsOwnWrite(_ value: Int) {
        @Dependency(\.defaultAppStorage) var appStorage
        #expect(appStorage.object(forKey: Self.key) == nil)

        appStorage.set(value, forKey: Self.key)

        #expect(appStorage.integer(forKey: Self.key) == value)
    }

    @Test
    func aScopeGetsItsOwnSuiteAndClearsItAtTheEnd() async throws {
        @Dependency(\.defaultAppStorage) var caseStorage
        let caseStorageID = ObjectIdentifier(caseStorage)
        let scoped = LockIsolated<UncheckedSendable<UserDefaults>?>(nil)
        let trait: IsolatedAppStorageTrait = .isolatedAppStorage
        let test = try #require(Test.current)

        try await trait.provideScope(for: test, testCase: Test.Case.current) {
            @Dependency(\.defaultAppStorage) var appStorage
            #expect(ObjectIdentifier(appStorage) != caseStorageID)
            appStorage.set(1, forKey: Self.key)
            let wrapped = UncheckedSendable(appStorage)
            scoped.setValue(wrapped)
        }

        let suite = try #require(scoped.value).wrappedValue
        #expect(suite.object(forKey: Self.key) == nil)
    }

    @Test
    func aSecondSuiteIsSeparateAndClearedAtTheEnd() async throws {
        @Dependency(\.defaultAppStorage) var caseStorage

        let second = try await withIsolatedAppStorage { appStorage in
            #expect(appStorage !== caseStorage)
            appStorage.set(2, forKey: Self.key)
            #expect(appStorage.integer(forKey: Self.key) == 2)
            return appStorage
        }

        #expect(second.object(forKey: Self.key) == nil)
        #expect(caseStorage.object(forKey: Self.key) == nil)
    }
}
