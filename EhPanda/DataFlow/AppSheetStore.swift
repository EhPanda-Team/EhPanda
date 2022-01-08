//
//  AppSheetStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture

struct AppSheetState: Equatable {
    @BindableState var sheetState: AppSheetType?
}
enum AppSheetType: Equatable, Identifiable {
    var id: Int {
        switch self {
        case .newDawn(let greeting):
            return greeting.hashValue
        }
    }

    case newDawn(Greeting)
}

enum AppSheetAction: BindableAction {
    case binding(BindingAction<AppSheetState>)
    case setSheetState(AppSheetType?)
    case fetchGreetingDone(Result<Greeting, AppError>)
}

struct AppSheetEnvironment {}

let appSheetReducer = Reducer<AppSheetState, AppSheetAction, AppSheetEnvironment> { state, action, _ in
    switch action {
    case .binding:
        return .none

    case .setSheetState(let type):
        state.sheetState = type
        return .none

    case .fetchGreetingDone(let result):
        if case .success(let greeting) = result, !greeting.gainedNothing {
            return .init(value: .setSheetState(.newDawn(greeting)))
        }
        return .none
    }
}
.binding()
