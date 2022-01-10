//
//  CommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI
import Kingfisher
import TTProgressHUD

struct CommentView: View {
//    @EnvironmentObject var store: DeprecatedStore

    @State private var commentContent = ""
    @State private var editCommentContent = ""
    @State private var editCommentID = ""
    @State private var commentJumpID: String?
    @State private var isNavLinkActive = false

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    @State private var commentCellOpacity: Double = 1

    private let gid: String
    private let comments: [GalleryComment]
    private var scrollID: String?

    init(gid: String, comments: [GalleryComment], scrollID: String? = nil) {
        self.gid = gid
        self.comments = comments
        self.scrollID = scrollID
    }

    // MARK: CommentView
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List(comments) { comment in
                    CommentCell(gid: gid, comment: comment, linkAction: handleURL)
                        .opacity(comment.commentID == scrollID ? commentCellOpacity : 1)
                        .onAppear {
                            if comment.commentID == scrollID {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                    withAnimation { commentCellOpacity = 0.25 }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                                    withAnimation { commentCellOpacity = 1 }
                                }
                            }
                        }
                        .swipeActions(edge: .leading) { leadingSwipeActions(comment: comment) }
                        .swipeActions(edge: .trailing) { trailingSwipeActions(comment: comment) }
                }
                .onAppear {
                    guard let id = scrollID else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        withAnimation { proxy.scrollTo(id) }
                    }
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
//        .background {
//            NavigationLink(
//                "", destination: DeprecatedDetailView(gid: commentJumpID ?? gid),
//                isActive: $isNavLinkActive
//            )
//        }
//        .toolbar(content: toolbar).sheet(item: $store.appState.environment.commentViewSheetState, content: sheet)
//        .onChange(of: environment.galleryItemReverseLoading) { if !$0 { dismissHUD() } }
//        .onChange(of: environment.galleryItemReverseID, perform: tryActivateNavLink)
        .onAppear { replaceGalleryCommentJumpID(gid: nil) }
    }
    // MARK: LeadingSwipeActions
    @ViewBuilder private func leadingSwipeActions(comment: GalleryComment) -> some View {
        if comment.votable {
            Button {
                voteDownComment(comment)
            } label: {
                Image(systemName: "hand.thumbsdown")
            }
            .tint(.red)
        }
    }
    // MARK: TrailingSwipeActions
    @ViewBuilder private func trailingSwipeActions(comment: GalleryComment) -> some View {
        if comment.votable {
            Button {
                voteUpComment(comment)
            } label: {
                Image(systemName: "hand.thumbsup")
            }
            .tint(.green)
        }
        if comment.editable {
            Button {
                editComment(comment)
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
//                store.dispatch(.setCommentViewSheetState(.newComment))
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .disabled(!CookiesUtil.didLogin)
        }
    }
    // MARK: Sheet
    private func sheet(item: CommentViewSheetState) -> some View {
        Group {
            switch item {
            case .newComment:
                DraftCommentView(
                    content: $commentContent, title: "Post Comment",
                    postAction: postNewComment, cancelAction: toggleCommentViewSheetNil
                )
            case .editComment:
                DraftCommentView(
                    content: $editCommentContent, title: "Edit Comment",
                    postAction: postEditComment, cancelAction: toggleCommentViewSheetNil
                )
            }
        }
//        .accentColor(accentColor)
//        .blur(radius: environment.blurRadius)
//        .allowsHitTesting(environment.isAppUnlocked)
    }
}

// MARK: Private Extension
private extension CommentView {
    func handleURL(_ url: URL) {
        URLUtil.handleURL(url, handlesOutgoingURL: true)
        { shouldParseGalleryURL, incomingURL, _, _ in
            guard let incomingURL = incomingURL else { return }

            let gid = URLUtil.parseGID(url: incomingURL, isGalleryURL: shouldParseGalleryURL)
//            store.dispatch(.setPendingJumpInfos(
//                gid: gid, pageIndex: pageIndex, commentID: commentID
//            ))

            if PersistenceController.galleryCached(gid: gid) {
                replaceGalleryCommentJumpID(gid: gid)
            } else {
//                store.dispatch(.fetchGalleryItemReverse(
//                    url: incomingURL.absoluteString,
//                    shouldParseGalleryURL: shouldParseGalleryURL
//                ))
//                presentHUD()
            }
        }
    }
    func tryActivateNavLink(newValue: String?) {
        guard newValue != nil else { return }

        commentJumpID = newValue
        isNavLinkActive = true
        replaceGalleryCommentJumpID(gid: nil)
    }

