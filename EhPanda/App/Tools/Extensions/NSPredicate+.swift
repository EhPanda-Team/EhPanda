//
//  NSPredicate+.swift
//  EhPanda
//
//  Created by Chihchy on 2024/01/28.
//

import Foundation

extension NSPredicate {
    convenience init(gid: String) {
        self.init(format: "gid == %@", gid)
    }
}
