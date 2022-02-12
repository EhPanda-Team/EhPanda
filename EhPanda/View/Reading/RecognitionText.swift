//
//  RecognitionText.swift
//  EhPanda
//
//  Created by zhaoxin on 2022/2/12.
//

import Foundation
import SwiftUI
import Vision


// 1. 识别文本 照搬官方教程 https://developer.apple.com/documentation/vision/recognizing_text_in_images
// 2. 将结果进行分组（这个代码主要的功能）
//   2.1. 多边形碰撞检测参考：（MIT License） https://www.codeproject.com/Articles/15573/2D-Polygon-Collision-Detection
// 3. 创建ui，对SwiftUI了解不深，不过还是通过画板实现了类似的效果。

struct RecognitionTextDemoView: View {
    
    @State var showImagePicker: Bool = false
    @State var image: UIImage? = nil
    
    // 我没有找到如何获取图片实际大小的方法，所有现在全部固定大小。
    let frameW = 400.0
    let frameH = 500.0
    
    @State var textGroupList: [TextGroup] = []
    
    // 识别文本
    func recognitionText() {
        guard let cgImage = image?.cgImage else { return }
        
        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        // Create a new request to recognize text.
        let textRecognitionRequest = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        textRecognitionRequest.usesLanguageCorrection = true
            // 设置主要语言
            /// 苹果内置的livetext是如何实现自动语言的，或者可以根据图库标签设置主要语言？
        // 从文档中看 貌似只有中文和英文可以组合使用
        // textRecognitionRequest.recognitionLanguages = [ "en-US" ]
            
        do {
            // Perform the text-recognition request.
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
    }
    
    // 文字识别结果处理
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        // TODO：可能是识别与ui的坐标系方向不同，上下是颠倒的，感觉从最开始就反转y或许比较好。 后面都是在用的时候反转的，有好几个地方。
        var textBlockList = observations.compactMap({ observation in
            return TextBlock(
                text: observation.topCandidates(1)[0].string,
                bounds: TextBounds(
                    topLeft: observation.topLeft,
                    topRight: observation.topRight,
                    bottomLeft: observation.bottomLeft,
                    bottomRight: observation.bottomRight
                )
            );
        })
        

        // 将文本块进行分组
        var groupData: [[TextBlock]] = []
        textBlockList.forEach { newItem in
            let groupIndex = groupData.firstIndex { items in
                return nil != items.first { item in
                    // 获取角度的差，模360防止超过一圈。
                    var a = abs(item.bounds.angle - newItem.bounds.angle).truncatingRemainder(dividingBy: 360.0)
                    // 359度 与 1度 也是接近的
                    let angleOk = a < 10 || a > (360 - 10);
                    
                    // 高度相近，两者差 不大于 两者最小高度的一半
                    let heightOk = abs(item.bounds.height - newItem.bounds.height) < (min(item.bounds.height, newItem.bounds.height) / 2)
                    
                    if( angleOk && heightOk) {
                        // 检测块是否重叠
                        return polygonsIntersecting(a: item.bounds.expandHalfHeight().list, b: newItem.bounds.expandHalfHeight().list)
                    }
                    return false
                }
            }
            if(groupIndex != nil) {
                groupData[groupIndex!].append(newItem);
            } else {
                groupData.append([newItem])
            }
        }
        
        textGroupList = groupData.compactMap({ items in
            return TextGroup(items: items)
        })
    }
    
    
    var body: some View {
        VStack {
            if image != nil {
                ZStack{
                    Image(uiImage: image!)
                        .resizable()
                        .frame(width: frameW, height: frameH)
                        
                    
                        // 黑色蒙版效果
                        Canvas { context, size in
                            let width = frameW
                            let height = frameH
                            let cgPath = CGMutablePath()
                            
                                // 底色
                            context.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)), with: .color(.black.opacity(0.4)))
                            
                                // 扣掉
                            context.blendMode = .destinationOut
                            for group in textGroupList {
                                for item in group.items {
                                    // let bounds = item.bounds
                                     let bounds = item.bounds.expandHalfHeight()
                                    // todo: 为了实现圆角，吧路径转换为圆角矩形，配合旋转大概效果还行，大角度有一定的偏移，肯定哪里还是有问题。但是没找到。
                                    let rect = CGRect(x: 0, y: 0,  width: bounds.width * width, height: bounds.height * height)
                                    let path = Path(roundedRect: rect, cornerRadius: bounds.height * height / 5)
                                        .applying(CGAffineTransform(rotationAngle: (0 - item.bounds.radian) )) // todo: 先旋转，再设置 x y，因为原点在左上角，并不知道如何手动设置原点。
                                        .offsetBy(dx: bounds.topLeft.x * width, dy: height - bounds.topLeft.y * height)
                                    context.fill(path, with: .color(.black))
                                }
                            }
                        }
                        // 点击区域
                    ForEach(textGroupList){ textGroup in
                        Path(textGroup.getRect(width: frameW, height: frameH, extendSize: 2.0))
                            .fill(Color.white.opacity(0.1)) // todo: 完全透明无法触发，不知道怎么弄透明的按钮，或者视图点击获取坐标与textGroup.getRect匹配看在不在矩形内
                            .onTapGesture {
                                print(textGroup.text)
                                    // todo: 在这里打开翻译
                            }
                    }
                    
                }
                .frame(width: frameW, height: frameH)
            }
            Button("选择图片") {
                showImagePicker = true
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                print(image)
                self.image = image
                showImagePicker = false
                recognitionText()
            }
        }
        .onAppear(perform: recognitionText)
    }
}



