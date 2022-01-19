//
//  ActivityView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    private var activityItems: [Any]

    init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
