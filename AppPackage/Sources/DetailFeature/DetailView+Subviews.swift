import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Kingfisher
import Resources
import SFSafeSymbolsExt
import SwiftUI
import TagTranslationFeature

// MARK: DescriptionSection
struct DescriptionSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let navigateGalleryInfosAction: () -> Void

    // 60pt at default (.large); scales with Dynamic Type relative to the row's dominant text style (.title3).
    @ScaledMetric(relativeTo: .title3) private var rowHeight: CGFloat = 60
    /// The designed width floor for one column: 80pt is exactly the width of the five rating stars
    /// drawn at `.caption` at the default size, and they are the widest fixed member any column has
    /// to hold.
    private static let designedColumnMinWidth: CGFloat = 80
    // Scales that floor on the stars' own metric, so it stays the star row as they grow rather than
    // becoming a clip on it. Symbol widths snap to whole points and so track the metric only to
    // within a couple of points — measured across the whole ramp the floor leads the star row
    // everywhere except `.xxxLarge`, where it trails it by 1.7pt, which is less than the symbols'
    // own side bearing. Below the default size the metric would shrink the floor instead; `max`
    // holds it at the designed 80, because narrowing the designed column is not what this is for.
    @ScaledMetric(relativeTo: .caption) private var scaledColumnMinWidth = DescriptionSection.designedColumnMinWidth
    private var columnMinWidth: CGFloat { max(scaledColumnMinWidth, Self.designedColumnMinWidth) }
    // The share of the container one column may take. 90 rather than 100 so a column that has spent
    // its whole budget still leaves a sliver of its neighbour on screen: one that spans the
    // container edge to edge reads as the whole strip and hides that there is more to scroll.
    private let columnWidthFraction: CGFloat = 0.9

    private var infos: [DescScrollInfo] {[
        DescScrollInfo(
            title: .favorited,
            description: String(localized: .favoritedUnit),
            value: .init(galleryDetail.favoritedCount)
        ),
        DescScrollInfo(
            title: .RLocalizable.language,
            description: String(localized: galleryDetail.language.value),
            value: galleryDetail.language.abbreviation,
            isValueDecorative: true
        ),
        DescScrollInfo(
            title: .ratingsCount(count: galleryDetail.ratingCount),
            description: .init(), value: .init(), rating: galleryDetail.rating, isRating: true
        ),
        DescScrollInfo(
            title: .pageCount,
            description: String(localized: .pageCountUnit),
            value: .init(galleryDetail.pageCount)
        ),
        DescScrollInfo(
            title: .fileSize,
            description: galleryDetail.sizeType,
            value: .init(galleryDetail.sizeCount),
            accessibilityDescription: galleryDetail.accessibilitySizeUnit(
                quantity: Double(galleryDetail.sizeCount)
            )
        )
    ]}
    /// The strip stays a strip at every size — columns side by side, scrolled horizontally, never
    /// stacked. What gives is a column's *width*.
    ///
    /// The designed rule, a fifth of the container and never below 80 pt, holds the text at the
    /// default size and nothing beyond it: a fifth of a phone is 78 pt, while the five rating stars
    /// alone are 250 pt across at `.accessibility5` and the captions above them three times taller,
    /// so the columns used to abbreviate their captions, then their values, and clip the rating row
    /// at both ends. So the floor scales with the text it has to hold (``columnMinWidth``) and the
    /// whole budget is capped at ``columnWidthFraction`` of the container: a column grows into that
    /// budget and its text wraps inside it, instead of being clipped by it.
    ///
    /// The designed height is a pin at and below the default size and a floor above it, so a
    /// caption that wrapped inside its column makes the strip taller rather than being cut off by
    /// it. At the default size the scaled floor is its literal 80, the cap cannot bind — it only
    /// could on a container narrower than 89 pt — and the content is shorter than the pin, so the
    /// strip renders exactly as designed, which is what default-size parity requires.
    @ViewBuilder var body: some View {
        if dynamicTypeSize <= .large {
            strip.frame(height: rowHeight)
        } else {
            strip.frame(minHeight: rowHeight)
        }
    }

    private var strip: some View {
        let minWidth = columnMinWidth
        let fraction = columnWidthFraction
        let itemWidth: (CGFloat, Axis) -> CGFloat = { width, _ in
            min(max(width / 5, minWidth), width * fraction)
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(infos) { info in
                    item(for: info)
                        .containerRelativeFrame(.horizontal, itemWidth)
                        .drawingGroup()
                    Divider()
                    if info == infos.last {
                        galleryInfosButton
                            .containerRelativeFrame(.horizontal, itemWidth)
                    }
                }
                .withHorizontalSpacing()
            }
        }
    }

    private var galleryInfosButton: some View {
        Button(action: navigateGalleryInfosAction) {
            Label(.metadataGalleryInfos, systemSymbol: .ellipsis)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.bold))
        }
    }

    @ViewBuilder private func item(for info: DescScrollInfo) -> some View {
        if info.isRating {
            DescScrollRatingItem(title: info.title, rating: info.rating)
        } else {
            DescScrollItem(
                title: info.title,
                value: info.value,
                description: info.description,
                isValueDecorative: info.isValueDecorative,
                accessibilityDescription: info.accessibilityDescription
            )
        }
    }
}

