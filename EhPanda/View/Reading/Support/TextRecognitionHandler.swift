//
//  TextRecognitionHandler.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/12.
//
//  swiftlint:disable line_length
//  Refercence
//  https://www.codeproject.com/Articles/15573/2D-Polygon-Collision-Detection
//  https://developer.apple.com/documentation/vision/recognizing_text_in_images
//  https://github.com/TelegramMessenger/Telegram-iOS/blob/2a32c871882c4e1b1ccdecd34fccd301723b30d9/submodules/Translate/Sources/Translate.swift
//  https://github.com/TelegramMessenger/Telegram-iOS/blob/0be460b147321b7455247aedca81ca819702959d/submodules/ImageContentAnalysis/Sources/ImageContentAnalysis.swift
//  swiftlint:enable line_length
//

import Vision
import SwiftUI
import Foundation

struct TextRecognitionView: View {
    @State private var textGroupList = [TextGroup]()
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    // 我没有找到如何获取图片实际大小的方法，所有现在全部固定大小。
    private let frameW = 400.0
    private let frameH = 600.0

    var body: some View {
        ZStack {
            Image(uiImage: image).resizable()

            // 黑色蒙版效果
            Canvas { context, _ in
                // 底色
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: frameW, height: frameH)),
                    with: .color(.black.opacity(0.1))
                )
                let paths: [Path] = textGroupList.flatMap(\.blocks).map { block in
                    // let bounds = item.bounds
                    let bounds = block.bounds.halfHeightExpanded
                    // TODO: 为了实现圆角，把路径转换为圆角矩形，配合旋转大概效果还行，大角度有一定的偏移，肯定哪里还是有问题。但是没找到。
                    let rect = CGRect(
                        x: 0, y: 0, width: bounds.width * frameW, height: bounds.height * frameH
                    )
                    return .init(roundedRect: rect, cornerRadius: bounds.height * frameH / 5)
                        // TODO: 先旋转，再设置 x, y，因为原点在左上角，并不知道如何手动设置原点。
                        .applying(CGAffineTransform(rotationAngle: (0 - block.bounds.radian)))
                        .offsetBy(dx: bounds.topLeft.x * frameW, dy: frameH - bounds.topLeft.y * frameH)
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

            // 点击区域
            ForEach(textGroupList) { textGroup in
                 TranslateButtonView(text: textGroup.text)
                    .frame(width: textGroup.width * frameW, height: textGroup.height * frameH)
                    .rotationEffect(Angle(degrees: 360 - (textGroup.blocks[0].bounds.angle)))
                    .position(
                        x: (textGroup.minX + textGroup.width / 2) * frameW,
                        y: (textGroup.minY + textGroup.height / 2) * frameH
                    )
            }
        }
        .frame(width: frameW, height: frameH)
        .onAppear {
            if let cgImage = image.cgImage {
                recognizeText(cgImage: cgImage)
            }
        }
    }
}

