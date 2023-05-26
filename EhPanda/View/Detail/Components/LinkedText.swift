//
//  LinkedText.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/10.
//  Copied from https://gist.github.com/mjm/0581781f85db45b05e8e2c5c33696f88
//

import SwiftUI

private let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

private struct LinkColoredText: View {
    private enum Component {
        case text(String)
        case link(String, URL)
    }

    private let text: String
    private let components: [Component]

    init(text: String, links: [NSTextCheckingResult]) {
        self.text = text
        let nsText = text as NSString

        var components: [Component] = []
        var index = 0
        for result in links {
            if result.range.location > index {
                let trimmedText = nsText.substring(
                    with: NSRange(location: index, length: result.range.location - index)
                )
                components.append(.text(trimmedText))
            }
            components.append(.link(nsText.substring(with: result.range), result.url!))
            index = result.range.location + result.range.length
        }

        if index < nsText.length {
            components.append(.text(nsText.substring(from: index)))
        }

        self.components = components
    }

    var body: some View {
        components.map { component in
            switch component {
            case .text(let text):
                return Text(verbatim: text)
            case .link(let text, _):
                return Text(verbatim: text).foregroundColor(.accentColor)
            }
        }.reduce(Text(""), +)
    }
}

struct LinkedText: View {
    private let text: String
    private let action: (URL) -> Void
    private let links: [NSTextCheckingResult]

    init (text: String, action: @escaping (URL) -> Void) {
        self.text = text
        self.action = action
        let nsText = text as NSString

        // find the ranges of the string that have URLs
        let wholeString = NSRange(location: 0, length: nsText.length)
        links = linkDetector?.matches(in: text, options: [], range: wholeString) ?? []
    }

    var body: some View {
        LinkColoredText(text: text, links: links)
            .font(.body) // enforce here because the link tapping won't be right if it's different
            .overlay(LinkTapOverlay(text: text, action: action, links: links))
    }
}

private struct LinkTapOverlay: UIViewRepresentable {
    private let text: String
    private let action: (URL) -> Void
    private let links: [NSTextCheckingResult]

    init(text: String, action: @escaping (URL) -> Void, links: [NSTextCheckingResult]) {
        self.text = text
        self.action = action
        self.links = links
    }

    func makeUIView(context: Context) -> LinkTapOverlayView {
        let view = LinkTapOverlayView()
        view.textContainer = context.coordinator.textContainer

        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didTapLabel(_:))
        )
        tapGesture.delegate = context.coordinator
        view.addGestureRecognizer(tapGesture)

        return view
    }

    func updateUIView(_ uiView: LinkTapOverlayView, context: Context) {
        let attributedString = NSAttributedString(
            string: text, attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        context.coordinator.textStorage = NSTextStorage(attributedString: attributedString)
        context.coordinator.textStorage!.addLayoutManager(context.coordinator.layoutManager)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(overlay: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let overlay: LinkTapOverlay

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        var textStorage: NSTextStorage?

        init(overlay: LinkTapOverlay) {
            self.overlay = overlay

            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            textContainer.maximumNumberOfLines = 0
            layoutManager.addTextContainer(textContainer)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let location = touch.location(in: gestureRecognizer.view!)
            let result = link(at: location)
            return result != nil
        }

        @objc func didTapLabel(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view!)
            guard let result = link(at: location) else {
                return
            }

            guard let url = result.url else {
                return
            }

            overlay.action(url)
        }

        private func link(at point: CGPoint) -> NSTextCheckingResult? {
            guard !overlay.links.isEmpty else {
                return nil
            }

            let indexOfCharacter = layoutManager.characterIndex(
                for: point,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            return overlay.links.first { $0.range.contains(indexOfCharacter) }
        }
    }
}

private final class LinkTapOverlayView: UIView {
    var textContainer: NSTextContainer!

    override func layoutSubviews() {
        super.layoutSubviews()

        var newSize = bounds.size
        newSize.height += 20 // need some extra space here to actually get the last line
        textContainer.size = newSize
    }
}
