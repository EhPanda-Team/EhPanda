import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import MyTagEditor
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import Sharing
import SwiftUI
import SystemNotification

/// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): the tag set (its picker, Enabled and default
/// colour, New Tag Set, and Delete Tag Set while the site offers it) and its tags, one row each; a row opens Edit Tag
/// and a trailing swipe removes the tag. Add Tag sits in the toolbar. Signed out it shows Log In; loading, the loading
/// view; failed, the error with Open in Browser.
struct MyTagsView: View {
    @Bindable private var store: StoreOf<MyTagsFeature>
    @SharedReader(.didLogin) private var didLogin: Bool

    init(store: StoreOf<MyTagsFeature>) {
        self.store = store
    }

    var body: some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(content: toolbar)
            .toast($store.scope(\.$toast, action: \.toast))
            .sheet(item: $store.scope(\.$destination, action: \.destination).editor) { store in
                MyTagEditorView(store: store)
                    .privacyMask()
            }
            .sheet(item: $store.browserURL.sending(\.browserChanged), id: \.absoluteString) { url in
                WebView(url: url.wrappedValue)
                    .ignoresSafeArea(edges: .bottom)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .privacyMask()
            }
            .navigationTitle(.myTags)
    }

    /// The page in its state: Log In signed out, the error with Open in Browser, the set's form, else loading.
    @ContentBuilder private var content: some View {
        if !didLogin {
            NotLoginView(action: { store.send(.delegate(.pushLogin)) })
        } else if case .failed(let error) = store.loadingState {
            ErrorView(
                error: error,
                secondaryTitle: .RLocalizable.openInBrowser,
                secondaryAction: { store.send(.openInBrowserTapped) },
                action: { store.send(.fetchMyTags) }
            )
        } else if store.loadingState != .loading, let tagSet = store.selectedTagSet {
            form(tagSet)
        } else {
            LoadingView()
        }
    }

    /// Add Tag needs a signed-in, loaded page with a tag set to add to.
    private var canAddTag: Bool {
        didLogin && store.loadingState == .idle && store.selectedTagSet != nil
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.addTagTapped)
            } label: {
                Label(.RLocalizable.myTagsAddTag, systemSymbol: .plus)
            }
            .disabled(!canAddTag)
        }
    }

    private func form(_ tagSet: MyTagSet) -> some View {
        Form {
            Section {
                Picker(.myTagsTagSet, selection: $store.selectedTagSetID.sending(\.tagSetSelected)) {
                    ForEach(store.user.myTags?.tagSets ?? []) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                AppToggle(.myTagsEnabled, isOn: $store.isTagSetEnabled.sending(\.enabledChanged))
                    // On the control whose request failed (AGENTS.md dialog placement).
                    .appAlert(alert(for: .enabled))
                HexColorField(
                    .myTagsDefaultColor,
                    color: $store.tagSetColor.sending(\.defaultColorChanged),
                    well: $store.tagSetWellColor.sending(\.defaultWellColorChanged),
                    prompt: nil
                )
                .appAlert(alert(for: .defaultColor))
                Button(.myTagsNewTagSet) {
                    store.send(.newTagSetTapped)
                }
                .disabled(store.isChangingTagSets)
                // On the row that opens them, the name alert and its failure alert (AGENTS.md dialog placement).
                .appAlert(
                    $store.scope(\.$newTagSetAlert, action: \.newTagSetAlert),
                    text: $store.newTagSetName.sending(\.newTagSetNameChanged)
                )
                .appAlert(alert(for: .newTagSet))
                // Shown while the set's page offers deleting it, and kept, disabled, while its own failure alert is up
                // (U-2a), so a refusal whose answer withdraws the offer is still seen on this row.
                if store.showsDeleteTagSetRow {
                    Button(.myTagsDeleteTagSet, role: .destructive) {
                        store.send(.deleteTagSetTapped)
                    }
                    .disabled(store.isChangingTagSets || !store.canDeleteTagSet)
                    // On the row that opens them, the confirmation and its failure alert (AGENTS.md dialog
                    // placement): on iPad the confirmation is a popover whose arrow points at this row.
                    .confirmationDialog($store.scope(\.$deleteTagSetDialog, action: \.deleteTagSetDialog))
                    .appAlert(alert(for: .deleteTagSet))
                }
            } footer: {
                Text(.myTagsTagSetFooter)
            }
            if tagSet.tags.isEmpty {
                Section {
                    emptyTags
                }
            } else {
                Section(.tags) {
                    ForEach(tagSet.tags) { tag in
                        Button {
                            store.send(.tagTapped(tag))
                        } label: {
                            MyTagRow(tag: tag, tagSetColor: tagSet.color)
                                .withArrow()
                        }
                        // A row that opens a page, not an action: the label's primary and secondary styles resolve
                        // against the label colour instead of the button's tint, as the other Settings rows do.
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .trailing) {
                            // Not the destructive role, which would take the row out before the site answers; the
                            // row leaves once the site's page no longer lists the tag.
                            Button {
                                store.send(.removeSwiped(tag))
                            } label: {
                                Label(.myTagsRemove, systemSymbol: .trash)
                            }
                            .tint(.red)
                        }
                        // On the row whose request failed (AGENTS.md dialog placement).
                        .appAlert(alert(for: .tag(tag.id)))
                    }
                }
            }
        }
        .refreshable {
            await store.send(.refresh).finish()
        }
    }

    /// A set without tags (design MyTags-States, "Empty"): the unavailable view sits on the page's grouped background
    /// under the tag set section, not in a row's card, so its row draws no background; its Add Tag is the app's
    /// unavailable-view button (`NotLoginView`'s gray-tinted glass in its own padding).
    private var emptyTags: some View {
        ContentUnavailableView {
            Label(.myTagsEmptyTitle, systemSymbol: .tag)
        } description: {
            Text(.myTagsEmptyDescription)
        } actions: {
            Button(.RLocalizable.myTagsAddTag) {
                store.send(.addTagTapped)
            }
            .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
            .interactiveHover(.highlight, in: .capsule)
            .padding()
        }
        .listRowBackground(Color.clear)
    }

    /// The alert of a failed request, on the control that sent it; every other control's binding is nil.
    private func alert(for source: MyTagsFeature.AlertSource) -> Binding<Store<AppAlertState<Never>, Never>?> {
        guard store.alertSource == source else { return .constant(nil) }
        return $store.scope(\.$alert, action: \.alert)
    }
}
