//
//  Item.swift
//  YouShu
//
//  Created by Paul Dexin Gong on 2026/7/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
