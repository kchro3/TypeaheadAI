//
//  ProfileView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/8/23.
//

import SwiftUI
import AppKit
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isShowingMenu = false
    @State private var anchor: UnitPoint = .center
    @State private var isHovered: Bool = false

    @AppStorage("bio") private var bio: String = ""

    private let maxCharacterCount = 500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Profile").font(.title).textSelection(.enabled)

                Divider()

                Text("What should TypeaheadAI know about you to provide better responses?").font(.headline)

                TextEditor(text: $bio)
                    .scrollContentBackground(.hidden)
                    .onChange(of: bio) { newValue in
                        if newValue.count > maxCharacterCount {
                            bio = String(newValue.prefix(maxCharacterCount))
                        }
                    }
                    .padding(10)
                    .background(.primary.opacity(0.1))
                    .cornerRadius(5)
                    .lineSpacing(5)
                    .frame(minHeight: 50, maxHeight: 200)

                Text("Character count: \(bio.count)/\(maxCharacterCount)")
                    .font(.footnote)
                    .foregroundColor(bio.count > maxCharacterCount ? .red : .primary)

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }
}

struct ProfileView_Previews: PreviewProvider {
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

        // Create a few sample history entries
        for i in 0..<5 {
            let entry = MemoEntry(context: context)
            entry.id = UUID()
            entry.content = "Content pretty long context Let's see what's a good length. Content pretty long context Let's see what's a good length. Content pretty long context Let's see what's a good length. Content pretty long context Let's see what's a good length. \(i)"
            entry.summary = "Summary \(i)"
            entry.createdAt = Date()
        }

        return ProfileView()
            .environment(\.managedObjectContext, context)
    }
}
