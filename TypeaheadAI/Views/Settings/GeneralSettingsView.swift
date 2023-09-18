//
//  GeneralSettingsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import SwiftUI
import KeyboardShortcuts
import CoreData
import LaunchAtLogin

struct GeneralSettingsView: View {
    @ObservedObject var promptManager: PromptManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFontSize: Double = UserDefaults.standard.double(forKey: "UserFontSize")

    var body: some View {
        VStack(alignment: .leading) {
            Text("General Settings").font(.title)

            Divider()

            Text("Hot-key configurations")
                .font(.headline)
                .padding(.bottom, 5)

            Form {
                VStack(alignment: .trailing) {
                    HStack {
                        KeyboardShortcuts.Recorder("Smart Copy:", name: .specialCopy)
                        Text("Responds to what you've selected.")
                            .frame(width: 325, alignment: .leading)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder("Smart Paste:", name: .specialPaste)
                        Text("Responds to what you've copied.")
                            .frame(width: 325, alignment: .leading)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder("Smart Cut:", name: .specialCut)
                        Text("Responds to what you've screen-captured.")
                            .frame(width: 325, alignment: .leading)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder("Smart Save:", name: .specialSave)
                        Text("Remembers what you've selected. (Work in Progress)")
                            .frame(width: 325, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 10)

            Divider()

            Text("Navigational Shortcuts")
                .font(.headline)
                .padding(.bottom, 5)

            Form {
                HStack {
                    KeyboardShortcuts.Recorder("New Chat:", name: .chatNew)
                    Text("Opens a new chat window")
                        .frame(width: 325, alignment: .leading)
                }
                HStack {
                    KeyboardShortcuts.Recorder("Refresh Chat:", name: .chatRefresh)
                    Text("Clears a chat window")
                        .frame(width: 325, alignment: .leading)
                }
                HStack {
                    KeyboardShortcuts.Recorder("Open Chat:", name: .chatOpen)
                    Text("Opens an existing chat window")
                        .frame(width: 325, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)

            Divider()

            Form {
                HStack(spacing: 40) {
                    Spacer()
                    LaunchAtLogin.Toggle()

                    Button("Reset User Prompts", action: {
                        promptManager.clearPrompts(context: viewContext)
                    })
                    Button("Reset User Settings", action: clearUserDefaults)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    private func clearUserDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create an in-memory Core Data store
        let container = NSPersistentContainer(name: "TypeaheadAI")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        let context = container.viewContext
        let promptManager = PromptManager(context: context)

        // Create some sample prompts
        let samplePrompts = ["this is a sample prompt", "this is an active prompt"]
        for prompt in samplePrompts {
            let newPrompt = PromptEntry(context: context)
            newPrompt.prompt = prompt
            promptManager.addPrompt(prompt, context: context)
        }

        return GeneralSettingsView(
            promptManager: promptManager
        )
        .environment(\.managedObjectContext, context)
    }
}
