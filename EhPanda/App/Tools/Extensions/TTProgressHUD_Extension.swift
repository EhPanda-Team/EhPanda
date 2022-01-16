//
//  TTProgressHUD_Extension.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/15.
//

import TTProgressHUD

extension TTProgressHUDConfig {
    static let loading: Self = .init(
        type: .loading, title: "Loading...".localized
    )
    static let error: Self = .init(
        type: .error, title: "Error".localized,
        shouldAutoHide: true, autoHideInterval: 1
    )
    static let copiedToClipboardSucceeded: Self = .init(
        type: .success, title: "Success".localized,
        caption: "Copied to clipboard".localized,
        shouldAutoHide: true, autoHideInterval: 1
    )
}
