//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI

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
            .sheet(item: $store.appState.environment.settingViewSheetState, content: sheet)
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
