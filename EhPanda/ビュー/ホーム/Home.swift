//
//  Home.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/20.
//  Copied from https://kavsoft.dev/SwiftUI_2.0/Twitter_Menu/
//

import SwiftUI
import Kingfisher

struct Home : View {
    @EnvironmentObject var store: Store
    @State var direction: Direction = .none
    @State var offset = -Defaults.FrameSize.slideMenuWidth
    
    enum Direction {
        case none
        case toLeft
        case toRight
    }
    
    let width = Defaults.FrameSize.slideMenuWidth
    
    var hasPermission: Bool {
        vcsCount == 1
    }
    var opacity: Double {
        Double((width + offset) / width) * 0.5
    }
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
            HomeView()
                .offset(x: offset + width)
            SlideMenu(offset: $offset)
                .offset(x: offset)
                .background(
                    Color.black.opacity(opacity)
                        .edgesIgnoringSafeArea(.vertical)
                        .onTapGesture {
                            performTransition(-width)
                        }
                )
        }
        .gesture (
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if hasPermission {
                        withAnimation {
                            switch direction {
                            case .none:
                                let isToLeft = value.translation.width < 0
                                direction = isToLeft ? .toLeft : .toRight
                            case .toLeft:
                                if offset > -width {
                                    offset = min(value.translation.width, 0)
                                }
                            case .toRight:
                                if offset < 0 {
                                    offset = max(-width + value.translation.width, -width)
                                }
                            }
                        }
                    }
                }
                .onEnded { value in
                    if hasPermission {
                        withAnimation {
                            let perdictedWidth = value.predictedEndTranslation.width
                            if perdictedWidth > width / 2 || -offset < width / 2 {
                                performTransition(0)
                            }
                            if perdictedWidth < -width / 2 || -offset > width / 2 {
                                performTransition(-width)
                            }
                            direction = .none
                        }
                    }
                }
            
        )
    }
    
    func performTransition(_ offset: CGFloat) {
        withAnimation(Animation.default) {
            self.offset = offset
        }
    }
}

// MARK: SlideMenu
private struct SlideMenu : View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    @Binding var offset: CGFloat
    
    var homeListType: HomeListType {
        store.appState.environment.homeListType
    }
    var user: User? {
        store.appState.settings.user
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
    var menuItems: [HomeListType]
        = [.frontpage, .popular, .watched, .favorites, .downloaded]
    var edges = UIApplication.shared.windows.first?.safeAreaInsets
    
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
                ForEach(menuItems) { item in
                    MenuRow(
                        isSelected: item == homeListType,
                        symbolName: item.symbolName,
                        text: item.rawValue,
                        action: { onMenuRowTap(item) }
                    )
                }
                Divider()
                    .padding(.vertical)
                MenuRow(
                    isSelected: false,
                    symbolName: "gear",
                    text: "設定",
                    action: onSettingMenuRowTap
                )
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top,edges!.top == 0 ? 15 : edges?.top)
            .padding(.bottom,edges!.bottom == 0 ? 15 : edges?.bottom)
            .frame(width: Defaults.FrameSize.slideMenuWidth)
            .background(reversedPrimary)
            .edgesIgnoringSafeArea(.vertical)
            
            Spacer()
        }
    }
    
    func onMenuRowTap(_ item: HomeListType) {
        store.dispatch(.toggleHomeListType(type: item))
        performTransition(-width)
    }
    func onSettingMenuRowTap() {
        store.dispatch(.toggleHomeViewSheetState(state: .setting))
    }
    
    func performTransition(_ offset: CGFloat) {
        withAnimation {
            self.offset = offset
        }
    }
}

// MARK: AvatarView
private struct AvatarView: View {
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
                        KFImage(URL(string: avatarURL), options: [])
                            .placeholder(placeholder)
                            .cancelOnDisappear(true)
                            .resizable()
                    } else {
                        Image("")
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
    
    var symbolFont: Font {
        isSelected ? .largeTitle : .title
    }
    var textFont: Font {
        isSelected ? .title3 : .headline
    }
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
        HStack {
            Image(systemName: symbolName)
                .font(symbolFont)
                .frame(width: 35)
                .foregroundColor(textColor)
                .padding(.trailing, 20)
            Text(text.lString())
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .font(textFont)
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
