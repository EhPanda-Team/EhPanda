//
//  LogsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/06/27.
//

import SwiftUI

struct LogsView: View, StoreAccessor {
    @EnvironmentObject var store: DeprecatedStore
    @State private var logs = [Log]()

    var body: some View {
        ZStack {
            List(logs) { log in
                NavigationLink(destination: LogView(log: log)) {
                    LogCell(log: log, isLatest: log == logs.first)
                }
                .swipeActions { swipeActions(log: log) }
            }
            ErrorView(error: .notFound, retryAction: nil)
                .opacity(logs.isEmpty ? 1 : 0)
        }
        .onAppear(perform: fetchLogsIfNeeded)
        .navigationBarTitle("Logs")
        .toolbar(content: toolbar)
    }

    private func swipeActions(log: Log) -> some View {
        Button {
            tryDeleteLog(name: log.fileName)
        } label: {
            Image(systemName: "trash")
        }
        .tint(.red)
    }
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: tryExportLog) {
                Image(systemName: "folder.badge.gearshape")
            }
        }
    }
}

// MARK: Private Methods
private extension LogsView {
    func tryDeleteLog(name: String) {
        guard let fileURL = FileUtil.logsDirectoryURL?.appendingPathComponent(name) else { return }

        try? FileManager.default.removeItem(at: fileURL)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            logs = logs.filter({ $0.fileName != name })
        }
    }

    func tryExportLog() {
        guard let dirPath = FileUtil.logsDirectoryURL?.path,
              let dirURL = URL(string: "shareddocuments://" + dirPath)
        else { return }

        UIApplication.shared.open(dirURL, options: [:], completionHandler: nil)
    }

    func fetchLogs() {
        guard let path = FileUtil.logsDirectoryURL?.path,
              let enumerator = FileManager.default.enumerator(atPath: path),
              let fileNames = (enumerator.allObjects as? [String])?
                .filter({ $0.contains(Defaults.FilePath.ehpandaLog) })
        else { return }

        let logs: [Log] = fileNames.compactMap { name in
            guard let fileURL = FileUtil.logsDirectoryURL?.appendingPathComponent(name),
                  let content = try? String(contentsOf: fileURL)
            else { return nil }

            return Log(
                fileName: name, contents: content
                    .components(separatedBy: "\n")
                    .filter({ !$0.isEmpty })
            )
        }
        .sorted()
        self.logs = logs
    }
    func fetchLogsIfNeeded() {
        guard logs.isEmpty else { return }
        fetchLogs()
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
                    Image(systemName: "checkmark.circle").foregroundColor(.green)
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
        .navigationBarTitle(log.fileName, displayMode: .inline)
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView()
    }
}
