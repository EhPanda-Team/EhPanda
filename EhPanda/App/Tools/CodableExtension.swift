//
//  CodableExtension.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/07/23.
//

import SwiftUI
import BetterCodable

typealias DefaultStringValue = DefaultCodable<DefaultStringValueStrategy>
struct DefaultStringValueStrategy: DefaultCodableStrategy {
    static var defaultValue: String { "" }
}

typealias DefaultDoubleValue = DefaultCodable<DefaultDoubleValueStrategy>
struct DefaultDoubleValueStrategy: DefaultCodableStrategy {
    static var defaultValue: Double { 0 }
}

typealias DefaultIntegerValue = DefaultCodable<DefaultIntegerValueStrategy>
struct DefaultIntegerValueStrategy: DefaultCodableStrategy {
    static var defaultValue: Int { 0 }
}

typealias DefaultColorValue = DefaultCodable<DefaultColorValueStrategy>
struct DefaultColorValueStrategy: DefaultCodableStrategy {
    static var defaultValue: Color { .blue }
}

typealias DefaultGalleryHost = DefaultCodable<DefaultGalleryHostStrategy>
struct DefaultGalleryHostStrategy: DefaultCodableStrategy {
    static var defaultValue: GalleryHost { .ehentai }
}

typealias DefaultListMode = DefaultCodable<DefaultListModeStrategy>
struct DefaultListModeStrategy: DefaultCodableStrategy {
    static var defaultValue: ListMode { isPadWidth ? .thumbnail : .detail }
}

typealias DefaultPreferredColorScheme = DefaultCodable<DefaultPreferredColorSchemeStrategy>
struct DefaultPreferredColorSchemeStrategy: DefaultCodableStrategy {
    static var defaultValue: PreferredColorScheme { .automatic }
}

typealias DefaultAutoLockPolicy = DefaultCodable<DefaultAutoLockPolicyStrategy>
struct DefaultAutoLockPolicyStrategy: DefaultCodableStrategy {
    static var defaultValue: AutoLockPolicy { .never }
}

typealias DefaultIconType = DefaultCodable<DefaultIconTypeStrategy>
struct DefaultIconTypeStrategy: DefaultCodableStrategy {
    static var defaultValue: IconType { .default }
}

typealias DefaultReadingDirection = DefaultCodable<DefaultReadingDirectionStrategy>
struct DefaultReadingDirectionStrategy: DefaultCodableStrategy {
    static var defaultValue: ReadingDirection { .vertical }
}
