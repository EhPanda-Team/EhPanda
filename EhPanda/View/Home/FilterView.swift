//
//  FilterView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct FilterView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private var categoryBindings: [Binding<Bool>] {
        [
            filterBinding.doujinshi,
            filterBinding.manga,
            filterBinding.artistCG,
            filterBinding.gameCG,
            filterBinding.western,
            filterBinding.nonH,
            filterBinding.imageSet,
            filterBinding.cosplay,
            filterBinding.asianPorn,
            filterBinding.misc
        ]
    }

    // MARK: FilterView
    var body: some View {
        Form {
            Section {
                CategoryView(bindings: categoryBindings)
                Button(action: onResetButtonTap) {
                    Text("Reset filters")
                        .foregroundStyle(.red)
                }
                Toggle("Advanced settings", isOn: filterBinding.advanced)
            }
            Group {
                Section(header: Text("Advanced")) {
                    Toggle("Search gallery name", isOn: filterBinding.galleryName)
                    Toggle("Search gallery tags", isOn: filterBinding.galleryTags)
                    Toggle("Search gallery description", isOn: filterBinding.galleryDesc)
                    Toggle("Search torrent filenames", isOn: filterBinding.torrentFilenames)
                    Toggle("Only show galleries with torrents", isOn: filterBinding.onlyWithTorrents)
                    Toggle("Search Low-Power tags", isOn: filterBinding.lowPowerTags)
                    Toggle("Search downvoted tags", isOn: filterBinding.downvotedTags)
                    Toggle("Show expunged galleries", isOn: filterBinding.expungedGalleries)
                }
                Section {
                    Toggle("Set minimum rating", isOn: filterBinding.minRatingActivated)
                    MinimumRatingSetter(minimum: filterBinding.minRating)
                        .disabled(!filter.minRatingActivated)
                    Toggle("Set pages range", isOn: filterBinding.pageRangeActivated)
                    PagesRangeSetter(
                        lowerBound: filterBinding.pageLowerBound,
                        upperBound: filterBinding.pageUpperBound
                    )
                    .disabled(!filter.pageRangeActivated)
                }
                Section(header: Text("Default Filter")) {
                    Toggle("Disable language filter", isOn: filterBinding.disableLanguage)
                    Toggle("Disable uploader filter", isOn: filterBinding.disableUploader)
                    Toggle("Disable tags filter", isOn: filterBinding.disableTags)
                }
            }
            .disabled(!filter.advanced)
        }
        .actionSheet(item: environmentBinding.filterViewActionSheetState) { item in
            switch item {
            case .resetFilters:
                return ActionSheet(title: Text("Are you sure to reset?"), buttons: [
                    .destructive(Text("Reset"), action: resetFilters),
                    .cancel()
                ])
            }
        }
        .navigationBarTitle("Filters")
    }
}

private extension FilterView {
    var settingsBinding: Binding<AppState.Settings> {
        $store.appState.settings
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var filterBinding: Binding<Filter> {
        settingsBinding.filter
    }

    func onResetButtonTap() {
        store.dispatch(.toggleFilterViewActionSheet(state: .resetFilters))
    }
    func resetFilters() {
        store.dispatch(.resetFilters)
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
            Picker(
                selection: $minimum,
                label: Text("\(minimum) stars")
            ) {
                ForEach(Array(stride(
                    from: 2, through: 5, by: 1
                )), id: \.self) { num in
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

    init(
        lowerBound: Binding<String>,
        upperBound: Binding<String>
    ) {
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
enum FilterViewActionSheetState: Identifiable {
    var id: Int { hashValue }

    case resetFilters
}

private struct TupleCategory: Identifiable {
    var id: String { category.rawValue }

    let isFiltered: Binding<Bool>
    let category: Category
}
