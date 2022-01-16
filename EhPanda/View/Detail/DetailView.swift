//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import Kingfisher
import ComposableArchitecture

struct DetailView: View {
    private let store: Store<DetailState, DetailAction>
    @ObservedObject private var viewStore: ViewStore<DetailState, DetailAction>
    private let gid: String
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<DetailState, DetailAction>, gid: String,
        user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        self.user = user
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    HeaderSection(
                        gallery: viewStore.gallery ?? .empty,
                        galleryDetail: viewStore.galleryDetail ?? .empty,
                        user: user,
                        showFullTitle: viewStore.showFullTitle,
                        showFullTitleAction: { viewStore.send(.toggleShowFullTitle) },
                        favorAction: { viewStore.send(.favorGallery($0)) },
                        unfavorAction: { viewStore.send(.unfavorGallery) },
                        navigateReadingAction: { viewStore.send(.setNavigation(.reading)) },
                        navigateUploaderAction: {
                            if let uploader = viewStore.galleryDetail?.uploader {
                                viewStore.send(.setNavigation(.searchRequest("uploader:" + "\"\(uploader)\"")))
                            }

                        }
                    )
                    .padding(.horizontal)
                    DescriptionSection(
                        gallery: viewStore.gallery ?? .empty,
                        galleryDetail: viewStore.galleryDetail ?? .empty,
                        navigateGalleryInfosAction: {
                            if let gallery = viewStore.gallery, let galleryDetail = viewStore.galleryDetail {
                                viewStore.send(.setNavigation(.galleryInfos(gallery, galleryDetail)))
                            }
                        }
                    )
                    ActionSection(
                        galleryDetail: viewStore.galleryDetail ?? .empty,
                        userRating: viewStore.userRating,
                        showUserRating: viewStore.showUserRating,
                        showUserRatingAction: { viewStore.send(.toggleShowUserRating) },
                        updateRatingAction: { viewStore.send(.updateRating($0)) },
                        confirmRatingAction: { viewStore.send(.confirmRating($0)) },
                        navigateSimilarGalleryAction: {
                            if let trimmedTitle = viewStore.galleryDetail?.trimmedTitle {
                                viewStore.send(.setNavigation(.searchRequest(trimmedTitle)))
                            }
                        }
                    )
                    if !viewStore.galleryTags.isEmpty {
                        TagsSection(
                            tags: viewStore.galleryTags,
                            navigateAction: { viewStore.send(.setNavigation(.searchRequest($0))) },
                            translateAction: {
                                tagTranslator.tryTranslate(
                                    text: $0, returnOriginal: !setting.translatesTags
                                )
                            }
                        )
                        .padding(.horizontal)
                    }
                    PreviewsSection(
                        pageCount: viewStore.galleryDetail?.pageCount ?? 0,
                        previews: viewStore.galleryPreviews,
                        navigatePreviewsAction: { viewStore.send(.setNavigation(.previews)) },
                        navigateReadingAction: {
                            viewStore.send(.updateReadingProgress($0))
                            viewStore.send(.setNavigation(.reading))
                        }
                    )
                    CommentsSection(
                        comments: viewStore.galleryComments,
                        navigateCommentAction: { viewStore.send(.setNavigation(.comments)) },
                        navigateDraftCommentAction: { viewStore.send(.setNavigation(.draftComment)) }
                    )
                }
                .padding(.bottom, 20)
                .padding(.top, -25)
            }
            .opacity(viewStore.galleryDetail == nil ? 0 : 1)
            LoadingView()
                .opacity(
                    viewStore.galleryDetail == nil
                    && viewStore.loadingState == .loading ? 1 : 0
                )
            let error = (/LoadingState.failed).extract(from: viewStore.loadingState)
            ErrorView(error: error ?? .unknown) {
                viewStore.send(.fetchGalleryDetail)
            }
            .opacity(viewStore.galleryDetail == nil && error != nil ? 1 : 0)
        }
        .animation(.default, value: viewStore.galleryDetail)
        .animation(.default, value: viewStore.showFullTitle)
        .animation(.default, value: viewStore.showUserRating)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                viewStore.send(.fetchDatabaseInfos(gid))
            }
        }
        .background(navigationLinks)
        .toolbar(content: toolbar)
    }
}

// MARK: NavigationLinks
private extension DetailView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /DetailState.Route.previews) { _ in
            PreviewsView(
                store: store.scope(state: \.previewsState, action: DetailAction.previews),
                gid: gid, pageCount: viewStore.gallery?.pageCount ?? 1
            )
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /DetailState.Route.comments) { _ in
            CommentsView(
                store: store.scope(state: \.commentsState, action: DetailAction.comments),
                gid: gid, token: viewStore.galleryToken, apiKey: viewStore.apiKey, comments: viewStore.galleryComments,
                user: user, setting: setting, tagTranslator: tagTranslator
            )
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /DetailState.Route.galleryInfos) { route in
            let (gallery, galleryDetail) = route.wrappedValue
            GalleryInfosView(gallery: gallery, galleryDetail: galleryDetail)
        }
    }
}

