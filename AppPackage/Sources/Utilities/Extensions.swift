import SwiftUI
import UIKit
import Foundation

// MARK: Encodable
extension Encodable {
    public func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

// MARK: UIApplication
extension UIApplication {
    @MainActor
    public func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: Data
extension Data {
    public func toObject<O: Decodable>() -> O? {
        try? JSONDecoder().decode(O.self, from: self)
    }
    public var utf8InvalidCharactersRipped: Data {
        var data = self
        data.append(0)

        let str = Array(data).withUnsafeBufferPointer { ptr -> String? in
            guard let address = ptr.baseAddress else { return nil }
            return String(cString: address)
        }
        guard let string = str else { return data }
        data = string.data(using: .utf8) ?? self
        return data
    }
}

// MARK: Float
extension Float {
    public var halfRounded: Float {
        let lowerbound = Int(self)
        let upperbound = lowerbound + 1
        let decimal: Float = self - Float(lowerbound)

        if decimal < 0.25 {
            return Float(lowerbound)
        } else if decimal >= 0.25 && decimal < 0.75 {
            return Float(lowerbound) + 0.5
        } else {
            return Float(upperbound)
        }
    }
}

// MARK: String
extension String {
    public var isInteger: Bool {
        Int(self) != nil
    }
    public var isValidGID: Bool {
        !isEmpty && isInteger
    }
    public var localizedKey: LocalizedStringKey {
        .init(self)
    }
    public var emojisRipped: String {
        unicodeScalars
            .filter { !$0.properties.isEmojiPresentation }
            .reduce("") { $0 + .init($1) }
    }

    public var urlEncoded: String {
        addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
    }

    public var isValidURL: Bool {
        if let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) {
            if let match = detector.firstMatch(in: self, options: [],
                                               range: NSRange(location: 0, length: utf16.count)
            ) {
                return match.range.length == utf16.count
            } else { return false }
        } else { return false }
    }

    public func caseInsensitiveContains(_ other: String) -> Bool {
        range(of: other, options: .caseInsensitive) != nil
    }
    public func caseInsensitiveEqualsTo(_ other: String) -> Bool {
        caseInsensitiveContains(other) && count == other.count
    }
}

// MARK: UIImage
extension UIImage {
    public func cropping(to rect: CGRect) -> UIImage? {
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )

        guard let cgImage = cgImage?.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    public func cropping(size: CGSize, offset: CGSize) -> UIImage? {
        let origin = CGPoint(x: offset.width, y: offset.height)
        let rect = CGRect(origin: origin, size: size)
        return cropping(to: rect)
    }

    public func withRoundedCorners(radius: CGFloat) -> UIImage? {
        let maxRadius = min(size.width, size.height) / 2

        let cornerRadius: CGFloat
        if radius > 0 && radius <= maxRadius {
            cornerRadius = radius
        } else {
            cornerRadius = maxRadius
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        let rect = CGRect(origin: .zero, size: size)
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        draw(in: rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: Color
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3:
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB, red: Double(red) / 255.0, green: Double(green) / 255.0,
            blue: Double(blue) / 255.0, opacity: Double(alpha) / 255.0
        )
    }
}

// MARK: Array
extension Array {
    public func removeDuplicates(by predicate: (Element, Element) -> Bool) -> Self {
        var result = [Element]()
        for value in self where result.filter({ predicate($0, value) }).isEmpty {
            result.append(value)
        }
        return result
    }
    public func removeDuplicates(by keyPath: KeyPath<Element, String>) -> Self {
        removeDuplicates(by: { $0[keyPath: keyPath] == $1[keyPath: keyPath] })
    }
    public func removeDuplicates() -> Self where Element: Equatable {
        removeDuplicates(by: ==)
    }
}

// MARK: Dictionary
extension Dictionary {
    public var tuples: [(Key, Value)] {
        map({ ($0.key, $0.value) })
    }
}

// MARK: TimeInterval
extension TimeInterval {
    public static let oneYear: Self = .init(60 * 60 * 24 * 365)
    public static let oneWeek: Self = .init(60 * 60 * 24 * 7)
}
