import AppComponents
import AppModels
import ComposableArchitecture
import OSLog
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

struct AppActivityLogsView: View {
    @Bindable private var store: StoreOf<AppActivityLogsReducer>

    @State private var keyword = ""
    @State private var isRunPickerPresented = false

    init(store: StoreOf<AppActivityLogsReducer>) {
        self.store = store
    }

    var body: some View {
        List(store.displayedLogs) { log in
            AppActivityLogRow(log: log)
        }
        .listStyle(.plain)
        .animation(.default) {
            $0.visible(!store.displayedLogs.isEmpty)
        }
        .overlay {
            LoadingView()
                .animation(.default) {
                    $0.visible(store.loadingState == .loading && store.displayedLogs.isEmpty)
                }
        }
        .overlay {
            Text(.appActivityLogsViewNoLogs)
                .foregroundStyle(.secondary)
                .animation(.default) {
                    $0.visible(store.loadingState != .loading && store.displayedLogs.isEmpty)
                }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .searchable(text: $keyword, placement: .navigationBarDrawer)
        .onSubmit(of: .search) {
            store.send(.queryLogs(keyword))
        }
        .onChange(of: keyword) { oldValue, newValue in
            if !oldValue.isEmpty, newValue.isEmpty {
                store.send(.queryLogs(newValue))
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle(.appActivityLogsViewTitle)
        .sheet(isPresented: $isRunPickerPresented) {
            RunPickerSheet(store: store) { isRunPickerPresented = false }
                .privacyMask()
        }
    }

    @ContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                runMenu
            } label: {
                Label(.appActivityLogsViewRuns, systemSymbol: .clock)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.send(.navigateToFileApp)
            } label: {
                Label(.appActivityLogsViewOpenInFiles, systemSymbol: .folderBadgeGearshape)
            }
        }
    }

    /// The run selector is a native `Picker`, not a column of hand-drawn checkmark rows.
    ///
    /// A menu row that draws its own tick as a `Label`'s icon loses that icon once the text reaches
    /// accessibility sizes: the row keeps its accessibility-tree selected trait, so the selection is
    /// still *reported*, but nothing on screen distinguishes the selected run from the others
    /// (Phase 16 finding #26). A `Picker` hands the selection state to the system, which draws it at
    /// every Dynamic Type size, and the rows keep their real titles for VoiceOver.
    ///
    /// One picker per group, each sharing the single selection, exactly as the checkmark rows shared
    /// `store.selectedRun`. A menu renders no heading for a picker — neither the picker's own label
    /// nor the title of a `Section` wrapped around it, verified on device — so each picker's inline
    /// group keeps the divider that separated the runs but the "Current" and per-day *captions* are
    /// gone. That is the one thing this change costs at every size, and it costs nothing outright:
    /// the day a run belongs to is still spelled out by the sectioned list behind **More Logs**,
    /// which is the surface for browsing every run rather than the five most recent. The labels stay
    /// on the pickers because they are what VoiceOver announces for the control.
    @ContentBuilder
    private var runMenu: some View {
        runPicker(title: Text(.appActivityLogsViewCurrent)) {
            Text(runLabel(store.currentRun))
                .tag(URL?.none)
        }

        // Show the latest runs including the current one: current + 4 previous = 5 rows.
        ForEach(groupedRuns(Array(store.previousRuns.prefix(4))), id: \.day) { group in
            runPicker(title: Text(runDayFormatter.string(from: group.day))) {
                ForEach(group.runs) { run in
                    Text(runLabel(run))
                        .tag(URL?.some(run.url))
                }
            }
        }

        Section {
            Button {
                isRunPickerPresented = true
            } label: {
                Label(.appActivityLogsViewMoreLogs, systemSymbol: .ellipsisCalendar)
            }
        }
    }

    private func runPicker<Content: View>(
        title: Text,
        @ContentBuilder content: () -> Content
    ) -> some View {
        Picker(
            selection: $store.selectedRun.sending(\.selectRun),
            content: content,
            label: { title }
        )
        .pickerStyle(.inline)
    }
}

// MARK: RunPickerSheet
private struct RunPickerSheet: View {
    @Bindable var store: StoreOf<AppActivityLogsReducer>
    let dismissAction: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(.appActivityLogsViewCurrent) {
                    RunButton(
                        run: store.currentRun,
                        isSelected: store.selectedRun == nil
                    ) {
                        store.send(.selectRun(nil))
                        dismissAction()
                    }
                }

                ForEach(groupedRuns(store.previousRuns), id: \.day) { group in
                    Section(runDayFormatter.string(from: group.day)) {
                        ForEach(group.runs) { run in
                            RunButton(
                                run: run,
                                isSelected: store.selectedRun == run.url
                            ) {
                                store.send(.selectRun(run.url))
                                dismissAction()
                            }
                        }
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(.appActivityLogsViewRuns)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: dismissAction)
                }
            }
        }
    }
}

