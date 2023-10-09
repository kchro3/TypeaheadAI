//
//  MenuPromptView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/23/23.
//

import SwiftUI

struct MenuPromptView: View {
    var prompt: PromptEntry
    var isActive: Bool
    @Binding var isEditing: Bool
    var onDelete: (() -> Void)?
    var onUpdate: ((String) -> Void)?

    @State private var isHovering: Bool = false
    @State private var localPromptContent: String

    init(
        prompt: PromptEntry,
        isActive: Bool,
        isEditing: Binding<Bool>,
        onDelete: (() -> Void)? = nil,
        onUpdate: ((String) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.isActive = isActive
        self._isEditing = isEditing
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        self._localPromptContent = State(initialValue: prompt.details ?? "")
    }

    var body: some View {
        HStack {
            Image(systemName: isActive ? "paperclip.circle.fill" : "paperclip.circle")
                .resizable()
                .frame(width: 24, height: 24)
                .symbolRenderingMode(isActive ? .palette : .monochrome)
                .foregroundStyle(isActive ? .white : .secondary, Color.accentColor)

            if isEditing {
                TextField("To delete, clear text and enter.", text: $localPromptContent)
                    .textFieldStyle(.plain)
                    .lineLimit(4)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(.secondary.opacity(0.1))
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        isEditing = false
                        if !localPromptContent.isEmpty {
                            onUpdate?(localPromptContent)
                        } else {
                            onDelete?()
                        }
                    }
            } else {
                Text(prompt.prompt ?? "")
                    // On double-click, switch to TextField
                    .onTapGesture(count: 2) {
                        isEditing = true
                    }
                    .foregroundColor(isActive ? .primary : .secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovering ? .primary.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct MenuPromptView_Previews: PreviewProvider {
    @State static var isNotEditing = false
    @State static var isEditing = true

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
        let prompt = PromptEntry(context: context)
        prompt.prompt = "sample prompt"

        return Group {
            MenuPromptView(prompt: prompt, isActive: false, isEditing: $isNotEditing)
            MenuPromptView(prompt: prompt, isActive: true, isEditing: $isNotEditing)
            MenuPromptView(prompt: prompt, isActive: false, isEditing: $isEditing)
            MenuPromptView(prompt: prompt, isActive: true, isEditing: $isEditing)
        }
    }
}
