//
//  AuxiliaryMenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/29/23.
//

import CoreData
import SwiftUI
import SettingsAccess

struct AuxiliaryMenuView: View {
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var settingsManager: SettingsManager

    @AppStorage("settingsTab") var settingsTab: String?
    @AppStorage("selectedModel") private var selectedModelURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            MenuButtonView(title: "Manage Quick Actions") {
                settingsTab = Tab.quickActions.id
                settingsManager.showModal()
                modalManager.closeModal()
            }

            MenuButtonView(title: "Settings") {
                settingsTab = Tab.general.id
                settingsManager.showModal()
                modalManager.closeModal()
            }
        }
        .padding(5)
        .frame(width: 200)
    }
}

#Preview {
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
        promptManager.addPrompt(prompt)
    }

    let modalManager = ModalManager()

    return AuxiliaryMenuView(
        modalManager: modalManager,
        settingsManager: SettingsManager(context: context)
    )
}
