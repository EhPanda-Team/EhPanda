//
//  AuthView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/09.
//

import SwiftUI

struct AuthView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var isLaunchingApp = true
    @Binding private var blurRadius: CGFloat
    @State private var enterBackgroundDate: Date?

    init(blurRadius: Binding<CGFloat>) {
        _blurRadius = blurRadius
    }

    // MARK: AuthView
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 80)).opacity(isAppUnlocked ? 0 : 1)
            .onAppear(perform: onStartTasks).onTapGesture(perform: authenticate)
            .onReceive(UIApplication.willResignActiveNotification.publisher, perform: onResignActive)
            .onReceive(UIApplication.didBecomeActiveNotification.publisher, perform: onDidBecomeActive)
            .onReceive(UIApplication.didEnterBackgroundNotification.publisher, perform: onDidEnterBackground)
            .onReceive(UIApplication.willEnterForegroundNotification.publisher, perform: onWillEnterForeground)
    }
}

private extension AuthView {
    var autoLockThreshold: Int {
        autoLockPolicy.rawValue
    }

    // MARK: Life Cycle
    func onStartTasks() {
        guard autoLockPolicy != .never && isLaunchingApp else { return }
        isLaunchingApp = false
        lock()
    }
    func onResignActive(_: Any? = nil) {
        guard backgroundBlurRadius > 0 else { return }
        setBlurEffect(activated: true)
    }
    func onDidBecomeActive(_: Any? = nil) {
        guard isAppUnlocked else { return }
        setBlurEffect(activated: false)
    }
    func onDidEnterBackground(_: Any? = nil) {
        guard autoLockThreshold >= 0 else { return }
        enterBackgroundDate = Date()
    }
    func onWillEnterForeground(_: Any? = nil) {
        if autoLockThreshold >= 0 {
            tryLock()
            if !isAppUnlocked {
                authenticate()
            }
        } else {
            setBlurEffect(activated: false)
        }
    }

    // MARK: Authorization
    func setBlurEffect(activated: Bool) {
        withAnimation(.linear(duration: 0.1)) {
            blurRadius = activated ? backgroundBlurRadius : 0
        }
        store.dispatch(.setBlurEffect(activated: activated))
    }
    func setAppLock(activated: Bool) {
        store.dispatch(.setAppLock(activated: activated))
    }

    func lock() {
        setAppLock(activated: true)
        setBlurEffect(activated: true)
    }
    func tryLock() {
        if let resignDate = enterBackgroundDate,
           Date().timeIntervalSince(resignDate)
            > Double(autoLockThreshold) { lock() }
        enterBackgroundDate = nil
    }

    func authenticate() {
        AuthorizationUtil.localAuth(
            reason: "The App has been locked due to the auto-lock expiration.",
            successAction: {
                setAppLock(activated: false)
                setBlurEffect(activated: false)
            }
        )
    }
}
