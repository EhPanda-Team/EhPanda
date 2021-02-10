//
//  AuthView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/09.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var store: Store
    @State var enterBackgroundDate: Date?
    @Binding var blurRadius: CGFloat
    
    var isAppUnlocked: Bool {
        store.appState.environment.isAppUnlocked
    }
    
    var setting: Setting? {
        store.appState.settings.setting
    }
    var allowsResignActiveBlur: Bool {
        setting?.allowsResignActiveBlur ?? true
    }
    var autoLockThreshold: Double {
        Double(setting?.autoLockPolicy.value ?? -1)
    }
    
    var body: some View {
        LockView(unlockAction: authenticate)
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
    
    func onLockTap() {
        impactFeedback(style: .soft)
        authenticate()
    }
    func onResignActive() {
        if allowsResignActiveBlur {
            setBlur(on: true)
        }
    }
    func onDidBecomeActive() {
        if isAppUnlocked {
            setBlur(on: false)
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
        }
    }
    
    func setBlur(on: Bool) {
        withAnimation(.linear(duration: 0.1)) {
            blurRadius = on ? 10 : 0
        }
        store.dispatch(.toggleBlurEffect(on: on))
    }
    
    func setUnlocked(_ isUnlocked: Bool) {
        store.dispatch(.toggleAppUnlocked(isUnlocked: isUnlocked))
    }
    
    func lockIfExpired() {
        if let resignDate = enterBackgroundDate,
           Date().timeIntervalSince(resignDate) > autoLockThreshold
        {
            setUnlocked(false)
            setBlur(on: true)
        }
        enterBackgroundDate = nil
    }
    
    func authenticate() {
        localAuth(
            reason: "自動ロック期限が切れたため、アプリがロックされています",
            successAction: {
                setUnlocked(true)
                setBlur(on: false)
            }
        )
    }
}

struct LockView: View {
    @EnvironmentObject var store: Store
    
    let unlockAction: () -> ()
    
    var isAppUnlocked: Bool {
        store.appState.environment.isAppUnlocked
    }
    
    var body: some View {
        Group {
            if !isAppUnlocked {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 80))
                            .onTapGesture(perform: unlockAction)
                        Spacer()
                    }
                }
            }
        }
    }
}
