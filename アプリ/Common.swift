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

public func cPrint(_ string: String) {
    print(Common.currentClassName() + ": " + (string))
}

public func ePrint(_ error: Error) {
    cPrint(error.localizedDescription)
}

public func ePrint(_ string: String) {
    cPrint(string)
}

public func ePrint(_ string: String?) {
    cPrint(string ?? "エラーの内容が解析できませんでした")
}
