//
//  lirc-data.swift
//  lirc-client
//
//  Created by Jeffrey Sisson on 10/10/24.
//

import Foundation
import Network

func sendLircdCommand(host: NWEndpoint.Host, port: NWEndpoint.Port, command: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        let connection = NWConnection(host: host, port: port, using: .tcp)
        var receivedData = ""
        // Define the data handler
        func handleReceivedData(data: Data?) {
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                receivedData += responseString
                if receivedData.contains("END") {
                    connection.cancel() // Close the socket connection
                    continuation.resume(returning: receivedData)
                } else {
                    // Continue receiving data
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            handleReceivedData(data: data)
                        }
                    }
                }
            }
        }
        // Setup the connection state update handler
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: "\(command)\n".data(using: .utf8), completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        // Start receiving data after sending
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                handleReceivedData(data: data)
                            }
                        }
                    }
                })
            case .failed(let error):
                continuation.resume(throwing: error)
            default:
                break
            }
        }
        // Start the connection
        connection.start(queue: .global())
    }
}

func decodeList(raw: String) -> [String] {
    let lines = raw.components(separatedBy: .newlines)

    var result: [String] = []
    var isCollectingData = false
    var itemsToCollect = 0

    // Loop through the lines and extract the data
    for line in lines {
        if line == "DATA" {
            isCollectingData = true // Start collecting data after "DATA"
        } else if line == "END" {
            break // Stop when we reach "END"
        } else if isCollectingData {
            // If the first line after "DATA" is a number, set it as the count of items to collect
            if let numberOfItems = Int(line), itemsToCollect == 0 {
                itemsToCollect = numberOfItems
            } else {
                // Collect the items and decrement the count
                result.append(line)
                itemsToCollect -= 1
                if itemsToCollect == 0 {
                    break // Stop when we've collected the specified number of items
                }
            }
        }
    }

    return result
}

func getRemoteCommands(host: NWEndpoint.Host, port: NWEndpoint.Port, remoteName: String) async throws -> Remote {
    let rawCommandNames = try await sendLircdCommand(host: host, port: port, command: "LIST \(remoteName)")
    let commandNames = decodeList(raw: rawCommandNames).map{command in
        return command.components(separatedBy: " ")[1]
    }

    return Remote(name:remoteName, commands: commandNames)
}

func getLircRemotes(host: NWEndpoint.Host, port: NWEndpoint.Port) async -> [Remote] {
    do {
        let result = try await sendLircdCommand(host: host, port: port, command: "LIST")
        let remoteNames = decodeList(raw: result)
        return try await withThrowingTaskGroup(of: Remote.self) { group in
            var results = [Remote]()
            for remoteName in remoteNames {
                group.addTask { try await getRemoteCommands(host: host, port: port, remoteName: remoteName) }
            }
            for try await remote in group {
                results.append(remote)
            }
            return results
        }
    } catch {
        print("Error: \(error)")
        return []
    }
}
