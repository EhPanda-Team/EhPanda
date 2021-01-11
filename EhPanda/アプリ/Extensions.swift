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

extension String {
    func lString() -> String {
        NSLocalizedString(self, comment: "")
    }
}

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

extension String {
    func URLString() -> String {
        self.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
