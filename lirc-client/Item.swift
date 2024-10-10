//
//  Item.swift
//  lirc-client
//
//  Created by Jeffrey Sisson on 10/10/24.
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
