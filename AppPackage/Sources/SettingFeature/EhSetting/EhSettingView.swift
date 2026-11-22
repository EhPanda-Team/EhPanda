import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import Sharing
import SwiftUI

struct EhSettingView: View {
    @AccessibilityFocusState private var profilePickerFocused: Bool
    @Bindable private var store: StoreOf<EhSettingReducer>
    @SharedReader(.setting) private var setting: Setting

    private var galleryHost: GalleryHost { setting.galleryHost }

    init(store: StoreOf<EhSettingReducer>) {
        self.store = store
    }

    // MARK: EhSettingView
    var body: some View {
        // The `ZStack` is the transition container for the conditional form; a `Group` would be worth
        // trying now that no lifecycle modifier needs a concrete view here, but that is a rendering
        // change, not a lifecycle one.
        ZStack {
            if let ehSetting = Binding($store.ehSetting),
               let ehProfile = Binding($store.ehProfile) {
                form(ehSetting: ehSetting, ehProfile: ehProfile)
                    .transition(.opacity.animation(.default))
            }
        }
        // Until the settings load, the `ZStack` is empty and so has no size, and its overlays are laid out in that
        // zero frame: the loading and error views drew nothing, and a failed load left a blank page with no
        // Retry (19-08 SUMMARY, `settings-pages-site-settings-error`). The form fills the page either way.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.ehSetting != nil && store.ehProfile != nil) { _, isReady in
            guard isReady else { return }
            profilePickerFocused = true
        }
        .overlay {
            LoadingView()
                .animation(.default) {
                    $0.visible(store.loadingState == .loading)
                }
        }
        .overlay {
            ErrorView(error: store.loadingState.failed ?? .unknown, action: { store.send(.fetchEhSetting) })
                .animation(.default) {
                    $0.visible(store.loadingState.is(\.failed))
                }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(.hostSettings(galleryHost.rawValue))
    }
    // MARK: Form
    private func form(ehSetting: Binding<EhSetting>, ehProfile: Binding<EhProfile>) -> some View {
        Form {
            Group {
                EhProfileSection(
                    ehSetting: ehSetting,
                    ehProfile: ehProfile,
                    updatingOptions: store.updatingOptions,
                    profilePickerFocus: $profilePickerFocused,
                    editingProfileName: $store.editingProfileName,
                    deleteDialogAction: { store.send(.deleteProfileButtonTapped) },
                    deleteConfirmationDialog: $store.scope(
                        \.$confirmationDialog, action: \.confirmationDialog
                    ),
                    performEhProfileAction: { store.send(.performAction(action: $0, name: $1, set: $2)) }
                )

                ImageLoadSettingsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                ImageSizeSettingsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                GalleryNameDisplaySection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                ArchiverSettingsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                FrontPageSettingsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                OptionalUIElementsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                FavoritesSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                SearchResultCountSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                ThumbnailSettingsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
            }
            Group {
                CoverScalingSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                RatingsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                TagWatchingThresholdSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                TagFilteringThresholdSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                FilteredRemovalCountSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                ExcludedLanguagesSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                ExcludedUploadersSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                ViewportOverrideSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                GalleryCommentsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                GalleryTagsSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
            }
            Group {
                GalleryPageThumbnailLabelingSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
                MultiplePageViewerSection(ehSetting: ehSetting, updatingOptions: store.updatingOptions)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

#Preview("Initial") {
    NavigationStack {
        EhSettingView(
            store: .init(
                initialState: .init(ehSetting: .empty, ehProfile: .empty, loadingState: .idle),
                reducer: EhSettingReducer.init
            )
        )
    }
}
