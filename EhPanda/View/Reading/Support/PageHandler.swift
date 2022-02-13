//
//  PageHandler.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/09.
//

import SwiftUI

final class PageHandler: ObservableObject {
    @Published var sliderValue: Float = 1 {
        didSet {
            Logger.info("sliderValue.didSet", context: ["sliderValue": sliderValue])
        }
    }

    func mapFromPager(index: Int, pageCount: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index + 1 }
        guard index > 0 else { return 1 }

        let result = setting.exceptCover ? index * 2 : index * 2 + 1

        if result + 1 == pageCount {
            return pageCount
        } else {
            return result
        }
    }

    func mapToPager(index: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index - 1 }
        guard index > 1 else { return 0 }

        return setting.exceptCover ? index / 2 : (index - 1) / 2
    }
}
