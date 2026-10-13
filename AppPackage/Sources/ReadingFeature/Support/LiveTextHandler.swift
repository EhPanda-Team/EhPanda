//  reason: the reference URLs below exceed the line-length limit and cannot wrap
//  swiftlint:disable line_length
//  Reference
//  https://www.codeproject.com/Articles/15573/2D-Polygon-Collision-Detection
//  https://developer.apple.com/documentation/vision/recognizing_text_in_images
//  https://github.com/TelegramMessenger/Telegram-iOS/blob/2a32c871882c4e1b1ccdecd34fccd301723b30d9/submodules/Translate/Sources/Translate.swift
//  https://github.com/TelegramMessenger/Telegram-iOS/blob/0be460b147321b7455247aedca81ca819702959d/submodules/ImageContentAnalysis/Sources/ImageContentAnalysis.swift
//  swiftlint:enable line_length
//

import AppModels
import Foundation
import LiveTextTranslation
import Observation
import OSLogExt
import SwiftUI
import Vision
#if DEBUG
import Dependencies
#endif

private let logger = Logger(category: .init(describing: LiveTextHandler.self))

@Observable
@MainActor
final class LiveTextHandler {
    var enablesLiveText = false {
        didSet {
            if !enablesLiveText {
                translator.endActivation()
            }
        }
    }
    var liveTextGroups = [Int: [LiveTextGroup]]()
    private(set) var focusedLiveTextGroup: LiveTextGroup?
    let translator = LiveTextTranslator()

    @ObservationIgnored
    private var analysisTasks = [Int: Task<Void, Never>]()

    #if DEBUG
    /// The capture launch's Live Text, which decides what the reader recognizes (17-06).
    @ObservationIgnored
    @Dependency(\.liveTextCapture) private var capture
    #endif

    init() {
        #if DEBUG
        // A capture of the reading-live-text screen opens the reader with Live Text on, as a
        // person's tap on the toolbar's Live Text button leaves it.
        enablesLiveText = capture != nil
        #endif
    }

    isolated deinit {
        cancelRequests()
    }

    func cancelRequests() {
        analysisTasks.values.forEach { task in
            task.cancel()
        }
        analysisTasks.removeAll()
        translator.cancel()
    }

    /// Whether `page` is still to be recognized, or translated.
    func needsAnalysis(page: Int) -> Bool {
        liveTextGroups[page] == nil || (translatesPages && translator.needsTranslation(page: page))
    }

    /// Whether recognized pages are translated. A capture launch never translates, so what it shows
    /// does not depend on the system's translation models (261013-ja0, Q3).
    private var translatesPages: Bool {
        #if DEBUG
        capture == nil
        #else
        true
        #endif
    }

    func setFocusedLiveTextGroup(_ group: LiveTextGroup) {
        focusedLiveTextGroup = group
    }

    #if DEBUG
    /// Whether a capture launch answers Live Text for `page` of gallery `gid` itself, so the reader
    /// must not recognize the page.
    ///
    /// A capture shows its saved groups on its own page and leaves every other page without Live
    /// Text; only a recording lets the reader recognize the capture's page as usual. Outside a
    /// capture the reader always recognizes.
    func capturesLiveText(gid: String, page: Int) -> Bool {
        guard let capture else {
            return false
        }
        switch capture.decision(gid: gid, page: page) {
        case .show(let groups):
            liveTextGroups[page] = groups
            return true
        case .skip:
            return true
        case .recognize:
            return false
        }
    }
    #endif

    func analyzeImage(_ cgImage: CGImage, size: CGSize, page: Int, recognitionLanguages: [String]?) {
        if let groups = liveTextGroups[page] {
            translate(groups, on: cgImage, page: page, recognitionLanguages: recognitionLanguages)
            return
        }
        analysisTasks[page]?.cancel()
        analysisTasks[page] = Task { [weak self] in
            do {
                let groups = try await Self.recognizeTextGroups(
                    in: cgImage,
                    size: size,
                    recognitionLanguages: recognitionLanguages
                )
                guard !Task.isCancelled else { return }
                self?.liveTextGroups[page] = groups
                self?.translate(groups, on: cgImage, page: page, recognitionLanguages: recognitionLanguages)
                #if DEBUG
                self?.capture?.recognized(groups, page: page, recognitionLanguages: recognitionLanguages)
                #endif
            } catch is CancellationError {
            } catch {
                logger.error("Live Text failed, page \(page, privacy: .public): \(error, privacy: .public)")
            }
        }
    }

