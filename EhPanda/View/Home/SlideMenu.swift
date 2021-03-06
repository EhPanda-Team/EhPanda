//
//  SlideMenu.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/18.
//

import SwiftUI
import Kingfisher
import SDWebImageSwiftUI

struct SlideMenu : View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    @Binding var offset: CGFloat
    
    var edges = UIApplication.shared.windows
        .first?.safeAreaInsets
    
    var settings: AppState.Settings {
        store.appState.settings
    }
    var environment: AppState.Environment {
        store.appState.environment
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var user: User? {
        settings.user
    }
    var setting: Setting? {
        settings.setting
    }
    var homeListType: HomeListType {
        environment.homeListType
    }
    var favoritesIndexBinding: Binding<Int> {
        environmentBinding.favoritesIndex
    }
    var width: CGFloat {
        Defaults.FrameSize.slideMenuWidth
    }
    var avatarW: CGFloat {
        Defaults.ImageSize.avatarW
    }
    var avatarH: CGFloat {
        Defaults.ImageSize.avatarH
    }
    var reversedPrimary: Color {
        colorScheme == .light ? .white : .black
    }
    var exxMenuItems = HomeListType
        .allCases.filter({ $0 != .search })
    var menuItems: [HomeListType] {
        if exx {
            return exxMenuItems
        } else {
            return Array(exxMenuItems.prefix(2))
        }
    }
    
    // MARK: SlideMenu
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                AvatarView(
                    avatarURL: user?.avatarURL,
                    displayName: user?.displayName,
                    width: avatarW,
                    height: avatarH
                )
                .padding(.top, 40)
                .padding(.bottom, 20)
                Divider()
                    .padding(.vertical)
                ScrollView(showsIndicators: false) {
                    ForEach(menuItems) { item in
                        MenuRow(
                            isSelected: item == homeListType,
                            symbolName: item.symbolName,
                            text: item.rawValue,
                            action: { onMenuRowTap(item) }
                        )
                    }
                }
                Divider()
                    .padding(.vertical)
                MenuRow(
                    isSelected: false,
                    symbolName: "gear",
                    text: "Setting",
                    action: onSettingMenuRowTap
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, edges?.top == 0 ? 15 : edges?.top)
            .padding(.bottom, edges?.bottom == 0 ? 15 : edges?.bottom)
            .frame(width: Defaults.FrameSize.slideMenuWidth)
            .background(reversedPrimary)
            .edgesIgnoringSafeArea(.vertical)
            
            Spacer()
        }
        .onChange(
            of: environment.favoritesIndex,
            perform: onFavoritesIndexChange
        )
    }
    
    func onMenuRowTap(_ item: HomeListType) {
        if homeListType != item {
            store.dispatch(.toggleHomeListType(type: item))
            impactFeedback(style: .soft)
            
            if setting?.closeSlideMenuAfterSelection == true {
                performTransition(-width)
            }
        }
    }
    func onSettingMenuRowTap() {
        store.dispatch(.toggleHomeViewSheetState(state: .setting))
    }
    func onFavoritesIndexChange(_ : Int) {
        if setting?.closeSlideMenuAfterSelection == true {
            performTransition(-width)
        }
    }
    
    func performTransition(_ offset: CGFloat) {
        withAnimation {
            self.offset = offset
        }
    }
}

// MARK: AvatarView
private struct AvatarView: View {
    @EnvironmentObject var store: Store
    
    var iconType: IconType {
        store.appState
            .settings.setting?
            .appIconType ?? appIconType
    }
    
    let avatarURL: String?
    let displayName: String?
    
    let width: CGFloat
    let height: CGFloat
    
    func placeholder() -> some View {
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Group {
                    if let avatarURL = avatarURL {
                        if !avatarURL.contains(".gif") {
                            KFImage(URL(string: avatarURL))
                                .placeholder(placeholder)
                                .resizable()
                        } else {
                            WebImage(url: URL(string: avatarURL))
                                .placeholder(content: placeholder)
                                .resizable()
                        }
                    } else {
                        Image(iconType.iconName)
                            .resizable()
                    }
                }
                .scaledToFit()
                .frame(width: width, height: height)
                .clipShape(Circle())
                Text(displayName ?? "Sad Panda")
                    .fontWeight(.bold)
                    .font(.largeTitle)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

// MARK: MenuRow
private struct MenuRow: View {
    @Environment(\.colorScheme) var colorScheme
    @State var isPressing = false
    let isSelected: Bool
    
    let symbolName: String
    let text: String
    let action: (()->())
    
    var textColor: Color {
        isSelected
            ? .primary
            : (colorScheme == .light
                ? Color(.darkGray)
                : Color(.lightGray))
    }
    var backgroundColor: Color {
        let color = Color(.systemGray6)
        
        return isSelected
            ? color
            : (isPressing
                ? color.opacity(0.6)
                : .clear)
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: symbolName)
                    .font(.title)
                    .frame(width: 35)
                    .foregroundColor(textColor)
                    .padding(.trailing, 20)
                Text(text.lString())
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(backgroundColor)
            .cornerRadius(10)
            .onTapGesture(perform: action)
            .onLongPressGesture(
                minimumDuration: .infinity,
                maximumDistance: 50,
                pressing: { isPressing = $0 },
                perform: {}
            )
        }
    }
}
