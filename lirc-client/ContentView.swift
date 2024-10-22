//
//  ContentView.swift
//  lirc-client
//
//  Created by Jeffrey Sisson on 10/10/24.
//

import SwiftUI
import SwiftData
import Network

struct RemoteForm: View {
    let buttonNames: [String:String] = [
        "KEY_VOLUMEUP": "speaker.plus.fill",
        "KEY_VOLUMEDOWN": "speaker.minus.fill",
        "KEY_POWER": "power.circle.fill",
        "KEY_CD": "cable.coaxial",
        "KEY_RADIO": "radio.fill",
        "KEY_RECORD": "record.circle.fill",
        "KEY_SLEEP": "sleep.circle.fill",
    ]
    var host: String
    var port: String
    var remoteGroup: RemotesGroup
    var selectedRemote: Remote? { remoteGroup.remotes.first(where: { $0.name == remoteGroup.selectedRemote})}
    var body: some View {
            Picker("Remote:", selection: Bindable(remoteGroup).selectedRemote) {
                Text("None selected").tag(nil as String?)
                ForEach(remoteGroup.remotes) { remote in
                    Text(remote.name).tag(remote.name as String?)
                }
            }.onAppear {
                if remoteGroup.remotes.isEmpty {
                    Task {
                        let result = await getLircRemotes(host: NWEndpoint.Host(host), port: NWEndpoint.Port(port)!)
                        remoteGroup.remotes = result
                    }
                }
            }
            if selectedRemote != nil {
                ForEach(selectedRemote!.commands, id: \.self) { command in
                    Button(
                        command,
                        systemImage: buttonNames[command] ?? "",
                        action: {
                            onCommand(command: "SEND_ONCE \(selectedRemote!.name) \(command)")
                        }
                    ).controlSize(.extraLarge)
                }
            }
    }
    func onCommand(command: String) {
        Task {
            do {
                _ = try await sendLircdCommand(host: NWEndpoint.Host(host), port: NWEndpoint.Port(port)!, command: command)
            } catch {
                print("error \(error)")
            }
        }
    }
}

struct HostForm: View {
    var remoteGroup: RemotesGroup
    @State private var draftHost: String
    @State private var draftPort: String
    init(remoteGroup: RemotesGroup) {
        self.remoteGroup = remoteGroup
        self.draftHost = remoteGroup.host
        self.draftPort = remoteGroup.port
    }
    var editing: Bool { remoteGroup.host != draftHost || remoteGroup.port != draftPort }
    var body: some View {
        Form {
            HStack {
                TextField("Host:", text: $draftHost)
                TextField("Port:",
                    text: $draftPort,
                    prompt: Text("8765")
                ).frame(width:120)
                    Button("Save",
                       action: {
                            remoteGroup.host = draftHost
                            remoteGroup.port = draftPort
                        }
                    )
                    .disabled(!editing)

            }
        }
    }
    
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var remotesGroups: [RemotesGroup]
    var remoteGroup: RemotesGroup? { remotesGroups.first }
    @State private var selectedRemote: String? = nil
    
    var body: some View {
        VStack(
            alignment:.leading
        ) {
                if remoteGroup != nil {
                    Section {
                        HostForm(remoteGroup: remoteGroup!)
                    }
                    if remoteGroup!.serverSet() {
                        Section {
                            RemoteForm(
                                host: remoteGroup!.host,
                                port: remoteGroup!.port.isEmpty ? "8765" : remoteGroup!.port,
                                remoteGroup:remoteGroup!
                            )
                        }
                        .focusable(true)
                    }
                }

        }
        .padding([.leading,.top,.trailing], 10)
        .containerRelativeFrame(
            [.horizontal, .vertical],
            alignment: .topLeading
        )
        .onAppear {
            if remotesGroups.isEmpty {
                Task {
                    modelContext.insert(RemotesGroup(
                        host: "",
                        port: "",
                        selectedRemote: nil,
                        remotes: []
                    ))
                }
            }
        }
    }
}

struct Previewer: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: RemotesGroup.self, configurations: config)
        ContentView()
            .modelContainer(container)
    }
}
