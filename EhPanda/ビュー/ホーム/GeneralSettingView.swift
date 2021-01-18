//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import Kingfisher

struct GeneralSettingView: View {
    @EnvironmentObject var store: Store
    
    var setting: Setting? {
        store.appState.settings.setting
    }
    
    var body: some View {
        if let setting = setting {
            Form {
                Section(header: Text("キャッシュ")) {
                    Button(action: toggleClearImgCaches) {
                        HStack {
                            Text("画像キャッシュを削除")
                            Spacer()
                            Text(setting.diskImageCacheSize)
                        }
                        .foregroundColor(.primary)
                    }
                    Button(action: toggleClearWebCaches) {
                        HStack {
                            Text("ウェブキャッシュを削除")
                            Spacer()
                            Text(browsingCaches())
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitle("一般")
        }
    }
    
    func toggleClearImgCaches() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .clearImgCaches))
    }
    func toggleClearWebCaches() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .clearWebCaches))
    }
}
