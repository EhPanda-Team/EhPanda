//
//  DataCacheTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DataCacheTests {
    @Test
    func testStoreAndReadDataFromDiskWithHashedFilename() async throws {
        let rootURL = makeRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = DataCache(
            configuration: .init(rootURL: rootURL, memoryCostLimit: 1, maxDiskAge: 60)
        )
        let key = "https://example.com/reader/1.webp"
        let data = Data([0x01, 0x02, 0x03])

        try await cache.store(data, forKey: key)
        await cache.removeAllMemory()

        #expect(await cache.data(forKey: key) == data)
        let files = try FileManager.default.contentsOfDirectory(atPath: rootURL.path)
        #expect(files.count == 1)
        #expect(files.first != key)
        let resourceValues = try rootURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(resourceValues.isExcludedFromBackup == true)
    }

    @Test
    func testStoreReadAndRemoveDataForOrderedKeys() async throws {
        let rootURL = makeRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = DataCache(configuration: .init(rootURL: rootURL))
        let data = Data([0x0A, 0x0B])

        try await cache.store(data, forKeys: ["stable", "absolute", "stable"])

        #expect(await cache.data(forKeys: ["missing", "absolute"]) == data)
        let files = try FileManager.default.contentsOfDirectory(atPath: rootURL.path)
        #expect(files.count == 2)

        try await cache.removeData(forKeys: ["stable", "absolute", "stable"])

        #expect(await cache.data(forKeys: ["stable", "absolute"]) == nil)
        #expect(try await cache.totalSize() == 0)
    }

    @Test
    func testExpiredDataIsRemovedOnRead() async throws {
        let rootURL = makeRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = DataCache(
            configuration: .init(rootURL: rootURL, maxDiskAge: 0.01)
        )

        try await cache.store(Data([0x01]), forKey: "expired")
        try await Task.sleep(for: .milliseconds(20))
        await cache.removeAllMemory()

        #expect(await cache.data(forKey: "expired") == nil)
        #expect(try await cache.totalSize() == 0)
    }

    @Test
    func testDiskSweepEvictsOldestEntriesToHalfLimit() async throws {
        let rootURL = makeRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = DataCache(
            configuration: .init(
                rootURL: rootURL,
                maxDiskAge: 60,
                diskSizeLimit: 10
            )
        )

        try await cache.store(Data(repeating: 0x01, count: 4), forKey: "old")
        try await Task.sleep(for: .milliseconds(10))
        try await cache.store(Data(repeating: 0x02, count: 4), forKey: "middle")
        try await Task.sleep(for: .milliseconds(10))
        try await cache.store(Data(repeating: 0x03, count: 4), forKey: "new")

        #expect(await cache.data(forKey: "old") == nil)
        #expect(await cache.data(forKey: "middle") == nil)
        #expect(await cache.data(forKey: "new") == Data(repeating: 0x03, count: 4))
        #expect(try await cache.totalSize() <= 5)
    }

    @Test
    func testRemoveAllClearsMemoryAndDisk() async throws {
        let rootURL = makeRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = DataCache(
            configuration: .init(rootURL: rootURL)
        )

        try await cache.store(Data([0x01]), forKey: "page")
        try await cache.removeAll()

        #expect(await cache.data(forKey: "page") == nil)
        #expect(try await cache.totalSize() == 0)
    }

    @Test
    func testUnreadableDiskEntryIsTreatedAsMissAndRemoved() async throws {
        let rootURL = makeRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = DataCache(configuration: .init(rootURL: rootURL))

        try await cache.store(Data([0x01, 0x02]), forKey: "page")
        await cache.removeAllMemory()

        // Make the on-disk entry unreadable by replacing the cached file with a
        // directory, which `Data(contentsOf:)` cannot read — the same failure mode
        // as a corrupt or mid-read-purged file.
        let files = try FileManager.default.contentsOfDirectory(atPath: rootURL.path)
        let entryURL = rootURL.appendingPathComponent(try #require(files.first))
        try FileManager.default.removeItem(at: entryURL)
        try FileManager.default.createDirectory(at: entryURL, withIntermediateDirectories: false)

        #expect(await cache.data(forKey: "page") == nil)
        #expect(try await cache.totalSize() == 0)
    }

    private func makeRootURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
