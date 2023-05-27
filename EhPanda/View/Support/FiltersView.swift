//
//  FiltersView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI
import ComposableArchitecture

struct FiltersView: View {
    private let store: StoreOf<FiltersReducer>
    @ObservedObject private var viewStore: ViewStoreOf<FiltersReducer>

    @FocusState private var focusedBound: FiltersReducer.FocusedBound?

    init(store: StoreOf<FiltersReducer>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    private var filter: Binding<Filter> {
        switch viewStore.filterRange {
        case .search:
            return viewStore.binding(\.$searchFilter)
        case .global:
            return viewStore.binding(\.$globalFilter)
        case .watched:
            return viewStore.binding(\.$watchedFilter)
        }
    }

    // MARK: FilterView
    var body: some View {
        NavigationView {
            Form {
                BasicSection(
                    route: viewStore.binding(\.$route),
                    filter: filter, filterRange: viewStore.binding(\.$filterRange),
                    resetFiltersAction: { viewStore.send(.resetFilters) },
                    resetFiltersDialogAction: { viewStore.send(.setNavigation(.resetFilters)) }
                )
                AdvancedSection(
                    filter: filter, focusedBound: $focusedBound,
                    submitAction: { viewStore.send(.onTextFieldSubmitted) }
                )
            }
            .synchronize(viewStore.binding(\.$focusedBound), $focusedBound)
            .navigationTitle(L10n.Localizable.FiltersView.Title.filters)
            .onAppear { viewStore.send(.fetchFilters) }
        }
    }
}

// MARK: BasicSection
private struct BasicSection: View {
    @Binding private var route: FiltersReducer.Route?
    @Binding private var filter: Filter
    @Binding private var filterRange: FilterRange
    private let resetFiltersAction: () -> Void
    private let resetFiltersDialogAction: () -> Void
    private var categoryBindings: [Binding<Bool>] { [
        $filter.doujinshi, $filter.manga, $filter.artistCG, $filter.gameCG, $filter.western,
        $filter.nonH, $filter.imageSet, $filter.cosplay, $filter.asianPorn, $filter.misc
    ] }

    init(
        route: Binding<FiltersReducer.Route?>, filter: Binding<Filter>, filterRange: Binding<FilterRange>,
        resetFiltersAction: @escaping () -> Void, resetFiltersDialogAction: @escaping () -> Void
    ) {
        _route = route
        _filter = filter
        _filterRange = filterRange
        self.resetFiltersAction = resetFiltersAction
        self.resetFiltersDialogAction = resetFiltersDialogAction
    }

    var body: some View {
        Section {
            Picker("", selection: $filterRange) {
                ForEach(FilterRange.allCases) { range in
                    Text(range.value).tag(range)
                }
            }
            .pickerStyle(.segmented)
            CategoryView(bindings: categoryBindings)
            Button(action: resetFiltersDialogAction) {
                Text(L10n.Localizable.FiltersView.Button.resetFilters).foregroundStyle(.red)
            }
            .confirmationDialog(
                message: L10n.Localizable.ConfirmationDialog.Title.reset,
                unwrapping: $route, case: /FiltersReducer.Route.resetFilters
            ) {
                Button(
                    L10n.Localizable.ConfirmationDialog.Button.reset,
                    role: .destructive, action: resetFiltersAction
                )
            }
            Toggle(L10n.Localizable.FiltersView.Title.advancedSettings, isOn: $filter.advanced)
        }
    }
}

// MARK: AdvancedSection
private struct AdvancedSection: View {
    @Binding private var filter: Filter
    private let focusedBound: FocusState<FiltersReducer.FocusedBound?>.Binding
    private let submitAction: () -> Void

    init(
        filter: Binding<Filter>,
        focusedBound: FocusState<FiltersReducer.FocusedBound?>.Binding,
        submitAction: @escaping () -> Void
    ) {
        _filter = filter
        self.focusedBound = focusedBound
        self.submitAction = submitAction
    }

