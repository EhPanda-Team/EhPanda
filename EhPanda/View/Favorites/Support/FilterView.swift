//
//  FilterView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct FilterView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var resetDialogPresented = false
    @State private var filterRange: FilterRange = .search

    private var filterBinding: Binding<Filter> {
        filterRange == .search
            ? $store.appState.settings.searchFilter
            : $store.appState.settings.globalFilter
    }

    // MARK: FilterView
    var body: some View {
        NavigationView {
            Form {
                BasicSection(
                    filter: filterBinding, filterRange: $filterRange,
                    resetDialogPresented: $resetDialogPresented
                )
                AdvancedSection(filter: filterBinding)
            }
            .confirmationDialog(
                "Are you sure to reset?", isPresented: $resetDialogPresented, titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    store.dispatch(.resetFilter(range: filterRange))
                }
            }
            .navigationBarTitle("Filters")
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

    init(filter: Binding<Filter>) {
        _filter = filter
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
                PagesRangeSetter(
                    lowerBound: $filter.pageLowerBound,
                    upperBound: $filter.pageUpperBound
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
    @FocusState private var focusBound: FocusBound?
    @Binding private var lowerBound: String
    @Binding private var upperBound: String

    enum FocusBound {
        case lower
        case upper
    }

    init(lowerBound: Binding<String>, upperBound: Binding<String>) {
        _lowerBound = lowerBound
        _upperBound = upperBound
    }

    var body: some View {
        HStack {
            Text("Pages range")
            Spacer()
            SettingTextField(text: $lowerBound)
                .focused($focusBound, equals: .lower)
                .submitLabel(.next)
            Text("-")
            SettingTextField(text: $upperBound)
                .focused($focusBound, equals: .upper)
                .submitLabel(.done)
        }
        .onSubmit {
            switch focusBound {
            case .lower:
                focusBound = .upper
            case .upper:
                focusBound = nil
            default:
                break
            }
        }
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
}
