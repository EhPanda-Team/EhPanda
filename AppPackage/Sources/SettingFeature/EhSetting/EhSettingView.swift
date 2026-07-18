import SwiftUI
import Sharing
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import SFSafeSymbolsExt

struct EhSettingView: View {
    @Bindable private var store: StoreOf<EhSettingReducer>
    @SharedReader(.setting) private var setting: Setting

    private var galleryHost: GalleryHost { setting.galleryHost }

    init(store: StoreOf<EhSettingReducer>) {
        self.store = store
    }

    // MARK: EhSettingView
    var body: some View {
        // Use `Group` here after migrating lifecycle trigger to reducer.
        ZStack {
            if let ehSetting = Binding($store.ehSetting),
               let ehProfile = Binding($store.ehProfile) {
                form(ehSetting: ehSetting, ehProfile: ehProfile)
                    .transition(.opacity.animation(.default))
            }
        }
        .overlay {
            LoadingView()
                .animation(.default) {
                    $0.opacity((store.loadingState == .loading || store.submittingState == .loading) ? 1 : 0)
                }
        }
        .overlay {
            ErrorView(error: store.loadingState.failed ?? .unknown, action: { store.send(.fetchEhSetting) })
                .animation(.default) {
                    $0.opacity(store.loadingState.is(\.failed) ? 1 : 0)
                }
        }
        .onAppear {
            if store.ehSetting == nil {
                store.send(.fetchEhSetting)
            }
        }
        .onDisappear {
            if let profileSet = store.ehSetting?.ehpandaProfile?.value {
                store.send(.setDefaultProfile(profileSet))
            }
        }
        .sheet(item: $store.destination.webView, id: \.absoluteString) { url in
            WebView(url: url.wrappedValue)
                .ignoresSafeArea(edges: .bottom)
                .privacyMask()
        }
        .toolbar(content: toolbar)
        .navigationTitle(.hostSettings(galleryHost.rawValue))
    }
    // MARK: Form
    private func form(ehSetting: Binding<EhSetting>, ehProfile: Binding<EhProfile>) -> some View {
        Form {
            Group {
                EhProfileSection(
                    ehSetting: ehSetting,
                    ehProfile: ehProfile,
                    editingProfileName: $store.editingProfileName,
                    deleteDialogAction: { store.send(.deleteProfileButtonTapped) },
                    deleteConfirmationDialog: $store.scope(
                        \.$confirmationDialog, action: \.confirmationDialog
                    ),
                    performEhProfileAction: { store.send(.performAction(action: $0, name: $1, set: $2)) }
                )

                ImageLoadSettingsSection(ehSetting: ehSetting)
                ImageSizeSettingsSection(ehSetting: ehSetting)
                GalleryNameDisplaySection(ehSetting: ehSetting)
                ArchiverSettingsSection(ehSetting: ehSetting)
                FrontPageSettingsSection(ehSetting: ehSetting)
                OptionalUIElementsSection(ehSetting: ehSetting)
                FavoritesSection(ehSetting: ehSetting)
                SearchResultCountSection(ehSetting: ehSetting)
                ThumbnailSettingsSection(ehSetting: ehSetting)
            }
            Group {
                CoverScalingSection(ehSetting: ehSetting)
                RatingsSection(ehSetting: ehSetting)
                TagWatchingThresholdSection(ehSetting: ehSetting)
                TagFilteringThresholdSection(ehSetting: ehSetting)
                FilteredRemovalCountSection(ehSetting: ehSetting)
                ExcludedLanguagesSection(ehSetting: ehSetting)
                ExcludedUploadersSection(ehSetting: ehSetting)
                ViewportOverrideSection(ehSetting: ehSetting)
                GalleryCommentsSection(ehSetting: ehSetting)
                GalleryTagsSection(ehSetting: ehSetting)
            }
            Group {
                GalleryPageThumbnailLabelingSection(ehSetting: ehSetting)
                MultiplePageViewerSection(ehSetting: ehSetting)
            }
        }
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.presentWebView(Defaults.URL.uConfig(host: setting.galleryHost)))
                } label: {
                    Label(.website, systemSymbol: .globe)
                }
                .disabled(setting.bypassSNIFiltering)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    store.send(.submitChanges)
                } label: {
                    Label(.submit, systemSymbol: .icloudAndArrowUp)
                }
                .disabled(store.ehSetting == nil)
            }
        }
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
