import SwiftUI
import AppModels
import Resources
import AppComponents

extension DetailView {
    struct CommentCell: View {
        let comment: GalleryComment
        let backgroundColor: Color

        private var content: String {
            comment.contents
                .filter({ [.plainText, .linkedText].contains($0.type) })
                .compactMap(\.text).joined()
        }

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text(comment.author).font(.subheadline.bold())
                    Spacer()
                    Group {
                        ZStack {
                            Image(systemSymbol: .handThumbsupFill)
                                .opacity(comment.votedUp ? 1 : 0)
                            Image(systemSymbol: .handThumbsdownFill)
                                .opacity(comment.votedDown ? 1 : 0)
                        }
                        Text(comment.score ?? "")
                        Text(comment.formattedDateString).lineLimit(1)
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.75).lineLimit(1)
                Text(content).padding(.top, 1)
                Spacer()
            }
            .padding().background(backgroundColor)
            .frame(width: 300, height: 120)
            .cornerRadius(15)
        }
    }
}

struct CommentButton: View {
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15)

        Button(action: action) {
            HStack {
                Image(systemSymbol: .squareAndPencil)
                Text(.postComment)
                    .bold()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .clipShape(shape)
        }
        .glassEffect(.clear.interactive(), in: shape)
    }
}