    func presentHUD() {
        hudConfig = TTProgressHUDConfig(type: .loading, title: "Loading...".localized)
        hudVisible = true
    }
    func dismissHUD() {
        hudVisible = false
        hudConfig = TTProgressHUDConfig()
    }

    func voteUpComment(_ comment: GalleryComment) {
//        store.dispatch(.voteGalleryComment(gid: gid, commentID: comment.commentID, vote: 1))
    }
    func voteDownComment(_ comment: GalleryComment) {
//        store.dispatch(.voteGalleryComment(gid: gid, commentID: comment.commentID, vote: -1))
    }
    func editComment(_ comment: GalleryComment) {
        editCommentID = comment.commentID
        editCommentContent = comment.contents
            .filter { [.plainText, .linkedText, .singleLink].contains($0.type) }
            .compactMap { $0.type == .singleLink ? $0.link : $0.text }.joined()
//        store.dispatch(.setCommentViewSheetState(.editComment))
    }
    func postNewComment() {
//        store.dispatch(.commentGallery(gid: gid, content: commentContent))
        toggleCommentViewSheetNil()
        commentContent = ""
    }
    func postEditComment() {
//        store.dispatch(.editGalleryComment(gid: gid, commentID: editCommentID, content: editCommentContent))
        editCommentID = ""
        editCommentContent = ""
        toggleCommentViewSheetNil()
    }

    func replaceGalleryCommentJumpID(gid: String?) {
//        store.dispatch(.setGalleryCommentJumpID(gid: gid))
    }
    func toggleCommentViewSheetNil() {
//        store.dispatch(.setCommentViewSheetState(nil))
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
                        Image(systemName: "hand.thumbsup.fill")
                            .opacity(comment.votedUp ? 1 : 0)
                        Image(systemName: "hand.thumbsdown.fill")
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

    @ViewBuilder
    private func generateWebImages(
        imgURL: String?, secondImgURL: String?,
        link: String?, secondLink: String?
    ) -> some View {
        // Double
        if let imgURL = imgURL, let secondImgURL = secondImgURL {
            HStack(spacing: 0) {
                if let link = link, let secondLink = secondLink {
                    KFImage(URL(string: imgURL))
                        .commentDefaultModifier().scaledToFit()
                        .frame(width: DeviceUtil.windowW / 4)
                        .onTapGesture { linkAction(link.safeURL()) }
                    KFImage(URL(string: secondImgURL))
                        .commentDefaultModifier().scaledToFit()
                        .frame(width: DeviceUtil.windowW / 4)
                        .onTapGesture { linkAction(secondLink.safeURL()) }
                } else {
                    KFImage(URL(string: imgURL))
                        .commentDefaultModifier().scaledToFit()
                        .frame(width: DeviceUtil.windowW / 4)
                    KFImage(URL(string: secondImgURL))
                        .commentDefaultModifier().scaledToFit()
                        .frame(width: DeviceUtil.windowW / 4)
                }
            }
        }
        // Single
        else if let imgURL = imgURL {
            if let link = link {
                KFImage(URL(string: imgURL))
                    .commentDefaultModifier().scaledToFit()
                    .frame(width: DeviceUtil.windowW / 2)
                    .onTapGesture { linkAction(link.safeURL()) }
            } else {
                KFImage(URL(string: imgURL))
                    .commentDefaultModifier().scaledToFit()
                    .frame(width: DeviceUtil.windowW / 2)
            }
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

// MARK: Definition
enum CommentViewSheetState: Identifiable {
    var id: Int { hashValue }

    case newComment
    case editComment
}
