//
//  LiveTextHandler.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/12.
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

final class LiveTextHandler: ObservableObject {
    @Published var enablesLiveText = false
    @Published var liveTextGroups = [Int: [LiveTextGroup]]()
    @Published private(set) var focusedLiveTextGroup: LiveTextGroup?

    private var processingRequests = [VNRequest]()

    deinit {
        cancelRequests()
    }

    func cancelRequests() {
        Logger.info("cancelRequests", context: [
            "processingRequestsCount": processingRequests.count
        ])
        processingRequests.forEach { request in
            request.cancel()
        }
    }

    func setFocusedLiveTextGroup(_ group: LiveTextGroup) {
        Logger.info("setFocusedLiveTextGroup", context: ["group": group])
        focusedLiveTextGroup = group
    }

    func analyzeImage(_ cgImage: CGImage, size: CGSize, index: Int, recognitionLanguages: [String]?) {
        Logger.info("analyzeImage", context: [
            "index": index, "recognitionLanguages": recognitionLanguages as Any
        ])

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let textRecognitionRequest = VNRecognizeTextRequest { [weak self] in
            self?.textRecognitionHandler(request: $0, error: $1, size: size, index: index)
        }
        textRecognitionRequest.usesLanguageCorrection = true
        textRecognitionRequest.preferBackgroundProcessing = true
        if let languages = recognitionLanguages {
            textRecognitionRequest.recognitionLanguages = languages
        }

        processingRequests.append(textRecognitionRequest)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            do {
                try requestHandler.perform([textRecognitionRequest])
            } catch {
                self.removeRequest(textRecognitionRequest)
                Logger.info("Unable to perform the requests.", context: ["error": error])
            }
        }
    }

    private func removeRequest(_ request: VNRequest) {
        if let index = processingRequests.firstIndex(of: request) {
            processingRequests.remove(at: index)
        }
    }

    private func textRecognitionHandler(request: VNRequest, error: Error?, size: CGSize, index: Int) {
        Logger.info("textRecognitionHandler", context: [
            "request": request, "error": error as Any, "index": index
        ])
        removeRequest(request)

        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let blocks: [LiveTextBlock] = observations.compactMap { observation in
                guard let recognizedText = observation.topCandidates(1).first?.string else { return nil }
                return .init(
                    text: recognizedText,
                    bounds: .init(
                        topLeft: observation.topLeft.verticalReversed,
                        topRight: observation.topRight.verticalReversed,
                        bottomLeft: observation.bottomLeft.verticalReversed,
                        bottomRight: observation.bottomRight.verticalReversed
                    )
                )
            }

            var groupData = [[LiveTextBlock]]()
            blocks.forEach { newItem in
                if let groupIndex = groupData.firstIndex(where: { items in
                    items.first { item in
                        let angle = abs(item.bounds.getAngle(size) - newItem.bounds.getAngle(size))
                            .truncatingRemainder(dividingBy: 360.0)
                        let isAngleValid = angle < 5 || angle > (360 - 5)
                        let aHeight = item.bounds.getHeight(size)
                        let bHeight = newItem.bounds.getHeight(size)
                        let isHeightValid = abs(aHeight - bHeight) < (min(aHeight, bHeight) / 2)

                        guard isAngleValid && isHeightValid else { return false }
                        return self.polygonsIntersecting(
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

            let groups = groupData.compactMap(LiveTextGroup.init)
            DispatchQueue.main.async {
                self.liveTextGroups[index] = groups
            }
        }
    }

    private func polygonsIntersecting(lhs: [CGPoint], rhs: [CGPoint]) -> Bool {
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
