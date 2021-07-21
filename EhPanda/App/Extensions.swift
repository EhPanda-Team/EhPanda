//
//  Extensions.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI
import Combine
import SwiftyBeaver

extension Dictionary where Key == String, Value == String {
    func dictString() -> String {
        var array = [String]()
        keys.forEach { key in
            let value = self[key]!
            array.append(key + "=" + value)
        }
        return array.joined(separator: "&")
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

extension Array where Element: Publisher {
    var zipAll: AnyPublisher<[Element.Output], Element.Failure> {
        let initial = Just([Element.Output]())
            .setFailureType(to: Element.Failure.self)
            .eraseToAnyPublisher()
        return reduce(initial) { result, publisher in
            result.zip(publisher) { $0 + [$1] }.eraseToAnyPublisher()
        }
    }
}

extension Encodable {
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

extension Data {
    func toObject<O: Decodable>() -> O? {
        try? JSONDecoder().decode(O.self, from: self)
    }
}

extension Float {
    func fixedRating() -> Float {
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

extension String {
    var hasLocalizedString: Bool {
        self.localized() != self
    }

    func localized() -> String {
        String(localized: StringLocalizationKey(self))
    }

    func urlEncoded() -> String {
        addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
    }

    var withComma: String? {
        Int(self)?.formatted(.number)
    }

    func capitalizingFirstLetter() -> String {
        prefix(1).capitalized + dropFirst()
    }

    func trimmedTitle() -> String {
        var title = self

        if let range = title.range(of: "|") {
            title = String(title.prefix(upTo: range.lowerBound))
        }

        return title
            .replacingOccurrences(from: "(", to: ")", with: "")
            .replacingOccurrences(from: "[", to: "]", with: "")
            .replacingOccurrences(from: "{", to: "}", with: "")
            .replacingOccurrences(from: "【", to: "】", with: "")
            .replacingOccurrences(from: "「", to: "」", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func replacingOccurrences(
        from subString1: String,
        to subString2: String,
        with replacement: String
    ) -> String {
        var result = self

        while let rangeA = result.range(of: subString1),
              let rangeB = result.range(of: subString2)
        {
            let unwanted =  String(
                result.suffix(from: rangeA.lowerBound)
                    .prefix(upTo: rangeB.upperBound)
            )
            result = result.replacingOccurrences(
                of: unwanted,
                with: replacement
            )
        }

        return result
    }

    func safeURL() -> URL {
        if isValidURL {
            return URL(string: self).forceUnwrapped
        } else {
            SwiftyBeaver.error("Invalid URL, redirect to default host...")
            return URL(string: Defaults.URL.ehentai).forceUnwrapped
        }
    }

    var isValidURL: Bool {
        if let detector = try? NSDataDetector(
            types: NSTextCheckingResult
                .CheckingType.link.rawValue
        ) {
            if let match = detector.firstMatch(
                in: self, options: [],
                range: NSRange(
                    location: 0,
                    length: self.utf16.count
                )
            ) {
                return match.range.length
                == self.utf16.count
            } else {
                return false
            }
        } else {
            return false
        }
    }
}

extension View {
    func withArrow() -> some View {
        HStack {
            self
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .imageScale(.small)
        }
    }
}

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

extension Int {
    var withComma: String? {
        formatted(.number)
    }
    var withoutComma: String {
        String(self).replacingOccurrences(of: ",", with: "")
    }
}

extension CGFloat {
    func roundedString() -> String {
        roundedString(with: 1)
    }

    func roundedString(with places: Int) -> String {
        String(format: "%.\(places)f", self)
    }
}

extension UIImage {
    func cropping(to rect: CGRect) -> UIImage? {
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )

        guard let cgImage = cgImage?
                .cropping(to: scaledRect)
        else { return nil }

        return UIImage(
            cgImage: cgImage,
            scale: scale,
            orientation: imageOrientation
        )
    }
}

extension Optional {
    var forceUnwrapped: Wrapped {
        if let value = self {
            return value
        }
        SwiftyBeaver.error(
            "Failed in force unwrapping..."
            + "Shutting down now...",
            context: [
                "type": Wrapped.self
            ]
        )
        fatalError()
    }
}

extension CGSize {
    static func * (left: CGSize, right: CGFloat) -> CGSize {
        CGSize(width: left.width * right, height: left.height * right)
    }
}

extension URLRequest {
    mutating func setURLEncodedContentType() {
        setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
    }
}

extension UIImage {
    func withRoundedCorners(radius: CGFloat) -> UIImage? {
        let maxRadius = min(size.width, size.height) / 2

        let cornerRadius: CGFloat
        if radius > 0 && radius <= maxRadius {
            cornerRadius = radius
        } else {
            cornerRadius = maxRadius
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        let rect = CGRect(
            origin: .zero, size: size
        )
        UIBezierPath(
            roundedRect: rect,
            cornerRadius: cornerRadius
        ).addClip()
        draw(in: rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
