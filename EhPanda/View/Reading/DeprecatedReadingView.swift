//
//  ReadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

//    var body: some View {
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
//    }

//    // MARK: Life Cycle
//    func onStartTasks() {
//        trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
//    }
//    func onEndTasks() {
//        trySetOrientation(allowsLandscape: false)
//    }
//    func trySetOrientation(allowsLandscape: Bool, shouldChangeOrientation: Bool = false) {
//        guard !DeviceUtil.isPad, setting.prefersLandscape else { return }
//        if allowsLandscape {
//            AppDelegate.orientationMask = .all
//            if shouldChangeOrientation {
//                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
//            }
//        } else {
//            AppDelegate.orientationMask = [.portrait, .portraitUpsideDown]
//            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
//        }
//        UINavigationController.attemptRotationToDeviceOrientation()
//    }
