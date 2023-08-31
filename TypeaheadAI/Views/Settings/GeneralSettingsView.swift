//
//  GeneralSettingsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import SwiftUI
import KeyboardShortcuts
import CoreData

struct GeneralSettingsView: View {
    @ObservedObject var promptManager: PromptManager
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack(alignment: .leading) {
            Text("General Settings").font(.title)

            Divider()

            Text("Hot-key configurations")
                .font(.headline)
                .padding(.bottom, 5)

            Form {
                KeyboardShortcuts.Recorder("Smart Copy:", name: .specialCopy)
                KeyboardShortcuts.Recorder("Smart Paste:", name: .specialPaste)
            }

            Divider()

            Form {
                Button("Reset User Prompts", action: {
                    promptManager.clearPrompts(context: viewContext)
                })
                Button("Reset User Settings", action: clearUserDefaults)
            }

            Spacer()
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
