//
//  SettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import ComposableArchitecture

enum SharedDataSettingAction: BindableAction {
    case binding(BindingAction<Setting>)
}

let sharedDataSettingReducer = Reducer<Setting, SharedDataSettingAction, AnyEnvironment> { _, action, _ in
    Logger.info(action)
    switch action {
    case .binding:
        return .none
    }
}
.binding()
