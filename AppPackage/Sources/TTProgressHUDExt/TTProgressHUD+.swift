import TTProgressHUD
import Resources

public enum ProgressHUDConfigState: Equatable, Sendable {
    case loading(title: String? = nil)
    case communicating
    case error(caption: String? = nil)
    case success(caption: String? = nil)
    case savedToPhotoLibrary
    case copiedToClipboardSucceeded

    @MainActor
    public var progressHUDConfig: TTProgressHUDConfig {
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
    public static var error: Self { error(caption: nil) }
    @MainActor
    public static var loading: Self { loading(title: L10n.Localizable.Hud.Title.loading) }
    @MainActor
    public static var communicating: Self { loading(title: L10n.Localizable.Hud.Title.communicating) }
    @MainActor
    public static var savedToPhotoLibrary: Self {
        success(caption: L10n.Localizable.Hud.Caption.savedToPhotoLibrary)
    }
    @MainActor
    public static var copiedToClipboardSucceeded: Self {
        success(caption: L10n.Localizable.Hud.Caption.copiedToClipboard)
    }

    public static func loading(title: String? = nil) -> Self {
        .init(type: .loading, title: title)
    }
    public static func error(caption: String? = nil) -> Self {
        autoHide(type: .error, title: L10n.Localizable.Hud.Title.error, caption: caption)
    }
    public static func success(caption: String? = nil) -> Self {
        autoHide(type: .success, title: L10n.Localizable.Hud.Title.success, caption: caption)
    }
    public static func autoHide(type: TTProgressHUDType, title: String? = nil, caption: String? = nil) -> Self {
        .init(type: type, title: title, caption: caption, shouldAutoHide: true, autoHideInterval: 1)
    }
}
