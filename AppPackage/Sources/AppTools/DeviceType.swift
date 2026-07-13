#if canImport(UIKit)
import UIKit
#endif

public enum DeviceType: Equatable, Sendable, CaseIterable {
    // reason: mirrors UIUserInterfaceIdiom.tv; the case name is fixed by the platform enum it maps.
    // swiftlint:disable:next identifier_name
    case unspecified, phone, pad, watch, tv, carPlay, mac, vision

    #if canImport(UIKit)
    public init(idiom: UIUserInterfaceIdiom) {
        switch idiom {
        case .unspecified: self = .unspecified
        case .phone: self = .phone
        case .pad: self = .pad
        case .tv: self = .tv
        case .carPlay: self = .carPlay
        case .mac: self = .mac
        case .vision: self = .vision
        @unknown default: self = .unspecified
        }
    }
    #endif
}
