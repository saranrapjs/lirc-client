//
//  Item.swift
//  lirc-client
//
//  Created by Jeffrey Sisson on 10/10/24.
//

import Foundation
import SwiftData


struct Remote: Codable, Identifiable {
    let name: String
    var id: String { name }
    var commands: [String] = []
}

@Model
final class RemotesGroup {
    var host: String = ""
    var port: String = ""
    var selectedRemote: String?
    var remotes: [Remote]
    
    func serverSet() -> Bool {
        return !host.isEmpty
    }
    
    init(host: String, port: String, selectedRemote: String?, remotes: [Remote]) {
        self.host = host
        self.port = port
        self.selectedRemote = selectedRemote
        self.remotes = remotes
    }
}
