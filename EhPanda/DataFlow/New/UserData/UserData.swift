//
//  UserData.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI

struct UserData: Equatable {
    @AppEnvStorage(type: User.self) var user: User
    @AppEnvStorage(type: Setting.self) var setting: Setting

    @AppEnvStorage(type: Filter.self, key: "searchFilter")
    var searchFilter: Filter
    @AppEnvStorage(type: Filter.self, key: "globalFilter")
    var globalFilter: Filter
}
