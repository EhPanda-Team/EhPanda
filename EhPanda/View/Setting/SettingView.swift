//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import Kingfisher
import SwiftyBeaver

struct SettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SettingRow(
                        symbolName: "person.fill", text: "Account",
                        destination: AccountSettingView()
                    )
                    SettingRow(
                        symbolName: "switch.2", text: "General",
                        destination: GeneralSettingView()
                            .onAppear(perform: calculateDiskCachesSize)
                    )
                    SettingRow(
                        symbolName: "circle.righthalf.fill", text: "Appearance",
                        destination: AppearanceSettingView()
                    )
                    SettingRow(
                        symbolName: "newspaper.fill", text: "Reading",
                        destination: ReadingSettingView()
                    )
                    SettingRow(
                        symbolName: "testtube.2", text: "Laboratory",
                        destination: LaboratorySettingView()
                    )
                    SettingRow(
                        symbolName: "p.circle.fill", text: "About EhPanda",
                        destination: EhPandaView()
                    )
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .navigationBarTitle("Setting")
            .sheet(item: environmentBinding.settingViewSheetState, content: sheet)
            .actionSheet(item: environmentBinding.settingViewActionSheetState, content: actionSheet)
        }
    }
    private func sheet(item: SettingViewSheetState) -> some View {
        Group {
            switch item {
            case .webviewLogin:
                WebView(url: Defaults.URL.webLogin.safeURL())
            case .webviewConfig:
                WebView(url: Defaults.URL.ehConfig().safeURL())
            case .webviewMyTags:
                WebView(url: Defaults.URL.ehMyTags().safeURL())
            }
        }
        .blur(radius: environment.blurRadius)
        .allowsHitTesting(environment.isAppUnlocked)
    }
    private func actionSheet(item: SettingViewActionSheetState) -> ActionSheet {
        switch item {
        case .logout:
            return ActionSheet(title: Text("Are you sure to logout?"), buttons: [
                .destructive(Text("Logout"), action: logout), .cancel()
            ])
        case .clearImageCaches:
            return ActionSheet(title: Text("Are you sure to clear?"), buttons: [
                .destructive(Text("Clear"), action: clearImageCaches), .cancel()
            ])
        }
    }
}

private extension SettingView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }

    func logout() {
        clearImageCaches()
        CookiesUtil.clearAll()
        store.dispatch(.resetUser)
    }

    func readableUnit<I: BinaryInteger>(bytes: I) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        return formatter.string(fromByteCount: Int64(bytes))
    }
    func calculateDiskCachesSize() {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                store.dispatch(.setDiskImageCacheSize(size: readableUnit(bytes: size)))
            case .failure(let error):
                SwiftyBeaver.error(error)
            }
        }
    }
    func clearImageCaches() {
        KingfisherManager.shared.cache.clearDiskCache()
        PersistenceController.removeImageURLs()
        calculateDiskCachesSize()
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
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(symbolName: String, text: String, destination: Destination) {
        self.symbolName = symbolName
        self.text = text
        self.destination = destination
    }

    var body: some View {
        HStack {
            Image(systemName: symbolName)
                .font(.largeTitle).foregroundColor(color)
                .padding(.trailing, 20).frame(width: 45)
            Text(text.localized).fontWeight(.medium)
                .font(.title3).foregroundColor(color)
            Spacer()
        }
        .background {
            NavigationLink("", destination: destination, isActive: $isActive)
        }
        .contentShape(Rectangle()).padding(.vertical, 10)
        .padding(.horizontal, 20).background(backgroundColor)
        .cornerRadius(10).onTapGesture { isActive.toggle() }
        .onLongPressGesture(
            minimumDuration: .infinity, maximumDistance: 50,
            pressing: { isPressing = $0 }, perform: {}
        )
    }
}

// MARK: Definition
enum SettingViewActionSheetState: Identifiable {
    var id: Int { hashValue }

    case logout
    case clearImageCaches
}

enum SettingViewSheetState: Identifiable {
    var id: Int { hashValue }

    case webviewLogin
    case webviewConfig
    case webviewMyTags
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView().environmentObject(Store.preview)
    }
}