    private func translate(_ groups: [LiveTextGroup], on cgImage: CGImage, page: Int, recognitionLanguages: [String]?) {
        guard translatesPages else {
            return
        }
        translator.translate(groups, on: cgImage, page: page, recognitionLanguages: recognitionLanguages)
    }

    @concurrent
    private static func recognizeTextGroups(
        in cgImage: CGImage,
        size: CGSize,
        recognitionLanguages: [String]?
    ) async throws -> [LiveTextGroup] {
        var request = RecognizeTextRequest()
        request.usesLanguageCorrection = true
        if let recognitionLanguages {
            request.recognitionLanguages = recognitionLanguages.map {
                Locale.Language(identifier: $0)
            }
        } else {
            // Without a language Vision reads every page as English; detecting it reads the page in
            // its own language, which translation needs.
            request.automaticallyDetectsLanguage = true
        }

        let observations = try await request.perform(on: cgImage)
        try Task.checkCancellation()

        let blocks: [LiveTextBlock] = observations.compactMap { observation in
            guard let recognizedText = observation.topCandidates(1).first?.string else { return nil }
            return .init(
                text: recognizedText,
                bounds: .init(
                    topLeft: observation.topLeft.cgPoint.verticalReversed,
                    topRight: observation.topRight.cgPoint.verticalReversed,
                    bottomLeft: observation.bottomLeft.cgPoint.verticalReversed,
                    bottomRight: observation.bottomRight.cgPoint.verticalReversed
                )
            )
        }

        try Task.checkCancellation()
        return groups(of: blocks, size: size)
    }

    /// Groups `blocks`, the recognized lines, into passages: two lines belong together when they run
    /// the same way, are about as tall, stack, and come within half a line of each other, and a passage
    /// takes every line linked to it through others, whatever order the lines were recognized in. Its
    /// lines read from the top down.
    ///
    /// A line's angle is only as sure as its shape allows: a word's box can tilt by about its height over
    /// its width without its glyphs telling otherwise, and Vision tilts hand-lettered short words by as
    /// much. Two lines run the same way when their angles differ by less than the less certain of them
    /// allows, and never by less than ``minimumAngleTolerance``.
    ///
    /// Lines stack when they overlap along their direction by ``minimumOverlapShare`` of the shorter
    /// one, as a passage's lines do however they are aligned; lines that only touch at a corner, as in
    /// two balloons joined side by side, belong to different passages.
    nonisolated static func groups(of blocks: [LiveTextBlock], size: CGSize) -> [LiveTextGroup] {
        var parents = Array(blocks.indices)
        func passage(of index: Int) -> Int {
            var root = index
            while parents[root] != root {
                root = parents[root]
            }
            return root
        }
        for first in blocks.indices {
            for second in blocks.indices.dropFirst(first + 1)
            where belongTogether(blocks[first], blocks[second], size: size) {
                parents[passage(of: second)] = passage(of: first)
            }
        }
        var passages = [Int: [LiveTextBlock]]()
        var order = [Int]()
        for (number, block) in blocks.enumerated() {
            let root = passage(of: number)
            if passages[root] == nil {
                order.append(root)
            }
            passages[root, default: []].append(block)
        }
        return order.compactMap { root in
            passages[root].flatMap({ LiveTextGroup(blocks: fromTheTopDown($0, size: size)) })
        }
    }

    /// The least difference in degrees two lines' angles are allowed, however sure both are.
    nonisolated static let minimumAngleTolerance = 5.0
    /// The least share of the shorter of two lines they overlap along their direction to stack.
    nonisolated static let minimumOverlapShare = 0.5

