//
//  MenuPromptView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/23/23.
//

import SwiftUI

struct MenuPromptView: View {
    @Binding var prompt: PromptEntry
    var isActive: Bool
    @Binding var isEditing: Bool
    var onDelete: (() -> Void)?
    var onUpdate: ((String) -> Void)?

    @State private var isHovering: Bool = false

    var body: some View {
        HStack {
            Image(systemName: isActive ? "paperclip.circle.fill" : "paperclip.circle")
                .resizable()
                .frame(width: 24, height: 24)
                .symbolRenderingMode(isActive ? .palette : .monochrome)
                .foregroundStyle(.primary, .blue)

            if isEditing {
                TextField("", text: Binding(
                    get: { self.prompt.prompt ?? "" },
                    set: { self.prompt.prompt = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    isEditing = false
                    if let newContent = prompt.prompt, !newContent.isEmpty {
                        onUpdate?(newContent)
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
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovering ? Color.gray : Color.clear)
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
            MenuPromptView(prompt: .constant(prompt), isActive: false, isEditing: $isNotEditing)
            MenuPromptView(prompt: .constant(prompt), isActive: true, isEditing: $isNotEditing)
            MenuPromptView(prompt: .constant(prompt), isActive: false, isEditing: $isEditing)
            MenuPromptView(prompt: .constant(prompt), isActive: true, isEditing: $isEditing)
        }
    }
}
