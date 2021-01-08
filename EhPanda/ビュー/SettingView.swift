//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import SDWebImageSwiftUI

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
                    Picker(
                        selection: settingsBinding.galleryType,
                        label: Text("ギャラリー"),
                        content: {
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
                        NavigationLink(
                            destination: WebView(),
                            isActive: environmentBinding.isWebViewPresented)
                        {
                            Text("ログイン")
                        }
                    }
                    
                    Button(action: toggleLogout) {
                        Text("ログアウト")
                            .foregroundColor(.red)
                    }
                    .actionSheet(
                        isPresented: environmentBinding.isLogoutPresented,
                        content: {
                            ActionSheet(title: Text("本当にログアウトしますか？"), buttons: [
                                .destructive(Text("ログアウト"), action: logout),
                                .cancel()
                            ])
                        })
                }
                Section(header: Text("キャッシュ")) {
                    Button(action: toggleEraseImageCaches) {
                        HStack {
                            Text("画像キャッシュを削除")
                            Spacer()
                            Text(diskImageCaches())
                        }
                        .foregroundColor(.primary)
                    }
                    .actionSheet(
                        isPresented: environmentBinding.isEraseImageCachesPresented,
                        content: {
                            ActionSheet(title: Text("本当に削除しますか？"), buttons: [
                                .destructive(Text("削除"), action: eraseImageCaches),
                                .cancel()
                            ])
                        })
                    Button(action: toggleEraseCachedList) {
                        HStack {
                            Text("ウェブキャッシュを削除")
                            Spacer()
                            Text(browsingCaches())
                        }
                        .foregroundColor(.primary)
                    }
                    .actionSheet(
                        isPresented: environmentBinding.isEraseCachedListPresented,
                        content: {
                            ActionSheet(
                                title: Text("警告"),
                                message: Text("デバッグ専用機能です"),
                                buttons: [
                                    .destructive(Text("削除"), action: eraseCachedList),
                                    .cancel()
                            ])
                    })
                }
            }
            .navigationBarTitle("設定")
        }
    }
    
    func toggleLogout() {
        store.dispatch(.toggleLogoutPresented)
    }
    func toggleEraseImageCaches() {
        store.dispatch(.toggleEraseImageCachesPresented)
    }
    func toggleEraseCachedList() {
        store.dispatch(.toggleEraseCachedListPresented)
        store.dispatch(.fetchPopularItems)
        store.dispatch(.fetchFavoritesItems)
    }
    
    func logout() {
        cleanCookies()
        store.dispatch(.updateUser(user: nil))
    }
    
    func eraseImageCaches() {
        SDImageCache.shared.clearDisk()
    }
    func eraseCachedList() {
        store.dispatch(.eraseCachedList)
    }
}
