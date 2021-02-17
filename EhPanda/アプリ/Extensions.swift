//
//  Extensions.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import UIKit
import SwiftUI
import Combine
import Foundation

extension Dictionary where Key == String, Value == String {
    func jsonString() -> String {
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
    func lString() -> String {
        NSLocalizedString(self, comment: "")
    }
    
    func URLString() -> String {
        self.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
    }
    
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
    
    func trimmedTitle() -> String {
        var title = self
        
        if let range = title.range(of: "|") {
            title = String(title.prefix(upTo: range.lowerBound))
        }
        
        title = title.replacingOccurrences(from: "(", to: ")", with: "")
        title = title.replacingOccurrences(from: "[", to: "]", with: "")
        title = title.replacingOccurrences(from: "{", to: "}", with: "")
        title = title.replacingOccurrences(from: "【", to: "】", with: "")
        title = title.replacingOccurrences(from: "「", to: "」", with: "")
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return title
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
        isValidURL
            ? URL(string: self)!
            : URL(string: Defaults.URL.ex)!
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
                .foregroundColor(.gray)
                .imageScale(.small)
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Bundle {
    public var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}
