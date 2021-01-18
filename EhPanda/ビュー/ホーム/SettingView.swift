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
    
    // MARK: SettingView本体
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SettingRow(
                        symbolName: "person.fill",
                        text: "アカウント",
                        destination: AccountSettingView()
                    )
                    SettingRow(
                        symbolName: "switch.2",
                        text: "一般",
                        destination: GeneralSettingView()
                    )
                    SettingRow(
                        symbolName: "circle.righthalf.fill",
                        text: "外観",
                        destination: AppearanceSettingView()
                    )
                    SettingRow(
                        symbolName: "newspaper.fill",
                        text: "閲覧",
                        destination: ReadingSettingView()
                    )
                    SettingRow(
                        symbolName: "p.circle.fill",
                        text: "EhPandaについて",
                        destination: EhPandaView()
                    )
                }
                .padding(.vertical, 40)
                .padding(.horizontal)
            }
            .navigationBarTitle("設定")
            .onAppear(perform: onAppear)
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
        }
    }
    
    func onAppear() {
        calculateDiskCachesSize()
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
                store.dispatch(
                    .updateDiskImageCacheSize(
                        size: readableUnit(bytes: Int64(size))
                    )
                )
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
}

// MARK: SettingRow
private struct SettingRow<Destination : View>: View {
    @Environment(\.colorScheme) var colorScheme
    @State var isPressing = false
    @State var isActive = false
    
    let symbolName: String
    let text: String
    let destination: Destination
    
    var color: Color {
        colorScheme == .light
            ? Color(.darkGray)
            : Color(.lightGray)
    }
    var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }
    
    var body: some View {
        ZStack {
            NavigationLink(
                "",
                destination: destination,
                isActive: $isActive
            )
            HStack {
                Image(systemName: symbolName)
                    .font(.largeTitle)
                    .foregroundColor(color)
                    .padding(.trailing, 20)
                    .frame(width: 40)
                Text(text)
                    .fontWeight(.medium)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(backgroundColor)
            .cornerRadius(10)
            .onTapGesture {
                isActive.toggle()
            }
            .onLongPressGesture(
                minimumDuration: .infinity,
                maximumDistance: 50,
                pressing: { isPressing = $0 },
                perform: {}
            )
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
