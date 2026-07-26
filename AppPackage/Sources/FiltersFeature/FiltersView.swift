import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SwiftUI

public struct FiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store: StoreOf<FiltersReducer>

    @FocusState private var focusedBound: FiltersReducer.FocusedBound?

    public init(store: StoreOf<FiltersReducer>) {
        self.store = store
    }

    private var filter: Binding<Filter> {
        switch store.filterRange {
        case .search:
            return $store.searchFilter
        case .global:
            return $store.globalFilter
        case .watched:
            return $store.watchedFilter
        }
    }

    // MARK: FilterView
    public var body: some View {
        NavigationStack {
            Form {
                BasicSection(
                    filter: filter, filterRange: $store.filterRange,
                    resetFiltersDialogAction: { store.send(.resetFiltersButtonTapped) },
                    confirmationDialog: $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
                )
                AdvancedSection(
                    filter: filter, focusedBound: $focusedBound,
                    submitAction: { store.send(.onTextFieldSubmitted) }
                )
            }
            .synchronize($store.focusedBound, $focusedBound)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: dismiss.callAsFunction)
                }
            }
            .navigationTitle(.RLocalizable.filters)
        }
    }
}

// MARK: BasicSection
private struct BasicSection: View {
    @Binding private var filter: Filter
    @Binding private var filterRange: FilterRange
    private let resetFiltersDialogAction: () -> Void
    private let confirmationDialog:
        Binding<Store<ConfirmationDialogState<FiltersReducer.Dialog>, FiltersReducer.Dialog>?>
    private var categoryBindings: [Binding<Bool>] { [
        $filter.doujinshi, $filter.manga, $filter.artistCG, $filter.gameCG, $filter.western,
        $filter.nonH, $filter.imageSet, $filter.cosplay, $filter.asianPorn, $filter.misc
    ] }

    init(
        filter: Binding<Filter>, filterRange: Binding<FilterRange>,
        resetFiltersDialogAction: @escaping () -> Void,
        confirmationDialog:
            Binding<Store<ConfirmationDialogState<FiltersReducer.Dialog>, FiltersReducer.Dialog>?>
    ) {
        _filter = filter
        _filterRange = filterRange
        self.resetFiltersDialogAction = resetFiltersDialogAction
        self.confirmationDialog = confirmationDialog
    }

    var body: some View {
        Section {
            Picker(.searchRange, selection: $filterRange) {
                ForEach(FilterRange.allCases) { range in
                    Text(range.value).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            CategoryView(bindings: categoryBindings)
            Button(action: resetFiltersDialogAction) {
                Text(.resetFilters).foregroundStyle(.red)
            }
            .confirmationDialog(confirmationDialog)
            AppToggle(.advancedSettings, isOn: $filter.advanced)
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
            Section(.advanced) {
                AppToggle(.searchGalleryName, isOn: $filter.galleryName)
                AppToggle(.searchGalleryTags, isOn: $filter.galleryTags)
                AppToggle(.searchGalleryDescription, isOn: $filter.galleryDesc)
                AppToggle(.searchTorrentFilenames, isOn: $filter.torrentFilenames)
                AppToggle(.requireGalleryTorrent, isOn: $filter.onlyWithTorrents)
                AppToggle(.searchLowPowerTags, isOn: $filter.lowPowerTags)
                AppToggle(.searchDownvotedTags, isOn: $filter.downvotedTags)
                AppToggle(.browseOnlyExpungedGalleries, isOn: $filter.expungedGalleries)
            }
            Section {
                AppToggle(.setMinimumRating, isOn: $filter.minRatingActivated)
                MinimumRatingSetter(minimum: $filter.minRating)
                    .disabled(!filter.minRatingActivated)
                AppToggle(.setPagesRange, isOn: $filter.pageRangeActivated)
                    .disabled(focusedBound.wrappedValue != nil)
                PagesRangeSetter(
                    lowerBound: $filter.pageLowerBound,
                    upperBound: $filter.pageUpperBound,
                    focusedBound: focusedBound,
                    submitAction: submitAction
                )
                .disabled(!filter.pageRangeActivated)
            }
            Section(.customFilters) {
                AppToggle(.disableLanguageFilter, isOn: $filter.disableLanguage)
                AppToggle(.disableUploaderFilter, isOn: $filter.disableUploader)
                AppToggle(.disableTagsFilter, isOn: $filter.disableTags)
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
        Picker(.minimumRating, selection: $minimum) {
            ForEach(Array(2...5), id: \.self) { number in
                Text(.RLocalizable.stars(count: number)).tag(number)
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
            Text(.pagesRange)
                .frame(maxWidth: .infinity, alignment: .leading)

            SettingTextField(text: $lowerBound, title: .pagesRange)
                .focused(focusedBound, equals: .lower)
                .submitLabel(.next)

            Text(.Constant.rangeSeparator)

            SettingTextField(text: $upperBound, title: .pagesRange)
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
    let category: AppModels.Category
}

#Preview("Initial") {
    FiltersView(store: .init(initialState: .init(), reducer: FiltersReducer.init))
}
