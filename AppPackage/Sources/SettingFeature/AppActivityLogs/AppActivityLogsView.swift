import SwiftUI
import Resources
import AppModels
import AppComponents
import SFSafeSymbols
import ComposableArchitecture
import SFSafeSymbolsExt

struct AppActivityLogsView: View {
    @Bindable private var store: StoreOf<AppActivityLogsReducer>

    @State private var keyword = ""
    @State private var isRunPickerPresented = false

    init(store: StoreOf<AppActivityLogsReducer>) {
        self.store = store
    }

    var body: some View {
        ZStack {
            List(store.displayedLogs) { log in
                AppActivityLogRow(log: log)
            }
            .listStyle(.plain)
            .opacity(store.displayedLogs.isEmpty ? 0 : 1)

            LoadingView()
                .opacity(store.loadingState == .loading && store.displayedLogs.isEmpty ? 1 : 0)

            Text(.appActivityLogsViewNoLogs)
                .foregroundColor(.secondary)
                .opacity(store.loadingState != .loading && store.displayedLogs.isEmpty ? 1 : 0)
        }
        .searchable(text: $keyword)
        .onSubmit(of: .search) {
            store.send(.queryLogs(keyword))
        }
        .onChange(of: keyword) { oldValue, newValue in
            if !oldValue.isEmpty, newValue.isEmpty {
                store.send(.queryLogs(newValue))
            }
        }
        .onAppear {
            store.send(.refreshAvailableRuns)
        }
        .toolbar(content: toolbar)
        .navigationTitle(.appActivityLogsViewTitle)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isRunPickerPresented) {
            RunPickerSheet(store: store) { isRunPickerPresented = false }
        }
    }

    @ToolbarContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                runMenu
            } label: {
                Image(systemSymbol: .clock)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.send(.navigateToFileApp)
            } label: {
                Label(.appActivityLogsViewOpenInFiles, systemSymbol: .folderBadgeGearshape)
            }
        }
    }

    @ViewBuilder
    private var runMenu: some View {
        Section(.appActivityLogsViewCurrent) {
            RunButton(
                run: store.currentRun,
                isSelected: store.selectedRun == nil
            ) {
                store.send(.selectRun(nil))
            }
        }

        // Show the latest runs including the current one: current + 4 previous = 5 rows.
        ForEach(groupedRuns(Array(store.previousRuns.prefix(4))), id: \.day) { group in
            Section(runDayFormatter.string(from: group.day)) {
                ForEach(group.runs) { run in
                    RunButton(
                        run: run,
                        isSelected: store.selectedRun == run.url
                    ) {
                        store.send(.selectRun(run.url))
                    }
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
            .navigationTitle(.appActivityLogsViewRuns)
            .navigationBarTitleDisplayMode(.inline)
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
        .map { (day: $0.key, runs: $0.value.sorted { $0.runCount > $1.runCount }) }
        .sorted { $0.day > $1.day }
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
    let log: AppActivityLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemSymbol: .circleFill)
                    .foregroundColor(log.level.color)
                    .font(.caption2)
                Text(log.dateDescription)
                if !log.category.isEmpty {
                    Text(log.category)
                        .foregroundColor(.primary)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray5))
                        .clipShape(.rect(cornerRadius: 4))
                        .bold()
                        .lineLimit(1)
                }
            }
            Text(log.message)
                .lineLimit(30)
        }
        .font(.caption.monospaced())
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppActivityLogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AppActivityLogsView(
                store: .init(initialState: .init(), reducer: AppActivityLogsReducer.init)
            )
        }
    }
}
