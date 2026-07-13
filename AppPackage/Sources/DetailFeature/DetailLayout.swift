import CoreGraphics

enum DetailLayout {
    static func archiveWidth(regular: Bool) -> CGFloat {
        regular ? 175 : 150
    }

    static func previewWidth(regular: Bool) -> CGFloat {
        regular ? 200 : 110
    }

    static func previewGridMinimumWidth(regular: Bool) -> CGFloat {
        regular ? 180 : 100
    }

    static func previewGridMaximumWidth(regular: Bool) -> CGFloat {
        regular ? 220 : 120
    }
}
