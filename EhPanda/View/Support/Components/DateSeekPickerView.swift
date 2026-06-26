//
//  DateSeekPickerView.swift
//  EhPanda
//

import SwiftUI

/// The "Seek to date" sheet content: a graphical date picker plus newer/older direction buttons.
///
/// This is a store-agnostic, reusable component — it is driven entirely by the values passed in,
/// not by a dedicated reducer. Hosts typically wire it to an embedded `DateSeekReducer`, but it
/// has no dependency on one.
struct DateSeekPickerView: View {
    let navigation: DateSeekNavigation
    @Binding var selectedDate: Date
    let seekAction: (DateSeekDirection) -> Void

    private var showsNewerButton: Bool {
        navigation.newerURL != nil
    }
    private var showsOlderButton: Bool {
        navigation.olderURL != nil
    }

    var body: some View {
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
                    if showsNewerButton {
                        Button {
                            seekAction(.newer)
                        } label: {
                            Label(L10n.Localizable.DateSeekView.Button.seekNewer, systemImage: "chevron.left")
                        }
                    }
                    if showsOlderButton {
                        Button {
                            seekAction(.older)
                        } label: {
                            Label(L10n.Localizable.DateSeekView.Button.seekOlder, systemImage: "chevron.right")
                        }
                    }
                }
            }
            .navigationTitle(L10n.Localizable.DateSeekView.Title.dateSeek)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            selectedDate = navigation.clampedDate(selectedDate)
        }
    }
}
