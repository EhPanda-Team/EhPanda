//
//  LiveTextHandler.swift
//  EhPanda
//
//  swiftlint:disable line_length
//  Refercence
//  https://www.codeproject.com/Articles/15573/2D-Polygon-Collision-Detection
//  https://developer.apple.com/documentation/vision/recognizing_text_in_images
//  https://github.com/TelegramMessenger/Telegram-iOS/blob/2a32c871882c4e1b1ccdecd34fccd301723b30d9/submodules/Translate/Sources/Translate.swift
//  https://github.com/TelegramMessenger/Telegram-iOS/blob/0be460b147321b7455247aedca81ca819702959d/submodules/ImageContentAnalysis/Sources/ImageContentAnalysis.swift
//  swiftlint:enable line_length
//

import Vision
import SwiftUI
import Foundation
import Observation

@Observable
@MainActor
final class LiveTextHandler {
    var enablesLiveText = false
    var liveTextGroups = [Int: [LiveTextGroup]]()
    private(set) var focusedLiveTextGroup: LiveTextGroup?

    @ObservationIgnored
    private var analysisTasks = [Int: Task<Void, Never>]()

    isolated deinit {
        cancelRequests()
    }

    func cancelRequests() {
        Logger.info("cancelRequests", context: [
            "processingRequestsCount": analysisTasks.count
        ])
        analysisTasks.values.forEach { task in
            task.cancel()
        }
        analysisTasks.removeAll()
    }

    func setFocusedLiveTextGroup(_ group: LiveTextGroup) {
        Logger.info("setFocusedLiveTextGroup", context: ["group": group])
        focusedLiveTextGroup = group
    }

    func analyzeImage(_ cgImage: CGImage, size: CGSize, index: Int, recognitionLanguages: [String]?) {
        Logger.info("analyzeImage", context: [
            "index": index, "recognitionLanguages": recognitionLanguages as Any
        ])

        analysisTasks[index]?.cancel()
        analysisTasks[index] = Task { [weak self] in
            do {
                let groups = try await Self.recognizeTextGroups(
                    in: cgImage,
                    size: size,
                    recognitionLanguages: recognitionLanguages
                )
                guard !Task.isCancelled else { return }
                self?.liveTextGroups[index] = groups
            } catch is CancellationError {
            } catch {
                Logger.info("Unable to perform the requests.", context: [
                    "error": error, "index": index
                ])
            }
            self?.analysisTasks[index] = nil
        }
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

        var groupData = [[LiveTextBlock]]()
        for newItem in blocks {
            try Task.checkCancellation()

            if let groupIndex = groupData.firstIndex(where: { items in
                items.first { item in
                    let angle = abs(item.bounds.getAngle(size) - newItem.bounds.getAngle(size))
                        .truncatingRemainder(dividingBy: 360.0)
                    let isAngleValid = angle < 5 || angle > (360 - 5)
                    let aHeight = item.bounds.getHeight(size)
                    let bHeight = newItem.bounds.getHeight(size)
                    let isHeightValid = abs(aHeight - bHeight) < (min(aHeight, bHeight) / 2)

                    guard isAngleValid && isHeightValid else { return false }
                    return polygonsIntersecting(
                        lhs: item.bounds.expandingHalfHeight(size).edges,
                        rhs: newItem.bounds.expandingHalfHeight(size).edges
                    )
                } != nil
            }) {
                groupData[groupIndex].append(newItem)
            } else {
                groupData.append([newItem])
            }
        }

        return groupData.compactMap(LiveTextGroup.init)
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