extension DescriptionSection {
    struct DescScrollInfo: Identifiable, Equatable {
        var id: String { String(localized: title) }
        let title: LocalizedStringResource
        let description: String
        let value: String
        var rating: Float = 0
        var isRating = false
        var isValueDecorative = false
        var accessibilityDescription: String?
    }
    struct DescScrollItem: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        let title: LocalizedStringResource
        let value: String
        let description: String
        let isValueDecorative: Bool
        let accessibilityDescription: String?

        var body: some View {
            VStack(spacing: 3) {
                Text(title).textCase(.uppercase).font(.caption)
                valueWithUnit
            }
            .accessibilityElement(children: .combine)
        }

        /// The value and the unit beneath it ("314.3" over "MB", "156" over "Pages") are one reading:
        /// exposed apart, the number is a bare figure the audit reports as "Label not human-readable"
        /// (Phase 16, the file-size column on iPad) and VoiceOver announces without its unit. The
        /// inner stack keeps the outer 3-point spacing, so the column lays out exactly as before.
        private var valueWithUnit: some View {
            VStack(spacing: 3) {
                Text(value)
                    .fontWeight(.medium)
                    .font(.title3)
                    .lineLimit(valueLineLimit)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: value)
                    .accessibilityHidden(isValueDecorative)
                Text(description)
                    .font(.caption)
                    .accessibilityLabel(accessibilityDescription ?? description)
            }
        }

        /// The designed single line is kept at and below the default size, where the strip's height
        /// is pinned and a second line would be cut off. Above it the column grew with the text and
        /// the strip's height became a floor, so the cap is lifted: a count that has lost digits is
        /// a value removed, while a wrapped one is merely taller.
        private var valueLineLimit: Int? {
            dynamicTypeSize <= .large ? 1 : nil
        }
    }
    struct DescScrollRatingItem: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        let title: LocalizedStringResource
        let rating: Float

        var body: some View {
            VStack(spacing: 3) {
                Text(title)
                    .textCase(.uppercase)
                    .font(.caption)
                    .lineLimit(titleLineLimit)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: title)
                Text(String(format: "%.2f", rating))
                    .fontWeight(.medium)
                    .font(.title3)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(rating)))
                    .animation(.default, value: rating)
                // The five symbols are the rating itself, not decoration: three drawn stars for a
                // 4.50 rating misstate the value. They set the column's width floor, so they are
                // never the member that gets clipped. VoiceOver receives the numeric rating once
                // from the text above, so the drawn stars stay out of its combined element.
                RatingView(rating: rating)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }
            // One element for the column: the caption-sized star group on its own was a 13-point
            // accessibility element, which the audit reports as a hit region too small (16-24);
            // read together, count, value and stars are one fact anyway.
            .accessibilityElement(children: .combine)
        }

        /// The caption carries the rating count, so it is a value as much as a label, and it holds
        /// two words that can share the column or take a line each. It keeps the designed single
        /// line where the strip's height is pinned, and wraps above that.
        private var titleLineLimit: Int? {
            dynamicTypeSize <= .large ? 1 : nil
        }
    }
}

