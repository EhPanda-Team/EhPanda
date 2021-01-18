//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import Kingfisher

struct SettingView: View {
    @EnvironmentObject var store: Store
    @State var diskCachesSize = "0 KB"
    
    var settings: AppState.Settings {
        store.appState.settings
    }
    var settingsBinding: Binding<AppState.Settings> {
        $store.appState.settings
    }
    var setting: Setting? {
        settings.setting
    }
    var settingBinding: Binding<Setting>? {
        Binding(settingsBinding.setting)
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
//            if let setting = setting,
//               let settingBinding = settingBinding {
//                Form {
//                    Section(header: Text("アカウント")) {
//                        Picker(
//                            selection: settingBinding.galleryType,
//                            label: Text("ギャラリー"),
//                            content: {
//                                let galleryTypes: [GalleryType] = [.eh, .ex]
//                                ForEach(galleryTypes, id: \.self) {
//                                    Text($0.rawValue.lString())
//                                }
//                            })
//                            .pickerStyle(SegmentedPickerStyle())
//                        if didLogin {
//                            Text("ログイン済み")
//                                .foregroundColor(.gray)
//                        } else {
//                            Button("ログイン", action: onLoginTap)
//                        }
//
//                        Button(action: toggleLogout) {
//                            Text("ログアウト")
//                                .foregroundColor(.red)
//                        }
//                        NavigationLink(
//                            destination: CookiesView(),
//                            label: {
//                                Text("クッキーを管理")
//                            }
//                        )
//                    }
//                    Section(header: Text("外観")) {
//                        if isPad {
//                            Toggle(isOn: settingBinding.hideSideBar) {
//                                Text("サイドバーを表示しない")
//                            }
//                        }
//                        Toggle(isOn: settingBinding.showContentDividers, label: {
//                            Text("画像の間に仕切りを挿む")
//                        })
//                        if setting.showContentDividers {
//                            HStack {
//                                Text("仕切りの厚さ")
//                                Picker(selection: settingBinding.contentDividerHeight, label: Text("Picker"), content: {
//                                    Text("5").tag(CGFloat(5))
//                                    Text("10").tag(CGFloat(10))
//                                    Text("15").tag(CGFloat(15))
//                                    Text("20").tag(CGFloat(20))
//                                })
//                                .pickerStyle(SegmentedPickerStyle())
//                                .padding(.leading, 10)
//                            }
//                        }
//
//                        Toggle(isOn: settingBinding.showSummaryRowTags) {
//                            HStack {
//                                Text("リストでタグを表示")
//                                if setting.showSummaryRowTags {
//                                    Image(systemName: "exclamationmark.triangle.fill")
//                                        .foregroundColor(.yellow)
//                                }
//                            }
//                        }
//                        if setting.showSummaryRowTags {
//                            Toggle(isOn: settingBinding.summaryRowTagsMaximumActivated) {
//                                Text("リストでのタグ数を制限")
//                            }
//                        }
//                        if setting.summaryRowTagsMaximumActivated {
//                            HStack {
//                                Text("タグ数上限")
//                                Spacer()
//                                TextField("", text: settingBinding.rawSummaryRowTagsMaximum)
//                                    .multilineTextAlignment(.center)
//                                    .keyboardType(.numberPad)
//                                    .background(Color(.systemGray6))
//                                    .frame(width: 50)
//                                    .cornerRadius(5)
//                            }
//                        }
//                    }
//                    Section(header: Text("キャッシュ")) {
//                        Button(action: toggleClearImgCaches) {
//                            HStack {
//                                Text("画像キャッシュを削除")
//                                Spacer()
//                                Text(diskCachesSize)
//                            }
//                            .foregroundColor(.primary)
//                        }
//                        Button(action: toggleClearWebCaches) {
//                            HStack {
//                                Text("ウェブキャッシュを削除")
//                                Spacer()
//                                Text(browsingCaches())
//                            }
//                            .foregroundColor(.primary)
//                        }
//                    }
//                }
//                .onAppear(perform: onAppear)
//                .sheet(item: environmentBinding.settingViewSheetState, content: { item in
//                    switch item {
//                    case .webview:
//                        WebView()
//                            .environmentObject(store)
//                    }
//                })
//                .actionSheet(item: environmentBinding.settingViewActionSheetState, content: { item in
//                    switch item {
//                    case .logout:
//                        return logoutActionSheet
//                    case .clearImgCaches:
//                        return clearImgCachesActionSheet
//                    case .clearWebCaches:
//                        return clearWebCachesActionSheet
//                    }
//                })
//                .navigationBarTitle("設定")
//            }
            
            
            ScrollView {
                VStack(alignment: .leading) {
                    Group {
                        SettingRow(symbolName: "person.fill", text: "アカウント")
                        SettingRow(symbolName: "switch.2", text: "一般")
                        SettingRow(symbolName: "circle.righthalf.fill", text: "外観")
                        SettingRow(symbolName: "newspaper.fill", text: "閲覧")
                        SettingRow(symbolName: "p.circle.fill", text: "EhPandaについて")
                    }
                    .padding(.vertical, 5)
                }
                .padding(40)
            }
            .navigationBarTitle("設定")
        }
    }
    
    func onAppear() {
        calculateDiskCachesSize()
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
    
    func calculateDiskCachesSize() {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                diskCachesSize = readableUnit(bytes: Int64(size))
            case .failure(let error):
                print(error)
            }
        }
    }
    func clearImageCaches() {
        KingfisherManager.shared.cache.clearDiskCache()
        calculateDiskCachesSize()
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

private struct SettingRow: View {
    let symbolName: String
    let text: String
    
    var body: some View {
        SFLabel(
            symbolName: symbolName,
            symbolFont: .largeTitle,
            symbolForeground: Color(.darkGray),
            symbolWidth: 40,
            text: text,
            textFontWeight: .medium,
            textFont: .title3,
            textForeground: Color(.darkGray),
            spacing: 20
        )
    }
}

private struct SFLabel: View {
    let symbolName: String
    var symbolFont: Font?
    var symbolForeground: Color?
    var symbolWidth: CGFloat?
    
    let text: String
    var textFontWeight: Font.Weight?
    var textFont: Font?
    var textForeground: Color?
    
    let spacing: CGFloat
    
    var body: some View {
        HStack {
            Image(systemName: symbolName)
                .font(symbolFont)
                .foregroundColor(symbolForeground)
                .padding(.trailing, spacing)
                .frame(width: symbolWidth)
            Text(text)
                .fontWeight(textFontWeight)
                .font(textFont)
                .foregroundColor(textForeground)
            Spacer()
        }
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
