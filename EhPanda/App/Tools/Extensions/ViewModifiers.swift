//
//  ViewModifiers.swift
//  EhPanda
//

import SwiftUI
import Kingfisher

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    @ViewBuilder func withHorizontalSpacing(width: CGFloat = 8, height: CGFloat? = nil) -> some View {
        Color.clear.frame(width: width, height: height)
        self
        Color.clear.frame(width: width, height: height)
    }

    func withArrow(isVisible: Bool = true) -> some View {
        HStack {
            self
            Spacer()
            Image(systemSymbol: .chevronRight)
                .foregroundColor(.secondary)
                .imageScale(.small)
                .opacity(isVisible ? 0.5 : 0)
        }
    }

    func autoBlur(radius: Double) -> some View {
        blur(radius: radius)
            .allowsHitTesting(radius < 1)
            .animation(.linear(duration: 0.1), value: radius)
    }

    func synchronize<Value: Equatable>(
        _ first: Binding<Value>,
        _ second: Binding<Value>,
        initial: (first: Bool, second: Bool) = (false, false)
    ) -> some View {
        self
            .onChange(of: first.wrappedValue, initial: initial.first) { _, newValue in
                second.wrappedValue = newValue
            }
            .onChange(of: second.wrappedValue, initial: initial.second) { _, newValue in
                first.wrappedValue = newValue
            }
    }

    func synchronize<Value>(
        _ first: Binding<Value>,
        _ second: FocusState<Value>.Binding,
        initial: (first: Bool, second: Bool) = (false, false)
    ) -> some View {
        self
            .onChange(of: first.wrappedValue, initial: initial.first) { _, newValue in
                second.wrappedValue = newValue
            }
            .onChange(of: second.wrappedValue, initial: initial.second) { _, newValue in
                first.wrappedValue = newValue
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
    private let offset: CGSize?

    init(size: CGSize?, offset: CGSize?) {
        self.size = size
        self.offset = offset
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        guard let size = size, let offset = offset
        else { return image }

        return image.cropping(size: size, offset: offset) ?? image
    }
}

struct RoundedOffsetModifier: ImageModifier {
    private let size: CGSize?
    private let offset: CGSize?

    init(size: CGSize?, offset: CGSize?) {
        self.size = size
        self.offset = offset
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        guard let size = size, let offset = offset,
              let croppedImg = image.cropping(size: size, offset: offset),
              let roundedCroppedImg = croppedImg.withRoundedCorners(radius: 5)
        else { return image.withRoundedCorners(radius: 5) ?? image }

        return roundedCroppedImg
    }
}

struct WebtoonModifier: ImageModifier {
    private let minAspect: CGFloat
    private let idealAspect: CGFloat

    init(minAspect: CGFloat, idealAspect: CGFloat) {
        self.minAspect = minAspect
        self.idealAspect = idealAspect
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        let width = image.size.width
        let height = image.size.height
        let idealHeight = width / idealAspect
        guard width / height < minAspect else { return image }
        return image.cropping(size: CGSize(width: width, height: idealHeight), offset: .zero) ?? image
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
    static func getPreviewConfigs(originalURL: URL?) -> (URL?, ImageModifier) {
        guard let url = originalURL,
              let (plainURL, size, offset) = Parser.parsePreviewConfigs(url: url)
        else {
            return (originalURL, RoundedOffsetModifier(size: nil, offset: nil))
        }
        return (plainURL, RoundedOffsetModifier(size: size, offset: offset))
    }
}
