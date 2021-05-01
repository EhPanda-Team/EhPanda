//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import Kingfisher
import SDWebImageSwiftUI

struct SettingView: View {
    @EnvironmentObject var store: Store

    var environment: AppState.Environment {
        store.appState.environment
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }

    var logoutActionSheet: ActionSheet {
        ActionSheet(title: Text("Are you sure to logout?"), buttons: [
            .destructive(Text("Logout"), action: logout),
            .cancel()
        ])
    }
    var clearImgCachesActionSheet: ActionSheet {
        ActionSheet(title: Text("Are you sure to clear?"), buttons: [
            .destructive(Text("Clear"), action: clearImageCaches),
            .cancel()
        ])
    }
    var clearWebCachesActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Warning".localized().uppercased()),
            message: Text("It's for debug only"),
            buttons: [
                .destructive(Text("Clear"), action: clearCachedList),
                .cancel()
            ]
        )
    }

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    if exx {
                        SettingRow(
                            symbolName: "person.fill",
                            text: "Account",
                            destination: AccountSettingView()
                        )
                    }
                    SettingRow(
                        symbolName: "switch.2",
                        text: "General",
                        destination: GeneralSettingView()
                            .onAppear(perform: onGeneralSettingAppear)
                    )
                    SettingRow(
                        symbolName: "circle.righthalf.fill",
                        text: "Apperance",
                        destination: AppearanceSettingView()
                    )
                    SettingRow(
                        symbolName: "newspaper.fill",
                        text: "Reading",
                        destination: ReadingSettingView()
                    )
                    SettingRow(
                        symbolName: "p.circle.fill",
                        text: "About EhPanda",
                        destination: EhPandaView()
                    )
                }
                .padding(.vertical, 40)
                .padding(.horizontal)
            }
            .navigationBarTitle("Setting")
            .sheet(item: environmentBinding.settingViewSheetState) { item in
                switch item {
                case .webviewLogin:
                    WebView(type: .ehLogin)
                        .environmentObject(store)
                        .blur(radius: environment.blurRadius)
                        .allowsHitTesting(environment.isAppUnlocked)
                case .webviewConfig:
                    WebView(type: .ehConfig)
                        .blur(radius: environment.blurRadius)
                        .allowsHitTesting(environment.isAppUnlocked)
                case .webviewMyTags:
                    WebView(type: .ehMyTags)
                        .blur(radius: environment.blurRadius)
                        .allowsHitTesting(environment.isAppUnlocked)
                }
            }
            .actionSheet(item: environmentBinding.settingViewActionSheetState) { item in
                switch item {
                case .logout:
                    return logoutActionSheet
                case .clearImgCaches:
                    return clearImgCachesActionSheet
                case .clearWebCaches:
                    return clearWebCachesActionSheet
                }
            }
        }
    }

    func onGeneralSettingAppear() {
        calculateDiskCachesSize()
    }

    func logout() {
        clearCookies()
        clearImageCaches()
        store.dispatch(.clearCachedList)
        store.dispatch(.clearHistoryItems)
        store.dispatch(.replaceUser(user: nil))
    }

    func calculateDiskCachesSize() {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                let size = size + SDImageCache.shared.totalDiskSize()
                store.dispatch(
                    .updateDiskImageCacheSize(
                        size: readableUnit(bytes: size)
                    )
                )
            case .failure(let error):
                print(error)
            }
        }
    }
    func clearImageCaches() {
        SDImageCache.shared.clear(with: .disk, completion: nil)
        KingfisherManager.shared.cache.clearDiskCache()
        calculateDiskCachesSize()
    }
    func clearCachedList() {
        store.dispatch(.clearCachedList)
        store.dispatch(.clearHistoryItems)
        store.dispatch(.fetchFrontpageItems)
    }
}

// MARK: SettingRow
private struct SettingRow<Destination: View>: View {
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
                    .frame(width: 45)
                Text(text.localized())
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

// MARK: Definition
enum SettingViewActionSheetState: Identifiable {
    var id: Int { hashValue }

    case logout
    case clearImgCaches
    case clearWebCaches
}

enum SettingViewSheetState: Identifiable {
    var id: Int { hashValue }

    case webviewLogin
    case webviewConfig
    case webviewMyTags
}
