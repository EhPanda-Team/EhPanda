import AppTools
import Dependencies
import HapticsClient
import Resources
import SwiftUI

public struct SubSection<Content: View>: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    private let title: LocalizedStringResource
    private let showAll: Bool
    private let isLoading: Bool?
    private let reloadAction: (() -> Void)?
    private let showAllAction: () -> Void
    private let content: Content

    public init(
        title: LocalizedStringResource, showAll: Bool = true,
        isLoading: Bool? = nil,
        reloadAction: (() -> Void)? = nil,
        showAllAction: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showAll = showAll
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
                            .animation(.default) {
                                $0.opacity(isLoading == true ? 1 : 0)
                            }
                    }
                }
                .allowsHitTesting(reloadAction != nil)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: showAllAction) {
                    Text(.showAll).font(.subheadline)
                }
                .opacity(showAll ? 1 : 0)
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
