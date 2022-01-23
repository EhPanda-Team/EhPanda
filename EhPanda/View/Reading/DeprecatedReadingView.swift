//
//  ReadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import Combine
import Kingfisher
import SwiftUIPager
import TTProgressHUD

struct DeprecatedReadingView: View {
    @StateObject private var imageSaver = ImageSaver()

    let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: ReadingView
    var body: some View {
        Text("")
//        .onChange(of: imageSaver.saveSucceeded, perform: { newValue in
//            guard let isSuccess = newValue else { return }
//            presentHUD(isSuccess: isSuccess, caption: "Saved to photo library")
//        })
//        .onReceive(AppNotification.appWidthDidChange.publisher) { _ in
//            DispatchQueue.main.async {
//                trySetOffset(.zero)
//                trySetScale(1.1)
//                trySetScale(1)
//            }
//            tryUpdatePagerIndex()
//        }
//        .onReceive(UIApplication.didBecomeActiveNotification.publisher) { _ in
//            trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
//        }
    }
}

private extension DeprecatedReadingView {
    // MARK: Life Cycle
    func onStartTasks() {
        trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
    }
    func onEndTasks() {
        trySetOrientation(allowsLandscape: false)
    }
    func trySetOrientation(allowsLandscape: Bool, shouldChangeOrientation: Bool = false) {
//        guard !DeviceUtil.isPad, setting.prefersLandscape else { return }
        if allowsLandscape {
            AppDelegate.orientationMask = .all
            if shouldChangeOrientation {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
        } else {
            AppDelegate.orientationMask = [.portrait, .portraitUpsideDown]
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UINavigationController.attemptRotationToDeviceOrientation()
    }

    // MARK: ContextMenu
    func copyImage(url: String) async {
//        guard let image = try? await imageSaver.retrieveImage(url: url.safeURL()) else {
//            presentHUD(isSuccess: false)
//            return
//        }
//        UIPasteboard.general.image = image
//        presentHUD(isSuccess: true, caption: "Copied to clipboard")
    }
    func saveImage(url: String) async {
//        guard let image = try? await imageSaver.retrieveImage(url: url.safeURL()) else {
//            presentHUD(isSuccess: false)
//            return
//        }
//        imageSaver.saveImage(image)
    }
    func shareImage(url: String) async {
//        guard let image = try? await imageSaver.retrieveImage(url: url.safeURL()) else {
//            presentHUD(isSuccess: false)
//            return
//        }
//        AppUtil.presentActivity(items: [image])
    }
}
