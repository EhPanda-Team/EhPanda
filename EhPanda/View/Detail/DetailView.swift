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
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<DetailState, DetailAction>,
        user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
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
                        favorAction: { viewStore.send(.favorGallery($0)) },
                        unfavorAction: { viewStore.send(.unfavorGallery) },
                        navigateReadingAction: {},
                        navigateUploaderAction: {}
                    )
                    .padding(.horizontal)
                    DescriptionSection(
                        gallery: viewStore.gallery ?? .empty,
                        detail: viewStore.galleryDetail ?? .empty,
                        navigateGalleryInfosAction: {}
                    )
                    ActionSection(
                        galleryDetail: viewStore.galleryDetail ?? .empty,
                        userRating: viewStore.binding(\.$userRating),
                        showUserRating: viewStore.binding(\.$showUserRating),
                        rateAction: { viewStore.send(.rateGallery($0)) },
                        navigateSimilarGalleryAction: {}
                    )
                    if !viewStore.galleryTags.isEmpty {
                        TagsSection(
                            tags: viewStore.galleryTags,
                            navigateAction: { _ in },
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
                        navigatePreviewsAction: {},
                        navigateReadingAction: { _ in }
                    )
                    CommentsSection(
                        comments: viewStore.galleryComments,
                        navigateCommentAction: {},
                        navigateDraftCommentAction: {}
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                viewStore.send(.fetchDatabaseInfos)
            }
        }
    }
}

// MARK: HeaderSection
private struct HeaderSection: View {
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail
    private let user: User
    private let favorAction: (Int) -> Void
    private let unfavorAction: () -> Void
    private let navigateReadingAction: () -> Void
    private let navigateUploaderAction: () -> Void

    init(
        gallery: Gallery,
        galleryDetail: GalleryDetail,
        user: User,
        favorAction: @escaping (Int) -> Void,
        unfavorAction: @escaping () -> Void,
        navigateReadingAction: @escaping () -> Void,
        navigateUploaderAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.user = user
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
                Text(galleryDetail.jpnTitle ?? galleryDetail.title).font(.title3.bold()).lineLimit(3)
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
            .frame(height: Defaults.ImageSize.headerH)
        }
    }
}

// MARK: DescriptionSection
private struct DescriptionSection: View {
    private let gallery: Gallery
    private let detail: GalleryDetail
    private let navigateGalleryInfosAction: () -> Void

    init(
        gallery: Gallery, detail: GalleryDetail,
        navigateGalleryInfosAction: @escaping () -> Void
    ) {
        self.gallery = gallery
        self.detail = detail
        self.navigateGalleryInfosAction = navigateGalleryInfosAction
    }

    private var infos: [DescScrollInfo] {[
        DescScrollInfo(
            title: "DESC_SCROLL_ITEM_FAVORITED", numeral: "Times",
            value: String(detail.favoredCount)
        ),
        DescScrollInfo(
            title: "Language",
            numeral: detail.language.name,
            value: detail.languageAbbr
        ),
        DescScrollInfo(
            title: "",
            titleKey: LocalizedStringKey(
                "\(detail.ratingCount) Ratings"
            ),
            numeral: "", value: "",
            rating: detail.rating, isRating: true
        ),
        DescScrollInfo(
            title: "Page Count", numeral: "Pages",
            value: String(detail.pageCount)
        ),
        DescScrollInfo(
            title: "File Size", numeral: detail.sizeType,
            value: String(detail.sizeCount)
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
    @Binding private var userRating: Int
    @Binding private var showUserRating: Bool
    private let rateAction: (Int) -> Void
    private let navigateSimilarGalleryAction: () -> Void

    init(
        galleryDetail: GalleryDetail,
        userRating: Binding<Int>,
        showUserRating: Binding<Bool>,
        rateAction: @escaping (Int) -> Void,
        navigateSimilarGalleryAction: @escaping () -> Void
    ) {
        self.galleryDetail = galleryDetail
        _userRating = userRating
        _showUserRating = showUserRating
        self.rateAction = rateAction
        self.navigateSimilarGalleryAction = navigateSimilarGalleryAction
    }

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button {
                        withAnimation { showUserRating.toggle() }
                    } label: {
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
                                .onChanged(updateRating)
                                .onEnded(confirmRating)
                        )
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }

    private func updateRating(value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
    private func confirmRating(value: DragGesture.Value) {
        updateRating(value: value)
        rateAction(userRating)
        HapticUtil.generateFeedback(style: .soft)
        withAnimation(Animation.default.delay(1)) {
            showUserRating.toggle()
        }
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
    private var previewsWithIndies: [(Int, String)] {
        previews
            .map({ ($0.key, $0.value) })
            .sorted { lhs, rhs in lhs.0 < rhs.0 }
    }

    var body: some View {
        SubSection(title: "Preview", showAll: pageCount > 20, showAllAction: navigatePreviewsAction) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(previewsWithIndies, id: \.0) { index, previewURL in
                        let (url, modifier) = PreviewResolver.getPreviewConfigs(originalURL: previewURL)
                        KFImage.url(URL(string: url), cacheKey: previewURL)
                            .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) }
                            .imageModifier(modifier).fade(duration: 0.25).resizable().scaledToFit()
                            .frame(width: width, height: height).onTapGesture { navigateReadingAction(index) }
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
        SubSection(title: "Comment", showAll: !comments.isEmpty, showAllAction: navigateCommentAction) {
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
                    initialState: .init(galleryID: .init()),
                    reducer: detailReducer,
                    environment: DetailEnvironment(
                        hapticClient: .live,
                        cookiesClient: .live,
                        databaseClient: .live
                    )
                ),
                user: .init(),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
