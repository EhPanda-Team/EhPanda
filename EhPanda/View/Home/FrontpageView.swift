//
//  FrontpageView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/18.
//

import SwiftUI

struct FrontpageView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    var body: some View {
        GenericList(
            items: homeInfo.frontpageItems,
            setting: setting,
            pageNumber: homeInfo.frontpagePageNumber,
            loadingFlag: homeInfo.frontpageLoading,
            loadError: homeInfo.frontpageLoadError,
            moreLoadingFlag: homeInfo.moreFrontpageLoading,
            moreLoadFailedFlag: homeInfo.moreFrontpageLoadFailed,
            fetchAction: fetchFrontpageItems,
            loadMoreAction: fetchMoreFrontpageItems,
            translateAction: {
                settings.tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .navigationTitle("Frontpage")
    }
}

private extension FrontpageView {
    func fetchFrontpageItems() {
        store.dispatch(.fetchFrontpageItems())
    }
    func fetchMoreFrontpageItems() {
        store.dispatch(.fetchMoreFrontpageItems)
    }
}

struct FrontpageView_Previews: PreviewProvider {
    static var previews: some View {
        FrontpageView().environmentObject(Store.preview)
    }
}
