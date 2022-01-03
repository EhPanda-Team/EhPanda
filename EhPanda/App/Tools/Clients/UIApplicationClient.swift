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
    let openURL: (URL) -> Effect<Never, Never>
    let hideKeyboard: () -> Effect<Never, Never>
    let alternateIconName: () -> String?
    let setAlternateIconName: (String?) -> Effect<Result<Bool, Never>, Never>
    let setUserInterfaceStyle: (UIUserInterfaceStyle) -> Effect<Never, Never>
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
                DeviceUtil.anyWindow?.overrideUserInterfaceStyle = userInterfaceStyle
            }
        }
    )
    func openSettings() -> Effect<Never, Never> {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            return openURL(url)
        }
        return .none
    }
    func openFileApp() -> Effect<Never, Never> {
        if let dirPath = FileUtil.logsDirectoryURL?.path,
           let dirURL = URL(string: "shareddocuments://" + dirPath)
        {
            return openURL(dirURL)
        }
        return .none
    }
}
