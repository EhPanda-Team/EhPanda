//
//  UIApplicationClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct UIApplicationClient {
    let openURL: @MainActor (URL) -> Void
    let hideKeyboard: () -> Void
    let alternateIconName: () -> String?
    let setAlternateIconName: @MainActor (String?) async -> Bool
    let setUserInterfaceStyle: @MainActor (UIUserInterfaceStyle) -> Void
}

extension UIApplicationClient {
    static let live: Self = .init(
        openURL: { url in
            UIApplication.shared.open(url, options: [:])
        },
        hideKeyboard: {
            UIApplication.shared.endEditing()
        },
        alternateIconName: {
            UIApplication.shared.alternateIconName
        },
        setAlternateIconName: { iconName in
            await withCheckedContinuation { continuation in
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error = error {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: true)
                    }
                }
            }
        },
        setUserInterfaceStyle: { userInterfaceStyle in
            (DeviceUtil.keyWindow ?? DeviceUtil.anyWindow)?.overrideUserInterfaceStyle = userInterfaceStyle
        }
    )
    @MainActor
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            return openURL(url)
        }
    }
    @MainActor
    func openFileApp() {
        if let dirPath = FileUtil.logsDirectoryURL?.path,
           let dirURL = URL(string: "shareddocuments://" + dirPath)
        {
            return openURL(dirURL)
        }
    }
}

// MARK: API
enum UIApplicationClientKey: DependencyKey {
    static let liveValue = UIApplicationClient.live
    static let previewValue = UIApplicationClient.noop
    static let testValue = UIApplicationClient.unimplemented
}

extension DependencyValues {
    var uiApplicationClient: UIApplicationClient {
        get { self[UIApplicationClientKey.self] }
        set { self[UIApplicationClientKey.self] = newValue }
    }
}

// MARK: Test
extension UIApplicationClient {
    static let noop: Self = .init(
        openURL: { _ in},
        hideKeyboard: {},
        alternateIconName: { nil },
        setAlternateIconName: { _ in false },
        setUserInterfaceStyle: { _ in }
    )

    static let unimplemented: Self = .init(
        openURL: XCTestDynamicOverlay.unimplemented("\(Self.self).openURL"),
        hideKeyboard: XCTestDynamicOverlay.unimplemented("\(Self.self).hideKeyboard"),
        alternateIconName: XCTestDynamicOverlay.unimplemented("\(Self.self).alternateIconName"),
        setAlternateIconName: XCTestDynamicOverlay.unimplemented("\(Self.self).importTagTranslator"),
        setUserInterfaceStyle: XCTestDynamicOverlay.unimplemented("\(Self.self).setUserInterfaceStyle")
    )
}
