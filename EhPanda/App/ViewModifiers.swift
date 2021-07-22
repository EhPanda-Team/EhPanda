//
//  ViewModifiers.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/06.
//

import SwiftUI
import Kingfisher

extension View {
    func modify<T, U>(
        if condition: Bool,
        then modifierT: T,
        else modifierU: U
    ) -> some View where
        T: ViewModifier,
        U: ViewModifier
    {
        Group {
            if condition {
                modifier(modifierT)
            } else {
                modifier(modifierU)
            }
        }
    }
}

struct PlainLinearProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        ProgressView(value: CGFloat(configuration.fractionCompleted ?? 0), total: 1)
    }
}
extension ProgressViewStyle where Self == PlainLinearProgressViewStyle {
    static var plainLinear: PlainLinearProgressViewStyle {
        PlainLinearProgressViewStyle()
    }
}

struct OffsetModifier: ImageModifier {
    private let size: CGSize?
    private let offset: CGFloat?

    init(size: CGSize?, offset: CGFloat?) {
        self.size = size
        self.offset = offset
    }

    func modify(
        _ image: KFCrossPlatformImage
    ) -> KFCrossPlatformImage
    {
        guard let size = size,
                let offset = offset
        else { return image }

        let origin = CGPoint(x: offset, y: 0)
        let rect = CGRect(origin: origin, size: size)
        return image.cropping(to: rect) ?? image
    }
}

extension KFImage {
    func defaultModifier(withRoundedCorners: Bool = true) -> KFImage {
        self
            .imageModifier(CornersModifier(
                radius: withRoundedCorners ? 5 : nil
            ))
            .fade(duration: 0.25)
            .resizable()
    }
}
