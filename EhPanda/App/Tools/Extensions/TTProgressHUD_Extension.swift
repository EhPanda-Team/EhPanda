//
//  TTProgressHUD_Extension.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/15.
//

import TTProgressHUD

extension TTProgressHUDConfig {
    static let error: Self = error(caption: nil)
    static let loading: Self = loading(title: R.string.localizable.hudTitleLoading())
    static let communicating: Self = loading(title: R.string.localizable.hudTitleCommunicating())
    static let savedToPhotoLibrary: Self = success(caption: R.string.localizable.hudCaptionSavedToPhotoLibrary())
    static let copiedToClipboardSucceeded: Self = success(caption: R.string.localizable.hudCaptionCopiedToClipboard())

    static func loading(title: String? = nil) -> Self {
        .init(type: .loading, title: title)
    }
    static func error(caption: String? = nil) -> Self {
        autoHide(type: .error, title: R.string.localizable.hudTitleError(), caption: caption)
    }
    static func success(caption: String? = nil) -> Self {
        autoHide(type: .success, title: R.string.localizable.hudTitleSuccess(), caption: caption)
    }
    static func autoHide(type: TTProgressHUDType, title: String? = nil, caption: String? = nil) -> Self {
        .init(type: type, title: title, caption: caption, shouldAutoHide: true, autoHideInterval: 1)
    }
}
