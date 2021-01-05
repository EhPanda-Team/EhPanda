//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject var store: Store
    
    var settingsBinding: Binding<AppState.Settings> {
        $store.appState.settings
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("アカウント")) {
                    Picker(selection: settingsBinding.galleryType, label: Text("ギャラリー"), content: {
                         let galleryTypes: [GalleryType] = [.eh, .ex]
                         ForEach(galleryTypes, id: \.self) {
                             Text($0.rawValue.lString())
                         }
                    })
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if didLogin() {
                        Text("ログイン済み")
                            .foregroundColor(.gray)
                    } else {
                        NavigationLink(destination: WebView(),
                                       isActive: environmentBinding.isWebViewPresented) {
                            Text("E-Hentaiでログインする")
                        }
                    }
                    
                    Button {
                        store.dispatch(.toggleCleanCookiesAlertPresented)
                    } label: {
                        Text("クッキー削除")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: environmentBinding.isCleanCookiesAlertPresented) { () -> Alert in
                        Alert(
                            title: Text("本当に削除しますか？"),
                            primaryButton:
                                .destructive(Text("削除"), action: cleanAuth),
                            secondaryButton: .cancel())
                    }
                }
            }
            .navigationBarTitle("設定")
        }
    }
    
    func cleanAuth() {
        cleanCookies()
        store.dispatch(.updateUser(user: nil))
    }
}
