//
//  QuickActionsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/15/23.
//

import SwiftUI

struct QuickActionRow: View {
    let quickAction: PromptEntry
    let isActive: Bool
    @State private var isHovered = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(quickAction.prompt ?? "none")
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .foregroundStyle(isActive ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        isActive ?
                        Color.accentColor :
                        (isHovered ? Color.primary.opacity(0.2) : Color.clear)
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct QuickActionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    @ObservedObject var promptManager: PromptManager

    @State var activeQuickAction: PromptEntry? = nil
    @State private var isEditing: Bool = false
    @State private var mutableLabel: String = ""
    @State private var mutableDetails: String = ""
    @State private var isSheetPresented: Bool = false

    @State private var searchText = ""
    var query: Binding<String> {
        Binding {
            searchText
        } set: { newValue in
            searchText = newValue
            quickActions.nsPredicate = newValue.isEmpty
            ? nil
            : NSPredicate(format: "prompt CONTAINS %@", newValue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Quick Actions header
            HStack {
                Text("Quick Actions").font(.title)

                Spacer()

                // New button for presenting the form sheet
                Button("New Quick Action") {
                    isSheetPresented.toggle()
                    activeQuickAction = nil
                    mutableLabel = activeQuickAction?.prompt ?? ""
                    mutableDetails = activeQuickAction?.details ?? ""
                    isEditing = false
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.accentColor)
                )
                .buttonStyle(.plain)
                .sheet(isPresented: $isSheetPresented) {
                    NewQuickActionForm(onSubmit: { label, details in
                        promptManager.addPrompt(label, details: details)
                        isSheetPresented = false
                    }, onCancel: {
                        isSheetPresented = false
                    })
                }
            }
            .padding()

            // Two-panel view
            HStack {
                VStack {
                    searchBar
                        .padding(10)

                    List(quickActions) { quickAction in
                        Button(action: {
                            activeQuickAction = quickAction
                            mutableLabel = activeQuickAction?.prompt ?? ""
                            mutableDetails = activeQuickAction?.details ?? ""
                            isEditing = false
                        }, label: {
                            QuickActionRow(quickAction: quickAction, isActive: quickAction.id == activeQuickAction?.id)
                        })
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.visible)
                    .scrollContentBackground(.hidden)
                }
                .frame(maxWidth: 200)

                if let activeQuickAction = activeQuickAction {
                    QuickActionDetails(
                        quickAction: activeQuickAction,
                        isEditing: $isEditing,
                        mutableLabel: $mutableLabel,
                        mutableDetails: $mutableDetails,
                        onDelete: {
                            self.activeQuickAction = nil
                            promptManager.removePrompt(with: activeQuickAction.id!)
                        },
                        onSubmit: { newLabel, newDetails in
                            promptManager.updatePrompt(
                                with: activeQuickAction.id!,
                                newLabel: newLabel,
                                newDetails: newDetails
                            )
                        }
                    )
                } else {
                    VStack {
                        Text(
                    """
                    Quickly search for specific quick actions using the search bar or scroll through the list to find the one you want.

                    You can then edit or delete them, or create a brand new one.
                    """
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()

                        Spacer()
                    }
                }

                Spacer()
            }
        }
    }

    private var searchBar: some View {
        TextField(text: query) {
            Text("Search quick actions...")
        }
        .textFieldStyle(.plain)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primary.opacity(0.1))
        )
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
    let samplePrompts = [
        "this is a sample prompt",
        "this is an active prompt",
        "this is a slightly longer prompt",
    ]
    for prompt in samplePrompts {
        let newPrompt = PromptEntry(context: context)
        newPrompt.id = UUID()
        newPrompt.prompt = prompt
    }

    return QuickActionsView(promptManager: promptManager)
        .environment(\.managedObjectContext, context)
}