// MARK: Recognition methods
private extension TextRecognitionView {
    // 识别文本
    func recognizeText(cgImage: CGImage) {
        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        // Create a new request to recognize text.
        let textRecognitionRequest = VNRecognizeTextRequest(completionHandler: textRecognitionHandler)
        textRecognitionRequest.usesLanguageCorrection = true

        // 设置主要语言
        // 苹果内置的 Live Text 是如何实现自动语言的，或者可以根据图库标签设置主要语言？
        // 从文档中看，似乎只有中文和英文可以组合使用。
        // textRecognitionRequest.recognitionLanguages = [ "en-US" ]

        do {
            // Perform the text-recognition request.
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
    }

    // 文字识别结果处理
    func textRecognitionHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

        // TODO: 可能是识别与 UI 的坐标系方向不同，上下是颠倒的，或许从最开始就反转 y 比较好。后面有好几个地方都是在用的时候反转的。
        let textBlockList = observations.compactMap { observation in
            TextBlock(
                text: observation.topCandidates(1)[0].string,
                bounds: TextBounds(
                    topLeft: observation.topLeft,
                    topRight: observation.topRight,
                    bottomLeft: observation.bottomLeft,
                    bottomRight: observation.bottomRight
                )
            )
        }

        // 将文本块进行分组
        var groupData = [[TextBlock]]()
        textBlockList.forEach { newItem in
            if let groupIndex = groupData.firstIndex(where: { items in
                items.first { item in
                    // 获取角度的差，模 360 防止超过一圈。
                    let angle = abs(item.bounds.angle - newItem.bounds.angle).truncatingRemainder(dividingBy: 360.0)
                    // 359° 与 1° 也是接近的
                    let isAngleValid = angle < 10 || angle > (360 - 10)

                    // 高度相近，两者差 小于 两者最小高度的一半
                    let isHeightValid = abs(item.bounds.height - newItem.bounds.height)
                    < (min(item.bounds.height, newItem.bounds.height) / 2)

                    guard isAngleValid && isHeightValid else { return false }
                    // 检测块是否重叠
                    return polygonsIntersecting(
                        lhs: item.bounds.halfHeightExpanded.edges,
                        rhs: newItem.bounds.halfHeightExpanded.edges
                    )
                } != nil
            }) {
                groupData[groupIndex].append(newItem)
            } else {
                groupData.append([newItem])
            }
        }

        textGroupList = groupData.compactMap(TextGroup.init)
    }

