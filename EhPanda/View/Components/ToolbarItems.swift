//
//  ToolbarItems.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import SwiftUI

struct CustomToolbarItem<Content: View>: ToolbarContent {
    private let placement: ToolbarItemPlacement
    private let content: Content

    init(placement: ToolbarItemPlacement = .navigationBarTrailing, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            HStack {
                content
            }
            .foregroundColor(.primary)
        }
    }
}

struct ToolbarFeaturesMenu<Content: View>: View {
    private let content: Content

    init(content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemSymbol: .ellipsisCircle)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct JumpPageButton: View {
    private let pageNumber: PageNumber
    private let action: () -> Void

    init(pageNumber: PageNumber, action: @escaping () -> Void) {
        self.pageNumber = pageNumber
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemSymbol: .arrowshapeBounceForward)
            Text("Jump page")
        }
        .disabled(pageNumber.isSinglePage)
    }
}

struct FavoritesIndexMenu: View {
    private let user: User
    private let index: Int
    private let action: (Int) -> Void

    init(user: User, index: Int, action: @escaping (Int) -> Void) {
        self.user = user
        self.index = index
        self.action = action
    }

    var body: some View {
        Menu {
            ForEach(-1..<10) { index in
                Button {
                    action(index)
                } label: {
                    Text(user.getFavoritesName(index: index))
                    if index == self.index {
                        Image(systemSymbol: .checkmark)
                    }
                }
            }
        } label: {
            Image(systemSymbol: .dialMin)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct SortOrderMenu: View {
    private let sortOrder: FavoritesSortOrder?
    private let action: (FavoritesSortOrder) -> Void

    init(sortOrder: FavoritesSortOrder?, action: @escaping (FavoritesSortOrder) -> Void) {
        self.sortOrder = sortOrder
        self.action = action
    }

    var body: some View {
        Menu {
            ForEach(FavoritesSortOrder.allCases) { order in
                Button {
                    action(order)
                } label: {
                    Text(order.value.localized)
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