// MARK: ToolBar
private extension DetailView {
    func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Menu {
                Button {
                    viewStore.send(.setNavigation(.archive))
                } label: {
                    Label("Archive", systemImage: "doc.zipper")
                }
                .disabled(viewStore.galleryDetail?.archiveURL == nil || !CookiesUtil.didLogin)
                Button {
                    viewStore.send(.setNavigation(.torrents))
                } label: {
                    let base = "Torrents".localized
                    let torrentCount = viewStore.galleryDetail?.torrentCount ?? 0
                    let baseWithCount = [base, "(\(torrentCount))"].joined(separator: " ")
                    Label(torrentCount > 0 ? baseWithCount : base, systemImage: "leaf" )
                }
                .disabled((viewStore.galleryDetail?.torrentCount ?? 0 > 0) != true)
                Button {
//                    viewStore.send(.setNavigation(.share))
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .disabled(viewStore.galleryDetail == nil || viewStore.loadingState == .loading)
        }
    }
}

// MARK: HeaderSection
private struct HeaderSection: View {
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail
    private let user: User
    private let showFullTitle: Bool
    private let showFullTitleAction: () -> Void
    private let favorAction: (Int) -> Void
    private let unfavorAction: () -> Void
    private let navigateReadingAction: () -> Void
    private let navigateUploaderAction: () -> Void

    init(
        gallery: Gallery,
        galleryDetail: GalleryDetail,
        user: User, showFullTitle: Bool,
        showFullTitleAction: @escaping () -> Void,
        favorAction: @escaping (Int) -> Void,
        unfavorAction: @escaping () -> Void,
        navigateReadingAction: @escaping () -> Void,
        navigateUploaderAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.user = user
        self.showFullTitle = showFullTitle
        self.showFullTitleAction = showFullTitleAction
        self.favorAction = favorAction
        self.unfavorAction = unfavorAction
        self.navigateReadingAction = navigateReadingAction
        self.navigateUploaderAction = navigateUploaderAction
    }

