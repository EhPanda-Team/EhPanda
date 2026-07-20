import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import Sharing
import SwiftUI

public struct CustomToolbarItem<Content: View>: ToolbarContent {
    private let placement: ToolbarItemPlacement
    private let disabled: Bool
    private let content: Content

    public init(
        placement: ToolbarItemPlacement = .navigationBarTrailing,
        disabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.disabled = disabled
        self.content = content()
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            HStack(spacing: 14) {
                content
            }
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
            Label(.more, systemSymbol: .ellipsisCircle)
                .labelStyle(.iconOnly)
                .symbolRenderingMode(symbolRenderingMode)
        }
    }
}

public struct FiltersButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // A plain `Label` renders icon-only in a toolbar and as an icon+title
            // row inside `ToolbarFeaturesMenu`, so the container picks the
            // presentation — no explicit `.labelStyle` needed.
            Label(.RLocalizable.filters, systemSymbol: .line3HorizontalDecrease)
        }
    }
}

public struct QuickSearchButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(.RLocalizable.quickSearch, systemSymbol: .magnifyingglass)
        }
    }
}

public struct JumpPageButton: View {
    private let pageNumber: PageNumber
    private let action: () -> Void

    public init(pageNumber: PageNumber, action: @escaping () -> Void) {
        self.pageNumber = pageNumber
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(.RLocalizable.jumpPage, systemSymbol: .arrowshapeBounceForward)
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
            Label(.RLocalizable.dateSeek, systemSymbol: .calendar)
        }
        .disabled(navigation == nil)
    }
}

public struct FavoritesIndexMenu: View {
    @SharedReader(.user) private var user: User
    private let index: Int
    private let action: (Int) -> Void

    public init(index: Int, action: @escaping (Int) -> Void) {
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
            Label(.RLocalizable.favorites, systemSymbol: .dialLow)
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
            Label(.toplistsType, systemSymbol: .dialLow)
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
            Label(.sortOrder, systemSymbol: .arrowUpArrowDownCircle)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
