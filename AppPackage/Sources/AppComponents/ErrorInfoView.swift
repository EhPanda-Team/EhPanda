import AppModels
import ComposableArchitecture
import DeviceClient
import Resources
import SwiftUI

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
                    // The detail, which this view previously dropped: `localizedDescription` is only
                    // the short title, so everything that distinguishes one occurrence of an error
                    // from another — the forum's refusal wording, the expunge reason, the failed
                    // file operation, the ban's remaining interval — reached the toast and then
                    // vanished on the way to the surface built to explain it.
                    //
                    // Skipped when empty (`.noUpdates`, `.webImageFailed`) and when it merely repeats
                    // the title, so no error gains a duplicated row.
                    if !errorInfo.error.alertText.isEmpty,
                       errorInfo.error.alertText != errorInfo.error.localizedDescription {
                        Text(errorInfo.error.alertText)
                            .foregroundStyle(.secondary)
                    }
                }
                if let solution = errorInfo.error.solution {
                    Section(.errorInfoSolution) {
                        Text(solution)
                    }
                }
                if let context = errorInfo.context, !context.isEmpty {
                    Section(.errorInfoContext) {
                        ForEach(
                            context.sorted(by: { $0.key.rawValue < $1.key.rawValue }),
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
            .accessibilityIdentifier("error_info_view")
            .navigationTitle(.error)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: dismiss.callAsFunction)
                }
            }
        }
    }
}