    var body: some View {
        Group {
            Section(L10n.Localizable.FiltersView.Section.Title.advanced) {
                Toggle(L10n.Localizable.FiltersView.Title.searchGalleryName, isOn: $filter.galleryName)
                Toggle(L10n.Localizable.FiltersView.Title.searchGalleryTags, isOn: $filter.galleryTags)
                Toggle(L10n.Localizable.FiltersView.Title.searchGalleryDescription, isOn: $filter.galleryDesc)
                Toggle(L10n.Localizable.FiltersView.Title.searchTorrentFilenames, isOn: $filter.torrentFilenames)
                Toggle(
                    L10n.Localizable.FiltersView.Title.onlyShowGalleriesWithTorrents,
                    isOn: $filter.onlyWithTorrents
                )
                Toggle(L10n.Localizable.FiltersView.Title.searchLowPowerTags, isOn: $filter.lowPowerTags)
                Toggle(L10n.Localizable.FiltersView.Title.searchDownvotedTags, isOn: $filter.downvotedTags)
                Toggle(L10n.Localizable.FiltersView.Title.searchExpungedGalleries, isOn: $filter.expungedGalleries)
            }
            Section {
                Toggle(L10n.Localizable.FiltersView.Title.setMinimumRating, isOn: $filter.minRatingActivated)
                MinimumRatingSetter(minimum: $filter.minRating)
                    .disabled(!filter.minRatingActivated)
                Toggle(L10n.Localizable.FiltersView.Title.setPagesRange, isOn: $filter.pageRangeActivated)
                    .disabled(focusedBound.wrappedValue != nil)
                PagesRangeSetter(
                    lowerBound: $filter.pageLowerBound,
                    upperBound: $filter.pageUpperBound,
                    focusedBound: focusedBound,
                    submitAction: submitAction
                )
                .disabled(!filter.pageRangeActivated)
            }
            Section(L10n.Localizable.FiltersView.Section.Title.defaultFilter) {
                Toggle(L10n.Localizable.FiltersView.Title.disableLanguageFilter, isOn: $filter.disableLanguage)
                Toggle(L10n.Localizable.FiltersView.Title.disableUploaderFilter, isOn: $filter.disableUploader)
                Toggle(L10n.Localizable.FiltersView.Title.disableTagsFilter, isOn: $filter.disableTags)
            }
        }
        .disabled(!filter.advanced)
    }
}

// MARK: MinimumRatingSetter
private struct MinimumRatingSetter: View {
    @Binding private var minimum: Int

    init(minimum: Binding<Int>) {
        _minimum = minimum
    }

    var body: some View {
        Picker(L10n.Localizable.FiltersView.Title.minimumRating, selection: $minimum) {
            ForEach(Array(2...5), id: \.self) { number in
                Text(L10n.Localizable.Common.Value.stars("\(number)")).tag(number)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: PagesRangeSetter
private struct PagesRangeSetter: View {
    @Binding private var lowerBound: String
    @Binding private var upperBound: String
    private let focusedBound: FocusState<FiltersReducer.FocusedBound?>.Binding
    private let submitAction: () -> Void

    init(
        lowerBound: Binding<String>,
        upperBound: Binding<String>,
        focusedBound: FocusState<FiltersReducer.FocusedBound?>.Binding,
        submitAction: @escaping () -> Void
    ) {
        _lowerBound = lowerBound
        _upperBound = upperBound
        self.focusedBound = focusedBound
        self.submitAction = submitAction
    }

    var body: some View {
        HStack {
            Text(L10n.Localizable.FiltersView.Title.pagesRange)
            Spacer()
            SettingTextField(text: $lowerBound)
                .focused(focusedBound, equals: .lower)
                .submitLabel(.next)
            Text("-")
            SettingTextField(text: $upperBound)
                .focused(focusedBound, equals: .upper)
                .submitLabel(.done)
        }
        .onSubmit(submitAction)
    }
}

// MARK: Definition
private struct TupleCategory: Identifiable {
    var id: String { category.rawValue }

    let isFiltered: Binding<Bool>
    let category: Category
}

enum FilterRange: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case search
    case global
    case watched
}
extension FilterRange {
    var value: String {
        switch self {
        case .search:
            return L10n.Localizable.Enum.FilterRange.Value.search
        case .global:
            return L10n.Localizable.Enum.FilterRange.Value.global
        case .watched:
            return L10n.Localizable.Enum.FilterRange.Value.watched
        }
    }
}

struct FiltersView_Previews: PreviewProvider {
    static var previews: some View {
        FiltersView(
            store: .init(
                initialState: .init(),
                reducer: FiltersReducer()
            )
        )
    }
}
