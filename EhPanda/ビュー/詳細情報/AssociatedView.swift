//
//  AssociatedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import SwiftUI

struct AssociatedView: View {
    @EnvironmentObject var store: Store

    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var loadingFlag: Bool {
        detailInfo.associatedItemsLoading
    }
    var loadFailedFlag: Bool {
        detailInfo.associatedItemsLoadFailed
    }
    var notFoundFlag: Bool {
        detailInfo.associatedItemsNotFound
    }
    var moreLoadingFlag: Bool {
        detailInfo.moreAssociatedItemsLoading
    }
    var moreLoadFailedFlag: Bool {
        detailInfo.moreAssociatedItemsLoadFailed
    }
    var assciatedItems: [AssociatedItem] {
        detailInfo.associatedItems
    }
    var assciatedItem: AssociatedItem {
        assciatedItems.count >= depth + 1
            ? assciatedItems[depth] : AssociatedItem(mangas: [])
    }
    var title: String {
        if let title = keyword.title {
            return title
        } else {
            var cat: String?
            var content: String?
            
            if let tagCategory = TagCategory(
                rawValue: keyword.category ?? ""
            ) {
                cat = tagCategory.jpn.lString()
            }
            if let language = Language(
                rawValue: keyword.content?
                    .capitalizingFirstLetter() ?? ""
            ) {
                content = language.translatedLanguage.lString()
            }
            if cat == nil {
                cat = keyword.category
            }
            if content == nil {
                content = keyword.content
            }
            
            return "\(cat ?? ""): \"\(content ?? "")\""
        }
    }
    
    let depth: Int
    let keyword: AssociatedKeyword
    
    var body: some View {
        ScrollView {
            LazyVStack {
                if !assciatedItem.mangas.isEmpty {
                    ForEach(assciatedItem.mangas) { manga in
                        NavigationLink(
                            destination: DetailView(
                                id: manga.id,
                                depth: depth + 1
                            )
                        ) {
                            MangaSummaryRow(manga: manga)
                                .onAppear(perform: {
                                    onRowAppear(manga)
                                })
                        }
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    onLinkTap(manga)
                                }
                        )
                    }
                    if moreLoadingFlag {
                        LoadingView(isCompact: true)
                            .padding()
                    } else if moreLoadFailedFlag {
                        NetworkErrorView(
                            isCompact: true,
                            retryAction: fetchMoreAssociatedItems
                        )
                        .padding()
                    }
                } else if loadingFlag {
                    LoadingView()
                        .padding(.top, 30)
                } else if loadFailedFlag {
                    NetworkErrorView(retryAction: retryAction)
                        .padding(.top, 30)
                } else if notFoundFlag {
                    NotFoundView(retryAction: retryAction)
                        .padding(.top, 30)
                }
            }
            .padding()
        }
        .onAppear(perform: onAppear)
        .navigationBarTitle(title)
    }
    
    func onAppear() {
        logScreen("AssociatedView")
        if assciatedItem.keyword != keyword {
            fetchAssociatedItems()
        }
    }
    func onRowAppear(_ item: Manga) {
        if item == assciatedItem.mangas.last {
            fetchMoreAssociatedItems()
        }
    }
    func onLinkTap(_ item: Manga) {
        logSelectItem(item)
    }
    
    func retryAction() {
        fetchAssociatedItems()
    }
    
    func fetchAssociatedItems() {
        store.dispatch(.fetchAssociatedItems(depth: depth, keyword: keyword))
    }
    func fetchMoreAssociatedItems() {
        store.dispatch(.fetchMoreAssociatedItems(depth: depth, keyword: keyword))
    }
}
