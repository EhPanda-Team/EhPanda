//
//  ReadingViewModel.swift
//  EhPanda
//
//  Created by zackie on 2025-07-28 for improved Reading view architecture
//

import SwiftUI
import Combine
import Kingfisher

// MARK: - Reading View Model
final class ReadingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var enablesLiveText = false
    @Published var liveTextGroups = [Int: [LiveTextGroup]]()
    @Published var focusedLiveTextGroup: LiveTextGroup?
    @Published var autoPlayPolicy: AutoPlayPolicy = .off
    @Published var webImageLoadSuccessIndices = Set<Int>()
    
    // MARK: - Private Properties
    private var autoPlayTimer: Timer?
    private var liveTextRequests = [VNRequest]()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupObservers()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup Methods
    func setup(with state: ReadingReducer.State, setting: Setting) {
        // Initialize with current state
        webImageLoadSuccessIndices = state.webImageLoadSuccessIndices
        
        // Setup live text if needed
        if enablesLiveText {
            analyzeExistingImages(indices: Array(webImageLoadSuccessIndices))
        }
    }
    
    private func setupObservers() {
        // Observe live text state changes
        $enablesLiveText
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.analyzeExistingImages(indices: Array(self?.webImageLoadSuccessIndices ?? []))
                } else {
                    self?.clearLiveText()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auto Play Management
    func setAutoPlayPolicy(_ policy: AutoPlayPolicy, pageUpdater: @escaping () -> Void) {
        Logger.info("Setting auto play policy", context: ["policy": policy])
        
        autoPlayPolicy = policy
        autoPlayTimer?.invalidate()
        
        if policy.isEnabled {
            autoPlayTimer = Timer.scheduledTimer(withTimeInterval: policy.timeInterval, repeats: true) { _ in
                pageUpdater()
            }
        }
    }
    
    func stopAutoPlay() {
        autoPlayTimer?.invalidate()
        autoPlayPolicy = .off
    }
    
    // MARK: - Live Text Management
    func setFocusedLiveTextGroup(_ group: LiveTextGroup) {
        Logger.info("Setting focused live text group", context: ["group": group])
        focusedLiveTextGroup = group
    }
    
    func analyzeImageForLiveText(
        index: Int,
        imageURL: URL?,
        recognitionLanguages: [String]?
    ) {
        Logger.info("Analyzing image for live text", context: ["index": index])
        
        guard enablesLiveText,
              liveTextGroups[index] == nil,
              let imageURL = imageURL,
              let key = imageURL.absoluteString as String?
        else {
            Logger.info("Skipping live text analysis", context: [
                "enablesLiveText": enablesLiveText,
                "alreadyAnalyzed": liveTextGroups[index] != nil,
                "hasURL": imageURL != nil
            ])
            return
        }
        
        KingfisherManager.shared.cache.retrieveImage(forKey: key) { [weak self] result in
            switch result {
            case .success(let result):
                if let image = result.image, let cgImage = image.cgImage {
                    self?.performLiveTextAnalysis(
                        cgImage: cgImage,
                        size: image.size,
                        index: index,
                        recognitionLanguages: recognitionLanguages
                    )
                } else {
                    Logger.info("Live text analysis: image not found", context: ["index": index])
                }
            case .failure(let error):
                Logger.info("Live text analysis failed", context: [
                    "index": index,
                    "error": error
                ] as [String: Any])
            }
        }
    }
    
    private func analyzeExistingImages(indices: [Int]) {
        indices.forEach { index in
            // This would be called with proper parameters from the main view
            // analyzeImageForLiveText(index: index, imageURL: nil, recognitionLanguages: nil)
        }
    }
    
    private func performLiveTextAnalysis(
        cgImage: CGImage,
        size: CGSize,
        index: Int,
        recognitionLanguages: [String]?
    ) {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleLiveTextRecognition(
                request: request,
                error: error,
                size: size,
                index: index
            )
        }
        
        textRecognitionRequest.usesLanguageCorrection = true
        textRecognitionRequest.preferBackgroundProcessing = true
        
        if let languages = recognitionLanguages {
            textRecognitionRequest.recognitionLanguages = languages
        }
        
        liveTextRequests.append(textRecognitionRequest)
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try requestHandler.perform([textRecognitionRequest])
            } catch {
                self?.removeLiveTextRequest(textRecognitionRequest)
                Logger.info("Live text recognition failed", context: ["error": error])
            }
        }
    }
    
    private func handleLiveTextRecognition(
        request: VNRequest,
        error: Error?,
        size: CGSize,
        index: Int
    ) {
        removeLiveTextRequest(request)
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let blocks = self?.processLiveTextObservations(observations) ?? []
            let groups = self?.groupLiveTextBlocks(blocks, size: size) ?? []
            
            DispatchQueue.main.async {
                self?.liveTextGroups[index] = groups
            }
        }
    }
    
    private func processLiveTextObservations(_ observations: [VNRecognizedTextObservation]) -> [LiveTextBlock] {
        return observations.compactMap { observation in
            guard let recognizedText = observation.topCandidates(1).first?.string else {
                return nil
            }
            
            return LiveTextBlock(
                text: recognizedText,
                bounds: LiveTextBounds(
                    topLeft: observation.topLeft.verticalReversed,
                    topRight: observation.topRight.verticalReversed,
                    bottomLeft: observation.bottomLeft.verticalReversed,
                    bottomRight: observation.bottomRight.verticalReversed
                )
            )
        }
    }
    
    private func groupLiveTextBlocks(_ blocks: [LiveTextBlock], size: CGSize) -> [LiveTextGroup] {
        var groupData = [[LiveTextBlock]]()
        
        blocks.forEach { newBlock in
            if let groupIndex = findMatchingGroup(for: newBlock, in: groupData, size: size) {
                groupData[groupIndex].append(newBlock)
            } else {
                groupData.append([newBlock])
            }
        }
        
        return groupData.compactMap(LiveTextGroup.init)
    }
    
    private func findMatchingGroup(
        for newBlock: LiveTextBlock,
        in groupData: [[LiveTextBlock]],
        size: CGSize
    ) -> Int? {
        return groupData.firstIndex { blocks in
            blocks.contains { existingBlock in
                areLiveTextBlocksCompatible(existingBlock, newBlock, size: size)
            }
        }
    }
    
    private func areLiveTextBlocksCompatible(
        _ block1: LiveTextBlock,
        _ block2: LiveTextBlock,
        size: CGSize
    ) -> Bool {
        let angle1 = block1.bounds.getAngle(size)
        let angle2 = block2.bounds.getAngle(size)
        let angleDiff = abs(angle1 - angle2).truncatingRemainder(dividingBy: 360.0)
        let isAngleValid = angleDiff < 5 || angleDiff > (360 - 5)
        
        let height1 = block1.bounds.getHeight(size)
        let height2 = block2.bounds.getHeight(size)
        let isHeightValid = abs(height1 - height2) < (min(height1, height2) / 2)
        
        guard isAngleValid && isHeightValid else { return false }
        
        return arePolygonsIntersecting(
            lhs: block1.bounds.expandingHalfHeight(size).edges,
            rhs: block2.bounds.expandingHalfHeight(size).edges
        )
    }
    
    private func arePolygonsIntersecting(lhs: [CGPoint], rhs: [CGPoint]) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty, lhs.count == rhs.count else { return false }
        
        for points in [lhs, rhs] {
            for index1 in 0..<points.count {
                let index2 = (index1 + 1) % points.count
                let point1 = points[index1]
                let point2 = points[index2]
                
                let basis = CGPoint(x: point2.y - point1.y, y: point1.x - point2.x)
                
                let (minA, maxA) = getProjectionRange(points: lhs, basis: basis)
                let (minB, maxB) = getProjectionRange(points: rhs, basis: basis)
                
                if maxA < minB || maxB < minA {
                    return false
                }
            }
        }
        return true
    }
    
    private func getProjectionRange(points: [CGPoint], basis: CGPoint) -> (min: Double, max: Double) {
        let projections = points.map { point in
            basis.x * point.x + basis.y * point.y
        }
        return (projections.min() ?? 0, projections.max() ?? 0)
    }
    
    private func clearLiveText() {
        liveTextGroups.removeAll()
        focusedLiveTextGroup = nil
        cancelLiveTextRequests()
    }
    
    private func removeLiveTextRequest(_ request: VNRequest) {
        if let index = liveTextRequests.firstIndex(of: request) {
            liveTextRequests.remove(at: index)
        }
    }
    
    private func cancelLiveTextRequests() {
        Logger.info("Canceling live text requests", context: [
            "count": liveTextRequests.count
        ])
        liveTextRequests.forEach { $0.cancel() }
        liveTextRequests.removeAll()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        autoPlayTimer?.invalidate()
        cancelLiveTextRequests()
        cancellables.removeAll()
    }
}

// MARK: - Extensions
private extension CGPoint {
    var verticalReversed: CGPoint {
        CGPoint(x: x, y: 1 - y)
    }
}

// MARK: - Import Vision Framework
import Vision 