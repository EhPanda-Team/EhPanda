//
//  ColorCodable.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/03.
//  Copied from https://brunowernimont.me/howtos/make-swiftui-color-codable
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit
#endif

fileprivate extension Color {
    #if os(macOS)
    typealias SystemColor = NSColor
    #else
    typealias SystemColor = UIColor
    #endif

    struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    var colorComponents: RGBA? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if os(macOS)
        SystemColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // Note that non RGB color will raise an exception,
        // that I don't now how to catch because it is an Objc exception.
        #else
        guard SystemColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            // Pay attention that the color should be convertible into RGB format
            // Colors using hue, saturation and brightness won't work
            return nil
        }
        #endif

        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)

        self.init(red: red, green: green, blue: blue)
    }

    public func encode(to encoder: Encoder) throws {
        guard let colorComponents = self.colorComponents else {
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(colorComponents.red, forKey: .red)
        try container.encode(colorComponents.green, forKey: .green)
        try container.encode(colorComponents.blue, forKey: .blue)
    }
}
