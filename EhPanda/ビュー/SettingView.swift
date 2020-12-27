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
                
                Button {
                    store.dispatch(.toggleCleanCookiesAlertPresented)
                } label: {
                    Text("クッキー削除")
                        .foregroundColor(.red)
                }
                .alert(isPresented: settingsBinding.isCleanCookiesAlertPresented) { () -> Alert in
                    Alert(title: Text("本当に削除しますか？"), primaryButton: .destructive(Text("削除"), action: cleanCookies), secondaryButton: .cancel())
                }
            }
        }
    }
}
