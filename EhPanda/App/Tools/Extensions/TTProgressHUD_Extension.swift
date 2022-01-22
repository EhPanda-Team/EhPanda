//
//  TTProgressHUD_Extension.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/15.
//

import TTProgressHUD

extension TTProgressHUDConfig {
    static let error: Self = error(caption: nil)
    static let loading: Self = loading(title: "Loading...".localized)
    static let communicating: Self = loading(title: "Communicating...".localized)
    static let savedToPhotoLibrary: Self = success(caption: "Saved to photo library".localized)
    static let copiedToClipboardSucceeded: Self = success(caption: "Copied to clipboard".localized)

    static func loading(title: String? = nil) -> Self {
        .init(type: .loading, title: title)
    }
    static func error(caption: String? = nil) -> Self {
        autoHide(type: .error, title: "Error".localized, caption: caption)
    }
    static func success(caption: String? = nil) -> Self {
        autoHide(type: .success, title: "Success".localized, caption: caption)
    }
    static func autoHide(type: TTProgressHUDType, title: String? = nil, caption: String? = nil) -> Self {
        .init(type: type, title: title, caption: caption, shouldAutoHide: true, autoHideInterval: 1)
    }
}
