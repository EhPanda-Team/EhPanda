import Foundation
import Network
import Synchronization

/// The interface kind a path is currently satisfied over, as a closed vocabulary.
///
/// Closed on purpose: the value is logged `public`, so it must be a symbol name this file decides
/// rather than anything the system could hand back as free text.
public enum DownloadNetworkKind: String, Sendable {
    case wifi
    case cellular
    case wired
    case other
    case unsatisfied
    case unknown
}

/// The device conditions that plausibly explain a background transfer being deferred: what it is
/// connected over, whether Low Power Mode is on, and how hot the device is.
public struct DownloadEnvironmentSnapshot: Sendable {
    public let network: DownloadNetworkKind
    public let isLowPowerModeEnabled: Bool
    public let thermalState: ProcessInfo.ThermalState

    public init(
        network: DownloadNetworkKind,
        isLowPowerModeEnabled: Bool,
        thermalState: ProcessInfo.ThermalState
    ) {
        self.network = network
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalState = thermalState
    }

    /// The thermal state as a closed symbol name, for the same reason `DownloadNetworkKind` is an
    /// enum: a logged field must be a vocabulary this module owns.
    public var thermalDescription: String {
        switch thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
}

/// Reads the environment above. Injectable so a suite gets a constant instead of the host's real
/// network and thermal state.
public struct DownloadEnvironmentProbe: Sendable {
    public var snapshot: @Sendable () -> DownloadEnvironmentSnapshot

    public init(snapshot: @escaping @Sendable () -> DownloadEnvironmentSnapshot) {
        self.snapshot = snapshot
    }

    /// The process-wide reader. ONE monitor for the whole app: `NWPathMonitor` starts a queue and
    /// holds a system observer, so minting one per probe would leak both per session.
    ///
    /// Low power mode and thermal state are read LIVE at each call — they are cheap process
    /// properties and reading them fresh keeps a snapshot honest — while the path is inherently a
    /// push, so it is cached from the monitor's own updates.
    public static let live = Self(snapshot: { livePathReader.snapshot() })

    /// A probe that always answers `snapshot`.
    public static func constant(_ snapshot: DownloadEnvironmentSnapshot) -> Self {
        Self(snapshot: { snapshot })
    }

    private static let livePathReader = LivePathReader()
}

/// Holds the monitor AND its latest summary inside one `Mutex`, so the class is `Sendable` by
/// composition rather than by an unchecked conformance: nothing reads either without the lock.
private final class LivePathReader: Sendable {
    private struct State {
        var monitor: NWPathMonitor?
        var network: DownloadNetworkKind = .unknown
    }

    private let state = Mutex(State())

    init() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let network = Self.networkKind(of: path)
            state.withLock({ $0.network = network })
        }
        state.withLock({ $0.monitor = monitor })
        monitor.start(queue: DispatchQueue(label: "app.ehpanda.downloads.path", qos: .utility))
    }

    func snapshot() -> DownloadEnvironmentSnapshot {
        DownloadEnvironmentSnapshot(
            network: state.withLock({ $0.network }),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }

    private static func networkKind(of path: NWPath) -> DownloadNetworkKind {
        guard path.status == .satisfied else { return .unsatisfied }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .other
    }
}
