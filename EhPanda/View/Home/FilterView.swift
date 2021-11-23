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

    private var categoryBindings: [Binding<Bool>] {
        [
            filterBinding.doujinshi, filterBinding.manga,
            filterBinding.artistCG, filterBinding.gameCG,
            filterBinding.western, filterBinding.nonH,
            filterBinding.imageSet, filterBinding.cosplay,
            filterBinding.asianPorn, filterBinding.misc
        ]
    }
    private var filterBinding: Binding<Filter> {
        $store.appState.settings.filter
    }

    // MARK: FilterView
    var body: some View {
        NavigationView {
            Form {
                Section {
                    CategoryView(bindings: categoryBindings)
                    Button {
                        resetDialogPresented = true
                    } label: {
                        Text("Reset filters").foregroundStyle(.red)
                    }
                    Toggle("Advanced settings", isOn: filterBinding.advanced)
                }
                Group {
                    Section("Advanced".localized) {
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
                    Section("Default Filter".localized) {
                        Toggle("Disable language filter", isOn: filterBinding.disableLanguage)
                        Toggle("Disable uploader filter", isOn: filterBinding.disableUploader)
                        Toggle("Disable tags filter", isOn: filterBinding.disableTags)
                    }
                }
                .disabled(!filter.advanced)
            }
            .confirmationDialog(
                "Are you sure to reset?",
                isPresented: $resetDialogPresented,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    store.dispatch(.resetFilters)
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
