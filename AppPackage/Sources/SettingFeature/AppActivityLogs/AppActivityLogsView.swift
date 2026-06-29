import SwiftUI
import Resources
import AppModels
import AppComponents
import SFSafeSymbols
import ComposableArchitecture

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

            Text(L10n.Localizable.AppActivityLogsView.Placeholder.noLogs)
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
        .navigationTitle(L10n.Localizable.AppActivityLogsView.title)
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
    }

    @ViewBuilder
    private var runMenu: some View {
        Section(L10n.Localizable.AppActivityLogsView.Section.current) {
            RunButton(
                runCount: store.currentRunCount,
                isSelected: store.selectedRunCount == nil
            ) {
                store.send(.selectRun(nil))
            }
        }

        ForEach(groupedRuns(Array(store.previousRuns.prefix(5))), id: \.date) { group in
            Section(runDayFormatter.string(from: group.date)) {
                ForEach(group.runs) { run in
                    RunButton(
                        runCount: run.runCount,
                        isSelected: store.selectedRunCount == run.runCount
                    ) {
                        store.send(.selectRun(run.runCount))
                    }
                }
            }
        }

        Section {
            Button(L10n.Localizable.AppActivityLogsView.moreLogs) {
                isRunPickerPresented = true
            }
        }
    }
}

// MARK: RunPickerSheet
private struct RunPickerSheet: View {
    @Bindable var store: StoreOf<AppActivityLogsReducer>
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.Localizable.AppActivityLogsView.Section.current) {
                    RunButton(
                        runCount: store.currentRunCount,
                        isSelected: store.selectedRunCount == nil
                    ) {
                        store.send(.selectRun(nil))
                        onSelect()
                    }
                }

                ForEach(groupedRuns(store.previousRuns), id: \.date) { group in
                    Section(runDayFormatter.string(from: group.date)) {
                        ForEach(group.runs) { run in
                            RunButton(
                                runCount: run.runCount,
                                isSelected: store.selectedRunCount == run.runCount
                            ) {
                                store.send(.selectRun(run.runCount))
                                onSelect()
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Localizable.AppActivityLogsView.runs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Localizable.AppActivityLogsView.done) {
                        onSelect()
                    }
                }
            }
        }
    }
}

// MARK: RunButton
private struct RunButton: View {
    let runCount: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                Label(runTitle(runCount), systemSymbol: .checkmark)
            } else {
                Text(runTitle(runCount))
            }
        }
        .foregroundStyle(.primary)
    }
}

// A nil run count is the current run before its count is resolved; fall back to "Current".
private func runTitle(_ runCount: Int?) -> String {
    guard let runCount else {
        return L10n.Localizable.AppActivityLogsView.Section.current
    }
    return L10n.Localizable.AppActivityLogsView.run("\(runCount)")
}

private func groupedRuns(_ runs: [RunLogFile]) -> [(date: Date, runs: [RunLogFile])] {
    Dictionary(grouping: runs, by: \.date)
        .map { (date: $0.key, runs: $0.value.sorted { $0.runCount > $1.runCount }) }
        .sorted { $0.date > $1.date }
}

private let runDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
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
