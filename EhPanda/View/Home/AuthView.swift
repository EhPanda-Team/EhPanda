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
            .font(.system(size: 80))
            .onAppear(perform: onAppear)
            .opacity(isAppUnlocked ? 0 : 1)
            .onTapGesture(perform: authenticate)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification
                )
            ) { _ in onResignActive() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification
                )
            ) { _ in onDidBecomeActive() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification
                )
            ) { _ in onDidEnterBackground() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )
            ) { _ in onWillEnterForeground() }
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
        impactFeedback(style: .soft)
        authenticate()
    }
    func onResignActive() {
        if allowsResignActiveBlur {
            setBlur(effectOn: true)
        }
    }
    func onDidBecomeActive() {
        if isAppUnlocked {
            setBlur(effectOn: false)
        }
    }
    func onDidEnterBackground() {
        if autoLockThreshold >= 0 {
            enterBackgroundDate = Date()
        }
    }
    func onWillEnterForeground() {
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
        localAuth(
            reason: "The App has been locked due to the auto-lock expiration.",
            successAction: {
                set(isUnlocked: true)
                setBlur(effectOn: false)
            }
        )
    }
}
