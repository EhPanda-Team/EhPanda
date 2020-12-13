//
//  MangaStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/11.
//

import Combine

class PopularItemsStore: ObservableObject {
    @Published var popularItems = [Manga]()
    
    func fetchPopularItems() {
        executeAsyncally {
            let items = RequestManager.shared.requestPopularItems()
            executeMainAsyncally { [weak self] in
                self?.popularItems = items
            }
        }
    }
}

class DetailItemsStore: ObservableObject {
    @Published var detailItem: MangaDetail?
    @Published var previewItems = [MangaContent]()
    
    func fetchDetailItem(url: String) {
        executeAsyncally {
            let item = RequestManager.shared.requestDetailItem(url: url)
            executeMainAsyncally { [weak self] in
                self?.detailItem = item
            }
        }
    }
    
    func fetchPreviewItems(url: String) {
        executeAsyncally {
            let items = RequestManager.shared.requestPreviewItems(url: url)
            executeMainAsyncally { [weak self] in
                self?.previewItems = items
            }
        }
    }
}

class ContentItemsStore: ObservableObject {
    @Published var contentItems = [MangaContent]()
    
    func fetchContentItems(url: String) {
        executeAsyncally {
            let items = RequestManager.shared.requestContentItems(url: url)
            executeMainAsyncally { [weak self] in
                self?.contentItems = items
            }
        }
    }
}