    nonisolated private static func belongTogether(
        _ first: LiveTextBlock,
        _ second: LiveTextBlock,
        size: CGSize
    ) -> Bool {
        let difference = abs(first.bounds.getAngle(size) - second.bounds.getAngle(size))
            .truncatingRemainder(dividingBy: 360)
        let tolerance = max(
            minimumAngleTolerance,
            angleUncertainty(of: first, size: size),
            angleUncertainty(of: second, size: size)
        )
        let isAngleValid = difference < tolerance || difference > 360 - tolerance
        let firstHeight = first.bounds.getHeight(size)
        let secondHeight = second.bounds.getHeight(size)
        let isHeightValid = abs(firstHeight - secondHeight) < min(firstHeight, secondHeight) / 2
        guard isAngleValid && isHeightValid && overlapShare(of: first, and: second, size: size) >= minimumOverlapShare
        else {
            return false
        }
        return polygonsIntersecting(
            lhs: first.bounds.expandingHalfHeight(size).edges,
            rhs: second.bounds.expandingHalfHeight(size).edges
        )
    }

    /// How much of the shorter of two lines they overlap along the first one's direction.
    nonisolated private static func overlapShare(
        of first: LiveTextBlock,
        and second: LiveTextBlock,
        size: CGSize
    ) -> Double {
        let radian = first.bounds.getRadian(size)
        func extent(of block: LiveTextBlock) -> ClosedRange<Double> {
            let positions = block.bounds.edges.map { point in
                point.x * size.width * cos(radian) + point.y * size.height * sin(radian)
            }
            return (positions.min() ?? 0)...(positions.max() ?? 0)
        }
        let firstExtent = extent(of: first)
        let secondExtent = extent(of: second)
        let overlap = min(firstExtent.upperBound, secondExtent.upperBound)
            - max(firstExtent.lowerBound, secondExtent.lowerBound)
        let shorter = min(
            firstExtent.upperBound - firstExtent.lowerBound,
            secondExtent.upperBound - secondExtent.lowerBound
        )
        return shorter > 0 ? overlap / shorter : 0
    }

    /// A passage's lines in order down the passage, across the first line's direction.
    nonisolated private static func fromTheTopDown(_ lines: [LiveTextBlock], size: CGSize) -> [LiveTextBlock] {
        guard let radian = lines.first?.bounds.getRadian(size) else {
            return lines
        }
        func depth(of line: LiveTextBlock) -> Double {
            let center = line.bounds.edges.reduce(CGPoint.zero) { sum, point in
                CGPoint(x: sum.x + point.x * size.width / 4, y: sum.y + point.y * size.height / 4)
            }
            return -center.x * sin(radian) + center.y * cos(radian)
        }
        return lines.sorted(by: { depth(of: $0) < depth(of: $1) })
    }

    /// How far in degrees a line's box may be tilted without its glyphs telling: its height over its width.
    nonisolated private static func angleUncertainty(of block: LiveTextBlock, size: CGSize) -> Double {
        let width = block.bounds.getWidth(size)
        guard width > 0 else {
            return 90
        }
        return atan(block.bounds.getHeight(size) / width) * 180 / .pi
    }

    nonisolated private static func polygonsIntersecting(lhs: [CGPoint], rhs: [CGPoint]) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty, lhs.count == rhs.count else { return false }
        for points in [lhs, rhs] {
            for index1 in 0..<points.count {
                let index2 = (index1 + 1) % points.count
                let point1 = points[index1]
                let point2 = points[index2]

                let basis = CGPoint(x: point2.y - point1.y, y: point1.x - point2.x)

                var minA: Double?
                var maxA: Double?
                lhs.forEach { point in
                    let projection = basis.x * point.x + basis.y * point.y
                    if let unwrappedMinA = minA {
                        minA = min(unwrappedMinA, projection)
                    } else {
                        minA = projection
                    }
                    if let unwrappedMaxA = maxA {
                        maxA = max(unwrappedMaxA, projection)
                    } else {
                        maxA = projection
                    }
                }

                var minB: Double?
                var maxB: Double?
                rhs.forEach { point in
                    let projection = basis.x * point.x + basis.y * point.y
                    if let unwrappedMinB = minB {
                        minB = min(unwrappedMinB, projection)
                    } else {
                        minB = projection
                    }
                    if let unwrappedMaxB = maxB {
                        maxB = max(unwrappedMaxB, projection)
                    } else {
                        maxB = projection
                    }
                }

                guard let minA = minA, let maxA = maxA,
                      let minB = minB, let maxB = maxB
                else { return false }

                if maxA < minB || maxB < minA {
                    return false
                }
            }
        }
        return true
    }
}

private extension CGPoint {
    var verticalReversed: CGPoint {
        .init(x: x, y: 1 - y)
    }
}
