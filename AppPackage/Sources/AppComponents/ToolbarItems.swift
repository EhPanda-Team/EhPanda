public import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI

public struct FiltersButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // A plain `Label` renders icon-only in a toolbar and as an icon+title
            // row inside native toolbar overflow, so the container picks the
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
            Label(.RLocalizable.quickSearch, systemSymbol: .textMagnifyingglass)
        }
    }
}

/// Saves a search results page's keyword as a saved search. It sits right after `QuickSearchButton`
/// in the overflow menu, and the host disables it when the keyword cannot be saved.
public struct SaveSearchButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(.RLocalizable.saveSearch, systemSymbol: .textBadgePlus)
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