// Section-scoped previews: the full DetailView preview pays the NavigationStack + ScrollView
// scaffolding cost on every canvas update, so iterate on a single section here instead.
#Preview("Description") {
    DescriptionSection(
        gallery: .preview,
        galleryDetail: .preview,
        navigateGalleryInfosAction: {}
    )
}

#Preview("Description, accessibility size") {
    DescriptionSection(
        gallery: .preview,
        galleryDetail: .preview,
        navigateGalleryInfosAction: {}
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

// MARK: ActionSection
struct ActionSection: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let galleryDetail: GalleryDetail
    let userRating: Int
    let showUserRating: Bool
    let showUserRatingAction: () -> Void
    let updateRatingAction: (DragGesture.Value) -> Void
    let confirmRatingAction: (DragGesture.Value) -> Void
    let navigateSimilarGalleryAction: () -> Void
    // 24pt at default (.large); scales with Dynamic Type relative to the nearest text style (.title2, 22pt).
    @ScaledMetric(relativeTo: .title2) private var userRatingSymbolSize: CGFloat = 24

    var body: some View {
        VStack {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading) {
                    actionButtons
                }
            } else {
                HStack {
                    actionButtons
                }
            }
            if showUserRating {
                HStack {
                    RatingView(rating: Float(userRating) / 2)
                        .font(.system(size: userRatingSymbolSize))
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

    @ViewBuilder private var actionButtons: some View {
        Group {
            Button(action: showUserRatingAction) {
                Label {
                    Text(.giveARating)
                        .bold()
                } icon: {
                    Image(systemSymbol: .squareAndPencil)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!didLogin)

            Button(action: navigateSimilarGalleryAction) {
                Label {
                    Text(.similarGallery).bold()
                } icon: {
                    Image(systemSymbol: .photoOnRectangleAngled)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .font(.callout)
        .tint(.primary)
    }
}

@MainActor private func previewActionSection(userRating: Int, showUserRating: Bool) -> some View {
    ActionSection(
        galleryDetail: .preview,
        userRating: userRating,
        showUserRating: showUserRating,
        showUserRatingAction: {},
        updateRatingAction: { _ in },
        confirmRatingAction: { _ in },
        navigateSimilarGalleryAction: {}
    )
}

#Preview("Actions") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(userRating: 0, showUserRating: false)
    }
}

#Preview("Actions (rating shown)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(userRating: 7, showUserRating: true)
    }
}

// MARK: TagsSection
struct TagsSection: View {
    let tags: [GalleryTag]
    let showsImages: Bool
    let voteTagAction: (String, Int) -> Void
    // Carries the tapped tag's namespace alongside the assembled search keyword so the reducer can
    // emit the namespace without parsing it back out of the keyword (which would be tag content).
    let navigateSearchAction: (String, TagNamespace?) -> Void
    let navigateTagDetailAction: (TagDetail) -> Void
    let translateAction: (String) -> TagTranslationLookup

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(
                    tag: tag, showsImages: showsImages,
                    voteTagAction: voteTagAction,
                    navigateSearchAction: navigateSearchAction,
                    navigateTagDetailAction: navigateTagDetailAction,
                    translateAction: translateAction
                )
            }
        }
        .padding(.horizontal)
    }
}

extension TagsSection {
    struct TagRow: View {
        @SharedReader(.didLogin) private var didLogin: Bool
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        let tag: GalleryTag
        let showsImages: Bool
        let voteTagAction: (String, Int) -> Void
        // Mirrors `TagsSection`: the row passes the namespace it already holds for its header text,
        // so no caller has to recover it from the assembled keyword.
        let navigateSearchAction: (String, TagNamespace?) -> Void
        let navigateTagDetailAction: (TagDetail) -> Void
        let translateAction: (String) -> TagTranslationLookup

