//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import ComposableArchitecture

@main struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            TabBarView(store: appDelegate.store).onAppear(perform: addTouchHandler)
                .navigationViewStyle(.stack).accentColor(.primary)
                .onAppear {
                    let codes = EhSetting.BrowsingCountry.allCases.map(\.name)
                        .map { name in
                            "case .\(name.namedAsProperty):\nreturn R.string.localizable.enumBrowsingCountryName\(name.namedAsProperty.firstLetterCapitalized)()"
                        }
                        .joined(separator: "\n")
                    print(codes)
                }
        }
    }
}
extension String {
    var namedAsProperty: String {
        camelCased.firstLetterLowercased.marksEscaped
    }
    var camelCased: String {
        split(separator: " ").map(String.init).map(\.firstLetterCapitalized).joined()
    }
    var firstLetterLowercased: String {
        prefix(1).lowercased() + dropFirst()
    }
    var marksEscaped: String {
        replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "'", with: "")
    }
}

// MARK: TouchHandler
final class TouchHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = TouchHandler()
    var currentPoint: CGPoint?

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        currentPoint = touch.location(in: touch.window)
        return false
    }
}
private extension EhPandaApp {
    func addTouchHandler() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let tapGesture = UITapGestureRecognizer(
                target: self, action: nil
            )
            tapGesture.delegate = TouchHandler.shared
            DeviceUtil.keyWindow?.addGestureRecognizer(tapGesture)
        }
    }
}