    var body: some View {
        HStack {
            KFImage(URL(string: gallery.coverURL))
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                .defaultModifier().scaledToFit()
                .frame(
                    width: Defaults.ImageSize.headerW,
                    height: Defaults.ImageSize.headerH
                )
            VStack(alignment: .leading) {
                Button(action: showFullTitleAction) {
                    Text(galleryDetail.jpnTitle ?? galleryDetail.title)
                        .font(.title3.bold()).multilineTextAlignment(.leading)
                        .tint(.primary).lineLimit(showFullTitle ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(gallery.uploader ?? "", action: navigateUploaderAction)
                    .lineLimit(1).font(.callout).foregroundStyle(.secondary)
                Spacer()
                HStack {
                    CategoryLabel(
                        text: gallery.category.rawValue.localized, color: gallery.color,
                        font: .headline, insets: .init(top: 2, leading: 4, bottom: 2, trailing: 4),
                        cornerRadius: 3
                    )
                    Spacer()
                    ZStack {
                        Button(action: unfavorAction) {
                            Image(systemSymbol: .heartFill)
                        }
                        .opacity(galleryDetail.isFavored ? 1 : 0)
                        Menu {
                            ForEach(0..<10) { index in
                                Button(user.getFavoritesName(index: index)) {
                                    favorAction(index)
                                }
                            }
                        } label: {
                            Image(systemSymbol: .heart)
                        }
                        .opacity(galleryDetail.isFavored ? 0 : 1)
                    }
                    .imageScale(.large).foregroundStyle(.tint)
                    .disabled(!CookiesUtil.didLogin)
                    Button(action: navigateReadingAction) {
                        Text("Read".localized).bold().textCase(.uppercase)
                            .font(.headline).foregroundColor(.white)
                            .padding(.vertical, -2).padding(.horizontal, 2)
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                }
                .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: Defaults.ImageSize.headerH)
        }
    }
}

// MARK: DescriptionSection
private struct DescriptionSection: View {
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail
    private let navigateGalleryInfosAction: () -> Void

    init(
        gallery: Gallery, galleryDetail: GalleryDetail,
        navigateGalleryInfosAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.navigateGalleryInfosAction = navigateGalleryInfosAction
    }

    private var infos: [DescScrollInfo] {[
        DescScrollInfo(
            title: "DESC_SCROLL_ITEM_FAVORITED", numeral: "Times",
            value: String(galleryDetail.favoredCount)
        ),
        DescScrollInfo(
            title: "Language",
            numeral: galleryDetail.language.name,
            value: galleryDetail.languageAbbr
        ),
        DescScrollInfo(
            title: "",
            titleKey: LocalizedStringKey(
                "\(galleryDetail.ratingCount) Ratings"
            ),
            numeral: "", value: "",
            rating: galleryDetail.rating, isRating: true
        ),
        DescScrollInfo(
            title: "Page Count", numeral: "Pages",
            value: String(galleryDetail.pageCount)
        ),
        DescScrollInfo(
            title: "File Size", numeral: galleryDetail.sizeType,
            value: String(galleryDetail.sizeCount)
        )
    ]}
    private var itemWidth: Double {
        max(DeviceUtil.absWindowW / 5, 80)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(infos) { info in
                    Group {
                        if info.isRating {
                            DescScrollRatingItem(titleKey: info.titleKey, rating: info.rating)
                        } else {
                            DescScrollItem(title: info.title, value: info.value, numeral: info.numeral)
                        }
                    }
                    .frame(width: itemWidth).drawingGroup()
                    Divider()
                    if info == infos.last {
                        Button(action: navigateGalleryInfosAction) {
                            Image(systemSymbol: .ellipsis)
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(width: itemWidth)
                    }
                }
                .withHorizontalSpacing()
            }
        }
        .frame(height: 60)
    }
}

private extension DescriptionSection {
    struct DescScrollInfo: Identifiable, Equatable {
        var id: Int { title.hashValue }

        let title: String
        var titleKey: LocalizedStringKey = ""
        let numeral: String
        let value: String
        var rating: Float = 0
        var isRating = false
    }
    struct DescScrollItem: View {
        private let title: String
        private let value: String
        private let numeral: String

        init(title: String, value: String, numeral: String) {
            self.title = title
            self.value = value
            self.numeral = numeral
        }

        var body: some View {
            VStack(spacing: 3) {
                Text(title.localized).textCase(.uppercase).font(.caption)
                Text(value).fontWeight(.medium).font(.title3).lineLimit(1)
                Text(numeral.localized).font(.caption)
            }
        }
    }
    struct DescScrollRatingItem: View {
        private let titleKey: LocalizedStringKey
        private let rating: Float

        init(titleKey: LocalizedStringKey, rating: Float) {
            self.titleKey = titleKey
            self.rating = rating
        }

        var body: some View {
            VStack(spacing: 3) {
                Text(titleKey).textCase(.uppercase).font(.caption).lineLimit(1)
                Text(String(format: "%.2f", rating)).fontWeight(.medium).font(.title3)
                RatingView(rating: rating).font(.system(size: 12)).foregroundStyle(.primary)
            }
        }
    }
}

// MARK: ActionSection
private struct ActionSection: View {
    private let galleryDetail: GalleryDetail
    private let userRating: Int
    private let showUserRating: Bool
    private let showUserRatingAction: () -> Void
    private let updateRatingAction: (DragGesture.Value) -> Void
    private let confirmRatingAction: (DragGesture.Value) -> Void
    private let navigateSimilarGalleryAction: () -> Void

    init(
        galleryDetail: GalleryDetail,
        userRating: Int, showUserRating: Bool,
        showUserRatingAction: @escaping () -> Void,
        updateRatingAction: @escaping (DragGesture.Value) -> Void,
        confirmRatingAction: @escaping (DragGesture.Value) -> Void,
        navigateSimilarGalleryAction: @escaping () -> Void
    ) {
        self.galleryDetail = galleryDetail
        self.userRating = userRating
        self.showUserRating = showUserRating
        self.showUserRatingAction = showUserRatingAction
        self.updateRatingAction = updateRatingAction
        self.confirmRatingAction = confirmRatingAction
        self.navigateSimilarGalleryAction = navigateSimilarGalleryAction
    }

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button(action: showUserRatingAction) {
                        Spacer()
                        Image(systemSymbol: .squareAndPencil)
                        Text("Give a Rating").bold()
                        Spacer()
                    }
                    .disabled(!CookiesUtil.didLogin)
                    Button(action: navigateSimilarGalleryAction) {
                        Spacer()
                        Image(systemSymbol: .photoOnRectangleAngled)
                        Text("Similar Gallery").bold()
                        Spacer()
                    }
                }
                .font(.callout).foregroundStyle(.primary)
            }
            if showUserRating {
                HStack {
                    RatingView(rating: Float(userRating) / 2)
                        .font(.system(size: 24))
                        .foregroundStyle(.yellow)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged(updateRatingAction)
                                .onEnded(confirmRatingAction)
                        )
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: TagsSection
private struct TagsSection: View {
    private let tags: [GalleryTag]
    private let navigateAction: (String) -> Void
    private let translateAction: (String) -> String

    init(
        tags: [GalleryTag],
        navigateAction: @escaping (String) -> Void,
        translateAction: @escaping (String) -> String
    ) {
        self.tags = tags
        self.navigateAction = navigateAction
        self.translateAction = translateAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(
                    tag: tag, navigateAction: navigateAction,
                    translateAction: translateAction
                )
            }
        }
        .padding(.horizontal)
    }
}