// 坐标信息，分别四个角，提供一些判断角度的方法。获取宽高。
struct TextBounds {
    var topLeft: CGPoint = CGPoint.zero
    var topRight: CGPoint = CGPoint.zero
    var bottomLeft: CGPoint = CGPoint.zero
    var bottomRight: CGPoint = CGPoint.zero
    
    var height: Double!
    var width: Double!
    var radian: Double!
    
    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft;
        self.topRight = topRight;
        self.bottomLeft = bottomLeft;
        self.bottomRight = bottomRight;
        self.height = _getHeight()
        self.width = _getWidth()
        self.radian = _getRadian()
    }
    
    var list: [CGPoint] {
        get { return  [topLeft, topRight, bottomRight, bottomLeft]}
    }
    
    // 获取块的高度
    func _getHeight() -> Double {
        let l = abs(sqrt(pow(topLeft.x - bottomLeft.x, 2) + pow(topLeft.y - bottomLeft.y, 2)));
        let r = abs(sqrt(pow(topRight.x - bottomRight.x, 2) + pow(topRight.y - bottomRight.y, 2)));
        return max(l, r);
    }
    
    // 获取块的宽度
    func _getWidth() -> Double {
        let t = abs(sqrt(pow(topLeft.x - topRight.x, 2) + pow(topLeft.y - topRight.y, 2)));
        let b = abs(sqrt(pow(bottomLeft.x - bottomRight.x, 2) + pow(bottomLeft.y - bottomRight.y, 2)));
        return max(t, b);
    }
    
    func _getRadian()-> Double {
        let cx = topLeft.x;
        let cy = topLeft.y;
        
        let x1 = topRight.x;
        let y1 = topRight.y;
        
        var radian = atan2(y1 - cy, x1 - cx);
        if(radian < 0) {
            radian = radian + 2 * Double.pi
        }
        return radian
    }
    
    // 获取块的角度
    var angle: Double {
        get {
            return 180.0 / Double.pi * radian;
        }
    }
    
    // 将四个角向外移动一定的距离。进行放大。
    func expand(size: Double) -> TextBounds {
        let angle = 360 - self.angle;
        let pt = hypotenuse(long: size, angle: angle)
        let pr = hypotenuse(long: size, angle: angle + 90)
        let pb = hypotenuse(long: size, angle: angle + 90 * 2)
        let pl = hypotenuse(long: size, angle: angle + 90 * 3)
        let tl = CGPoint(x:topLeft.x + pt.x + pl.x, y: topLeft.y + pt.y + pl.y )
        let tr = CGPoint(x:topRight.x + pt.x + pr.x, y: topRight.y + pt.y + pr.y)
        let bl = CGPoint(x:bottomLeft.x + pb.x + pl.x, y: bottomLeft.y + pb.y + pl.y )
        let br = CGPoint(x:bottomRight.x + pb.x + pr.x, y: bottomRight.y + pb.y + pr.y)
        return TextBounds(topLeft: tl, topRight: tr, bottomLeft: bl, bottomRight: br)
    }
    
    // todo: 或许需要缓存一下 不要每次都计算，调用次数挺多的。
    func expandHalfHeight() -> TextBounds {
        return expand(size: height / 2)
    }
}

