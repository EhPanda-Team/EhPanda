//
//  AlertKit_Extension.swift
//  EhPanda
//

import SwiftUI
import AlertKit

extension View {
    func jumpPageAlert(
        index: Binding<String>, isPresented: Binding<Bool>, isFocused: Binding<Bool>,
        pageNumber: PageNumber, jumpAction: @escaping () -> Void
    ) -> some View {
        JumpPageAlert(
            content: self, index: index, isPresented: isPresented,
            isFocused: isFocused, pageNumber: pageNumber, jumpAction: jumpAction
        )
    }
}

private struct JumpPageAlert<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let content: Content
    @Binding private var index: String
    @Binding private var isPresented: Bool
    @Binding private var isFocused: Bool
    private let pageNumber: PageNumber
    private let jumpAction: () -> Void

    @FocusState private var focused
    @StateObject private var manager = CustomAlertManager()

    init(
        content: Content,
        index: Binding<String>,
        isPresented: Binding<Bool>,
        isFocused: Binding<Bool>,
        pageNumber: PageNumber,
        jumpAction: @escaping () -> Void
    ) {
        self.content = content
        _index = index
        _isPresented = isPresented
        _isFocused = isFocused
        self.pageNumber = pageNumber
        self.jumpAction = jumpAction
    }

    private var widthFactor: Double {
        Defaults.FrameSize.alertWidthFactor
    }
    private var backgroundOpacity: Double {
        colorScheme == .light ? 0.2 : 0.5
    }

    var body: some View {
        content.customAlert(
            manager: manager,
            widthFactor: widthFactor,
            backgroundOpacity: backgroundOpacity,
            content: {
                PageJumpView(
                    inputText: $index,
                    isFocused: $focused,
                    pageNumber: pageNumber
                )
            },
            buttons: [
                .regular(
                    content: { Text(L10n.Localizable.JumpPageView.Button.confirm) },
                    action: jumpAction
                )
            ]
        )
        .synchronize($isFocused, $focused)
        .synchronize($isPresented, $manager.isPresented)
    }
}

struct DateSeekView: View {
    let pageNumber: PageNumber
    @Binding var selectedDate: Date
    let jumpAction: (DateSeekDirection) -> Void

    private var navigation: DateSeekNavigation? {
        pageNumber.dateSeekNavigation
    }
    private var dateRange: ClosedRange<Date> {
        navigation?.dateRange ?? Date.distantPast...Date.distantFuture
    }
    private var showsNewerButton: Bool {
        navigation?.previousURL != nil
    }
    private var showsOlderButton: Bool {
        navigation?.nextURL != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker(
                        L10n.Localizable.DateSeekView.Title.date,
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                } footer: {
                    Text(L10n.Localizable.DateSeekView.Footer.seekAroundDate)
                }

                Section {
                    if showsNewerButton {
                        Button {
                            jumpAction(.newer)
                        } label: {
                            Label(L10n.Localizable.DateSeekView.Button.seekNewer, systemImage: "chevron.left")
                        }
                    }
                    if showsOlderButton {
                        Button {
                            jumpAction(.older)
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
            if let navigation {
                selectedDate = navigation.clampedDate(selectedDate)
            }
        }
    }
}
