import SwiftUI
import Resources
import AppTools
import Dependencies
import HapticsClient

public struct SubSection<Content: View>: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    private let title: LocalizedStringResource
    private let showAll: Bool
    private let tint: Color?
    private let isLoading: Bool?
    private let reloadAction: (() -> Void)?
    private let showAllAction: () -> Void
    private let content: Content

    public init(
        title: LocalizedStringResource, showAll: Bool = true,
        tint: Color? = nil, isLoading: Bool? = nil,
        reloadAction: (() -> Void)? = nil,
        showAllAction: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showAll = showAll
        self.tint = tint
        self.isLoading = isLoading
        self.reloadAction = reloadAction
        self.showAllAction = showAllAction
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    reloadAction?()
                    hapticsClient.generateFeedback(.soft)
                } label: {
                    HStack(spacing: 10) {
                        Text(title).font(.title3.bold())
                        ProgressView()
                            .opacity(isLoading == true ? 1 : 0)
                            .animation(.default, value: isLoading)
                    }
                }
                .allowsHitTesting(reloadAction != nil)
                .foregroundStyle(.primary)
                Spacer()
                Button(action: showAllAction) {
                    Text(.showAll).font(.subheadline)
                }
                .tint(tint).opacity(showAll ? 1 : 0)
            }
            .padding(.horizontal)
            content
        }
    }
}

#Preview("Default") {
    SubSection(title: "Popular") {
        Text(verbatim: "Content")
    }
}

#Preview("Loading, no show-all") {
    SubSection(title: "Popular", showAll: false, isLoading: true, reloadAction: {}) {
        Text(verbatim: "Content")
    }
}
