import SwiftUI
import Sharing
import AppModels
import Resources
import AppComponents

extension EhSettingView {

// MARK: OptionalUIElementsSection
struct OptionalUIElementsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Toggle(
                .enableGalleryThumbnailSelector,
                isOn: $ehSetting.enableGalleryThumbnailSelector
            )
        } header: {
            Text.ehSettingBoldHeader(
                .optionalUiElements,
                description: .optionalUiElementsDescription
            )
        }
    }
}

// MARK: FavoritesSection
struct FavoritesSection: View {
    @SharedReader(.setting) private var setting: Setting
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
                        .foregroundColor(category.color(host: setting.galleryHost))
                        .frame(width: 10)

                    SettingTextField(
                        text: nameBinding, title: .favoriteCategories,
                        promptText: .favoriteCategories,
                        width: nil, alignment: .leading, background: .clear
                    )
                    .focused($isFocused)
                }
                .padding(.leading)
            }
        } header: {
            Text.ehSettingBoldHeader(
                .favoritesSection,
                description: .favoriteCategories
            )
        }

        Section {
            Picker(
                .favoritesSortOrder,
                selection: $ehSetting.favoritesSortOrder
            ) {
                ForEach(EhSetting.FavoritesSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(.favoritesSortOrderDescription)
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
            LabeledContent(.ratingsColor) {
                SettingTextField(
                    text: $ehSetting.ratingsColor,
                    title: .ratingsColor,
                    promptText: .ratingsColorPrompt,
                    width: 80
                )
                .focused($isFocused)
            }
        } header: {
            Text.ehSettingBoldHeader(
                .ratings,
                description: .ratingsColorDescription
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
            Picker(.resultCount, selection: $ehSetting.searchResultCount) {
                ForEach(ehSetting.capableSearchResultCounts) { count in
                    Text(String(count.value))
                        .tag(count)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                .searchResultCount,
                description: .resultCountDescription
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
                .thumbnailLoadTiming,
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
                .thumbnailSettings,
                description: .thumbnailLoadTimingDescription
            )
        } footer: {
            Text(ehSetting.thumbnailLoadTiming.description)
        }

        Section {
            LabeledContent(.thumbnailSize) {
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

            LabeledContent(.thumbnailRowCount) {
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
            Text(.thumbnailConfiguration)
                .ehSettingRegularHeaderStyled()
        }
    }
}