private extension TagsSection {
    struct TagRow: View {
        @Environment(\.colorScheme) private var colorScheme

        private let tag: GalleryTag
        private let navigateAction: (String) -> Void
        private let translateAction: (String) -> String
        private var reversePrimary: Color {
            colorScheme == .light ? .white : .black
        }

        init(
            tag: GalleryTag,
            navigateAction: @escaping (String) -> Void,
            translateAction: @escaping (String) -> String
        ) {
            self.tag = tag
            self.navigateAction = navigateAction
            self.translateAction = translateAction
        }

        var body: some View {
            HStack(alignment: .top) {
                Text(tag.namespace.firstLetterCapitalized.localized).font(.subheadline.bold())
                    .foregroundColor(reversePrimary).padding(.vertical, 5).padding(.horizontal, 14)
                    .background(Rectangle().foregroundColor(Color(.systemGray))).cornerRadius(5)
                TagCloudView(
                    tag: tag, font: .subheadline, textColor: .primary, backgroundColor: Color(.systemGray5),
                    paddingV: 5, paddingH: 14, onTapAction: navigateAction, translateAction: translateAction
                )
            }
        }
    }
}

// MARK: PreviewSection
private struct PreviewsSection: View {
    private let pageCount: Int
    private let previews: [Int: String]
    private let navigatePreviewsAction: () -> Void
    private let navigateReadingAction: (Int) -> Void

    init(
        pageCount: Int, previews: [Int: String],
        navigatePreviewsAction: @escaping () -> Void,
        navigateReadingAction: @escaping (Int) -> Void
    ) {
        self.pageCount = pageCount
        self.previews = previews
        self.navigatePreviewsAction = navigatePreviewsAction
        self.navigateReadingAction = navigateReadingAction
    }

    private var width: CGFloat {
        Defaults.ImageSize.previewAvgW
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.previewAspect
    }

    var body: some View {
        SubSection(title: "Previews", showAll: pageCount > 20, showAllAction: navigatePreviewsAction) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(previews.tuples.sorted(by: { $0.0 < $1.0 }), id: \.0) { index, previewURL in
                        let (url, modifier) = PreviewResolver.getPreviewConfigs(originalURL: previewURL)
                        Button {
                            navigateReadingAction(index)
                        } label: {
                            KFImage.url(URL(string: url), cacheKey: previewURL)
                                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) }
                                .imageModifier(modifier).fade(duration: 0.25).resizable().scaledToFit()
                                .frame(width: width, height: height)
                        }
                    }
                    .withHorizontalSpacing(height: height)
                }
            }
        }
    }
}

// MARK: CommentsSection
private struct CommentsSection: View {
    private let comments: [GalleryComment]
    private let navigateCommentAction: () -> Void
    private let navigateDraftCommentAction: () -> Void

    init(
        comments: [GalleryComment],
        navigateCommentAction: @escaping () -> Void,
        navigateDraftCommentAction: @escaping () -> Void
    ) {
        self.comments = comments
        self.navigateCommentAction = navigateCommentAction
        self.navigateDraftCommentAction = navigateDraftCommentAction
    }

    var body: some View {
        SubSection(title: "Comments", showAll: !comments.isEmpty, showAllAction: navigateCommentAction) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(min(comments.count, 6))) { comment in
                        CommentCell(comment: comment)
                    }
                    .withHorizontalSpacing()
                }
                .drawingGroup()
            }
            CommentButton(action: navigateDraftCommentAction)
                .padding(.horizontal).disabled(!CookiesUtil.didLogin)
        }
    }
}

private extension CommentsSection {
    struct CommentCell: View {
        private let comment: GalleryComment

        init(comment: GalleryComment) {
            self.comment = comment
        }

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
            .padding().background(Color(.systemGray6))
            .frame(width: 300, height: 120)
            .cornerRadius(15)
        }
    }
}

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(
                store: .init(
                    initialState: .init(),
                    reducer: detailReducer,
                    environment: DetailEnvironment(
                        urlClient: .live,
                        hapticClient: .live,
                        cookiesClient: .live,
                        databaseClient: .live,
                        uiApplicationClient: .live
                    )
                ),
                gid: .init(),
                user: .init(),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
