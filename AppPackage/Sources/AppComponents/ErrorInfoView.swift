import SwiftUI
import AppModels
import AppTools
import ComposableArchitecture
import DeviceClient
import Resources

public struct ErrorInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.deviceClient) private var deviceClient
    private let errorInfo: ErrorInfo

    public init(errorInfo: ErrorInfo) {
        self.errorInfo = errorInfo
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(.errorInfoDescription) {
                    Text(errorInfo.error.localizedDescription)
                }
                if let solution = errorInfo.error.solution {
                    Section(.errorInfoSolution) {
                        Text(solution)
                    }
                }
                if let context = errorInfo.context, !context.isEmpty {
                    Section(.errorInfoContext) {
                        ForEach(
                            context.sorted { $0.key.rawValue < $1.key.rawValue },
                            id: \.key
                        ) { key, value in
                            LabeledContent(key.rawValue, value: value.displayValue)
                        }
                    }
                }
                Section(.errorInfoEnvironment) {
                    LabeledContent(
                        .errorInfoAppVersion,
                        value: "\(AppInfo.version) (\(AppInfo.build))"
                    )
                    LabeledContent(
                        .errorInfoDevice,
                        value: String(describing: deviceClient.deviceType())
                    )
                    LabeledContent(
                        .errorInfoOS,
                        value: ProcessInfo.processInfo.operatingSystemVersionString
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.close) {
                        dismiss()
                    }
                }
            }
        }
    }
}
