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
            .font(.system(size: 80)).onAppear(perform: onAppear)
            .opacity(isAppUnlocked ? 0 : 1).onTapGesture(perform: authenticate)
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

    func onAppear() {
        guard autoLockPolicy != .never
                && isLaunchingApp
        else { return }
        isLaunchingApp = false
        lock()
    }
    func onLockTap() {
        HapticUtil.generateFeedback(style: .soft)
        authenticate()
    }
    func onResignActive(_: Any? = nil) {
        if allowsResignActiveBlur {
            setBlur(effectOn: true)
        }
    }
    func onDidBecomeActive(_: Any? = nil) {
        if isAppUnlocked {
            setBlur(effectOn: false)
        }
    }
    func onDidEnterBackground(_: Any? = nil) {
        if autoLockThreshold >= 0 {
            enterBackgroundDate = Date()
        }
    }
    func onWillEnterForeground(_: Any? = nil) {
        if autoLockThreshold >= 0 {
            lockIfExpired()
            if !isAppUnlocked {
                authenticate()
            }
        } else {
            setBlur(effectOn: false)
        }
    }

    func setBlur(effectOn: Bool) {
        withAnimation(.linear(duration: 0.1)) {
            blurRadius = effectOn ? 10 : 0
        }
        store.dispatch(.toggleBlur(effectOn: effectOn))
    }
    func set(isUnlocked: Bool) {
        store.dispatch(.toggleApp(unlocked: isUnlocked))
    }

    func lock() {
        set(isUnlocked: false)
        setBlur(effectOn: true)
    }
    func lockIfExpired() {
        if let resignDate = enterBackgroundDate,
           Date().timeIntervalSince(resignDate)
            > Double(autoLockThreshold) { lock() }
        enterBackgroundDate = nil
    }

    func authenticate() {
        AuthorizationUtil.localAuth(
            reason: "The App has been locked due to the auto-lock expiration.",
            successAction: {
                set(isUnlocked: true)
                setBlur(effectOn: false)
            }
        )
    }
}
