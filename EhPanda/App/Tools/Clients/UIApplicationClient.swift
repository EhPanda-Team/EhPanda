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
    let openURL: (URL) -> EffectTask<Never>
    let hideKeyboard: () -> EffectTask<Never>
    let alternateIconName: () -> String?
    let setAlternateIconName: (String?) -> EffectTask<Result<Bool, Never>>
    let setUserInterfaceStyle: (UIUserInterfaceStyle) -> EffectTask<Never>
}

extension UIApplicationClient {
    static let live: Self = .init(
        openURL: { url in
            .fireAndForget {
                UIApplication.shared.open(url, options: [:])
            }
        },
        hideKeyboard: {
            .fireAndForget {
                UIApplication.shared.endEditing()
            }
        },
        alternateIconName: {
            UIApplication.shared.alternateIconName
        },
        setAlternateIconName: { iconName in
            Future { promise in
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error = error {
                        promise(.success(false))
                    } else {
                        promise(.success(true))
                    }
                }
            }
            .eraseToAnyPublisher()
            .catchToEffect()
        },
        setUserInterfaceStyle: { userInterfaceStyle in
            .fireAndForget {
                (DeviceUtil.keyWindow ?? DeviceUtil.anyWindow)?.overrideUserInterfaceStyle = userInterfaceStyle
            }
        }
    )
    func openSettings() -> EffectTask<Never> {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            return openURL(url)
        }
        return .none
    }
    func openFileApp() -> EffectTask<Never> {
        if let dirPath = FileUtil.logsDirectoryURL?.path,
           let dirURL = URL(string: "shareddocuments://" + dirPath)
        {
            return openURL(dirURL)
        }
        return .none
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
        openURL: { _ in .none},
        hideKeyboard: { .none },
        alternateIconName: { nil },
        setAlternateIconName: { _ in .none },
        setUserInterfaceStyle: { _ in .none }
    )

    static let unimplemented: Self = .init(
        openURL: XCTestDynamicOverlay.unimplemented("\(Self.self).openURL"),
        hideKeyboard: XCTestDynamicOverlay.unimplemented("\(Self.self).hideKeyboard"),
        alternateIconName: XCTestDynamicOverlay.unimplemented("\(Self.self).alternateIconName"),
        setAlternateIconName: XCTestDynamicOverlay.unimplemented("\(Self.self).importTagTranslator"),
        setUserInterfaceStyle: XCTestDynamicOverlay.unimplemented("\(Self.self).setUserInterfaceStyle")
    )
}
