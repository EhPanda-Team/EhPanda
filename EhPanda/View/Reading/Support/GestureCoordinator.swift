//
//  GestureCoordinator.swift
//  EhPanda
//
//  Created by zackie on 2025-07-28 for improved Reading view architecture
//

import SwiftUI
import SwiftUIPager

// MARK: - Gesture Coordinator
final class GestureCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var scaleAnchor: UnitPoint = .center
    @Published var scale: Double = 1.0
    @Published var offset: CGSize = .zero
    @Published var dragStartOffset: CGSize = .zero
    
    // MARK: - Private Properties
    private var baseScale: Double = 1.0
    private var baseOffset: CGSize = .zero
    private var currentPanOffset: CGSize = .zero
    private var setting: Setting = .init()
    
    // MARK: - Configuration
    private var gestureConfig: GestureConfiguration = .init()
    
    // MARK: - Setup
    func setup(setting: Setting) {
        self.setting = setting
        gestureConfig = GestureConfiguration(setting: setting)
    }
    
    func cleanup() {
        resetToDefaults()
    }
    
    private func resetToDefaults() {
        scale = 1.0
        offset = .zero
        scaleAnchor = .center
        baseScale = 1.0
        baseOffset = .zero
    }
    
    // MARK: - Gesture Handlers
    
    /// Handles single tap gestures for page navigation or panel toggling
    func handleSingleTap(
        readingDirection: ReadingDirection,
        onPageNavigation: @escaping (Int) -> Void,
        onTogglePanel: @escaping () -> Void
    ) {
        Logger.info("Handle single tap", context: ["readingDirection": readingDirection])
        
        // For vertical reading, always toggle panel
        guard readingDirection != .vertical,
              let touchPoint = TouchHandler.shared.currentPoint
        else {
            onTogglePanel()
            return
        }
        
        let tapRegion = determineTapRegion(point: touchPoint)
        handleTapRegion(tapRegion, readingDirection: readingDirection, onPageNavigation: onPageNavigation, onTogglePanel: onTogglePanel)
    }
    
    /// Handles double tap gestures for zoom
    func handleDoubleTap() {
        Logger.info("Handle double tap", context: [
            "currentScale": scale,
            "doubleTapScale": setting.doubleTapScaleFactor
        ])
        
        let targetScale = scale == 1.0 ? setting.doubleTapScaleFactor : 1.0
        
        if let touchPoint = TouchHandler.shared.currentPoint {
            updateScaleAnchor(for: touchPoint)
        }
        
        withAnimation(.easeInOut(duration: 0.25)) {
            scale = targetScale
            if targetScale == 1.0 {
                offset = .zero
                scaleAnchor = .center
            }
        }
        
        baseScale = scale
        baseOffset = offset
    }
    
    /// Handles magnification (pinch) gestures
    func handleMagnificationChanged(value: Double) {
        Logger.info("Handle magnification changed", context: ["value": value])
        
        if value == 1.0 {
            baseScale = scale
        }
        
        if let touchPoint = TouchHandler.shared.currentPoint {
            updateScaleAnchor(for: touchPoint)
        }
        
        let newScale = min(max(value * baseScale, 1.0), setting.maximumScaleFactor)
        scale = newScale
        constrainOffset()
    }
    
    func handleMagnificationEnded(value: Double) {
        Logger.info("Handle magnification ended", context: ["value": value])
        
        let finalScale = min(max(value * baseScale, 1.0), setting.maximumScaleFactor)
        
        // Snap to 1.0 if very close
        if abs(finalScale - 1.0) < 0.05 {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
                offset = .zero
                scaleAnchor = .center
            }
        } else {
            scale = finalScale
            constrainOffset()
        }
        
        baseScale = scale
        baseOffset = offset
    }
    
    /// Handles drag gestures for panning when zoomed
    func handleDragChanged(value: DragGesture.Value) {
        guard scale > 1.0 else { return }
        
        Logger.info("Handle drag changed", context: [
            "translation": value.translation,
            "scale": scale,
            "currentPanOffset": currentPanOffset
        ])
        
        // Add high sensitivity multiplier for more responsive movement
        let sensitivity: CGFloat = 2.0
        let adjustedTranslation = CGSize(
            width: value.translation.width * sensitivity,
            height: value.translation.height * sensitivity
        )
        
        // Update current pan offset
        currentPanOffset = adjustedTranslation
        
        // Calculate total offset (base + current pan)
        let totalOffset = CGSize(
            width: baseOffset.width + currentPanOffset.width,
            height: baseOffset.height + currentPanOffset.height
        )
        
        // Temporarily remove constraints for testing
        offset = totalOffset
        
        Logger.info("Offset updated", context: [
            "adjustedTranslation": adjustedTranslation,
            "currentPanOffset": currentPanOffset,
            "totalOffset": totalOffset,
            "offset": offset
        ])
    }
    
    func handleDragStarted() {
        guard scale > 1.0 else { return }
        Logger.info("Handle drag started")
        currentPanOffset = .zero
    }
    
    func handleDragEnded(value: DragGesture.Value) {
        guard scale > 1.0 else { return }
        Logger.info("Handle drag ended")
        
        // Update base offset with final position
        baseOffset = offset
        currentPanOffset = .zero
    }
    
    /// Handles control panel dismiss gesture
    func handleControlPanelDismiss(value: DragGesture.Value, dismissAction: @escaping () -> Void) {
        Logger.info("Handle control panel dismiss", context: ["translation": value.translation])
        
        if value.predictedEndTranslation.height > 30 {
            dismissAction()
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func determineTapRegion(point: CGPoint) -> TapRegion {
        let screenWidth = DeviceUtil.absWindowW
        let leftThreshold = screenWidth * 0.2
        let rightThreshold = screenWidth * 0.8
        
        if point.x < leftThreshold {
            return .left
        } else if point.x > rightThreshold {
            return .right
        } else {
            return .center
        }
    }
    
    private func handleTapRegion(
        _ region: TapRegion,
        readingDirection: ReadingDirection,
        onPageNavigation: @escaping (Int) -> Void,
        onTogglePanel: @escaping () -> Void
    ) {
        let isRightToLeft = readingDirection == .rightToLeft
        
        switch region {
        case .left:
            onPageNavigation(isRightToLeft ? 1 : -1)
        case .right:
            onPageNavigation(isRightToLeft ? -1 : 1)
        case .center:
            onTogglePanel()
        }
    }
    
    private func updateScaleAnchor(for point: CGPoint) {
        let normalizedX = min(1, max(0, point.x / DeviceUtil.absWindowW))
        let normalizedY = min(1, max(0, point.y / DeviceUtil.absWindowH))
        scaleAnchor = UnitPoint(x: normalizedX, y: normalizedY)
    }
    
    @discardableResult
    private func constrainOffset(_ newOffset: CGSize? = nil) -> CGSize {
        let targetOffset = newOffset ?? offset
        
        let constrainedWidth = constrainOffsetDimension(
            value: targetOffset.width,
            anchor: scaleAnchor.x,
            screenSize: DeviceUtil.absWindowW
        )
        
        let constrainedHeight = constrainOffsetDimension(
            value: targetOffset.height,
            anchor: scaleAnchor.y,
            screenSize: DeviceUtil.absWindowH
        )
        
        let constrained = CGSize(width: constrainedWidth, height: constrainedHeight)
        
        if newOffset == nil {
            offset = constrained
        }
        
        return constrained
    }
    
    private func constrainOffsetDimension(
        value: Double,
        anchor: Double,
        screenSize: Double
    ) -> Double {
        let margin = screenSize * (scale - 1) / 2
        let leadingMargin = (anchor / 0.5) * margin
        let trailingMargin = ((1 - anchor) / 0.5) * margin
        
        return min(max(value, -trailingMargin), leadingMargin)
    }
    
    private func constrainOffsetSimple(_ newOffset: CGSize) -> CGSize {
        let screenWidth = DeviceUtil.absWindowW
        let screenHeight = DeviceUtil.absWindowH
        
        // Calculate maximum allowed offset based on zoom level with more flexibility
        let maxOffsetX = screenWidth * (scale - 1) * 0.8  // Allow 80% of theoretical max
        let maxOffsetY = screenHeight * (scale - 1) * 0.8
        
        // Apply bounds with more flexibility for natural panning
        let constrainedWidth = min(max(newOffset.width, -maxOffsetX), maxOffsetX)
        let constrainedHeight = min(max(newOffset.height, -maxOffsetY), maxOffsetY)
        
        return CGSize(width: constrainedWidth, height: constrainedHeight)
    }
}

// MARK: - Supporting Types

private enum TapRegion {
    case left, center, right
}

private struct GestureConfiguration {
    let tapRegionThreshold: Double
    let snapToOneThreshold: Double
    let panVelocityThreshold: Double
    
    init(setting: Setting? = nil) {
        self.tapRegionThreshold = 0.2
        self.snapToOneThreshold = 0.05
        self.panVelocityThreshold = 100.0
    }
}

// MARK: - View Extensions for Gesture Support

extension View {
    func readingGestures(
        gestureCoordinator: GestureCoordinator,
        pageCoordinator: PageCoordinator,
        setting: Setting,
        page: Page,
        onTogglePanel: @escaping () -> Void
    ) -> some View {
        let tapGesture = createTapGesture(
            gestureCoordinator: gestureCoordinator,
            pageCoordinator: pageCoordinator,
            setting: setting,
            page: page,
            onTogglePanel: onTogglePanel
        )
        
        let magnificationGesture = createMagnificationGesture(
            gestureCoordinator: gestureCoordinator
        )
        
        let dragGesture = createDragGesture(
            gestureCoordinator: gestureCoordinator
        )
        
        return self
            .gesture(dragGesture, isEnabled: gestureCoordinator.scale > 1)
            .simultaneousGesture(
                tapGesture,
                isEnabled: gestureCoordinator.scale > 1
            )
            .gesture(tapGesture, isEnabled: gestureCoordinator.scale == 1)
            .gesture(magnificationGesture)
    }
    
    private func createTapGesture(
        gestureCoordinator: GestureCoordinator,
        pageCoordinator: PageCoordinator,
        setting: Setting,
        page: Page,
        onTogglePanel: @escaping () -> Void
    ) -> some Gesture {
        let singleTap = TapGesture(count: 1)
            .onEnded {
                gestureCoordinator.handleSingleTap(
                    readingDirection: setting.readingDirection,
                    onPageNavigation: { offset in
                        let newIndex = page.index + offset
                        page.update(.new(index: newIndex))
                        Logger.info("Page navigation", context: ["newIndex": newIndex])
                    },
                    onTogglePanel: onTogglePanel
                )
            }
        
        let doubleTap = TapGesture(count: 2)
            .onEnded {
                gestureCoordinator.handleDoubleTap()
            }
        
        return ExclusiveGesture(doubleTap, singleTap)
    }
    
    private func createMagnificationGesture(
        gestureCoordinator: GestureCoordinator
    ) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureCoordinator.handleMagnificationChanged(value: value)
            }
            .onEnded { value in
                gestureCoordinator.handleMagnificationEnded(value: value)
            }
    }
    
    private func createDragGesture(
        gestureCoordinator: GestureCoordinator
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                gestureCoordinator.handleDragChanged(value: value)
            }
            .onEnded { value in
                gestureCoordinator.handleDragEnded(value: value)
            }
    }
} 