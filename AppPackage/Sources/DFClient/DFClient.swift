import Foundation
import Kingfisher
import ComposableArchitecture
import Networking

public struct DFClient: Sendable {
    public let setActive: @Sendable (Bool) -> Void
}

extension DFClient {
    public static let live: Self = .init(
        setActive: { newValue in
            if newValue {
                URLProtocol.registerClass(DFURLProtocol.self)
            } else {
                URLProtocol.unregisterClass(DFURLProtocol.self)
            }
            // Kingfisher
            let config = KingfisherManager.shared.downloader.sessionConfiguration
            config.protocolClasses = newValue ? [DFURLProtocol.self] : nil
            KingfisherManager.shared.downloader.sessionConfiguration = config
        }
    )
}

// MARK: API
public enum DFClientKey: DependencyKey {
    public static let liveValue = DFClient.live
    public static let previewValue = DFClient.noop
    public static let testValue = DFClient.unimplemented
}

extension DependencyValues {
    public var dfClient: DFClient {
        get { self[DFClientKey.self] }
        set { self[DFClientKey.self] = newValue }
    }
}

// MARK: Test
extension DFClient {
    public static let noop: Self = .init(
        setActive: { _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        setActive: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
