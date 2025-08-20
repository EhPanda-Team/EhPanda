//
//  TTProgressHUD_Extension.swift
//  EhPanda
//

import TTProgressHUD

extension TTProgressHUDConfig {
    static let error: Self = error(caption: nil)
    static let loading: Self = loading(title: L10n.Localizable.Hud.Title.loading)
    static let communicating: Self = loading(title: L10n.Localizable.Hud.Title.communicating)
    static let savedToPhotoLibrary: Self = success(caption: L10n.Localizable.Hud.Caption.savedToPhotoLibrary)
    static let copiedToClipboardSucceeded: Self = success(caption: L10n.Localizable.Hud.Caption.copiedToClipboard)

    static func loading(title: String? = nil) -> Self {
        .init(type: .loading, title: title)
    }
    static func error(caption: String? = nil) -> Self {
        autoHide(type: .error, title: L10n.Localizable.Hud.Title.error, caption: caption)
    }
    static func success(caption: String? = nil) -> Self {
        autoHide(type: .success, title: L10n.Localizable.Hud.Title.success, caption: caption)
    }
    static func autoHide(type: TTProgressHUDType, title: String? = nil, caption: String? = nil) -> Self {
        .init(type: type, title: title, caption: caption, shouldAutoHide: true, autoHideInterval: 1)
    }
}
