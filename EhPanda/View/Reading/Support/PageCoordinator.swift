//
//  PageCoordinator.swift
//  EhPanda
//
//  Created by zackie on 2025-07-28 for improved Reading view architecture
//

import SwiftUI
import Combine

// MARK: - Page Coordinator
final class PageCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var sliderValue: Float = 1.0 {
        didSet {
            Logger.info("Slider value changed", context: ["sliderValue": sliderValue])
        }
    }
    
    // MARK: - Private Properties
    private var pageCount: Int = 1
    private var setting: Setting = .init()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private var pageConfig: PageConfiguration = .init()
    
    // MARK: - Initialization
    init() {
        setupObservers()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup Methods
    func setup(pageCount: Int, setting: Setting) {
        self.pageCount = pageCount
        self.setting = setting
        self.pageConfig = PageConfiguration(setting: setting)
        
        Logger.info("Page coordinator setup", context: [
            "pageCount": pageCount,
            "readingDirection": setting.readingDirection.rawValue
        ])
    }
    
    func setup(pageCount: Int, setting: Setting, initialPage: Int) {
        setup(pageCount: pageCount, setting: setting)
        
        // Initialize slider value with reading progress
        let validProgress = max(1, min(initialPage, pageCount))
        sliderValue = Float(validProgress)
        
        Logger.info("Page coordinator setup with initial page", context: [
            "initialPage": initialPage,
            "validProgress": validProgress
        ])
    }
    
    private func setupObservers() {
        // Observe slider value changes for page navigation
        $sliderValue
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.handleSliderValueChange(newValue)
            }
            .store(in: &cancellables)
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
    
    // MARK: - Page Mapping Methods
    
    /// Maps from pager index to page number
    func mapFromPager(
        index: Int,
        pageCount: Int,
        setting: Setting,
        isLandscape: Bool = DeviceUtil.isLandscape
    ) -> Int {
        Logger.info("Map from pager", context: [
            "index": index,
            "pageCount": pageCount,
            "isDualPage": isDualPageMode(setting: setting, isLandscape: isLandscape)
        ])
        
        guard isDualPageMode(setting: setting, isLandscape: isLandscape) else {
            return index + 1
        }
        
        guard index > 0 else { return 1 }
        
        let result = setting.exceptCover ? index * 2 : index * 2 + 1
        
        // Handle edge case for last page in dual mode
        if result + 1 == pageCount {
            return pageCount
        } else {
            return result
        }
    }
    
    /// Maps from page number to pager index
    func mapToPager(
        index: Int,
        setting: Setting,
        isLandscape: Bool = DeviceUtil.isLandscape
    ) -> Int {
        Logger.info("Map to pager", context: [
            "index": index,
            "isDualPage": isDualPageMode(setting: setting, isLandscape: isLandscape)
        ])
        
        guard isDualPageMode(setting: setting, isLandscape: isLandscape) else {
            return index - 1
        }
        
        guard index > 1 else { return 0 }
        
        return setting.exceptCover ? index / 2 : (index - 1) / 2
    }
    
    // MARK: - Page Navigation
    
    /// Updates the current page and synchronizes slider
    func updateCurrentPage(_ pageIndex: Int) {
        let clampedIndex = max(1, min(pageIndex, pageCount))
        sliderValue = Float(clampedIndex)
        
        Logger.info("Updated current page", context: [
            "pageIndex": pageIndex,
            "clampedIndex": clampedIndex
        ])
    }
    
    /// Handles page navigation with bounds checking
    func navigatePage(offset: Int, currentIndex: Int) -> Int {
        let newIndex = currentIndex + offset
        let clampedIndex = max(0, min(newIndex, pageCount - 1))
        
        Logger.info("Navigate page", context: [
            "offset": offset,
            "currentIndex": currentIndex,
            "newIndex": newIndex,
            "clampedIndex": clampedIndex
        ])
        
        return clampedIndex
    }
    
    /// Gets valid page range for the current configuration
    func getValidPageRange() -> ClosedRange<Int> {
        return 1...pageCount
    }
    
    /// Checks if a page index is valid
    func isValidPageIndex(_ index: Int) -> Bool {
        return index >= 1 && index <= pageCount
    }
    
    // MARK: - Dual Page Support
    
    /// Determines if dual page mode should be active
    func isDualPageMode(setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Bool {
        return isLandscape && 
               setting.enablesDualPageMode && 
               setting.readingDirection != .vertical
    }
    
    /// Gets the page configuration for dual page mode
    func getDualPageConfiguration(
        for index: Int,
        setting: Setting,
        isLandscape: Bool = DeviceUtil.isLandscape
    ) -> DualPageConfiguration {
        let isDualPage = isDualPageMode(setting: setting, isLandscape: isLandscape)
        let isReversed = setting.readingDirection == .rightToLeft
        let isFirstSingle = setting.exceptCover
        let isFirstPageAndSingle = index == 1 && isFirstSingle
        
        let firstIndex = isDualPage && isReversed && !isFirstPageAndSingle ? index + 1 : index
        let secondIndex = firstIndex + (isReversed ? -1 : 1)
        
        let isValidFirstRange = firstIndex >= 1 && firstIndex <= pageCount
        let isValidSecondRange = isFirstSingle 
            ? secondIndex >= 2 && secondIndex <= pageCount 
            : secondIndex >= 1 && secondIndex <= pageCount
        
        return DualPageConfiguration(
            firstIndex: firstIndex,
            secondIndex: secondIndex,
            isFirstAvailable: isValidFirstRange,
            isSecondAvailable: !isFirstPageAndSingle && isValidSecondRange && isDualPage,
            isDualPage: isDualPage
        )
    }
    
    // MARK: - Auto Play Support
    
    /// Gets the next page index for auto play
    func getNextAutoPlayIndex(currentIndex: Int) -> Int? {
        let nextIndex = currentIndex + 1
        guard nextIndex < pageCount else { return nil }
        return nextIndex
    }
    
    // MARK: - Private Methods
    
    private func handleSliderValueChange(_ newValue: Float) {
        Logger.info("Handle slider value change", context: [
            "newValue": newValue,
            "pageCount": pageCount
        ])
        
        // Validate slider value
        let clampedValue = max(1, min(newValue, Float(pageCount)))
        if clampedValue != newValue {
            DispatchQueue.main.async { [weak self] in
                self?.sliderValue = clampedValue
            }
        }
    }
}

// MARK: - Supporting Types

/// Configuration for dual page display
struct DualPageConfiguration {
    let firstIndex: Int
    let secondIndex: Int
    let isFirstAvailable: Bool
    let isSecondAvailable: Bool
    let isDualPage: Bool
}

/// Configuration for page behavior
private struct PageConfiguration {
    let enablesDualPage: Bool
    let exceptCover: Bool
    let readingDirection: ReadingDirection
    
    init(setting: Setting? = nil) {
        self.enablesDualPage = setting?.enablesDualPageMode ?? false
        self.exceptCover = setting?.exceptCover ?? false
        self.readingDirection = setting?.readingDirection ?? .leftToRight
    }
}

// MARK: - Page Coordinator Extensions

extension PageCoordinator {
    /// Gets container data source for the current page configuration
    func getContainerDataSource(
        pageCount: Int,
        setting: Setting,
        isLandscape: Bool = DeviceUtil.isLandscape
    ) -> [Int] {
        let defaultData = Array(1...pageCount)
        
        guard isDualPageMode(setting: setting, isLandscape: isLandscape) else {
            return defaultData
        }
        
        let data = setting.exceptCover
            ? [1] + Array(stride(from: 2, through: pageCount, by: 2))
            : Array(stride(from: 1, through: pageCount, by: 2))
        
        Logger.info("Generated container data source", context: [
            "defaultCount": defaultData.count,
            "dualPageCount": data.count,
            "exceptCover": setting.exceptCover
        ])
        
        return data
    }
}

// MARK: - Image Stack Configuration

/// Configuration for image stack display
struct ImageStackConfig {
    let firstIndex: Int
    let secondIndex: Int
    let isFirstAvailable: Bool
    let isSecondAvailable: Bool
    
    init(from dualPageConfig: DualPageConfiguration) {
        self.firstIndex = dualPageConfig.firstIndex
        self.secondIndex = dualPageConfig.secondIndex
        self.isFirstAvailable = dualPageConfig.isFirstAvailable
        self.isSecondAvailable = dualPageConfig.isSecondAvailable
    }
} 