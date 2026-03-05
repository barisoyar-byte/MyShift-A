//
//  Model.swift
//  MyShift A
//
//  Created by Barış Oyar on 28.02.2026.
//

import SwiftData
import Foundation

@Model
final class Entry {
    var initials: String
    var name: String
    init(initials: String, name: String) {
        self.initials = initials
        self.name = name
    }
}
