import AppComponents
import AppModels
public import ComposableArchitecture
import Resources
public import SwiftUI
import TagTranslationFeature

/// The Add Tag and Edit Tag sheet (port of PR 462 item 10, design approved 2026-11-22): the state and the tag, the
/// colour, the weight and, for an edit, Remove from My Tags. The confirm checkmark turns into a spinner while its
/// request is on its way.
public struct MyTagEditorView: View {
    @Bindable private var store: StoreOf<MyTagEditorFeature>
    @SharedReader(.tagTranslator) private var tagTranslator: TagTranslator
    /// The weight field: 3 em at the body size, scaling with it (G-3 of quick 261126-wzg).
    @ScaledMetric(relativeTo: .body) private var weightFieldWidth = 48.0
    @FocusState private var isWeightFieldFocused: Bool

    public init(store: StoreOf<MyTagEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                stateAndTagSection
                colorSection
                weightSection
                if !store.isAdding {
                    removeSection
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(store.isAdding ? .RLocalizable.myTagsAddTag : .myTagsEditTag)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        store.send(.closeTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if store.running == .confirm {
                        ProgressView()
                    } else {
                        Button(role: .confirm) {
                            store.send(.confirmTapped)
                        }
                        .disabled(!store.canConfirm)
                        // On the control whose request failed (AGENTS.md dialog placement).
                        .appAlert(alert(for: .confirm))
                    }
                }
            }
        }
    }

    private var stateAndTagSection: some View {
        Section {
            Picker(.myTagsState, selection: $store.kind) {
                Text(.myTagsStateNormal).tag(MyTagKind.flagged)
                Text(.myTagsWatched).tag(MyTagKind.watched)
                Text(.myTagsHidden).tag(MyTagKind.hidden)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            LabeledContent(.myTagsTag) {
                if store.isNameEditable {
                    TextField(text: $store.name, prompt: Text(.myTagsTagPrompt)) {
                        Text(.myTagsTag)
                    }
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .onSubmit {
                        store.send(.confirmTapped)
                    }
                } else {
                    Text(store.name)
                }
            }
            if store.isNameEditable {
                // The site's suggestions whatever Show Tag Suggestions says; with Translate Tags, the translations'
                // matches and names too (G-1 of quick 261126-wzg).
                TagSuggestionView(
                    tag: store.name,
                    siteSuggestions: store.siteSuggestions,
                    translations: store.setting.translateTags ? tagTranslator.translations : [:],
                    showsImages: store.setting.showImagesInTags,
                    choose: { store.send(.suggestionChosen($0)) }
                )
            }
        } footer: {
            Text(.myTagsStateFooter)
        }
    }

    private var colorSection: some View {
        Section {
            HexColorField(
                .myTagsColor,
                text: $store.colorText,
                color: $store.color,
                well: $store.wellColor,
                prompt: store.tagSetColor?.hex
            )
            if store.color != nil {
                Button(.myTagsUseDefaultColor) {
                    store.color = nil
                }
            }
        } footer: {
            colorFooter
        }
    }

    /// Which colour applies, or, in red while the hex field holds an invalid code, that it does (G-2 of quick
    /// 261126-wzg).
    @ViewBuilder private var colorFooter: some View {
        switch store.colorFooter {
        case .invalidCode:
            Text(.myTagsHexInvalid)
                .foregroundStyle(.red)
        case .ownColor:
            Text(.myTagsColorFooterOwn)
        case .tagSetColor:
            Text(.myTagsColorFooterTagSet)
        case .noColor:
            Text(.myTagsColorFooterNone)
        }
    }

    /// A number field and the Stepper, 12 pt apart at the trailing side, following each other; the Stepper's halves
    /// stop at the ends of the site's range (G-3 of quick 261126-wzg).
    private var weightSection: some View {
        Section {
            LabeledContent(.myTagsWeight) {
                HStack(spacing: 12) {
                    TextField(text: $store.weightText, prompt: Text(0, format: .number)) {
                        Text(.myTagsWeight)
                    }
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .accessibilityLabel(.myTagsWeight)
                    .frame(width: weightFieldWidth)
                    .focused($isWeightFieldFocused)
                    .onSubmit {
                        store.send(.weightFieldCommitted)
                    }
                    .onChange(of: isWeightFieldFocused) {
                        guard !isWeightFieldFocused else { return }
                        store.send(.weightFieldCommitted)
                    }
                    Stepper(value: $store.weight, in: MyTag.weightRange) {
                        Text(.myTagsWeight)
                    }
                    .labelsHidden()
                    .accessibilityValue(store.weight.formatted())
                }
            }
        } footer: {
            Text(.myTagsWeightFooter(store.setting.galleryHost.rawValue))
        }
    }

    private var removeSection: some View {
        Section {
            Button(role: .destructive) {
                store.send(.removeTapped)
            } label: {
                Text(.RLocalizable.myTagsRemoveFromMyTags)
            }
            .disabled(store.running != nil)
            // On the control whose request failed (AGENTS.md dialog placement).
            .appAlert(alert(for: .remove))
        }
    }

    /// The alert of a failed request, on the control that sent it; every other control's binding is nil.
    private func alert(for control: MyTagEditorFeature.Control) -> Binding<Store<AppAlertState<Never>, Never>?> {
        guard store.alertSource == control else { return .constant(nil) }
        return $store.scope(\.$alert, action: \.alert)
    }
}
