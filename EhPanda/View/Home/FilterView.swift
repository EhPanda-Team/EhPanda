//
//  FilterView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct FilterView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State var resetDialogPresented = false

    private var searchCategoryBindings: [Binding<Bool>] {
        [
            searchFilterBinding.doujinshi, searchFilterBinding.manga,
            searchFilterBinding.artistCG, searchFilterBinding.gameCG,
            searchFilterBinding.western, searchFilterBinding.nonH,
            searchFilterBinding.imageSet, searchFilterBinding.cosplay,
            searchFilterBinding.asianPorn, searchFilterBinding.misc
        ]
    }
    private var searchFilterBinding: Binding<Filter> {
        $store.appState.settings.searchFilter
    }

    // MARK: FilterView
    var body: some View {
        NavigationView {
            Form {
                Section {
                    CategoryView(bindings: searchCategoryBindings)
                    Button {
                        resetDialogPresented = true
                    } label: {
                        Text("Reset filters").foregroundStyle(.red)
                    }
                    Toggle("Advanced settings", isOn: searchFilterBinding.advanced)
                }
                Group {
                    Section("Advanced".localized) {
                        Toggle("Search gallery name", isOn: searchFilterBinding.galleryName)
                        Toggle("Search gallery tags", isOn: searchFilterBinding.galleryTags)
                        Toggle("Search gallery description", isOn: searchFilterBinding.galleryDesc)
                        Toggle("Search torrent filenames", isOn: searchFilterBinding.torrentFilenames)
                        Toggle("Only show galleries with torrents", isOn: searchFilterBinding.onlyWithTorrents)
                        Toggle("Search Low-Power tags", isOn: searchFilterBinding.lowPowerTags)
                        Toggle("Search downvoted tags", isOn: searchFilterBinding.downvotedTags)
                        Toggle("Show expunged galleries", isOn: searchFilterBinding.expungedGalleries)
                    }
                    Section {
                        Toggle("Set minimum rating", isOn: searchFilterBinding.minRatingActivated)
                        MinimumRatingSetter(minimum: searchFilterBinding.minRating)
                            .disabled(!searchFilter.minRatingActivated)
                        Toggle("Set pages range", isOn: searchFilterBinding.pageRangeActivated)
                        PagesRangeSetter(
                            lowerBound: searchFilterBinding.pageLowerBound,
                            upperBound: searchFilterBinding.pageUpperBound
                        )
                        .disabled(!searchFilter.pageRangeActivated)
                    }
                    Section("Default Filter".localized) {
                        Toggle("Disable language filter", isOn: searchFilterBinding.disableLanguage)
                        Toggle("Disable uploader filter", isOn: searchFilterBinding.disableUploader)
                        Toggle("Disable tags filter", isOn: searchFilterBinding.disableTags)
                    }
                }
                .disabled(!searchFilter.advanced)
            }
            .confirmationDialog(
                "Are you sure to reset?",
                isPresented: $resetDialogPresented,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    store.dispatch(.resetSearchFilter)
                }
            }
            .navigationBarTitle("Filters")
        }
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
