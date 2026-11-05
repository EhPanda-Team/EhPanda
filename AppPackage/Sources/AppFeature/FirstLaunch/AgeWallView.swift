import AppComponents
import ComposableArchitecture
import Resources
import SwiftUI

/// The age wall (UI-SPEC C-2; AGE-18-01, D-04, D-05): the app icon, the title, the body, the approved declaration as
/// a checkbox card, Continue dimmed until it is ticked, and the footnote, always rendered.
///
/// It is a statement by the user, never a check: there is no "No", no exit, no date picker, no age and no "18+".
/// The title is a `FirstLaunchTitle`, which wraps freely and keeps a single word off its last line (UI-SPEC C-3).
struct AgeWallView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable private var store: StoreOf<FirstLaunchReducer>
    private let titleFocus: AccessibilityFocusState<FirstLaunchReducer.Step?>.Binding

    init(
        store: StoreOf<FirstLaunchReducer>,
        titleFocus: AccessibilityFocusState<FirstLaunchReducer.Step?>.Binding
    ) {
        self.store = store
        self.titleFocus = titleFocus
    }

    var body: some View {
        FirstLaunchPage(identifier: "first_launch_age_wall", compactTop: 48, regularTop: 96) {
            VStack(spacing: 0) {
                appIcon
                FirstLaunchTitle(.RLocalizable.ageWallTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(titleFocus, equals: .ageWall)
                    .accessibilityIdentifier("first_launch_age_wall_title")
                    .padding(.top, 24)
                Text(.RLocalizable.ageWallBody)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Toggle(isOn: $store.isDeclarationTicked) {
                    Text(.RLocalizable.ageWallDeclaration)
                }
                .toggleStyle(CheckboxToggleStyle())
                .accessibilityIdentifier("first_launch_declaration")
                .padding(.top, 32)
                if dynamicTypeSize.isAccessibilitySize {
                    footnote
                        .padding(.top, 16)
                }
            }
        } bottom: {
            VStack(spacing: 12) {
                FirstLaunchContinueButton {
                    store.send(.ageWallContinue)
                }
                .disabled(!store.isDeclarationTicked)
                .accessibilityHint(.RLocalizable.ageWallContinueHint, isEnabled: !store.isDeclarationTicked)
                .accessibilityIdentifier("first_launch_continue")
                if !dynamicTypeSize.isAccessibilitySize {
                    footnote
                }
            }
        }
    }

    /// The footnote, always shown (D-04): in the bar 12pt under Continue, or at accessibility sizes, where it would
    /// add three lines to the pinned bar, the last scroll item, 16pt under the checkbox card (D-17b, UI-SPEC C-2).
    private var footnote: some View {
        Text(.RLocalizable.ageWallFootnote)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("first_launch_age_wall_footnote")
    }

    /// The app's own icon, decorative: 80pt, or 120pt at accessibility sizes.
    @ViewBuilder private var appIcon: some View {
        if let icon = UIImage(named: "AppIcon_Default", in: .main, with: nil) {
            let side: CGFloat = dynamicTypeSize.isAccessibilitySize ? 120 : 80
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(.rect(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
                .accessibilityIgnoresInvertColors()
        }
    }
}
