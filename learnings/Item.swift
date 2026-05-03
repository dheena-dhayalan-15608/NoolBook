//
//  Item.swift
//  learnings
//
//  Created by Dheena Dhayalan P on 5/3/2026.
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
