import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import AppComponents

struct EhSettingView: View {
    @Bindable private var store: StoreOf<EhSettingReducer>
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    // Should make it an Environment value.
    private var galleryHost: GalleryHost { AppUtil.galleryHost }

    init(store: StoreOf<EhSettingReducer>, bypassesSNIFiltering: Bool, blurRadius: Double) {
        self.store = store
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.blurRadius = blurRadius
    }

    // MARK: EhSettingView
    var body: some View {
        ZStack {
            // Workaround: Stay if-else approach
            if store.loadingState == .loading || store.submittingState == .loading {
                LoadingView()
                    .tint(nil)
            } else if case .failed(let error) = store.loadingState {
                ErrorView(error: error, action: { store.send(.fetchEhSetting) })
                    .tint(nil)
            }
            // Using `Binding.init` will crash the app
            else if let ehSetting = Binding(unwrapping: $store.ehSetting),
                    let ehProfile = Binding(unwrapping: $store.ehProfile) {
                form(ehSetting: ehSetting, ehProfile: ehProfile)
                    .transition(.opacity.animation(.default))
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
                .autoBlur(radius: blurRadius)
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
                        state: \.confirmationDialog, action: \.confirmationDialog
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
                    store.send(.presentWebView(Defaults.URL.uConfig))
                } label: {
                    Image(systemSymbol: .globe)
                }
                .disabled(bypassesSNIFiltering)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    store.send(.submitChanges)
                } label: {
                    Image(systemSymbol: .icloudAndArrowUp)
                }
                .disabled(store.ehSetting == nil)
            }

            ToolbarItem(placement: .keyboard) {
                Button(String(localized: .done)) {
                    store.send(.setKeyboardHidden)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

struct EhSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EhSettingView(
                store: .init(
                    initialState: .init(ehSetting: .empty, ehProfile: .empty, loadingState: .idle),
                    reducer: EhSettingReducer.init
                ),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
