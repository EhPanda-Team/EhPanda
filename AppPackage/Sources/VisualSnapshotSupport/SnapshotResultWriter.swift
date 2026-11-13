public import Foundation

/// One line of `results.jsonl` (19-RESEARCH §9). Reasons are fixed codes, never page text.
public struct SnapshotResultLine: Codable, Equatable, Sendable {
    public let key: String
    public let status: SnapshotStatus
    public let attempts: Int
    public let flaky: Bool
    public let seconds: Double
    public let settleSamples: Int
    public let bytes: Int
    public let sha256: String?
    public let reason: String?

    public init(
        key: String, status: SnapshotStatus, attempts: Int, flaky: Bool, seconds: Double, settleSamples: Int,
        bytes: Int, sha256: String?, reason: String?
    ) {
        self.key = key
        self.status = status
        self.attempts = attempts
        self.flaky = flaky
        self.seconds = seconds
        self.settleSamples = settleSamples
        self.bytes = bytes
        self.sha256 = sha256
        self.reason = reason
    }
}

/// `shard.json` (19-RESEARCH §9): what ran where, and the infrastructure error class, if any.
public struct SnapshotShardRecord: Codable, Equatable, Sendable {
    public enum Infrastructure: String, Codable, Sendable {
        case crash
        case timeout
        case runnerLost = "runner-lost"
        case drift
        case baselineMismatch = "baseline-mismatch"
    }

    public let shard: String
    public let units: [String]
    public let workers: Int
    public let xcodeBuild: String
    public let runtime: String
    public let model: String
    public let runnerImage: String?
    public let started: String
    public let finished: String
    public let infra: Infrastructure?

    public init(
        shard: String, units: [String], workers: Int, xcodeBuild: String, runtime: String, model: String,
        runnerImage: String?, started: String, finished: String, infra: Infrastructure?
    ) {
        self.shard = shard
        self.units = units
        self.workers = workers
        self.xcodeBuild = xcodeBuild
        self.runtime = runtime
        self.model = model
        self.runnerImage = runnerImage
        self.started = started
        self.finished = finished
        self.infra = infra
    }

    private enum CodingKeys: String, CodingKey {
        case shard, units, workers, xcodeBuild, runtime, model, runnerImage, started, finished, infra
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shard, forKey: .shard)
        try container.encode(units, forKey: .units)
        try container.encode(workers, forKey: .workers)
        try container.encode(xcodeBuild, forKey: .xcodeBuild)
        try container.encode(runtime, forKey: .runtime)
        try container.encode(model, forKey: .model)
        try container.encode(runnerImage, forKey: .runnerImage)
        try container.encode(started, forKey: .started)
        try container.encode(finished, forKey: .finished)
        // `null` is written explicitly: a missing key would read as an unknown shard state.
        try container.encode(infra, forKey: .infra)
    }
}

/// A picture written with its result line: `kind` is the subdirectory (`actual`, `difference`, …) or `nil` for the
/// output root, and `relativePath` the coordinate's baseline path.
public struct SnapshotPicture: Sendable {
    public let data: Data
    public let kind: String?
    public let relativePath: String

    public init(_ data: Data, kind: String?, relativePath: String) {
        self.data = data
        self.kind = kind
        self.relativePath = relativePath
    }
}

/// Appends result lines to `<output>/results.jsonl` and writes the run's pictures under `<output>`.
///
/// Several simulator clones of one run share the output directory, so each line is one `write` to a descriptor
/// opened with `O_APPEND` under an exclusive `flock`: lines from different processes never interleave.
///
/// Each coordinate keeps the first line written for it, and only that line's pictures. A hosted runner froze for
/// 25 minutes (run 43298876957, shard s15): XCTest gave the stalled runners up, started new ones on
/// the same clones and ran their classes again, and the old runners woke and went on with the same classes. Both
/// wrote each coordinate, the aggregate kept the first line and the disk kept the last picture, and 34 lines
/// named pictures whose digest and size were not the ones on disk. The check, the pictures and the line are now
/// one step under the lock.
public struct SnapshotResultWriter: Sendable {
    public let output: URL

    public init(output: URL) {
        self.output = output
    }

    public var resultsURL: URL {
        output.appending(path: "results.jsonl")
    }

    /// Writes `pictures`, then `line`, unless `line.key` already has a line; returns whether it wrote them.
    ///
    /// The pictures go first: a process killed between the two leaves pictures without a line, which a re-run
    /// replaces (`Scripts/visual/snapshot_shard.py` `prune`), never a line without its pictures.
    @discardableResult
    public func append(_ line: SnapshotResultLine, pictures: [SnapshotPicture] = []) throws -> Bool {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(line)
        data.append(0x0A)
        let descriptor = open(resultsURL.path(percentEncoded: false), O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard descriptor >= 0 else { throw SnapshotResultWriterError.open(errno) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw SnapshotResultWriterError.lock(errno) }
        defer { flock(descriptor, LOCK_UN) }
        guard try !recordedKeys().contains(line.key) else { return false }
        for picture in pictures {
            try writePicture(picture.data, kind: picture.kind, relativePath: picture.relativePath)
        }
        let written = data.withUnsafeBytes { buffer in
            write(descriptor, buffer.baseAddress, buffer.count)
        }
        guard written == data.count else { throw SnapshotResultWriterError.write(errno) }
        return true
    }

    /// Writes `data` at `relativePath` below the output, or below one of its subdirectories (`actual`,
    /// `difference`). Candidates go to the output root, so a candidate directory is laid out as a baseline slice.
    @discardableResult
    public func writePicture(_ data: Data, kind: String?, relativePath: String) throws -> URL {
        let base = kind.map({ output.appending(path: $0, directoryHint: .isDirectory) }) ?? output
        let url = base.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }

    public func writeShard(_ record: SnapshotShardRecord) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: output.appending(path: "shard.json"), options: .atomic)
    }

    /// The keys of every line written so far. A line that does not read as a result (a clone killed mid-write) is
    /// passed over: the caller only asks whether a coordinate already has its line.
    public func recordedKeys() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: resultsURL.path(percentEncoded: false)) else { return [] }
        let text = try String(contentsOf: resultsURL, encoding: .utf8)
        var keys = Set<String>()
        for line in text.split(separator: "\n") {
            let object: Any
            do {
                object = try JSONSerialization.jsonObject(with: Data(line.utf8))
            } catch {
                continue
            }
            if let key = (object as? [String: Any])?["key"] as? String {
                keys.insert(key)
            }
        }
        return keys
    }

    /// Reads every line written so far.
    public func lines() throws -> [SnapshotResultLine] {
        guard FileManager.default.fileExists(atPath: resultsURL.path(percentEncoded: false)) else { return [] }
        let decoder = JSONDecoder()
        return try String(contentsOf: resultsURL, encoding: .utf8)
            .split(separator: "\n")
            .map({ try decoder.decode(SnapshotResultLine.self, from: Data($0.utf8)) })
    }
}

public enum SnapshotResultWriterError: Error, Equatable {
    case open(Int32)
    case lock(Int32)
    case write(Int32)
}
