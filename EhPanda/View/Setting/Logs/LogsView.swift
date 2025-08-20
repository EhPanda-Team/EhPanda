//
//  LogsView.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct LogsView: View {
    @Bindable private var store: StoreOf<LogsReducer>

    init(store: StoreOf<LogsReducer>) {
        self.store = store
    }

    var body: some View {
        ZStack {
            List(store.logs) { log in
                Button {
                    store.send(.setNavigation(.log(log)))
                } label: {
                    LogCell(log: log, isLatest: log == store.logs.first)
                }
                .swipeActions {
                    Button {
                        store.send(.deleteLog(log.fileName))
                    } label: {
                        Image(systemSymbol: .trash)
                    }
                    .tint(.red)
                }
                .foregroundColor(.primary)
            }
            .opacity(store.logs.isEmpty ? 0 : 1)

            LoadingView().opacity(store.loadingState == .loading && store.logs.isEmpty ? 1 : 0)

            let error = store.loadingState.failed
            ErrorView(error: error ?? .notFound) {
                store.send(.fetchLogs)
            }
            .opacity(error != nil && store.logs.isEmpty ? 1 : 0)
        }
        .onAppear {
            if store.logs.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchLogs)
                }
            }
        }
        .toolbar(content: toolbar)
        .background(navigationLink)
        .navigationTitle(L10n.Localizable.LogsView.Title.logs)
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: $store.route, case: \.log) { route in
            LogView(log: route.wrappedValue)
        }
    }
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.send(.navigateToFileApp)
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
                    Image(systemSymbol: .checkmarkCircle)
                        .foregroundColor(.green)
                    Text(L10n.Localizable.LogsView.Title.latest)
                }
                .opacity(isLatest ? 0.6 : 0)
                .font(.caption)
            }
            HStack {
                Text(dateRangeString).bold()
                Spacer()
                Text(L10n.Localizable.Common.Value.records("\(log.contents.count)"))
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
            Text("\(log.id + 1). \(log.content)")
                .fontWeight(.medium).font(.caption).padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(log.fileName)
    }
}

// MARK: Definition
struct Log: Identifiable, Comparable {
    static func < (lhs: Log, rhs: Log) -> Bool {
        lhs.fileName < rhs.fileName
    }

    var id: String { fileName }
    let fileName: String
    let contents: [String]
}
extension Log: CustomStringConvertible {
    var description: String {
        let params = String(
            describing: [
                "fileName": fileName,
                "contentsCount": contents.count
            ]
            as [String: Any]
        )
        return "Log(\(params))"
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogsView(store: .init(initialState: .init(), reducer: LogsReducer.init))
        }
    }
}
