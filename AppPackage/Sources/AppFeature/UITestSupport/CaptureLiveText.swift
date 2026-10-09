#if DEBUG
import AppModels
import CoreGraphics
import Foundation
import ReadingFeature

/// A Live Text recording a marketing fixture holds (17-06): what the app's own Live Text found on
/// one flow page, which `record-live-text.py` saved from a recording launch's diagnostics.
///
/// The groups keep the recognizer's IDs, so every capture that replays them shows the same groups.
struct CaptureLiveTextRecord: Equatable, Sendable {
    /// The simulator a recording ran on.
    struct Device: Equatable, Sendable {
        let model: String
        let runtimeBuild: String
    }

    let schemaVersion: Int
    let gid: String
    let page: Int
    /// The SHA-256 of the page image the recognizer read.
    let pageSHA256: String
    /// The languages the reader asked the recognizer for; `nil` when it named none.
    let recognitionLanguages: [String]?
    let recordedOn: Device
    let groups: [CaptureLiveTextGroup]
}

/// Lines the reader groups into one selectable region, as records and diagnostics carry them.
struct CaptureLiveTextGroup: Equatable, Sendable, Codable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case blocks
    }

    let id: UUID
    let blocks: [CaptureLiveTextBlock]
}

/// One recognized line, as records and diagnostics carry it.
struct CaptureLiveTextBlock: Equatable, Sendable, Codable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case text
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    let id: UUID
    let text: String
    let topLeft: CaptureLiveTextPoint
    let topRight: CaptureLiveTextPoint
    let bottomLeft: CaptureLiveTextPoint
    let bottomRight: CaptureLiveTextPoint
}

/// A line's corner in the page image's normalized coordinates, with the origin at the top left,
/// kept as JSON `x` and `y`.
struct CaptureLiveTextPoint: Equatable, Sendable, Codable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case horizontal = "x"
        case vertical = "y"
    }

    /// The distance from the page's left edge, as a fraction of its width.
    let horizontal: Double
    /// The distance from the page's top edge, as a fraction of its height.
    let vertical: Double
}

// MARK: Replay
extension CaptureLiveTextRecord {
    /// The reader's groups for `page` of gallery `gid`, once the record proves it was recognized on
    /// that page's saved image, with the languages the reader asks for, on a named simulator, and
    /// holds lines the reader can draw.
    ///
    /// Corners may lie slightly outside the page, as Vision can place them, so a line only has to
    /// have an extent and overlap the page.
    func replayGroups(
        gid: String,
        page: Int,
        pageSHA256: String,
        recognitionLanguages: [String]?
    ) throws(CaptureFailure) -> [LiveTextGroup] {
        let name = "the Live Text record of page \(page) of gallery \(gid)"
        guard schemaVersion == 1, self.gid == gid, self.page == page else {
            throw .malformedScene("\(name) names another page or schema")
        }
        guard self.pageSHA256 == pageSHA256 else {
            throw .malformedScene("\(name) was recognized on other bytes than the page image")
        }
        guard self.recognitionLanguages == recognitionLanguages else {
            throw .malformedScene("\(name) was recognized in other languages than the reader requests")
        }
        guard !recordedOn.model.isEmpty, !recordedOn.runtimeBuild.isEmpty else {
            throw .malformedScene("\(name) names no recording simulator")
        }
        let identifiers = groups.flatMap({ [$0.id] + $0.blocks.map(\.id) })
        guard Set(identifiers).count == identifiers.count else {
            throw .malformedScene("\(name) repeats an ID")
        }
        guard !groups.isEmpty else {
            throw .malformedScene("\(name) holds no groups")
        }
        return try groups.map { group throws(CaptureFailure) in
            let blocks = try group.blocks.map { block throws(CaptureFailure) in
                guard !block.text.isEmpty, block.isDrawable else {
                    throw .malformedScene("\(name) holds a line without text or outside the page")
                }
                return block.liveTextBlock
            }
            guard var liveTextGroup = LiveTextGroup(blocks: blocks) else {
                throw .malformedScene("\(name) holds a group without lines")
            }
            liveTextGroup.id = group.id
            return liveTextGroup
        }
    }
}

extension CaptureLiveTextGroup {
    /// The reader's group as records and diagnostics carry it.
    init(_ group: LiveTextGroup) {
        self.init(id: group.id, blocks: group.blocks.map(CaptureLiveTextBlock.init))
    }
}

extension CaptureLiveTextBlock {
    init(_ block: LiveTextBlock) {
        self.init(
            id: block.id,
            text: block.text,
            topLeft: .init(block.bounds.topLeft),
            topRight: .init(block.bounds.topRight),
            bottomLeft: .init(block.bounds.bottomLeft),
            bottomRight: .init(block.bounds.bottomRight)
        )
    }

