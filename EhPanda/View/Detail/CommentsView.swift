//
//  CommentsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI
import Kingfisher
import ComposableArchitecture

struct CommentsView: View {
    private let store: Store<CommentsState, CommentsAction>
    @ObservedObject private var viewStore: ViewStore<CommentsState, CommentsAction>
    private let gid: String
    private let token: String
    private let apiKey: String
    private let comments: [GalleryComment]
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<CommentsState, CommentsAction>,
        gid: String, token: String, apiKey: String, comments: [GalleryComment],
        user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        self.token = token
        self.apiKey = apiKey
        self.comments = comments
        self.user = user
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    // MARK: CommentView
    var body: some View {
        ScrollViewReader { proxy in
            List(comments) { comment in
                CommentCell(
                    gid: gid, comment: comment,
                    linkAction: { viewStore.send(.handleCommentLink($0)) }
                )
                .opacity(
                    comment.commentID == viewStore.scrollGalleryID
                    ? viewStore.scrollRowOpacity : 1
                )
                .swipeActions(edge: .leading) {
                    if comment.votable {
                        Button {
                            viewStore.send(.voteComment(gid, token, apiKey, comment.commentID, -1))
                        } label: {
                            Image(systemSymbol: .handThumbsdown)
                        }
                        .tint(.red)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if comment.votable {
                        Button {
                            viewStore.send(.voteComment(gid, token, apiKey, comment.commentID, 1))
                        } label: {
                            Image(systemSymbol: .handThumbsup)
                        }
                        .tint(.green)
                    }
                    if comment.editable {
                        Button {
                            viewStore.send(.setNavigation(.postComment(comment.plainTextContent)))
                        } label: {
                            Image(systemSymbol: .squareAndPencil)
                        }
                    }
                }
            }
            .onAppear {
                if let scrollGalleryID = viewStore.scrollGalleryID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        proxy.scrollTo(scrollGalleryID)
                    }
                }
            }
        }
        .progressHUD(
            config: viewStore.hudConfig,
            unwrapping: viewStore.binding(\.$route),
            case: /CommentsState.Route.hud
        )
        .sheet(unwrapping: viewStore.binding(\.$route), case: /CommentsState.Route.postComment) { _ in
//            DraftCommentView()
//            route.wrappedValue
        }
        .animation(.default, value: viewStore.scrollRowOpacity)
        .onAppear {
            viewStore.send(.onAppear)
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle("Comments")
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                viewStore.send(.setNavigation(.postComment("")))
            } label: {
                Image(systemSymbol: .squareAndPencil)
            }
            .disabled(!CookiesUtil.didLogin)
        }
    }
}

// MARK: NavigationLinks
private extension CommentsView {
    @ViewBuilder var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /CommentsState.Route.detail) { route in
            ForEachStore(store.scope(state: \.detailStates, action: CommentsAction.detail)) { subStore in
                DetailView(
                    store: subStore, gid: route.wrappedValue, user: user,
                    setting: setting, tagTranslator: tagTranslator
                )
            }
        }
    }
}

// MARK: CommentCell
private struct CommentCell: View {
    private let gid: String
    private var comment: GalleryComment
    private let linkAction: (URL) -> Void

    init(gid: String, comment: GalleryComment, linkAction: @escaping (URL) -> Void) {
        self.gid = gid
        self.comment = comment
        self.linkAction = linkAction
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
                    Text(comment.formattedDateString)
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            .minimumScaleFactor(0.75).lineLimit(1)
            ForEach(comment.contents) { content in
                switch content.type {
                case .plainText:
                    if let text = content.text {
                        LinkedText(text: text, action: linkAction)
                    }
                case .linkedText:
                    if let text = content.text, let link = content.link {
                        Text(text).foregroundStyle(.tint)
                            .onTapGesture { linkAction(link.safeURL()) }
                    }
                case .singleLink:
                    if let link = content.link {
                        Text(link).foregroundStyle(.tint)
                            .onTapGesture { linkAction(link.safeURL()) }
                    }
                case .singleImg, .doubleImg, .linkedImg, .doubleLinkedImg:
                    generateWebImages(
                        imgURL: content.imgURL, secondImgURL: content.secondImgURL,
                        link: content.link, secondLink: content.secondLink
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    @ViewBuilder private func generateWebImages(
        imgURL: String?, secondImgURL: String?,
        link: String?, secondLink: String?
    ) -> some View {
        // Double
        if let imgURL = imgURL, let secondImgURL = secondImgURL {
            HStack(spacing: 0) {
                if let link = link, let secondLink = secondLink {
                    imageContainer(url: imgURL, widthFactor: 4) {
                        linkAction(link.safeURL())
                    }
                    imageContainer(url: secondImgURL, widthFactor: 4) {
                        linkAction(secondLink.safeURL())
                    }
                } else {
                    imageContainer(url: imgURL, widthFactor: 4)
                    imageContainer(url: secondImgURL, widthFactor: 4)
                }
            }
        }
        // Single
        else if let imgURL = imgURL {
            if let link = link {
                imageContainer(url: imgURL, widthFactor: 2) {
                    linkAction(link.safeURL())
                }
            } else {
                imageContainer(url: imgURL, widthFactor: 2)
            }
        }
    }
    @ViewBuilder func imageContainer(
        url: String, widthFactor: Double, action: (() -> Void)? = nil
    ) -> some View {
        let image = KFImage(URL(string: url))
            .commentDefaultModifier().scaledToFit()
            .frame(width: DeviceUtil.windowW / widthFactor)
        if let action = action {
            Button(action: action) {
                image
            }
            .buttonStyle(.plain)
        } else {
            image
        }
    }
}

private extension KFImage {
    func commentDefaultModifier() -> KFImage {
        defaultModifier()
            .placeholder {
                Placeholder(style: .activity(ratio: 1))
            }
    }
}

struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CommentsView(
                store: .init(
                    initialState: .init(),
                    reducer: commentsReducer,
                    environment: CommentsEnvironment(
                        urlClient: .live,
                        hapticClient: .live,
                        cookiesClient: .live,
                        databaseClient: .live,
                        uiApplicationClient: .live
                    )
                ),
                gid: .init(),
                token: .init(),
                apiKey: .init(),
                comments: [],
                user: .init(),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
