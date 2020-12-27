//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject var store: Store
    
    var settings: AppState.Settings {
        store.appState.settings
    }
    var settingsBinding: Binding<AppState.Settings> {
        $store.appState.settings
    }
    
    var body: some View {
        Form {
            Section(header: Text("アカウント")) {
                if didLogin() {
                    Text("ログイン済み")
                        .foregroundColor(.gray)
                    Button {
                        store.dispatch(.toggleLogoutAlertPresented)
                    } label: {
                        Text("ログアウトする")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: settingsBinding.isLogoutAlertPresented) { () -> Alert in
                        Alert(title: Text("本当にログアウトしますか？"), primaryButton: .destructive(Text("ログアウト"), action: {
                            guard let cookies = HTTPCookieStorage.shared.cookies else { return }
                            for cookie in cookies {
                                HTTPCookieStorage.shared.deleteCookie(cookie)
                            }
                        }), secondaryButton: .cancel())
                    }
                } else {
                    Button(action: {
                        store.dispatch(.toggleWebViewPresented)
                    }, label: {
                        Text("ExHentaiでログインする")
                    })
                    .sheet(isPresented: settingsBinding.isWebViewPresented, content: {
                        WebView()
                    })
                }
            }
        }
    }
}
