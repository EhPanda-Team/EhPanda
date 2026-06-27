import SwiftUI
import SFSafeSymbols
import AppModels
import Resources

public struct CustomToolbarItem<Content: View>: ToolbarContent {
    private let placement: ToolbarItemPlacement
    private let tint: Color?
    private let disabled: Bool
    private let content: Content

    public init(placement: ToolbarItemPlacement = .navigationBarTrailing,
         tint: Color? = nil, disabled: Bool = false,
         @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.tint = tint
        self.disabled = disabled
        self.content = content()
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            HStack(spacing: 14) {
                content
            }
            .foregroundColor(tint)
            .disabled(disabled)
        }
    }
}

public struct ToolbarFeaturesMenu<Content: View>: View {
    private let content: Content
    private let symbolRenderingMode: SymbolRenderingMode

    public init(symbolRenderingMode: SymbolRenderingMode = .monochrome, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.symbolRenderingMode = symbolRenderingMode
    }

    public var body: some View {
        Menu {
            content
        } label: {
            Image(systemSymbol: .ellipsisCircle)
                .symbolRenderingMode(symbolRenderingMode)
        }
    }
}

public struct FiltersButton: View {
    private let hideText: Bool
    private let action: () -> Void

    public init(hideText: Bool = false, action: @escaping () -> Void) {
        self.hideText = hideText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemSymbol: .line3HorizontalDecrease)
            if !hideText {
                Text(L10n.Localizable.ToolbarItem.Button.filters)
            }
        }
    }
}

public struct QuickSearchButton: View {
    private let hideText: Bool
    private let action: () -> Void

    public init(hideText: Bool = false, action: @escaping () -> Void) {
        self.hideText = hideText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemSymbol: .magnifyingglass)
            if !hideText {
                Text(L10n.Localizable.ToolbarItem.Button.quickSearch)
            }
        }
    }
}

public struct JumpPageButton: View {
    private let pageNumber: PageNumber
    private let hideText: Bool
    private let action: () -> Void

    public init(pageNumber: PageNumber, hideText: Bool = false, action: @escaping () -> Void) {
        self.pageNumber = pageNumber
        self.hideText = hideText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemSymbol: .arrowshapeBounceForward)
            if !hideText {
                Text(L10n.Localizable.ToolbarItem.Button.jumpPage)
            }
        }
        .disabled(pageNumber.isSinglePage)
    }
}

public struct DateSeekButton: View {
    private let navigation: DateSeekNavigation?
    private let action: (DateSeekNavigation) -> Void

    public init(navigation: DateSeekNavigation?, action: @escaping (DateSeekNavigation) -> Void) {
        self.navigation = navigation
        self.action = action
    }

    public var body: some View {
        Button {
            navigation.map(action)
        } label: {
            Label(L10n.Localizable.ToolbarItem.Button.dateSeek, systemSymbol: .calendar)
        }
        .disabled(navigation == nil)
    }
}

public struct FavoritesIndexMenu: View {
    private let user: User
    private let index: Int
    private let action: (Int) -> Void

    public init(user: User, index: Int, action: @escaping (Int) -> Void) {
        self.user = user
        self.index = index
        self.action = action
    }

    public var body: some View {
        Menu {
            ForEach(-1..<10) { index in
                Button {
                    action(index)
                } label: {
                    Text(user.getFavoriteCategory(index: index))
                    if index == self.index {
                        Image(systemSymbol: .checkmark)
                    }
                }
            }
        } label: {
            Image(systemSymbol: .dialLow)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

public struct ToplistsTypeMenu: View {
    private let type: ToplistsType
    private let action: (ToplistsType) -> Void

    public init(type: ToplistsType, action: @escaping (ToplistsType) -> Void) {
        self.type = type
        self.action = action
    }

    public var body: some View {
        Menu {
            ForEach(ToplistsType.allCases) { type in
                Button {
                    action(type)
                } label: {
                    Text(type.value)
                    if type == self.type {
                        Image(systemSymbol: .checkmark)
                    }
                }
            }
        } label: {
            Image(systemSymbol: .dialLow)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

public struct SortOrderMenu: View {
    private let sortOrder: FavoritesSortOrder?
    private let action: (FavoritesSortOrder) -> Void

    public init(sortOrder: FavoritesSortOrder?, action: @escaping (FavoritesSortOrder) -> Void) {
        self.sortOrder = sortOrder
        self.action = action
    }

    public var body: some View {
        Menu {
            ForEach(FavoritesSortOrder.allCases) { order in
                Button {
                    action(order)
                } label: {
                    Text(order.value)
                    if order == sortOrder {
                        Image(systemSymbol: .checkmark)
                    }
                }
            }
        } label: {
            Image(systemSymbol: .arrowUpArrowDownCircle)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
