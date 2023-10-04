//
//  UserIntentsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/4/23.
//

import SwiftUI

struct UserIntentsView: View {
    @ObservedObject var modalManager: ModalManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(modalManager.userIntents.indices, id: \.self) { index in
                    intent(for: index)
                        .padding([.horizontal, .vertical], 5)
                }
            }
        }
    }

    private func intent(for index: Int) -> some View {
        Button(action: {
            modalManager.addUserMessage(modalManager.userIntents[index], implicit: true)
            modalManager.userIntents = []
        }) {
            Text(modalManager.userIntents[index])
                .foregroundStyle(.white)
                .lineLimit(1)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.accentColor.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
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

    var modalManager = ModalManager()
    modalManager.userIntents = [
        "Test",
        "This is a longer sentence",
        "How about a third sentence"
    ]

    return UserIntentsView(modalManager: modalManager)
        .frame(width: 400, height: 200)
}
