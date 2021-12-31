//
//  SettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import Foundation
import ComposableArchitecture

struct SettingState: Equatable {
    @BindableState var sheetState: SettingViewSheetState?
    @BindableState var route: SettingRowType?
}

enum SettingAction: BindableAction {
    case binding(BindingAction<SettingState>)
    case setRoute(SettingRowType?)
    case setSheetState(SettingViewSheetState?)
}

let settingReducer = Reducer<SettingState, SettingAction, AnyEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .binding:
        return .none

    case .setRoute(let route):
        state.route = route
        return .none

    case .setSheetState(let sheetState):
        state.sheetState = sheetState
        return .none
    }
}
.binding()
