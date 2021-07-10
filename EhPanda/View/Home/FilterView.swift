//
//  FilterView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct FilterView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    // MARK: FilterView
    var body: some View {
        let filter = settings.filter
        let filterBinding = settingsBinding.filter
        Form {
            Section(header: Text("Basic")) {
                CategoryView(filter: filter, filterBinding: filterBinding)
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

    func onResetButtonTap() {
        store.dispatch(.toggleFilterViewActionSheet(state: .resetFilters))
    }
    func resetFilters() {
        store.dispatch(.initializeFilter)
    }
}

// MARK: CategoryView
private struct CategoryView: View {
    private let filter: Filter
    private let filterBinding: Binding<Filter>

    private let gridItems = [
        GridItem(
            .adaptive(
                minimum: isPadWidth
                    ? 100 : 80,
                maximum: 100
            )
        )
    ]
    private var tuples: [TupleCategory] {
        [TupleCategory(isFiltered: filterBinding.doujinshi.isFiltered, category: filter.doujinshi.category),
         TupleCategory(isFiltered: filterBinding.manga.isFiltered, category: filter.manga.category),
         TupleCategory(isFiltered: filterBinding.artistCG.isFiltered, category: filter.artistCG.category),
         TupleCategory(isFiltered: filterBinding.gameCG.isFiltered, category: filter.gameCG.category),
         TupleCategory(isFiltered: filterBinding.western.isFiltered, category: filter.western.category),
         TupleCategory(isFiltered: filterBinding.nonH.isFiltered, category: filter.nonH.category),
         TupleCategory(isFiltered: filterBinding.imageSet.isFiltered, category: filter.imageSet.category),
         TupleCategory(isFiltered: filterBinding.cosplay.isFiltered, category: filter.cosplay.category),
         TupleCategory(isFiltered: filterBinding.asianPorn.isFiltered, category: filter.asianPorn.category),
         TupleCategory(isFiltered: filterBinding.misc.isFiltered, category: filter.misc.category)]
    }

    init(filter: Filter, filterBinding: Binding<Filter>) {
        self.filter = filter
        self.filterBinding = filterBinding
    }

    var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples) { tuple in
                CategoryCell(
                    isFiltered: tuple.isFiltered,
                    category: tuple.category
                )
            }
        }
        .padding(.vertical)
    }
}

// MARK: CategoryCell
private struct CategoryCell: View {
    @Binding private var isFiltered: Bool
    private let category: Category

    init(isFiltered: Binding<Bool>, category: Category) {
        _isFiltered = isFiltered
        self.category = category
    }

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(
                    isFiltered
                        ? category.color.opacity(0.3)
                        : category.color
                )
            Text(category.rawValue.localized())
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.vertical, 5)
        }
        .onTapGesture(perform: onTapGesture)
        .cornerRadius(5)
    }

    private func onTapGesture() {
        isFiltered.toggle()
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
            let star = "stars".localized()
            Text("Minimum rating")
            Spacer()
            Picker(
                selection: $minimum,
                label: Text("\(minimum)" + star)
            ) {
                Text("2" + star).tag(2)
                Text("3" + star).tag(3)
                Text("4" + star).tag(4)
                Text("5" + star).tag(5)
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: PagesRangeSetter
private struct PagesRangeSetter: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var lowerBound: String
    @Binding private var upperBound: String

    private var color: Color {
        if colorScheme == .light {
            return Color(.systemGray6)
        } else {
            return Color(.systemGray3)
        }
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
            TextField("", text: $lowerBound)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .background(color)
                .frame(width: 50)
                .cornerRadius(5)
            Text("-")
            TextField("", text: $upperBound)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .background(color)
                .frame(width: 50)
                .cornerRadius(5)
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
