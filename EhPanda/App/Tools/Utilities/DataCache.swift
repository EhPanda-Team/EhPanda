//
//  DataCache.swift
//  EhPanda
//

import CryptoKit
import Foundation
import UIKit

actor DataCache {
    struct Configuration: Equatable, Sendable {
        var rootURL: URL
        var memoryCostLimit: Int
        var maxDiskAge: TimeInterval
        var diskSizeLimit: UInt64
        var sweepByteInterval: UInt64

        init(
            rootURL: URL = FileUtil.cachesDirectory
                .appendingPathComponent("DataCache.reading", isDirectory: true),
            memoryCostLimit: Int = Int(ProcessInfo.processInfo.physicalMemory / 4),
            maxDiskAge: TimeInterval = 7 * 24 * 60 * 60,
            diskSizeLimit: UInt64 = 0
        ) {
            self.rootURL = rootURL
            self.memoryCostLimit = memoryCostLimit
            self.maxDiskAge = maxDiskAge
            self.diskSizeLimit = diskSizeLimit
            self.sweepByteInterval = diskSizeLimit == 0 ? 0 : max(diskSizeLimit / 8, 1)
        }
    }

    static let shared = DataCache()

    private let configuration: Configuration
    private let fileManager: FileManager
    private let memoryCache = NSCache<NSString, NSData>()
    private var bytesWrittenSinceSweep: UInt64 = 0

    init(
        configuration: Configuration = .init(),
        fileManager: sending FileManager = FileManager()
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        memoryCache.totalCostLimit = configuration.memoryCostLimit
    }

    nonisolated static func installSystemPurgeObservers() {
        Task { @MainActor in
            _ = dataCacheSystemPurgeObserver
        }
    }

    func data(forKey key: String) -> Data? {
        let filename = Self.filename(forKey: key)
        if let data = memoryCache.object(forKey: filename as NSString) {
            return Data(referencing: data)
        }

        let fileURL = configuration.rootURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        if isExpired(fileURL) {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        // A file that exists but can't be read — corrupt, truncated, or purged
        // between the existence check and the read — is treated as a miss and
        // removed, so the caller re-downloads instead of sticking on the broken
        // entry until it expires.
        guard let data = try? Data(contentsOf: fileURL) else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        memoryCache.setObject(data as NSData, forKey: filename as NSString, cost: data.count)
        // A failed access-date bump must not fail an otherwise-successful read.
        try? touchAccessDate(for: fileURL)
        return data
    }

    func data(forKeys keys: [String]) -> Data? {
        for key in Self.uniqued(keys) {
            if let data = data(forKey: key) {
                return data
            }
        }
        return nil
    }

    func store(_ data: Data, forKey key: String) throws {
        let filename = Self.filename(forKey: key)
        memoryCache.setObject(data as NSData, forKey: filename as NSString, cost: data.count)
        let fileURL = configuration.rootURL.appendingPathComponent(filename)
        try write(data, to: fileURL, canRetryDirectoryCreation: true)
        bytesWrittenSinceSweep += UInt64(data.count)
        if configuration.sweepByteInterval > 0,
           bytesWrittenSinceSweep >= configuration.sweepByteInterval {
            bytesWrittenSinceSweep = 0
            try sweepDisk()
        }
    }

    func store(_ data: Data, forKeys keys: [String]) throws {
        for key in Self.uniqued(keys) {
            try store(data, forKey: key)
        }
    }

    func removeData(forKey key: String) throws {
        let filename = Self.filename(forKey: key)
        memoryCache.removeObject(forKey: filename as NSString)
        let fileURL = configuration.rootURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func removeData(forKeys keys: [String]) throws {
        for key in Self.uniqued(keys) {
            try removeData(forKey: key)
        }
    }

    func removeAll() throws {
        memoryCache.removeAllObjects()
        if fileManager.fileExists(atPath: configuration.rootURL.path) {
            try fileManager.removeItem(at: configuration.rootURL)
        }
        try ensureDirectory()
        bytesWrittenSinceSweep = 0
    }

    func removeAllMemory() {
        memoryCache.removeAllObjects()
    }

    func totalSize() throws -> UInt64 {
        guard fileManager.fileExists(atPath: configuration.rootURL.path) else { return 0 }
        guard let enumerator = fileManager.enumerator(
            at: configuration.rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values?.isRegularFile == true else { return }
                total += UInt64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    func sweepDisk() throws {
        guard fileManager.fileExists(atPath: configuration.rootURL.path) else { return }
        var entries = try diskEntries()
        let now = Date()
        if configuration.maxDiskAge > 0 {
            for entry in entries where now.timeIntervalSince(entry.accessDate) > configuration.maxDiskAge {
                evictDiskEntry(entry)
            }
            entries.removeAll { now.timeIntervalSince($0.accessDate) > configuration.maxDiskAge }
        }

        guard configuration.diskSizeLimit > 0 else { return }
        var totalSize = entries.reduce(UInt64(0)) { $0 + $1.size }
        guard totalSize > configuration.diskSizeLimit else { return }
        let targetSize = configuration.diskSizeLimit / 2
        for entry in entries.sorted(by: { $0.accessDate < $1.accessDate }) {
            evictDiskEntry(entry)
            totalSize = totalSize > entry.size ? totalSize - entry.size : 0
            guard totalSize > targetSize else { break }
        }
    }

    // Evicts a single entry from disk and drops only its matching memory object.
    // The memory cache is keyed by the on-disk hashed filename, so eviction stays
    // scoped to the swept keys instead of purging the whole memory front.
    private func evictDiskEntry(_ entry: DiskEntry) {
        try? fileManager.removeItem(at: entry.url)
        memoryCache.removeObject(forKey: entry.url.lastPathComponent as NSString)
    }

    private func write(
        _ data: Data,
        to fileURL: URL,
        canRetryDirectoryCreation: Bool
    ) throws {
        do {
            try ensureDirectory()
            try data.write(to: fileURL, options: .atomic)
            // A failed access-date bump must not fail an otherwise-successful write.
            try? touchAccessDate(for: fileURL)
        } catch {
            guard canRetryDirectoryCreation else { throw error }
            try? fileManager.removeItem(at: configuration.rootURL)
            try ensureDirectory()
            try write(data, to: fileURL, canRetryDirectoryCreation: false)
        }
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: configuration.rootURL,
            withIntermediateDirectories: true
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directoryURL = configuration.rootURL
        try? directoryURL.setResourceValues(resourceValues)
    }

    private static func filename(forKey key: String) -> String {
        SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private nonisolated static func uniqued(_ keys: [String]) -> [String] {
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }

    private func isExpired(_ fileURL: URL) -> Bool {
        guard configuration.maxDiskAge > 0 else { return false }
        let accessDate = accessDate(for: fileURL)
        return Date().timeIntervalSince(accessDate) > configuration.maxDiskAge
    }

    private func touchAccessDate(for fileURL: URL) throws {
        try fileManager.setAttributes(
            [.creationDate: Date(), .modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        var resourceValues = URLResourceValues()
        resourceValues.contentAccessDate = Date()
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(resourceValues)
    }

    private func accessDate(for fileURL: URL) -> Date {
        if let date = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate {
            return date
        }
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    private func diskEntries() throws -> [DiskEntry] {
        guard let enumerator = fileManager.enumerator(
            at: configuration.rootURL,
            includingPropertiesForKeys: [
                .contentAccessDateKey,
                .fileSizeKey,
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries = [DiskEntry]()
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [
                .contentAccessDateKey,
                .fileSizeKey,
                .isRegularFileKey
            ])
            guard values.isRegularFile == true else { continue }
            entries.append(
                DiskEntry(
                    url: fileURL,
                    size: UInt64(values.fileSize ?? 0),
                    accessDate: values.contentAccessDate ?? accessDate(for: fileURL)
                )
            )
        }
        return entries
    }
}

@MainActor
private let dataCacheSystemPurgeObserver = DataCacheSystemPurgeObserver(cache: .shared)

@MainActor
private final class DataCacheSystemPurgeObserver {
    private let tokens: [NSObjectProtocol]

    init(cache: DataCache) {
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak cache] _ in
                Task {
                    await cache?.removeAllMemory()
                }
            },
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak cache] _ in
                Task {
                    await cache?.removeAllMemory()
                    try? await cache?.sweepDisk()
                }
            }
        ]
    }
}

private struct DiskEntry {
    let url: URL
    let size: UInt64
    let accessDate: Date
}
