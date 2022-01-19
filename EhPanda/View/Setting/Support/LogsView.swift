//
//  LogsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/06/27.
//

import SwiftUI
import ComposableArchitecture

struct LogsView: View {
    private let store: Store<LogsState, LogsAction>
    @ObservedObject private var viewStore: ViewStore<LogsState, LogsAction>

    init(store: Store<LogsState, LogsAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    var body: some View {
        ZStack {
            List(viewStore.logs) { log in
                Button {
                    viewStore.send(.setNavigation(.log(log)))
                } label: {
                    LogCell(log: log, isLatest: log == viewStore.logs.first)
                }
                .swipeActions { swipeActions(log: log) }
                .foregroundColor(.primary)
            }
            ErrorView(error: .notFound, retryAction: nil)
                .opacity(viewStore.logs.isEmpty ? 1 : 0)
        }
        .onAppear {
            if viewStore.logs.isEmpty {
                viewStore.send(.fetchLogs)
            }
        }
        .toolbar(content: toolbar)
        .background(navigationLink)
        .navigationTitle("Logs")
    }

    private func swipeActions(log: Log) -> some View {
        Button {
            viewStore.send(.deleteLog(log.fileName))
        } label: {
            Image(systemSymbol: .trash)
        }
        .tint(.red)
    }
    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /LogsState.Route.log) { route in
            LogView(log: route.wrappedValue)
        }
    }
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewStore.send(.navigateToFileApp)
            } label: {
                Image(systemSymbol: .folderBadgeGearshape)
            }
        }
    }
}

// MARK: LogCell
private struct LogCell: View {
    private let log: Log
    private let isLatest: Bool

    private var dateRangeString: String {
        parseDate(string: log.contents.first)
        + " - " + parseDate(string: log.contents.last)
    }

    init(log: Log, isLatest: Bool) {
        self.log = log
        self.isLatest = isLatest
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(log.fileName).font(.callout)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemSymbol: .checkmarkCircle).foregroundColor(.green)
                    Text("Latest").foregroundColor(.secondary)
                }
                .opacity(isLatest ? 1 : 0)
                .font(.caption)
            }
            HStack {
                Text(dateRangeString).bold()
                Spacer()
                Text("\(log.contents.count) records")
            }
            .foregroundColor(.secondary)
            .font(.caption2).lineLimit(1)
        }
        .padding()
    }

    private func parseDate(string: String?) -> String {
        guard let string = string,
              let range = string.range(of: " ")
        else { return "" }

        return String(string[..<range.upperBound])
    }
}

// MARK: LogView
private struct LogView: View {
    private struct IdentifiableLog: Identifiable {
        let id: Int
        let content: String
    }

    private let log: Log

    init(log: Log) {
        self.log = log
    }

    private var logs: [IdentifiableLog] {
        Array(0..<log.contents.count).map { index in
            IdentifiableLog(id: index, content: log.contents[index])
        }
    }

    var body: some View {
        List(logs) { log in
            Text("\(log.id + 1). " + log.content)
                .fontWeight(.medium).font(.caption).padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(log.fileName)
    }
}

// MARK: Definition
enum LogsRoute: Equatable {
    case log(String)
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView(
            store: .init(
                initialState: .init(),
                reducer: logsReducer,
                environment: .init(
                    fileClient: .live,
                    uiApplicationClient: .live
                )
            )
        )
    }
}