// MARK: RunButton
private struct RunButton: View {
    let run: RunLogFile?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                Label(runLabel(run), systemSymbol: .checkmark)
            } else {
                Text(runLabel(run))
            }
        }
        .foregroundStyle(.primary)
    }
}

// A nil run is the current run before its count is resolved; fall back to "Current".
private func runLabel(_ run: RunLogFile?) -> String {
    guard let run else {
        return String(localized: .appActivityLogsViewCurrent)
    }
    let title = String(localized: .appActivityLogsViewRun(count: run.runCount))
    return "\(title) (\(runTimeFormatter.string(from: run.date)))"
}

private func groupedRuns(_ runs: [RunLogFile]) -> [(day: Date, runs: [RunLogFile])] {
    Dictionary(grouping: runs) { Calendar.current.startOfDay(for: $0.date) }
        .map({ group in
            (day: group.key, runs: group.value.sorted(by: { $0.runCount > $1.runCount }))
        })
        .sorted(by: { $0.day > $1.day })
}

private let runDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

// 24-hour HH:mm; the day is already shown by the section header.
private let runTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

// MARK: AppActivityLogRow
private struct AppActivityLogRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let log: AppActivityLog

    /// The subsystem chip keeps the designed single line at and below the default size, and none
    /// above it: the timestamp it shares the line with already wraps freely, so the chip matches it.
    ///
    /// A badge budget of a few lines is the usual answer, and it is not enough here — the chip is
    /// left roughly a third of an already narrow row, so at accessibility sizes three lines fit only
    /// a dozen characters and `DownloadClient` still loses its tail (measured on device at AX3).
    /// Two sources that share a prefix are told apart *only* by that tail. No budget is needed to
    /// bound this text either: the value is `os.Logger`'s category, a short identifier fixed in
    /// source, not something a gallery or a server can grow.
    private var categoryLineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            stampAndCategory
            Text(log.message)
                .lineLimit(30)
        }
        .accessibilityElement(children: .combine)
        .font(.caption.monospaced())
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The chip drops to a line of its own as soon as it stops fitting beside the timestamp, which
    /// is where it used to be squeezed into the row's last third and wrap a character at a time
    /// (Phase 16 finding #25). The timestamp and its level dot stay welded together in a nested
    /// stack, because the dot marks *that* timestamp's severity and would read as a bullet for the
    /// whole row if the split ever fell between them.
    ///
    /// This pair is a legitimate subject for `ViewThatFits`: neither member's ideal width is
    /// open-ended — the timestamp is a fixed-format 18-character stamp and the category is
    /// `os.Logger`'s, a short identifier fixed in source — so both candidates measure a real width
    /// and the row keeps its designed single line for exactly as long as that line can hold both.
    ///
    /// Stacked, the chip keeps the row's own 4-point rhythm: the same gap the timestamp keeps from
    /// the message beneath it, so the chip reads as the timestamp's second line rather than as a
    /// third element of the row. The horizontal margins are the `List` row's own and are untouched
    /// by the split, so neither line moves closer to the edge than the timestamp already sits.
    private var stampAndCategory: some View {
        AdaptiveStack(hSpacing: 4, hAlignment: .firstTextBaseline, vSpacing: 4, vAlignment: .leading) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Colour is the dot's only visible meaning; the level name is what it stands for.
                Image(systemSymbol: .circleFill)
                    .foregroundStyle(log.level.color)
                    .font(.caption2)
                    .accessibilityLabel(log.level.title)
                Text(log.dateDescription)
            }
            if !log.category.isEmpty {
                Text(log.category)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(Color(.systemGray5))
                    .clipShape(.rect(cornerRadius: 4))
                    .bold()
                    .lineLimit(categoryLineLimit)
            }
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        AppActivityLogsView(
            store: .init(
                initialState: {
                    var state = AppActivityLogsReducer.State()
                    // A non-nil `selectedRun` makes `displayedLogs` read the seeded
                    // `selectedRunLogs` instead of the `@SharedReader` current-run logs.
                    state.selectedRun = URL(string: "file:///preview.log")
                    state.selectedRunLogs = [
                        .init(
                            date: .now, category: "Networking",
                            level: .info, message: "Fetched frontpage galleries."
                        ),
                        .init(
                            date: .now, category: "Database",
                            level: .notice, message: "Persisted 24 galleries to cache."
                        ),
                        .init(
                            date: .now, category: "Networking",
                            level: .error, message: "Request timed out after 30s."
                        )
                    ]
                    return state
                }(),
                reducer: AppActivityLogsReducer.init
            )
        )
    }
}

#Preview("Row at accessibility size") {
    List {
        AppActivityLogRow(
            log: .init(
                date: .now, category: "DownloadClient",
                level: .notice, message: "Resumed 3 pending downloads."
            )
        )
    }
    .listStyle(.plain)
    .environment(\.dynamicTypeSize, .accessibility3)
}
