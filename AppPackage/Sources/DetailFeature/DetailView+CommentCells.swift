import AppComponents
import AppModels
import Resources
import SwiftUI

extension DetailView {
    struct CommentCell: View {
        let comment: GalleryComment
        let backgroundColor: Color

        // 120pt at default (.large); scales with Dynamic Type relative to the card body text style (.body).
        @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 120

        private var content: String {
            comment.contents
                .filter({ [.plainText, .linkedText].contains($0.type) })
                .compactMap(\.text).joined()
        }

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text(comment.author)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        Image(systemSymbol: comment.votedUp ? .handThumbsupFill : .handThumbsdownFill)
                            .animation(.default) {
                                $0.opacity(comment.votedUp || comment.votedDown ? 1 : 0)
                            }

                        comment.score.map(Text.init)

                        Text(comment.formattedDateString)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                }
                .minimumScaleFactor(0.75)
                .lineLimit(1)

                Text(content)
                    .padding(.top, 1)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding()
            .background(backgroundColor)
            .frame(width: 300, height: cardHeight)
            .clipShape(.rect(cornerRadius: 15))
        }
    }
}

struct CommentButton: View {
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15)

        Button(action: action) {
            Label {
                Text(.postComment)
                    .bold()
            } icon: {
                Image(systemSymbol: .squareAndPencil)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .clipShape(shape)
        }
        .glassEffect(.clear.interactive(), in: shape)
    }
}
