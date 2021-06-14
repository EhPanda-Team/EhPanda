//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import Kingfisher
import SDWebImageSwiftUI

struct SettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SettingRow(
                        symbolName: "person.fill",
                        text: "Account",
                        destination: AccountSettingView()
                    )
                    SettingRow(
                        symbolName: "switch.2",
                        text: "General",
                        destination: GeneralSettingView()
                            .task(calculateDiskCachesSize)
                    )
                    SettingRow(
                        symbolName: "circle.righthalf.fill",
                        text: "Appearance",
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
                Group {
                    switch item {
                    case .webviewLogin:
                        WebView(type: .ehLogin)
                    case .webviewConfig:
                        WebView(type: .ehConfig)
                    case .webviewMyTags:
                        WebView(type: .ehMyTags)
                    }
                }
                .blur(radius: environment.blurRadius)
                .allowsHitTesting(environment.isAppUnlocked)
            }
            .actionSheet(item: environmentBinding.settingViewActionSheetState) { item in
                switch item {
                case .logout:
                    return ActionSheet(title: Text("Are you sure to logout?"), buttons: [
                        .destructive(Text("Logout"), action: logout),
                        .cancel()
                    ])
                case .clearImgCaches:
                    return ActionSheet(title: Text("Are you sure to clear?"), buttons: [
                        .destructive(Text("Clear"), action: clearImageCaches),
                        .cancel()
                    ])
                case .clearWebCaches:
                    return ActionSheet(
                        title: Text("Warning".localized().uppercased()),
                        message: Text("It's for debug only."),
                        buttons: [
                            .destructive(Text("Clear"), action: clearCachedList),
                            .cancel()
                        ]
                    )
                }
            }
        }
    }
}

private extension SettingView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false
    @State private var isActive = false

    private let symbolName: String
    private let text: String
    private let destination: Destination

    private var color: Color {
        colorScheme == .light
            ? Color(.darkGray)
            : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(
        symbolName: String,
        text: String,
        destination: Destination
    ) {
        self.symbolName = symbolName
        self.text = text
        self.destination = destination
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

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store()
        store.appState.settings.setting = Setting()
        store.appState.environment.isPreview = true

        return SettingView()
            .environmentObject(store)
    }
}
