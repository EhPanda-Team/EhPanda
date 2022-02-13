//
//  LiveTextView.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/12.
//

import SwiftUI

struct LiveTextView: View {
    private let liveTextGroups: [LiveTextGroup]

    init(liveTextGroups: [LiveTextGroup]) {
        self.liveTextGroups = liveTextGroups
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(x: 0, y: 0, width: width, height: height)),
                        with: .color(.black.opacity(0.1))
                    )
                    let paths: [Path] = liveTextGroups.flatMap(\.blocks).map { block in
                        // let bounds = item.bounds
                        let bounds = block.bounds.halfHeightExpanded
                        let rect = CGRect(
                            x: 0, y: 0, width: bounds.width * width, height: bounds.height * height
                        )
                        return .init(roundedRect: rect, cornerRadius: bounds.height * height / 5)
                            .applying(CGAffineTransform(rotationAngle: (0 - block.bounds.radian)))
                            .offsetBy(dx: bounds.topLeft.x * width, dy: height - bounds.topLeft.y * height)
                    }
                    context.withCGContext { cgContext in
                        paths.forEach { path in
                            cgContext.setFillColor(.init(red: 255, green: 255, blue: 255, alpha: 1))
                            cgContext.setShadow(
                                offset: .zero, blur: 15,
                                color: .init(red: 0, green: 0, blue: 0, alpha: 0.3)
                            )
                            cgContext.addPath(path.cgPath)
                            cgContext.drawPath(using: .fill)
                        }
                    }
                    context.blendMode = .destinationOut
                    paths.forEach { path in
                        context.fill(path, with: .color(.red))
                        context.stroke(path, with: .color(.red))
                    }
                }

                ForEach(liveTextGroups) { textGroup in
                    HighlightView(text: textGroup.text)
                        .frame(width: textGroup.width * width, height: textGroup.height * height)
                        .rotationEffect(Angle(degrees: 360 - (textGroup.blocks[0].bounds.angle)))
                        .position(
                            x: (textGroup.minX + textGroup.width / 2) * width,
                            y: (textGroup.minY + textGroup.height / 2) * height
                        )
                }
            }
        }
    }
}

// MARK: HighlightView
private struct HighlightView: UIViewRepresentable {
    final class Coordinator: NSObject {
        var textView: UITextView?
        var highLightView: HighlightView

        init(_ highLightView: HighlightView) {
            self.highLightView = highLightView
        }

        @objc func onTap(sender: UIView) {
            Logger.info("onTap", context: ["tappedText": textView?.text])
            textView?.selectAll(nil)
            textView?.perform(NSSelectorFromString("_translate:"), with: nil)
        }
    }

    private let text: String

    init(text: String) {
        self.text = text
    }

    func makeCoordinator() -> Coordinator {
        .init(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        context.coordinator.textView = textView
        let text = text.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation }
            .reduce("") { $0 + String($1)}
        textView.text = text
        textView.isEditable = false
        textView.tintColor = .clear
        textView.textColor = .clear
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .sentences
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.onTap(sender:))
        )
        textView.addGestureRecognizer(tap)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        // uiView.font = UIFont.preferredFont(forTextStyle: textStyle)
    }
}
