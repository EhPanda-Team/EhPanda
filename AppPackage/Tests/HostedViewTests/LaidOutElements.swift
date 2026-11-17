import Foundation
import SwiftUI
import UIKit

/// The accessibility elements of a SwiftUI view laid out at `width` and a Dynamic Type size, with their frames.
@MainActor
struct LaidOutElements {
    private let frames: [(label: String, frame: CGRect)]

    init(of view: some View, width: CGFloat, size: DynamicTypeSize) throws {
        let content = view
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.dynamicTypeSize, size)
            .environment(\.locale, Locale(identifier: "en_US"))
        let window = CGSize(width: width + 40, height: 2000)
        frames = try AccessibilityElements.read(of: content, size: window) { elements in
            elements.compactMap { element in
                guard let label = element.accessibilityLabel, !label.isEmpty else { return nil }
                return (label, element.accessibilityFrame)
            }
        }
    }

    func frame(labelled label: String) -> CGRect? {
        frames.first(where: { $0.label == label })?.frame
    }
}