    // 检测两个多边形是否重叠
    func polygonsIntersecting(lhs: [CGPoint], rhs: [CGPoint]) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty, lhs.count == rhs.count else { return false }
        for points in [lhs, rhs] {
            for index1 in 0..<points.count {
                let index2 = (index1 + 1) % points.count
                let point1 = points[index1]
                let point2 = points[index2]

                let basis = CGPoint(x: point2.y - point1.y, y: point1.x - point2.x)

                var minA: Double?
                var maxA: Double?
                lhs.forEach { point in
                    let projection = basis.x * point.x + basis.y * point.y
                    if let unwrappedMinA = minA {
                        minA = min(unwrappedMinA, projection)
                    } else {
                        minA = projection
                    }
                    if let unwrappedMaxA = maxA {
                        maxA = max(unwrappedMaxA, projection)
                    } else {
                        maxA = projection
                    }
                }

                var minB: Double?
                var maxB: Double?
                rhs.forEach { point in
                    let projection = basis.x * point.x + basis.y * point.y
                    if let unwrappedMinB = minB {
                        minB = min(unwrappedMinB, projection)
                    } else {
                        minB = projection
                    }
                    if let unwrappedMaxB = maxB {
                        maxB = max(unwrappedMaxB, projection)
                    } else {
                        maxB = projection
                    }
                }

                guard let minA = minA, let maxA = maxA,
                      let minB = minB, let maxB = maxB
                else { return false }

                if maxA < minB || maxB < minA {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: TextBounds
// 坐标信息，分别四个角，提供一些判断角度的方法。获取宽高。
private struct TextBounds {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    private(set) var height: Double!
    private(set) var width: Double!
    private(set) var radian: Double!
    private(set) var angle: Double!

    var edges: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }
    // TODO: 或许需要缓存一下，不要每次都计算，调用次数挺多的。
    var halfHeightExpanded: Self {
        expanding(size: height / 2)
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        height = calculateHeight()
        width = calculateWidth()
        radian = calculateRadian()
        angle = 180.0 / .pi * radian
    }

    private func calculateHeight() -> Double {
        let left = abs(sqrt(pow(topLeft.x - bottomLeft.x, 2) + pow(topLeft.y - bottomLeft.y, 2)))
        let right = abs(sqrt(pow(topRight.x - bottomRight.x, 2) + pow(topRight.y - bottomRight.y, 2)))
        return max(left, right)
    }
    private func calculateWidth() -> Double {
        let top = abs(sqrt(pow(topLeft.x - topRight.x, 2) + pow(topLeft.y - topRight.y, 2)))
        let bottom = abs(sqrt(pow(bottomLeft.x - bottomRight.x, 2) + pow(bottomLeft.y - bottomRight.y, 2)))
        return max(top, bottom)
    }
    private func calculateRadian() -> Double {
        let radian = atan2(topRight.y - topLeft.y, topRight.x - topLeft.x)
        return radian < 0 ? radian + .pi * 2 : radian
    }

    // 将四个角向外移动一定的距离。进行放大。
    private func expanding(size: Double) -> Self {
        let angle = 360 - angle
        let topPoint = hypotenuse(long: size, angle: angle)
        let rightPoint = hypotenuse(long: size, angle: angle + 90)
        let bottomPoint = hypotenuse(long: size, angle: angle + 90 * 2)
        let leftPoint = hypotenuse(long: size, angle: angle + 90 * 3)
        let topLeft = CGPoint(
            x: topLeft.x + topPoint.x + leftPoint.x,
            y: topLeft.y + topPoint.y + leftPoint.y
        )
        let topRight = CGPoint(
            x: topRight.x + topPoint.x + rightPoint.x,
            y: topRight.y + topPoint.y + rightPoint.y
        )
        let bottomLeft = CGPoint(
            x: bottomLeft.x + bottomPoint.x + leftPoint.x,
            y: bottomLeft.y + bottomPoint.y + leftPoint.y
        )
        let bottomRight = CGPoint(
            x: bottomRight.x + bottomPoint.x + rightPoint.x,
            y: bottomRight.y + bottomPoint.y + rightPoint.y
        )
        return .init(
            topLeft: topLeft, topRight: topRight,
            bottomLeft: bottomLeft, bottomRight: bottomRight
        )
    }
    // 通过长边和一个角度，获取直接边长度。用于控制点向某个角度移动，得到 x, y 的分量。
    private func hypotenuse(long: Double, angle: Double) -> CGPoint {
        let radian = 2 * .pi / 360 * angle
        return .init(x: sin(radian) * long, y: cos(radian) * long)
    }
}

// MARK: TextGroup
// 一组文本
private struct TextGroup: Identifiable {
    var id: UUID = .init()
    let blocks: [TextBlock]
    let text: String

    var minX: Double!
    var maxX: Double!
    var minY: Double!
    var maxY: Double!
    var width: Double!
    var height: Double!

    init?(blocks: [TextBlock]) {
        guard let firstBlock = blocks.first else { return nil }
        self.blocks = blocks
        self.text = blocks.map(\.text).joined(separator: " ")
        self.minX = firstBlock.bounds.topLeft.x
        self.maxX = firstBlock.bounds.topLeft.x
        self.minY = 1.0 - firstBlock.bounds.topLeft.y
        self.maxY = 1.0 - firstBlock.bounds.topLeft.y
        blocks.forEach { block in
            block.bounds.edges.forEach { point in
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, 1 - point.y)
                maxY = max(maxY, 1 - point.y)
            }
        }
        width = maxX - minX
        height = maxY - minY
    }

    // 一个包含所有块的矩形区域，一般用于 UI 或事件判断。
    func getRect(width: Double, height: Double, extendSize: Double) -> CGRect {
        .init(
            x: minX * width - extendSize,
            y: minY * height - extendSize,
            width: (maxX - minX) * width + extendSize * 2,
            height: (maxY - minY) * height + extendSize * 2
        )
    }
}

// MARK: TextBlock
// 一小块文本
private struct TextBlock: Identifiable {
    var id: UUID = .init()
    let text: String
    let bounds: TextBounds
}

// MARK: TranslateButtonView
private struct TranslateButtonView: UIViewRepresentable {
    final class Coordinator: NSObject {
        var textView: UITextView?
        var translateButtonView: TranslateButtonView

        init(_ translateButtonView: TranslateButtonView) {
            self.translateButtonView = translateButtonView
        }

        @objc func tapClick(sender: UIView) {
            print(textView?.text ?? "")
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
        textView.isSelectable = false
        textView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.tapClick(sender:))
        )
        textView.addGestureRecognizer(tap)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        // uiView.font = UIFont.preferredFont(forTextStyle: textStyle)
    }
}
