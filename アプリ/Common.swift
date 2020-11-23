//
//  Common.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

class Common {
    static func currentClassName() -> String {
        String(describing: self)
    }
}

public func ePrint(_ error: Error) {
    print(error.localizedDescription)
}

public func ePrint(_ string: String) {
    print(string)
}

public func ePrint(_ string: String?) {
    print(string ?? "エラーの内容が解析できませんでした")
}
