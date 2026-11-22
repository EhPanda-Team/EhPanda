import AppComponents
import AppModels
import Resources
import Sharing
import SwiftUI

extension EhSettingView {

// MARK: OptionalUIElementsSection
struct OptionalUIElementsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            AppToggle(
                .enableGalleryThumbnailSelector,
                isOn: $ehSetting.enableGalleryThumbnailSelector
            )
            .disabled(updatingOptions.contains(.enableGalleryThumbnailSelector))
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
    let updatingOptions: Set<EhSettingReducer.Option>

    private var tuples: [(AppModels.Category, Binding<String>)] {
        Array(zip(AppModels.Category.allFavoritesCases, $ehSetting.favoriteCategories))
    }

    var body: some View {
        Section {
            ForEach(Array(tuples.enumerated()), id: \.element.0) { index, tuple in
                let nameBinding = tuple.1
                HStack(spacing: 30) {
                    Circle()
                        .foregroundStyle(tuple.0.color(host: setting.galleryHost))
                        .frame(width: 10)

                    DraftTextField(
                        text: nameBinding, title: .favoriteCategoryName,
                        width: nil, alignment: .leading, background: .clear
                    )
                    .disabled(updatingOptions.contains(.favoriteCategory(index)))
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
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.favoritesSortOrder))
        } header: {
            Text(.favoritesSortOrderDescription)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: RatingsSection
struct RatingsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            LabeledContent(.ratingsColor) {
                DraftTextField(
                    text: $ehSetting.ratingsColor,
                    title: .ratingsColor,
                    promptText: .ratingsColorPrompt,
                    width: 80
                )
                .disabled(updatingOptions.contains(.ratingsColor))
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
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            Picker(.resultCount, selection: $ehSetting.searchResultCount) {
                ForEach(ehSetting.capableSearchResultCounts) { count in
                    Text(String(count.value))
                        .tag(count)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.searchResultCount))
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
    let updatingOptions: Set<EhSettingReducer.Option>

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
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.thumbnailLoadTiming))
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
                .disabled(updatingOptions.contains(.thumbnailConfigSize))
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
                .disabled(updatingOptions.contains(.thumbnailConfigRows))
                .frame(width: 200)
            }
        } header: {
            Text(.thumbnailConfiguration)
                .ehSettingRegularHeaderStyled()
        }
    }
}
