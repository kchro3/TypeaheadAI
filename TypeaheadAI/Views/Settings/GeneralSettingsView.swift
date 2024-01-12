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
    @ObservedObject var promptManager: QuickActionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFontSize: Double = UserDefaults.standard.double(forKey: "UserFontSize")
    @AppStorage("isWebSearchEnabled") private var isWebSearchEnabled: Bool = true
    @AppStorage("isAutopilotEnabled") private var isAutopilotEnabled: Bool = true
    @AppStorage("isNarrateEnabled") private var isNarrateEnabled: Bool = false

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
                        KeyboardShortcuts.Recorder(NSLocalizedString("Smart Copy:", comment: ""), name: .specialCopy)
                        Text("Responds to what you've selected.")
                            .frame(width: 325, alignment: .leading)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder(NSLocalizedString("Smart Paste:", comment: ""), name: .specialPaste)
                        Text("Pastes the most recent Typeahead response.")
                            .frame(width: 325, alignment: .leading)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder(NSLocalizedString("Cancel Tasks:", comment: ""), name: .cancelTasks)
                        Text("Aborts any streaming results or autopilot tasks.")
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
                    KeyboardShortcuts.Recorder(NSLocalizedString("New Chat:", comment: ""), name: .chatNew)
                    Text("Opens a new chat window")
                        .frame(width: 325, alignment: .leading)
                }
                HStack {
                    KeyboardShortcuts.Recorder(NSLocalizedString("Open Chat:", comment: ""), name: .chatOpen)
                    Text("Opens an existing chat window")
                        .frame(width: 325, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)

            Divider()

            Form {
                VStack {
                    HStack {
                        Spacer()
                        Button("Reset User Prompts", action: {
                            promptManager.clearPrompts()
                        })
                        Spacer()
                        Button("Reset User Settings", action: clearUserDefaults)
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        LaunchAtLogin.Toggle {
                            Text("Launch at Login")
                        }
                        Spacer()
                        Toggle(isOn: $isWebSearchEnabled) {
                            Text("Enable web search")
                        }
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Toggle(isOn: $isAutopilotEnabled) {
                            Text("Enable Autopilot")
                        }
                        Spacer()
                        Toggle(isOn: $isNarrateEnabled) {
                            Text("Enable Narration")
                        }
                        Spacer()
                    }
                }
            }

            Spacer()

            Divider()

            version
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    @ViewBuilder
    private var version: some View {
        if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            HStack {
                Spacer()
                Text("v\(versionString)")
            }
        } else {
            EmptyView()
        }
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
        let promptManager = QuickActionManager(context: context, backgroundContext: context)

        // Create some sample prompts
        let samplePrompts = ["this is a sample prompt", "this is an active prompt"]
        for prompt in samplePrompts {
            let newPrompt = PromptEntry(context: context)
            newPrompt.prompt = prompt
            promptManager.addPrompt(prompt)
        }

        return GeneralSettingsView(
            promptManager: promptManager
        )
        .environment(\.managedObjectContext, context)
    }
}
