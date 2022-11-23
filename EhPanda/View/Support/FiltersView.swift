//
//  FiltersView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI
import ComposableArchitecture

struct FiltersView: View {
    private let store: Store<FiltersState, FiltersAction>
    @ObservedObject private var viewStore: ViewStore<FiltersState, FiltersAction>

    @FocusState private var focusedBound: FiltersState.FocusedBound?

    init(store: Store<FiltersState, FiltersAction>) {
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
            .navigationTitle(R.string.localizable.filtersViewTitleFilters())
            .onAppear { viewStore.send(.fetchFilters) }
        }
    }
}

// MARK: BasicSection
private struct BasicSection: View {
    @Binding private var route: FiltersState.Route?
    @Binding private var filter: Filter
    @Binding private var filterRange: FilterRange
    private let resetFiltersAction: () -> Void
    private let resetFiltersDialogAction: () -> Void
    private var categoryBindings: [Binding<Bool>] { [
        $filter.doujinshi, $filter.manga, $filter.artistCG, $filter.gameCG, $filter.western,
        $filter.nonH, $filter.imageSet, $filter.cosplay, $filter.asianPorn, $filter.misc
    ] }

    init(
        route: Binding<FiltersState.Route?>, filter: Binding<Filter>, filterRange: Binding<FilterRange>,
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
                Text(R.string.localizable.filtersViewButtonResetFilters()).foregroundStyle(.red)
            }
            .confirmationDialog(
                message: L10n.Localizable.ConfirmationDialog.Title.Reset(),
                unwrapping: $route, case: /FiltersState.Route.resetFilters
            ) {
                Button(
                    L10n.Localizable.ConfirmationDialog.Button.Reset(),
                    role: .destructive, action: resetFiltersAction
                )
            }
            Toggle(R.string.localizable.filtersViewTitleAdvancedSettings(), isOn: $filter.advanced)
        }
    }
}

// MARK: AdvancedSection
private struct AdvancedSection: View {
    @Binding private var filter: Filter
    private let focusedBound: FocusState<FiltersState.FocusedBound?>.Binding
    private let submitAction: () -> Void

    init(
        filter: Binding<Filter>,
        focusedBound: FocusState<FiltersState.FocusedBound?>.Binding,
        submitAction: @escaping () -> Void
    ) {
        _filter = filter
        self.focusedBound = focusedBound
        self.submitAction = submitAction
    }

    var body: some View {
        Group {
            Section(R.string.localizable.filtersViewSectionTitleAdvanced()) {
                Toggle(R.string.localizable.filtersViewTitleSearchGalleryName(), isOn: $filter.galleryName)
                Toggle(R.string.localizable.filtersViewTitleSearchGalleryTags(), isOn: $filter.galleryTags)
                Toggle(R.string.localizable.filtersViewTitleSearchGalleryDescription(), isOn: $filter.galleryDesc)
                Toggle(R.string.localizable.filtersViewTitleSearchTorrentFilenames(), isOn: $filter.torrentFilenames)
                Toggle(
                    R.string.localizable.filtersViewTitleOnlyShowGalleriesWithTorrents(),
                    isOn: $filter.onlyWithTorrents
                )
                Toggle(R.string.localizable.filtersViewTitleSearchLowPowerTags(), isOn: $filter.lowPowerTags)
                Toggle(R.string.localizable.filtersViewTitleSearchDownvotedTags(), isOn: $filter.downvotedTags)
                Toggle(R.string.localizable.filtersViewTitleShowExpungedGalleries(), isOn: $filter.expungedGalleries)
            }
            Section {
                Toggle(R.string.localizable.filtersViewTitleSetMinimumRating(), isOn: $filter.minRatingActivated)
                MinimumRatingSetter(minimum: $filter.minRating)
                    .disabled(!filter.minRatingActivated)
                Toggle(R.string.localizable.filtersViewTitleSetPagesRange(), isOn: $filter.pageRangeActivated)
                    .disabled(focusedBound.wrappedValue != nil)
                PagesRangeSetter(
                    lowerBound: $filter.pageLowerBound,
                    upperBound: $filter.pageUpperBound,
                    focusedBound: focusedBound,
                    submitAction: submitAction
                )
                .disabled(!filter.pageRangeActivated)
            }
            Section(R.string.localizable.filtersViewSectionTitleDefaultFilter()) {
                Toggle(R.string.localizable.filtersViewTitleDisableLanguageFilter(), isOn: $filter.disableLanguage)
                Toggle(R.string.localizable.filtersViewTitleDisableUploaderFilter(), isOn: $filter.disableUploader)
                Toggle(R.string.localizable.filtersViewTitleDisableTagsFilter(), isOn: $filter.disableTags)
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
        Picker(R.string.localizable.filtersViewTitleMinimumRating(), selection: $minimum) {
            ForEach(Array(2...5), id: \.self) { number in
                Text(R.string.localizable.commonValueStars("\(number)")).tag(number)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: PagesRangeSetter
private struct PagesRangeSetter: View {
    @Binding private var lowerBound: String
    @Binding private var upperBound: String
    private let focusedBound: FocusState<FiltersState.FocusedBound?>.Binding
    private let submitAction: () -> Void

    init(
        lowerBound: Binding<String>,
        upperBound: Binding<String>,
        focusedBound: FocusState<FiltersState.FocusedBound?>.Binding,
        submitAction: @escaping () -> Void
    ) {
        _lowerBound = lowerBound
        _upperBound = upperBound
        self.focusedBound = focusedBound
        self.submitAction = submitAction
    }

    var body: some View {
        HStack {
            Text(R.string.localizable.filtersViewTitlePagesRange())
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
            return R.string.localizable.enumFilterRangeValueSearch()
        case .global:
            return R.string.localizable.enumFilterRangeValueGlobal()
        case .watched:
            return R.string.localizable.enumFilterRangeValueWatched()
        }
    }
}

struct FiltersView_Previews: PreviewProvider {
    static var previews: some View {
        FiltersView(
            store: .init(
                initialState: .init(),
                reducer: filtersReducer,
                environment: FiltersEnvironment(
                    databaseClient: .live
                )
            )
        )
    }
}
