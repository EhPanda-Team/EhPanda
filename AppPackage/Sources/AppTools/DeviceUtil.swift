import SwiftUI
import Foundation

@MainActor
public struct DeviceUtil {
    public static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    public static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    public static var isPadWidth: Bool {
        windowW >= 744
    }

    public static var isSEWidth: Bool {
        windowW <= 320
    }

    public static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.filter({ $0.isKeyWindow }).last
    }
    public static var anyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.last
    }

    private static var currentScreen: UIScreen? {
        keyWindow?.windowScene?.screen ?? anyWindow?.windowScene?.screen
    }

    public static var isLandscape: Bool {
        [.landscapeLeft, .landscapeRight]
            .contains(keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation)
    }

    public static var isPortrait: Bool {
        [.portrait, .portraitUpsideDown]
            .contains(keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation)
    }

    public static var windowW: CGFloat {
        min(absWindowW, absWindowH)
    }

    public static var windowH: CGFloat {
        max(absWindowW, absWindowH)
    }

    public static var screenW: CGFloat {
        min(absScreenW, absScreenH)
    }

    public static var screenH: CGFloat {
        max(absScreenW, absScreenH)
    }

    public static var absWindowW: CGFloat {
        keyWindow?.frame.size.width ?? absScreenW
    }

    public static var absWindowH: CGFloat {
        keyWindow?.frame.size.height ?? absScreenH
    }

    public static var absScreenW: CGFloat {
        currentScreen?.bounds.size.width ?? 0
    }

    public static var absScreenH: CGFloat {
        currentScreen?.bounds.size.height ?? 0
    }
}
