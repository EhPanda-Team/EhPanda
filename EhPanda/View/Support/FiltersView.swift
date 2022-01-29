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
    @Binding private var searchFilter: Filter
    @Binding private var globalFilter: Filter
    @Binding private var watchedFilter: Filter

    @FocusState private var focusedBound: FiltersState.FocusedBound?

    init(
        store: Store<FiltersState, FiltersAction>,
        searchFilter: Binding<Filter>,
        globalFilter: Binding<Filter>,
        watchedFilter: Binding<Filter>
    ) {
        self.store = store
        viewStore = ViewStore(store)
        _searchFilter = searchFilter
        _globalFilter = globalFilter
        _watchedFilter = watchedFilter
    }

    private var filter: Binding<Filter> {
        switch viewStore.filterRange {
        case .search:
            return $searchFilter
        case .global:
            return $globalFilter
        case .watched:
            return $watchedFilter
        }
    }

    // MARK: FilterView
    var body: some View {
        NavigationView {
            Form {
                BasicSection(
                    filter: filter, filterRange: viewStore.binding(\.$filterRange),
                    resetDialogPresented: viewStore.binding(\.$resetDialogPresented)
                )
                AdvancedSection(
                    filter: filter, focusedBound: $focusedBound,
                    submitAction: { viewStore.send(.onTextFieldSubmitted) }
                )
            }
            .synchronize(viewStore.binding(\.$focusedBound), $focusedBound)
            .confirmationDialog(
                "Are you sure to reset?", isPresented: viewStore.binding(\.$resetDialogPresented),
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    viewStore.send(.onResetFilterConfirmed)
                }
            }
            .navigationTitle(R.string.localizable.filtersViewTitleFilters())
        }
    }
}

// MARK: BasicSection
private struct BasicSection: View {
    @Binding private var filter: Filter
    @Binding private var filterRange: FilterRange
    @Binding private var resetDialogPresented: Bool
    private var categoryBindings: [Binding<Bool>] { [
        $filter.doujinshi, $filter.manga, $filter.artistCG, $filter.gameCG, $filter.western,
        $filter.nonH, $filter.imageSet, $filter.cosplay, $filter.asianPorn, $filter.misc
    ] }

    init(filter: Binding<Filter>, filterRange: Binding<FilterRange>, resetDialogPresented: Binding<Bool>) {
        _filter = filter
        _filterRange = filterRange
        _resetDialogPresented = resetDialogPresented
    }

    var body: some View {
        Section {
            Picker("Range", selection: $filterRange) {
                ForEach(FilterRange.allCases) { range in
                    Text(range.rawValue.localized).tag(range)
                }
            }
            .pickerStyle(.segmented)
            CategoryView(bindings: categoryBindings)
            Button {
                resetDialogPresented = true
            } label: {
                Text("Reset filters").foregroundStyle(.red)
            }
            Toggle("Advanced settings", isOn: $filter.advanced)
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
            Section("Advanced".localized) {
                Toggle("Search gallery name", isOn: $filter.galleryName)
                Toggle("Search gallery tags", isOn: $filter.galleryTags)
                Toggle("Search gallery description", isOn: $filter.galleryDesc)
                Toggle("Search torrent filenames", isOn: $filter.torrentFilenames)
                Toggle("Only show galleries with torrents", isOn: $filter.onlyWithTorrents)
                Toggle("Search Low-Power tags", isOn: $filter.lowPowerTags)
                Toggle("Search downvoted tags", isOn: $filter.downvotedTags)
                Toggle("Show expunged galleries", isOn: $filter.expungedGalleries)
            }
            Section {
                Toggle("Set minimum rating", isOn: $filter.minRatingActivated)
                MinimumRatingSetter(minimum: $filter.minRating)
                    .disabled(!filter.minRatingActivated)
                Toggle("Set pages range", isOn: $filter.pageRangeActivated)
                    .disabled(focusedBound.wrappedValue != nil)
                PagesRangeSetter(
                    lowerBound: $filter.pageLowerBound,
                    upperBound: $filter.pageUpperBound,
                    focusedBound: focusedBound,
                    submitAction: submitAction
                )
                .disabled(!filter.pageRangeActivated)
            }
            Section("Default Filter".localized) {
                Toggle("Disable language filter", isOn: $filter.disableLanguage)
                Toggle("Disable uploader filter", isOn: $filter.disableUploader)
                Toggle("Disable tags filter", isOn: $filter.disableTags)
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
        HStack {
            Text("Minimum rating")
            Spacer()
            Picker(selection: $minimum, label: Text("\(minimum) stars")) {
                ForEach(Array(2...5), id: \.self) { num in
                    Text("\(num) stars").tag(num)
                }
            }
            .pickerStyle(.menu)
        }
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
            Text("Pages range")
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

enum FilterRange: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case search = "Search"
    case global = "Global"
    case watched = "Watched"
}

struct FiltersView_Previews: PreviewProvider {
    static var previews: some View {
        FiltersView(
            store: .init(
                initialState: .init(),
                reducer: filtersReducer,
                environment: FiltersEnvironment()
            ),
            searchFilter: .constant(.init()),
            globalFilter: .constant(.init()),
            watchedFilter: .constant(.init())
        )
    }
}