        private var reversedPrimary: Color { colorScheme == .light ? .white : .black }
        private var backgroundColor: Color { Color(.systemGray5) }
        private var padding: EdgeInsets { .init(top: 5, leading: 14, bottom: 5, trailing: 14) }

        /// The namespace chip is a whole tag-sized block sitting in front of the cloud of its
        /// children, so as the type size grows it takes an ever larger share of the row and leaves
        /// the cloud a channel too narrow to flow in — every child ends up on a line of its own,
        /// indented under a chip that is wider than they are. Stacked, the chip heads its children
        /// the way a section header heads a section, and the cloud flows across the whole row.
        ///
        /// The arrangement is chosen by an explicit size read, not by `ViewThatFits`: the cloud is a
        /// flow layout whose *ideal* width is every child on one line, so no candidate containing it
        /// can report a fitting width and the fallback would win at every size, the default
        /// included. Below the accessibility sizes the designed row renders verbatim.
        ///
        /// The 8pt gap is deliberately narrower than the 14pt of air inside the chip: the chip and
        /// its children are one group, and the gap has to read as smaller than the space separating
        /// this row from the next one.
        @ViewBuilder var body: some View {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    namespaceChip
                    tagCloud
                }
            } else {
                HStack(alignment: .top) {
                    namespaceChip
                    tagCloud
                }
            }
        }

        private var namespaceChip: some View {
            Text(tag.namespace.map({ String(localized: $0.value) }) ?? tag.rawNamespace)
                .font(.subheadline.bold())
                .foregroundStyle(reversedPrimary)
                .padding(padding)
                .background(Color(.systemGray))
                .clipShape(.rect(cornerRadius: 5))
        }

        private var tagCloud: some View {
            TagCloudView(data: tag.contents) { content in
                tagContentView(content: content)
            }
        }

        @ViewBuilder
        private func tagContentView(content: GalleryTag.Content) -> some View {
            let translation = translateAction(content.rawNamespace + content.text).translation
            Button {
                navigateSearchAction(content.serachKeyword(tag: tag), tag.namespace)
            } label: {
                TagCloudCell(
                    text: translation?.displayValue ?? content.text,
                    imageURL: translation?.valueImageURL,
                    showsImages: showsImages,
                    font: .subheadline, padding: padding, textColor: .primary,
                    backgroundColor: backgroundColor
                )
            }
            .contextMenu {
                tagContextMenu(content: content, translation: translation)
            }
            // SwiftUI surfaces swipe actions, but not context-menu items, as VoiceOver custom
            // actions (16-CONTRAST-AUDIT, `CONTEXTMENU=not-exposed`), so the builder that fills the
            // menu also fills the Actions rotor: an action can never exist without its menu item.
            .accessibilityActions {
                tagContextMenu(content: content, translation: translation)
            }
        }

        @ViewBuilder
        private func tagContextMenu(
            content: GalleryTag.Content,
            translation: TagTranslation?
        ) -> some View {
            if let translation = translation,
               let description = translation.descriptionPlainText,
               !description.isEmpty {
                Button {
                    navigateTagDetailAction(.init(
                        title: translation.displayValue, description: description,
                        imageURLs: translation.descriptionImageURLs,
                        links: translation.links
                    ))
                } label: {
                    Label(.RLocalizable.detail, systemSymbol: .richtextPage)
                }
            }
            if didLogin {
                tagVoteButtons(content: content)
            }
        }

        @ViewBuilder
        private func tagVoteButtons(content: GalleryTag.Content) -> some View {
            if content.isVotedUp || content.isVotedDown {
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), content.isVotedUp ? -1 : 1)
                } label: {
                    Label(.withdrawVote, systemSymbol: content.isVotedUp ? .handThumbsup : .handThumbsdown)
                        .symbolVariant(.fill)
                }
            } else {
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), 1)
                } label: {
                    Label(.voteUp, systemSymbol: .handThumbsup)
                }
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), -1)
                } label: {
                    Label(.voteDown, systemSymbol: .handThumbsdown)
                }
            }
        }
    }
}

