//
//  AuthView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/09.
//

import SwiftUI

struct AuthView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var enterBackgroundDate: Date?
    @Binding private var blurRadius: CGFloat

    init(blurRadius: Binding<CGFloat>) {
        _blurRadius = blurRadius
    }

    // MARK: AuthView
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 80))
            .opacity(isAppUnlocked ? 0 : 1)
            .onTapGesture(perform: authenticate)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification
                )
            ) { _ in
                onResignActive()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification
                )
            ) { _ in
                onDidBecomeActive()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification
                )
            ) { _ in
                onDidEnterBackground()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )
            ) { _ in
                onWillEnterForeground()
            }
    }
}

private extension AuthView {
    var autoLockThreshold: Int {
        autoLockPolicy.value
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
        store.dispatch(.toggleBlurEffect(effectOn: effectOn))
    }

    func set(isUnlocked: Bool) {
        store.dispatch(.toggleAppUnlocked(isUnlocked: isUnlocked))
    }

    func lockIfExpired() {
        if let resignDate = enterBackgroundDate,
           Date().timeIntervalSince(resignDate)
            > Double(autoLockThreshold)
        {
            set(isUnlocked: false)
            setBlur(effectOn: true)
        }
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
