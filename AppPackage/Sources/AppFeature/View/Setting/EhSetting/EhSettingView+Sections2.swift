import SwiftUI
import AppModels
import Resources

extension EhSettingView {

// MARK: OptionalUIElementsSection
struct OptionalUIElementsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Toggle(
                L10n.Localizable.EhSettingView.Title.enableGalleryThumbnailSelector,
                isOn: $ehSetting.enableGalleryThumbnailSelector
            )
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.optionalUIElements,
                description: L10n.Localizable.EhSettingView.Description.optionalUIElements
            )
        }
    }
}

// MARK: FavoritesSection
struct FavoritesSection: View {
    @Binding var ehSetting: EhSetting
    @FocusState private var isFocused

    private var tuples: [(AppModels.Category, Binding<String>)] {
        AppModels.Category.allFavoritesCases.enumerated().map { index, category in
            (category, $ehSetting.favoriteCategories[index])
        }
    }

    var body: some View {
        Section {
            ForEach(tuples, id: \.0) { category, nameBinding in
                HStack(spacing: 30) {
                    Circle()
                        .foregroundColor(category.color)
                        .frame(width: 10)

                    SettingTextField(text: nameBinding, width: nil, alignment: .leading, background: .clear)
                        .focused($isFocused)
                }
                .padding(.leading)
            }
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.favorites,
                description: L10n.Localizable.EhSettingView.Description.favoriteCategories
            )
        }

        Section {
            Picker(
                L10n.Localizable.EhSettingView.Title.favoritesSortOrder,
                selection: $ehSetting.favoritesSortOrder
            ) {
                ForEach(EhSetting.FavoritesSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Description.favoritesSortOrder)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: RatingsSection
struct RatingsSection: View {
    @Binding var ehSetting: EhSetting
    @FocusState var isFocused

    var body: some View {
        Section {
            LabeledContent(L10n.Localizable.EhSettingView.Title.ratingsColor) {
                SettingTextField(
                    text: $ehSetting.ratingsColor,
                    promptText: L10n.Localizable.EhSettingView.Promt.ratingsColor,
                    width: 80
                )
                .focused($isFocused)
            }
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.ratings,
                description: L10n.Localizable.EhSettingView.Description.ratingsColor
            )
        }
    }
}

}

// MARK: SearchResultCountSection
struct SearchResultCountSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.resultCount, selection: $ehSetting.searchResultCount) {
                ForEach(ehSetting.capableSearchResultCounts) { count in
                    Text(String(count.value))
                        .tag(count)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.searchResultCount,
                description: L10n.Localizable.EhSettingView.Description.resultCount
            )
        }
    }
}

// MARK: ThumbnailSettingsSection
struct ThumbnailSettingsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(
                L10n.Localizable.EhSettingView.Title.thumbnailLoadTiming,
                selection: $ehSetting.thumbnailLoadTiming
            ) {
                ForEach(EhSetting.ThumbnailLoadTiming.allCases) { timing in
                    Text(timing.value)
                        .tag(timing)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.thumbnailSettings,
                description: L10n.Localizable.EhSettingView.Description.thumbnailLoadTiming
            )
        } footer: {
            Text(ehSetting.thumbnailLoadTiming.description)
        }

        Section {
            LabeledContent(L10n.Localizable.EhSettingView.Title.thumbnailSize) {
                Picker(selection: $ehSetting.thumbnailConfigSize) {
                    ForEach(ehSetting.capableThumbnailConfigSizes) { size in
                        Text(size.value)
                            .tag(size)
                    }
                } label: {
                    Text(ehSetting.thumbnailConfigSize.value)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            LabeledContent(L10n.Localizable.EhSettingView.Title.thumbnailRowCount) {
                Picker(selection: $ehSetting.thumbnailConfigRows) {
                    ForEach(ehSetting.capableThumbnailConfigRowCounts) { row in
                        Text(row.value)
                            .tag(row)
                    }
                } label: {
                    Text(ehSetting.capableThumbnailConfigRowCount.value)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        } header: {
            Text(L10n.Localizable.EhSettingView.Description.thumbnailConfiguration)
                .ehSettingRegularHeaderStyled()
        }
    }
}
