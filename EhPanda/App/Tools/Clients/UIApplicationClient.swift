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
    static let testValue = UIApplicationClient.noop
    static let previewValue = UIApplicationClient.noop
}

extension DependencyValues {
    var uiApplicationClient: UIApplicationClient {
        get { self[UIApplicationClientKey.self] }
        set { self[UIApplicationClientKey.self] = newValue }
    }
}

// MARK: Test
// swiftlint:disable line_length
#if DEBUG
import XCTestDynamicOverlay

extension UIApplicationClient {
    static let failing: Self = .init(
        openURL: { .failing("\(Self.self).openURL(\($0)) is unimplemented") },
        hideKeyboard: { .failing("\(Self.self).hideKeyboard is unimplemented") },
        alternateIconName: {
            XCTFail("\(Self.self).alternateIconName is unimplemented")
            return nil
        },
        setAlternateIconName: { .failing("\(Self.self).setAlternateIconName(\(String(describing: $0))) is unimplemented") },
        setUserInterfaceStyle: { .failing("\(Self.self).setUserInterfaceStyle(\($0)) is unimplemented") }
    )
}
#endif
// swiftlint:enable line_length
extension UIApplicationClient {
    static let noop: Self = .init(
        openURL: { _ in .none},
        hideKeyboard: { .none },
        alternateIconName: { nil },
        setAlternateIconName: { _ in .none },
        setUserInterfaceStyle: { _ in .none }
    )
}
