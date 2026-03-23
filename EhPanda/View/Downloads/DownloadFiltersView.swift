//
//  DownloadFiltersView.swift
//  EhPanda
//

import SwiftUI

private enum DownloadFilterFocusedBound: Hashable {
    case lower
    case upper
}

struct DownloadFiltersView: View {
    @Binding private var filter: DownloadGalleryFilter
    @FocusState private var focusedBound: DownloadFilterFocusedBound?
    private let resetAction: () -> Void

    init(filter: Binding<DownloadGalleryFilter>, resetAction: @escaping () -> Void) {
        _filter = filter
        self.resetAction = resetAction
    }

    private var categoryBindings: [Binding<Bool>] {
        Category.allFiltersCases.map(categoryBinding)
    }

    private func categoryBinding(_ category: Category) -> Binding<Bool> {
        .init(
            get: {
                filter.excludedCategories.contains(category)
            },
            set: { isExcluded in
                if isExcluded {
                    filter.excludedCategories.insert(category)
                } else {
                    filter.excludedCategories.remove(category)
                }
            }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    CategoryView(bindings: categoryBindings)
                }

                Section(L10n.Localizable.FiltersView.Section.Title.advanced) {
                    Toggle(
                        L10n.Localizable.FiltersView.Title.setMinimumRating,
                        isOn: $filter.minimumRatingActivated
                    )
                    DownloadMinimumRatingSetter(minimum: $filter.minimumRating)
                        .disabled(!filter.minimumRatingActivated)
                    Toggle(
                        L10n.Localizable.FiltersView.Title.setPagesRange,
                        isOn: $filter.pageRangeActivated
                    )
                        .disabled(focusedBound != nil)
                    DownloadPagesRangeSetter(
                        lowerBound: $filter.pageLowerBound,
                        upperBound: $filter.pageUpperBound,
                        focusedBound: $focusedBound
                    )
                    .disabled(!filter.pageRangeActivated)
                }

                Section {
                    Button(role: .destructive, action: resetAction) {
                        Text(L10n.Localizable.FiltersView.Button.resetFilters)
                    }
                }
            }
            .navigationTitle(L10n.Localizable.FiltersView.Title.filters)
        }
    }
}

private struct DownloadMinimumRatingSetter: View {
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

private struct DownloadPagesRangeSetter: View {
    @Binding private var lowerBound: String
    @Binding private var upperBound: String
    private let focusedBound: FocusState<DownloadFilterFocusedBound?>.Binding

    init(
        lowerBound: Binding<String>,
        upperBound: Binding<String>,
        focusedBound: FocusState<DownloadFilterFocusedBound?>.Binding
    ) {
        _lowerBound = lowerBound
        _upperBound = upperBound
        self.focusedBound = focusedBound
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
        .onSubmit {
            switch focusedBound.wrappedValue {
            case .lower:
                focusedBound.wrappedValue = .upper
            default:
                focusedBound.wrappedValue = nil
            }
        }
    }
}
