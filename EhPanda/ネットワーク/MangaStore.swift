//
//  MangaStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/11.
//

import Combine
import Foundation

class ContentItemsStore: ObservableObject {
    @Published var contentItems = [MangaContent]()
    var owner: String
    
    init(owner: String) {
        self.owner = owner
        ePrint("ContentItemsStore(\(owner)) inited!!")
    }
    
    deinit {
        ePrint("ContentItemsStore(\(owner)) deinited!!")
    }
    
    func fetchContentItems(url: String, pages: Int) {
        let queue = DispatchQueue(label: "com.queue.contentFetch")
        let pageCount = Int(ceil(Double(pages)/10))
        for index in 0..<pageCount {
            queue.async {
                let items = RequestManager.shared.requestContentItems(url: url, pageIndex: index)
                
                executeMainAsyncally { [weak self] in
                    self?.contentItems.append(contentsOf: items)
                }
            }
        }
    }
}
