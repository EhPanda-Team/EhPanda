//
//  DeviceUtil.swift
//  EhPanda
//

import SwiftUI
import Foundation

struct DeviceUtil {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    static var isPadWidth: Bool {
        windowW >= 744
    }

    static var isSEWidth: Bool {
        windowW <= 320
    }

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.filter({ $0.isKeyWindow }).last
    }
    static var anyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.last
    }

    static var isLandscape: Bool {
        [.landscapeLeft, .landscapeRight]
            .contains(keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation)
    }

    static var isPortrait: Bool {
        [.portrait, .portraitUpsideDown]
            .contains(keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation)
    }

    static var windowW: CGFloat {
        min(absWindowW, absWindowH)
    }

    static var windowH: CGFloat {
        max(absWindowW, absWindowH)
    }

    static var screenW: CGFloat {
        min(absScreenW, absScreenH)
    }

    static var screenH: CGFloat {
        max(absScreenW, absScreenH)
    }

    static var absWindowW: CGFloat {
        keyWindow?.frame.size.width ?? absScreenW
    }

    static var absWindowH: CGFloat {
        keyWindow?.frame.size.height ?? absScreenH
    }

    static var absScreenW: CGFloat {
        UIScreen.main.bounds.size.width
    }

    static var absScreenH: CGFloat {
        UIScreen.main.bounds.size.height
    }
}
