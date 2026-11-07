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

/// Appends result lines to `<output>/results.jsonl` and writes the run's pictures under `<output>`.
///
/// Several simulator clones of one run share the output directory, so each line is one `write` to a descriptor
/// opened with `O_APPEND` under an exclusive `flock`: lines from different processes never interleave.
public struct SnapshotResultWriter: Sendable {
    public let output: URL

    public init(output: URL) {
        self.output = output
    }

    public var resultsURL: URL {
        output.appending(path: "results.jsonl")
    }

    public func append(_ line: SnapshotResultLine) throws {
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
        let written = data.withUnsafeBytes { buffer in
            write(descriptor, buffer.baseAddress, buffer.count)
        }
        guard written == data.count else { throw SnapshotResultWriterError.write(errno) }
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
