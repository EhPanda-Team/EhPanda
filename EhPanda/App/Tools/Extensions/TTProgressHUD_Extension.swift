import TTProgressHUD

enum ProgressHUDConfigState: Equatable, Sendable {
    case loading(title: String? = nil)
    case communicating
    case error(caption: String? = nil)
    case success(caption: String? = nil)
    case savedToPhotoLibrary
    case copiedToClipboardSucceeded

    @MainActor
    var progressHUDConfig: TTProgressHUDConfig {
        switch self {
        case .loading(let title):
            return .loading(title: title)
        case .communicating:
            return .loading(title: L10n.Localizable.Hud.Title.communicating)
        case .error(let caption):
            return .error(caption: caption)
        case .success(let caption):
            return .success(caption: caption)
        case .savedToPhotoLibrary:
            return .success(caption: L10n.Localizable.Hud.Caption.savedToPhotoLibrary)
        case .copiedToClipboardSucceeded:
            return .success(caption: L10n.Localizable.Hud.Caption.copiedToClipboard)
        }
    }
}

extension TTProgressHUDConfig {
    @MainActor
    static var error: Self { error(caption: nil) }
    @MainActor
    static var loading: Self { loading(title: L10n.Localizable.Hud.Title.loading) }
    @MainActor
    static var communicating: Self { loading(title: L10n.Localizable.Hud.Title.communicating) }
    @MainActor
    static var savedToPhotoLibrary: Self { success(caption: L10n.Localizable.Hud.Caption.savedToPhotoLibrary) }
    @MainActor
    static var copiedToClipboardSucceeded: Self { success(caption: L10n.Localizable.Hud.Caption.copiedToClipboard) }

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
