import AppModels
import SFSafeSymbols

extension DownloadBadge {
    public var symbol: SFSymbol {
        switch status {
        case .active: .playFill
        case .queued: .listDash
        case .inactive: .pauseFill
        case .completed: .checkmarkCircleFill
        case .updateAvailable: .arrowUpCircleFill
        case .error: .exclamationmarkTriangleFill
        }
    }
}
