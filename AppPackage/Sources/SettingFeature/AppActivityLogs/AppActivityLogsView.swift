import SwiftUI
import Resources
import AppModels
import AppComponents
import SFSafeSymbols
import ComposableArchitecture

struct AppActivityLogsView: View {
    @Bindable private var store: StoreOf<AppActivityLogsReducer>

    @State private var keyword = ""

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
            store.send(.refreshAvailableLaunches)
        }
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.AppActivityLogsView.title)
        .navigationBarTitleDisplayMode(.large)
    }

    @ToolbarContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                launchMenu
            } label: {
                Image(systemSymbol: .clock)
            }
        }
    }

    @ViewBuilder
    private var launchMenu: some View {
        Button {
            store.send(.selectLaunch(nil))
        } label: {
            launchLabel(title: currentLaunchTitle, isSelected: store.selectedLaunchCount == nil)
        }

        ForEach(groupedLaunches, id: \.date) { group in
            Section(Self.dayFormatter.string(from: group.date)) {
                ForEach(group.launches) { launch in
                    Button {
                        store.send(.selectLaunch(launch.launchCount))
                    } label: {
                        launchLabel(
                            title: L10n.Localizable.AppActivityLogsView.launch(
                                "\(launch.launchCount)", Self.dayFormatter.string(from: launch.date)
                            ),
                            isSelected: store.selectedLaunchCount == launch.launchCount
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func launchLabel(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemSymbol: .checkmark)
        } else {
            Text(title)
        }
    }

    private var currentLaunchTitle: String {
        guard let count = store.currentLaunchCount, let date = store.launchDate else {
            return L10n.Localizable.AppActivityLogsView.Launch.current
        }
        return L10n.Localizable.AppActivityLogsView.launch("\(count)", Self.dayFormatter.string(from: date))
    }

    private var groupedLaunches: [(date: Date, launches: [LaunchLogFile])] {
        Dictionary(grouping: store.previousLaunches, by: \.date)
            .map { (date: $0.key, launches: $0.value.sorted { $0.launchCount > $1.launchCount }) }
            .sorted { $0.date > $1.date }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

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