// 一组文本
struct TextGroup: Identifiable {
    init(items: [TextBlock]) {
        self.items = items;
        self.text = items.compactMap { $0.text }.joined(separator: " ");
        self.minX = items.first!.bounds.topLeft.x;
        self.maxX = items.first!.bounds.topLeft.x;
        self.minY = 1.0 - items.first!.bounds.topLeft.y;
        self.maxY = 1.0 - items.first!.bounds.topLeft.y;
        items.forEach { item in
            item.bounds.list.forEach { point in
                minX = min(minX, point.x);
                maxX = max(maxX, point.x);
                minY = min(minY, 1 - point.y);
                maxY = max(maxY, 1 - point.y);
            }
        }
    }
    var id: UUID = UUID()
    var items: [TextBlock];
    var text: String;
    
    var minX: Double!;
    var maxX: Double!;
    var minY: Double!;
    var maxY: Double!;
    
    // 一个包含所有块的矩形区域，一般用于ui或事件判断。
    func getRect( width: Double, height: Double, extendSize: Double )-> CGRect {
        return CGRect(x: minX * width - extendSize, y: minY * height - extendSize, width: ( maxX - minX)  * width + extendSize * 2, height: (maxY - minY) * height + extendSize * 2) ;
    }
    
}

// 一小块文本
struct TextBlock: Identifiable {
    var id: UUID = UUID()
    var text: String
    var bounds: TextBounds
}

// 通过长边和一个角度，获取直接边长度。用于控制点向某个角度移动，得到xy的分量。
func hypotenuse(long: Double, angle: Double) -> CGPoint{
    var radian = 2 * Double.pi / 360 * angle;
    return CGPoint(x: sin(radian) * long, y: cos(radian) * long);
}

// 检测两个多边形是否重叠
func polygonsIntersecting(a: [CGPoint], b: [CGPoint]) -> Bool {
    for points in [a, b] {
        for i1 in 0..<points.count {
            let i2 = (i1 + 1) % points.count
            let p1 = points[i1]
            let p2 = points[i2]
            
            let normal = CGPoint(x: p2.y - p1.y, y: p1.x - p2.x);
            
            var minA: Double?;
            var maxA: Double?;
            a.forEach { p in
                let projected = normal.x * p.x + normal.y * p.y
                if(minA == nil || projected < minA!) {
                    minA = projected
                }
                if(maxA == nil || projected > maxA!) {
                    maxA = projected
                }
            }
            
            var minB: Double?;
            var maxB: Double?;
            
            b.forEach { p in
                let projected = normal.x * p.x + normal.y * p.y
                if(minB == nil || projected < minA!) {
                    minB = projected
                }
                if(maxB == nil || projected > maxA!) {
                    maxB = projected
                }
            }
            if(maxA! < minB! || maxB! < minA!) {
                return false;
            }
        }
    }
    return true;
}



// 图片选择
struct ImagePicker: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode)
    private var presentationMode
    
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    final class Coordinator: NSObject,
                             UINavigationControllerDelegate,
                             UIImagePickerControllerDelegate {
        
        @Binding
        private var presentationMode: PresentationMode
        private let sourceType: UIImagePickerController.SourceType
        private let onImagePicked: (UIImage) -> Void
        
        init(presentationMode: Binding<PresentationMode>,
             sourceType: UIImagePickerController.SourceType,
             onImagePicked: @escaping (UIImage) -> Void) {
            _presentationMode = presentationMode
            self.sourceType = sourceType
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let uiImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
            onImagePicked(uiImage)
            presentationMode.dismiss()
            
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            presentationMode.dismiss()
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode,
                           sourceType: sourceType,
                           onImagePicked: onImagePicked)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePicker>) {
        
    }
}
