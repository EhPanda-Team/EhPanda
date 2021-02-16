//
//  FilterView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct FilterView: View {
    @EnvironmentObject var store: Store
    
    var settings: AppState.Settings {
        store.appState.settings
    }
    var settingsBinding: Binding<AppState.Settings> {
        $store.appState.settings
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    
    var resetFiltersActionSheet: ActionSheet {
        ActionSheet(title: Text("本当に戻しますか？"), buttons: [
            .destructive(Text("戻す"), action: resetFilters),
            .cancel()
        ])
    }
    
    // MARK: FilterView本体
    var body: some View {
        NavigationView {
            if let filter = settings.filter,
               let filterBinding = Binding(settingsBinding.filter) {
                Form {
                    Section(header: Text("基本")) {
                        CategoryView()
                        Button(action: onResetButtonTap) {
                            Text("既定値に戻す")
                                .foregroundColor(.red)
                        }
                        Toggle("高度な設定", isOn: filterBinding.advanced)
                    }
                    if filter.advanced {
                        Section(header: Text("高度")) {
                            Toggle("ギャラリー名を検索", isOn: filterBinding.galleryName)
                            Toggle("ギャラリータグを検索", isOn: filterBinding.galleryTags)
                            Toggle("ギャラリー説明を検索", isOn: filterBinding.galleryDesc)
                            Toggle("トレントファイル名を検索", isOn: filterBinding.torrentFilenames)
                            Toggle("トレントを含むもののみを表示", isOn: filterBinding.onlyWithTorrents)
                            Toggle("低希望タグを検索", isOn: filterBinding.lowPowerTags)
                            Toggle("低評価タグを検索", isOn: filterBinding.downvotedTags)
                            Toggle("削除済みのギャラリーを表示", isOn: filterBinding.expungedGalleries)
                        }
                        Section {
                            Toggle("評価の下限を指定", isOn: filterBinding.minRatingActivated)
                            if filter.minRatingActivated {
                                MinimumRatingSetter(minimum: filterBinding.minRating)
                            }
                            Toggle("ページ数範囲を指定", isOn: filterBinding.pageRangeActivated)
                            if filter.pageRangeActivated {
                                PagesRangeSetter(
                                    lowerBound: filterBinding.pageLowerBound,
                                    upperBound: filterBinding.pageUpperBound
                                )
                            }
                        }
                        Section(header: Text("既定フィルター")) {
                            Toggle("言語フィルターを無効化", isOn: filterBinding.disableLanguage)
                            Toggle("アップローダフィルターを無効化", isOn: filterBinding.disableUploader)
                            Toggle("タグフィルターを無効化", isOn: filterBinding.disableTags)
                        }
                    }
                }
                .actionSheet(item: environmentBinding.filterViewActionSheetState) { item in
                    switch item {
                    case .resetFilters:
                        return resetFiltersActionSheet
                    }
                }
                .navigationBarTitle("フィルター")
            }
        }
        .onAppear(perform: onAppear)
    }
    
    func onAppear() {
        logScreen("FilterView")
        if settings.filter == nil {
            store.dispatch(.initiateFilter)
        }
    }
    
    func onResetButtonTap() {
        store.dispatch(.toggleFilterViewActionSheetState(state: .resetFilters))
    }
    
    func resetFilters() {
        store.dispatch(.initiateFilter)
    }
}

// MARK: カテゴリー
private struct CategoryView: View {
    @EnvironmentObject var store: Store
    
    var filter: Filter? {
        store.appState.settings.filter
    }
    var filterBinding: Binding<Filter>? {
        Binding($store.appState.settings.filter)
    }
    
    let gridItems = [
        GridItem(
            .adaptive(
                minimum: isPadWidth
                    ? 100 : 80,
                maximum: 100
            )
        )
    ]
    
    var body: some View {
        if let filter = filter,
           let filterBinding = filterBinding {
            LazyVGrid(columns: gridItems) {
                ForEach(tuples(filter, filterBinding)) { tuple in
                    CategoryCell(
                        isFiltered: tuple.isFiltered,
                        category: tuple.category
                    )
                }
            }
            .padding(.vertical)
        }
    }
    
    private func tuples(_ filter: Filter, _ filterBinding: Binding<Filter>) -> [TupleCategory] {
        [TupleCategory(isFiltered: filterBinding.doujinshi.isFiltered, category: filter.doujinshi.category),
         TupleCategory(isFiltered: filterBinding.manga.isFiltered, category: filter.manga.category),
         TupleCategory(isFiltered: filterBinding.artist_CG.isFiltered, category: filter.artist_CG.category),
         TupleCategory(isFiltered: filterBinding.game_CG.isFiltered, category: filter.game_CG.category),
         TupleCategory(isFiltered: filterBinding.western.isFiltered, category: filter.western.category),
         TupleCategory(isFiltered: filterBinding.non_h.isFiltered, category: filter.non_h.category),
         TupleCategory(isFiltered: filterBinding.image_set.isFiltered, category: filter.image_set.category),
         TupleCategory(isFiltered: filterBinding.cosplay.isFiltered, category: filter.cosplay.category),
         TupleCategory(isFiltered: filterBinding.asian_porn.isFiltered, category: filter.asian_porn.category),
         TupleCategory(isFiltered: filterBinding.misc.isFiltered, category: filter.misc.category)]
    }
    
    private struct TupleCategory: Identifiable {
        var id = UUID()
        
        let isFiltered: Binding<Bool>
        let category: Category
    }
}

private struct CategoryCell: View {
    @Binding var isFiltered: Bool
    let category: Category
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(
                    isFiltered
                        ? category.color.opacity(0.3)
                        : category.color
                )
            Text(category.jpn.lString())
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, 5)
        }
        .onTapGesture(perform: onTapGesture)
        .cornerRadius(5)
    }
    
    func onTapGesture() {
        isFiltered.toggle()
    }
}

// MARK: 評価下限
private struct MinimumRatingSetter: View {
    @Binding var minimum: Int
    
    var body: some View {
        HStack {
            let star = "つ星".lString()
            Text("評価の下限")
            Spacer()
            Picker(
                selection: $minimum,
                label: Text("\(minimum)" + star)
            ) {
                Text("2" + star).tag(2)
                Text("3" + star).tag(3)
                Text("4" + star).tag(4)
                Text("5" + star).tag(5)
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

// MARK: ページ範囲
private struct PagesRangeSetter: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var lowerBound: String
    @Binding var upperBound: String
    
    var color: Color {
        if colorScheme == .light {
            return Color(.systemGray6)
        } else {
            return Color(.systemGray3)
        }
    }
    
    var body: some View {
        HStack {
            Text("ページ数範囲")
            Spacer()
            TextField("", text: $lowerBound)
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .keyboardType(.numberPad)
                .background(color)
                .frame(width: 50)
                .cornerRadius(5)
            Text("-")
            TextField("", text: $upperBound)
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .keyboardType(.numberPad)
                .background(color)
                .frame(width: 50)
                .cornerRadius(5)
        }
    }
}

// MARK: 定義
enum FilterViewActionSheetState: Identifiable {
    var id: Int { hashValue }
    
    case resetFilters
}