// `translateAction` returns the word unchanged: previewing the tag layout does not need a
// populated TagTranslator, and returning no translation keeps the rows on their raw text.
#Preview("Tags") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        TagsSection(
            tags: [
                .init(rawNamespace: "language", contents: [
                    .init(rawNamespace: "language", text: "japanese", isVotedUp: false, isVotedDown: false),
                    .init(rawNamespace: "language", text: "translated", isVotedUp: true, isVotedDown: false)
                ]),
                .init(rawNamespace: "artist", contents: [
                    .init(rawNamespace: "artist", text: "Anonymous", isVotedUp: false, isVotedDown: false)
                ])
            ],
            showsImages: false,
            voteTagAction: { _, _ in },
            navigateSearchAction: { _, _ in },
            navigateTagDetailAction: { _ in },
            translateAction: { .init(text: $0, translation: nil) }
        )
    }
}

// MARK: PreviewsSection
struct PreviewsSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let pageCount: Int
    let previewURLs: [Int: URL]
    let navigatePreviewsAction: () -> Void
    let navigateReadingAction: (Int) -> Void

    private var width: CGFloat {
        DetailLayout.previewWidth(regular: horizontalSizeClass == .regular)
    }
    private var height: CGFloat { width / Defaults.ImageSize.previewAspect }

    var body: some View {
        SubSection(
            title: .previews,
            showAll: pageCount > 20, showAllAction: navigatePreviewsAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(previewURLs.tuples.sorted(by: { $0.0 < $1.0 }), id: \.0) { index, previewURL in
                        Button {
                            navigateReadingAction(index)
                        } label: {
                            PreviewImageView(originalURL: previewURL)
                                .frame(width: width, height: height)
                        }
                        // The thumbnail is the button's only content; the page it opens is its name.
                        .accessibilityLabel(.accessibilityPreviewPage(page: index))
                    }
                    .withHorizontalSpacing(height: height)
                }
            }
        }
    }
}

// The thumbnails are remote, so the canvas shows placeholders — this previews the row layout.
#Preview("Previews row") {
    PreviewsSection(
        pageCount: 114,
        previewURLs: [0: .mock, 1: .mock, 2: .mock, 3: .mock],
        navigatePreviewsAction: {},
        navigateReadingAction: { _ in }
    )
}

// MARK: CommentsSection
struct CommentsSection: View {
    @SharedReader(.didLogin) private var didLogin: Bool

    let comments: [GalleryComment]
    let navigateCommentAction: () -> Void
    let navigatePostCommentAction: () -> Void

    private var backgroundColor: Color { Color(.systemGray5) }

    var body: some View {
        SubSection(
            title: .comments,
            showAll: !comments.isEmpty, showAllAction: navigateCommentAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(min(comments.count, 6))) { comment in
                        DetailView.CommentCell(comment: comment, backgroundColor: backgroundColor)
                    }
                    .withHorizontalSpacing()
                }
                .drawingGroup()
            }
            CommentButton(backgroundColor: backgroundColor, action: navigatePostCommentAction)
                .padding(.horizontal).disabled(!didLogin)
        }
    }
}

private func previewComment(
    id: String, author: String, score: String, votedUp: Bool, text: String
) -> GalleryComment {
    .init(
        votedUp: votedUp, votedDown: false, votable: true, editable: false,
        score: score, author: author,
        contents: [.init(type: .plainText, text: text)],
        commentID: id, commentDate: .now
    )
}

#Preview("Comments") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        CommentsSection(
            comments: [
                previewComment(
                    id: "0", author: "Nreo", score: "+15", votedUp: false,
                    text: "Thanks for the upload, great quality scans!"
                ),
                previewComment(
                    id: "1", author: "Chihchy", score: "+42", votedUp: true,
                    text: "Agreed. The later pages look excellent."
                )
            ],
            navigateCommentAction: {},
            navigatePostCommentAction: {}
        )
    }
}

#Preview("Comments (empty)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        CommentsSection(
            comments: [],
            navigateCommentAction: {},
            navigatePostCommentAction: {}
        )
    }
}
