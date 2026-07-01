import AppTools
import SFSafeSymbols
import AppModels
import Resources
import SwiftUI

/// The "Seek to date" sheet content: a graphical date picker plus newer/older direction buttons.
///
/// This is a store-agnostic, reusable component — it is driven entirely by the values passed in,
/// not by a dedicated reducer. Hosts typically wire it to a presented `DateSeekReducer`, but it
/// has no dependency on one.
///
/// - Precondition: `selectedDate` lies within `navigation.dateRange`. The picker renders the
///   binding as-is and does not clamp it; keeping the date in range is the responsibility of
///   whoever owns the date state (the presented `DateSeekReducer` clamps it in its initializer).
public struct DateSeekPickerView: View {
    @Binding var selectedDate: Date
    let navigation: DateSeekNavigation
    let seekAction: (DateSeekDirection) -> Void

    public init(
        selectedDate: Binding<Date>,
        navigation: DateSeekNavigation,
        seekAction: @escaping (DateSeekDirection) -> Void
    ) {
        _selectedDate = selectedDate
        self.navigation = navigation
        self.seekAction = seekAction
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker(
                        L10n.Localizable.DateSeekView.Title.date,
                        selection: $selectedDate,
                        in: navigation.dateRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                } footer: {
                    Text(L10n.Localizable.DateSeekView.Footer.seekAroundDate)
                }

                Section {
                    let seekOlderButton =
                    SeekButton(
                        symbol: .chevronLeftChevronLeftDotted,
                        title: L10n.Localizable.DateSeekView.Button.seekOlder,
                        reversedIconTitlePosition: false,
                        action: { seekAction(.older) }
                    )
                    .disabled(navigation.olderURL == nil)

                    let seekNewerButton =
                    SeekButton(
                        symbol: .chevronRightDottedChevronRight,
                        title: L10n.Localizable.DateSeekView.Button.seekNewer,
                        reversedIconTitlePosition: true,
                        action: { seekAction(.newer) }
                    )
                    .disabled(navigation.newerURL == nil)

                    ViewThatFits(in: .horizontal) {
                        HStack {
                            seekOlderButton
                            Spacer(minLength: 8)
                            seekNewerButton
                        }
                        VStack {
                            seekOlderButton
                                .frame(maxWidth: .infinity, alignment: .leading)

                            seekNewerButton
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                }
            }
            .navigationTitle(L10n.Localizable.DateSeekView.Title.dateSeek)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct SeekButton: View {
    let symbol: SFSymbol
    let title: String
    let reversedIconTitlePosition: Bool
    let action: () -> Void

    var symbolImage: some View {
        Image(systemSymbol: symbol)
    }

    var titleLabel: some View {
        Text(title)
            .font(.subheadline.bold())
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if reversedIconTitlePosition {
                    titleLabel
                    symbolImage
                } else {
                    symbolImage
                    titleLabel
                }
            }
            .lineLimit(1)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .buttonBorderShape(.buttonBorder)
        .buttonStyle(.glass(.clear))
    }
}

private extension DateSeekNavigation {
    /// A navigation spanning a fixed sample range, used only to drive the previews below.
    static func preview(_ directions: Directions) -> Self {
        .init(
            directions: directions,
            minimumDate: dateFormatter.date(from: "2007-03-20").forceUnwrapped,
            maximumDate: dateFormatter.date(from: "2023-09-08").forceUnwrapped
        )
    }
}

private let previewNewerURL: URL = .init(string: "https://e-hentai.org/?prev=2563984").forceUnwrapped
private let previewOlderURL: URL = .init(string: "https://e-hentai.org/?next=2668517").forceUnwrapped

#Preview("Both directions") {
    @Previewable @State var date: Date = DateSeekNavigation.dateFormatter.date(from: "2015-06-01").forceUnwrapped
    DateSeekPickerView(
        selectedDate: $date,
        navigation: .preview(.both(newer: previewNewerURL, older: previewOlderURL)),
        seekAction: { _ in }
    )
}

#Preview("Newer only") {
    @Previewable @State var date: Date = DateSeekNavigation.dateFormatter.date(from: "2015-06-01").forceUnwrapped
    DateSeekPickerView(
        selectedDate: $date,
        navigation: .preview(.newer(previewNewerURL)),
        seekAction: { _ in }
    )
}

#Preview("Older only") {
    @Previewable @State var date: Date = DateSeekNavigation.dateFormatter.date(from: "2015-06-01").forceUnwrapped
    DateSeekPickerView(
        selectedDate: $date,
        navigation: .preview(.older(previewOlderURL)),
        seekAction: { _ in }
    )
}
