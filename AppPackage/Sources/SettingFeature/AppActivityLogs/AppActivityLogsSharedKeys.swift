import Sharing
import AppModels

// In-memory shared keys bridging the always-alive activity-logs pump (writer, owned by AppReducer)
// to the read-only activity-logs screen (a Setting-stack path element). Domain-typed keys live in
// their owning feature rather than a generic keys module, per the shared-keys design.
extension SharedReaderKey where Self == InMemoryKey<RunLogFile?>.Default {
    static var appActivityLogsCurrentRun: Self {
        Self[.inMemory("appActivityLogs.currentRun"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<[AppActivityLog]>.Default {
    static var appActivityLogsCurrentRunLogs: Self {
        Self[.inMemory("appActivityLogs.currentRunLogs"), default: []]
    }
}
