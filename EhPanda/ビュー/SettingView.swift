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
    
    var logoutActionSheet: ActionSheet {
        ActionSheet(title: Text("本当にログアウトしますか？"), buttons: [
            .destructive(Text("ログアウト"), action: logout),
            .cancel()
        ])
    }
    var clearImgCachesActionSheet: ActionSheet {
        ActionSheet(title: Text("本当に削除しますか？"), buttons: [
            .destructive(Text("削除"), action: clearImageCaches),
            .cancel()
        ])
    }
    var clearWebCachesActionSheet: ActionSheet {
        ActionSheet(
            title: Text("警告"),
            message: Text("デバッグ専用機能です"),
            buttons: [
                .destructive(Text("削除"), action: clearCachedList),
                .cancel()
            ]
        )
    }
    
    var body: some View {
        NavigationView {
            if let settingBinding = Binding(settingsBinding.setting) {
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
                        if didLogin {
                            Text("ログイン済み")
                                .foregroundColor(.gray)
                        } else {
                            Button("ログイン", action: onLoginTap)
                        }
                        
                        Button(action: toggleLogout) {
                            Text("ログアウト")
                                .foregroundColor(.red)
                        }
                        NavigationLink(
                            destination: PermissionView(),
                            label: {
                                Text("権限を確認")
                            }
                        )
                    }
                    if isPad {
                        Section(header: Text("外観")) {
                            Toggle(isOn: settingBinding.hideSideBar) {
                                Text("サイドバーを表示しない")
                            }
                        }
                    }
                    Section(header: Text("キャッシュ")) {
                        Button(action: toggleClearImgCaches) {
                            HStack {
                                Text("画像キャッシュを削除")
                                Spacer()
                                Text(diskImageCaches())
                            }
                            .foregroundColor(.primary)
                        }
                        Button(action: toggleClearWebCaches) {
                            HStack {
                                Text("ウェブキャッシュを削除")
                                Spacer()
                                Text(browsingCaches())
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .sheet(item: environmentBinding.settingViewSheetState, content: { item in
                    switch item {
                    case .webview:
                        WebView()
                            .environmentObject(store)
                    }
                })
                .actionSheet(item: environmentBinding.settingViewActionSheetState, content: { item in
                    switch item {
                    case .logout:
                        return logoutActionSheet
                    case .clearImgCaches:
                        return clearImgCachesActionSheet
                    case .clearWebCaches:
                        return clearWebCachesActionSheet
                    }
                })
                .navigationBarTitle("設定")
            }
        }
    }
    
    func onLoginTap() {
        toggleWebView()
    }
    func logout() {
        clearCookies()
        clearImageCaches()
        store.dispatch(.clearCachedList)
        store.dispatch(.updateUser(user: nil))
    }
    func clearImageCaches() {
        SDImageCache.shared.clearDisk()
    }
    func clearCachedList() {
        store.dispatch(.clearCachedList)
        store.dispatch(.fetchPopularItems)
        store.dispatch(.fetchFavoritesItems)
    }
    
    func toggleWebView() {
        store.dispatch(.toggleSettingViewSheetState(state: .webview))
    }
    func toggleLogout() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .logout))
    }
    func toggleClearImgCaches() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .clearImgCaches))
    }
    func toggleClearWebCaches() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .clearWebCaches))
    }
}

// MARK: 定義
enum SettingViewActionSheetState: Identifiable {
    var id: Int { hashValue }
    
    case logout
    case clearImgCaches
    case clearWebCaches
}

enum SettingViewSheetState: Identifiable {
    var id: Int { hashValue }
    
    case webview
}
