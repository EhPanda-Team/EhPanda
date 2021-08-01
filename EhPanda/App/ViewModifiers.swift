//
//  ViewModifiers.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/06.
//

import SwiftUI
import Kingfisher

extension View {
    func modify<T, U>(if condition: Bool, then modifierT: T, else modifierU: U
    ) -> some View where T: ViewModifier, U: ViewModifier {
        Group {
            if condition {
                modifier(modifierT)
            } else {
                modifier(modifierU)
            }
        }
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }

    @ViewBuilder
    func withHorizontalSpacing(height: CGFloat? = nil) -> some View {
        Color.clear.frame(width: 8, height: height)
        self
        Color.clear.frame(width: 8, height: height)
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

// MARK: Image Modifier
struct CornersModifier: ImageModifier {
    let radius: CGFloat?

    init(radius: CGFloat? = nil) {
        self.radius = radius
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        if let radius = radius {
            return image.withRoundedCorners(radius: radius) ?? image
        } else {
            return image
        }
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

        return image.cropping(
            size: size, offset: offset
        ) ?? image
    }
}

struct RoundedOffsetModifier: ImageModifier {
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
                let offset = offset,
              let croppedImg = image.cropping(
                size: size, offset: offset
              ),
              let roundedCroppedImg = croppedImg
                .withRoundedCorners(radius: 5)
        else {
            return image
            .withRoundedCorners(radius: 5) ?? image
        }

        return roundedCroppedImg
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

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(
                width: radius,
                height: radius
            )
        )
        return Path(path.cgPath)
    }
}

struct PreviewResolver {
    static func getPreviewConfigs(
        previews: [Int: String], index: Int
    ) -> (String, ImageModifier) {
        let originalURL = previews[index] ?? ""
        let configs = Parser.parsePreviewConfigs(
            string: originalURL
        )
        let containsConfigs = configs != nil

        let plainURL = configs?.0 ?? ""
        let loadURL = containsConfigs
            ? plainURL : originalURL
        let modifier = RoundedOffsetModifier(
            size: configs?.1, offset: configs?.2
        )
        return (loadURL, modifier)
    }
}
