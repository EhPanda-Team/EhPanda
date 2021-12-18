//
//  SubSection.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/18.
//

import SwiftUI

struct SubSection<Content: View, Destination: View>: View {
    private let title: LocalizedStringKey
    private let showAll: Bool
    private let tint: Color?
    private let destination: Destination
    private let content: Content

    init(
        title: LocalizedStringKey, showAll: Bool = true, tint: Color? = nil,
        destination: Destination, @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showAll = showAll
        self.tint = tint
        self.destination = destination
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.title3.bold())
                Spacer()
                NavigationLink(destination: destination) {
                    Text("Show All").font(.subheadline)
                }
                .tint(tint).opacity(showAll ? 1 : 0)
            }
            .padding(.horizontal)
            content
        }
    }
}

struct SubSection_Previews: PreviewProvider {
    static var previews: some View {
        SubSection(title: "Title", destination: EmptyView()) {
            Text("Content")
        }
    }
}