    var liveTextBlock: LiveTextBlock {
        LiveTextBlock(
            id: id,
            text: text,
            bounds: LiveTextBounds(
                topLeft: topLeft.cgPoint,
                topRight: topRight.cgPoint,
                bottomLeft: bottomLeft.cgPoint,
                bottomRight: bottomRight.cgPoint
            )
        )
    }

    /// Whether every corner is finite and the line has an extent that overlaps the page.
    var isDrawable: Bool {
        let corners = [topLeft, topRight, bottomLeft, bottomRight]
        let horizontals = corners.map(\.horizontal)
        let verticals = corners.map(\.vertical)
        guard
            corners.allSatisfy({ $0.horizontal.isFinite && $0.vertical.isFinite }),
            let left = horizontals.min(), let right = horizontals.max(),
            let top = verticals.min(), let bottom = verticals.max()
        else {
            return false
        }
        return left < right && top < bottom && right > 0 && left < 1 && bottom > 0 && top < 1
    }
}

extension CaptureLiveTextPoint {
    init(_ point: CGPoint) {
        self.init(horizontal: point.x, vertical: point.y)
    }

    var cgPoint: CGPoint {
        CGPoint(x: horizontal, y: vertical)
    }
}

// MARK: Decoding
extension CaptureLiveTextRecord: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case gid
        case page
        case pageSHA256
        case recognitionLanguages
        case recordedOn
        case groups
    }

    /// Decodes a record whose every object has exactly its keys, matching the fixture tools' schema.
    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        gid = try container.decode(String.self, forKey: .gid)
        page = try container.decode(Int.self, forKey: .page)
        pageSHA256 = try container.decode(String.self, forKey: .pageSHA256)
        recognitionLanguages = try container.decode([String]?.self, forKey: .recognitionLanguages)
        recordedOn = try container.decode(Device.self, forKey: .recordedOn)
        groups = try container.decode([CaptureLiveTextGroup].self, forKey: .groups)
    }
}

extension CaptureLiveTextRecord.Device: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case model
        case runtimeBuild
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        runtimeBuild = try container.decode(String.self, forKey: .runtimeBuild)
    }
}

extension CaptureLiveTextGroup {
    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        blocks = try container.decode([CaptureLiveTextBlock].self, forKey: .blocks)
    }
}

extension CaptureLiveTextBlock {
    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        topLeft = try container.decode(CaptureLiveTextPoint.self, forKey: .topLeft)
        topRight = try container.decode(CaptureLiveTextPoint.self, forKey: .topRight)
        bottomLeft = try container.decode(CaptureLiveTextPoint.self, forKey: .bottomLeft)
        bottomRight = try container.decode(CaptureLiveTextPoint.self, forKey: .bottomRight)
    }
}

extension CaptureLiveTextPoint {
    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        horizontal = try container.decode(Double.self, forKey: .horizontal)
        vertical = try container.decode(Double.self, forKey: .vertical)
    }
}

// MARK: Diagnostics

/// The Live Text a reader shows in a capture launch, as the diagnostics report it.
///
/// A recording reads its groups from here, and a replay's groups must equal the record's.
struct CaptureLiveTextDiagnostics: Equatable, Encodable {
    enum Source: String, Encodable {
        /// The groups came from the fixture's record.
        case fixture
        /// The reader's own recognizer found the groups in this launch.
        case recognition
    }

    private enum CodingKeys: String, CodingKey {
        case gid
        case page
        case source
        case recognitionLanguages
        case groups
    }

    let gid: String
    let page: Int
    let source: Source
    /// The languages the reader asked the recognizer for; only a recognition has them.
    let recognitionLanguages: [String]?
    let groups: [CaptureLiveTextGroup]

    /// Encodes every key, `recognitionLanguages` as `null` when the reader named none, as a record
    /// keeps it.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gid, forKey: .gid)
        try container.encode(page, forKey: .page)
        try container.encode(source, forKey: .source)
        try container.encode(recognitionLanguages, forKey: .recognitionLanguages)
        try container.encode(groups, forKey: .groups)
    }
}

extension CaptureLiveTextDiagnostics {
    /// What `capture`'s page shows after `outcome`, or `nil` while it shows no Live Text.
    init?(capture: LiveTextCapture, outcome: LiveTextCapture.Outcome?) {
        switch outcome {
        case .replayed(let groups):
            self.init(capture: capture, source: .fixture, recognitionLanguages: nil, groups: groups)
        case .recognized(let groups, let languages):
            self.init(capture: capture, source: .recognition, recognitionLanguages: languages, groups: groups)
        case .otherGallery, nil:
            return nil
        }
    }

    private init(capture: LiveTextCapture, source: Source, recognitionLanguages: [String]?, groups: [LiveTextGroup]) {
        self.init(
            gid: capture.gid,
            page: capture.page,
            source: source,
            recognitionLanguages: recognitionLanguages,
            groups: groups.map(CaptureLiveTextGroup.init)
        )
    }
}
#endif
