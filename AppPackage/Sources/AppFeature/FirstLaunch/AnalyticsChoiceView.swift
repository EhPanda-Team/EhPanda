import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
import Resources
import SFSafeSymbols
import SwiftUI

/// The analytics choice (UI-SPEC C-3; CONSENT-18-01, D-06a to D-06g): a neutral symbol, the title, the intro, the
/// Privacy Policy link, then the three levels in the order Minimal, Basic, Full, none selected, and Continue dimmed
/// until one is picked.
///
/// The intro is `consent.body` and `consent.footer` as one paragraph in one `Text` (D-06g, owner msg 1898); both
/// strings stay as approved and only the separator between them depends on the language. Basic carries the
/// "Recommended" label but is not pre-selected (D-06f). Nothing sits under the cards. The title is a
/// `FirstLaunchTitle`, which wraps freely and keeps a single word off its last line (UI-SPEC C-3).
struct AnalyticsChoiceView: View {
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
        FirstLaunchPage(identifier: "first_launch_analytics_choice", compactTop: 32, regularTop: 72) {
            VStack(spacing: 0) {
                Image(systemSymbol: .chartBarXaxis)
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                FirstLaunchTitle(.RLocalizable.consentTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(titleFocus, equals: .analyticsChoice)
                    .accessibilityIdentifier("first_launch_analytics_title")
                    .padding(.top, 16)
                Text(verbatim: Self.intro)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("first_launch_analytics_intro")
                    .padding(.top, 8)
                privacyLink
                    .padding(.top, 8)
                levels
                    .padding(.top, 16)
            }
        } bottom: {
            FirstLaunchContinueButton {
                if let level = store.selectedLevel {
                    store.send(.analyticsContinue(level))
                }
            }
            .disabled(store.selectedLevel == nil)
            .accessibilityIdentifier("first_launch_continue")
        }
    }

    /// Opens the website's privacy page in the default browser. Its hit area is 44pt tall while the layout keeps
    /// the text's own height, so the 8pt and 16pt gaps around it read as the spec draws them.
    @ViewBuilder private var privacyLink: some View {
        if let url = URL(string: String(localized: .RConstant.contactPrivacyPolicy)) {
            Link(destination: url) {
                HStack(spacing: 4) {
                    Text(.RLocalizable.consentPrivacyLink)
                    Image(systemSymbol: .arrowUpRight)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.vertical, Self.linkHitPadding)
                .contentShape(.rect)
                .padding(.vertical, -Self.linkHitPadding)
            }
            // A link takes the tint, the accent; the spec keeps the accent for selection (UI-SPEC Color).
            .tint(.primary)
            .accessibilityIdentifier("first_launch_privacy_link")
        }
    }

    private var levels: some View {
        VStack(spacing: 12) {
            ForEach(AnalyticsLevel.allCases, id: \.self) { level in
                ChoiceCard(
                    level.name,
                    description: level.levelDescription,
                    label: level == .basic ? .RLocalizable.consentLevelRecommended : nil,
                    isSelected: store.selectedLevel == level
                ) {
                    store.send(.binding(.set(\.selectedLevel, level)))
                }
                .accessibilityIdentifier("first_launch_level_\(level.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.RLocalizable.consentTitle)
    }

    /// Half of what the link's hit area adds to a footnote line to reach 44pt.
    private static let linkHitPadding: CGFloat = 14

    /// `consent.body` then `consent.footer`, as one paragraph in the app's language.
    private static var intro: String {
        let body = String(localized: .RLocalizable.consentBody)
        let footer = String(localized: .RLocalizable.consentFooter)
        return body + introSeparator(languageCode: ResolvedAppLanguage.code) + footer
    }

    /// What joins the intro's two sentences (D-06g): one space in en, de and ko; nothing in ja, zh-Hans and zh-Hant,
    /// whose sentences end in full-width punctuation.
    nonisolated static func introSeparator(languageCode: String?) -> String {
        switch languageCode {
        case "ja", "zh":
            ""
        default:
            " "
        }
    }
}

private extension AnalyticsLevel {
    var name: LocalizedStringResource {
        switch self {
        case .minimal: .RLocalizable.consentLevelMinimal
        case .basic: .RLocalizable.consentLevelBasic
        case .full: .RLocalizable.consentLevelFull
        }
    }

    var levelDescription: LocalizedStringResource {
        switch self {
        case .minimal: .RLocalizable.consentLevelMinimalDescription
        case .basic: .RLocalizable.consentLevelBasicDescription
        case .full: .RLocalizable.consentLevelFullDescription
        }
    }
}
